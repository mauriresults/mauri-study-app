#!/usr/bin/env python3
"""Bounded, resumable Drive -> independent R2/D1 importer for site-indexed PDFs.

Reads ONLY the app's D1 site_source_files inventory. The original website is
never queried at runtime and its production services are never modified.

Requires CF_ACCOUNT_ID, CF_API_TOKEN, R2_ACCESS_KEY_ID,
R2_SECRET_ACCESS_KEY and GOOGLE_DRIVE_ACCESS_TOKEN (read-only Drive OAuth).
Files are published only after PDF sniffing, local and R2 SHA256 round-trip.
Each failed file gets a persistent error entry and may be retried separately.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
import tempfile
import time
from pathlib import Path
from typing import Any


DB_ID = "124dee36-99ce-4365-8cf9-af0b01b2d1d7"
BUCKET = "mauri-study-files"
PENDING_SQL = """
 SELECT drive_file_id, original_title, level_id, track_id, subject_id,
        kind, exam_year, advertised_size
 FROM site_source_files
 WHERE state IN ({states}) AND LOWER(original_title) LIKE '%.pdf'
 ORDER BY advertised_size, drive_file_id LIMIT ?
"""
FAILURE_SCHEMA = """
 CREATE TABLE IF NOT EXISTS site_import_failures (
   drive_file_id TEXT PRIMARY KEY, attempts INTEGER NOT NULL DEFAULT 0,
   last_error TEXT NOT NULL, updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
 )
"""

class ImportErrorWithStatus(Exception):
    def __init__(self, message: str, status: str = "failed"):
        super().__init__(message)
        self.status = status


def verify_pdf(path: Path, advertised_size: int) -> tuple[int, str]:
    """No HTML or tiny redirect pages can be published as PDF."""
    size = path.stat().st_size
    if not size or (advertised_size and size != advertised_size):
        raise ImportErrorWithStatus(
            f"Size mismatch: expected {advertised_size}, received {size}"
        )
    with path.open("rb") as file:
        if file.read(5) != b"%PDF-":
            raise ImportErrorWithStatus("Not a PDF (missing PDF signature)", "unavailable")
        if size >= 20:
            file.seek(max(0, size - 4096))
            if b"%%EOF" not in file.read():
                raise ImportErrorWithStatus("PDF trailer is missing", "unavailable")
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return size, digest.hexdigest()


def download_pdf(session: requests.Session, file_id: str, destination: Path,
                 access_token: str, max_size: int) -> None:
    url = f"https://www.googleapis.com/drive/v3/files/{file_id}?alt=media"
    with session.get(url, headers={"Authorization": f"Bearer {access_token}"},
                     stream=True, timeout=(20, 90), allow_redirects=True) as response:
        if response.status_code in (401, 403, 404):
            raise ImportErrorWithStatus(f"Drive HTTP {response.status_code}", "unavailable")
        response.raise_for_status()
        declared = int(response.headers.get("content-length") or 0)
        if declared > max_size:
            raise ImportErrorWithStatus("File exceeds per-file limit")
        received = 0
        with destination.open("wb") as output:
            for block in response.iter_content(chunk_size=256 * 1024):
                if not block:
                    continue
                received += len(block)
                if received > max_size:
                    raise ImportErrorWithStatus("File exceeds per-file limit")
                output.write(block)


def make_key(row: dict[str, Any]) -> str:
    for field in ("drive_file_id", "level_id", "track_id"):
        value = row[field]
        if not value or not all(c.isascii() and (c.isalnum() or c in "_-") for c in value):
            raise ValueError(f"Unsafe {field}")
    return (f"site-import/{row['level_id']}/{row['track_id']}/"
            f"{row['drive_file_id']}.pdf")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limit", type=int, default=10)
    parser.add_argument("--max-total-mb", type=int, default=100)
    parser.add_argument("--max-file-mb", type=int, default=75)
    parser.add_argument("--retry-failed", action="store_true")
    parser.add_argument("--rights-confirmed", action="store_true",
                        help="Required confirmation that redistribution rights cover this batch.")
    args = parser.parse_args()
    if not args.rights_confirmed:
        parser.error("Publishing requires --rights-confirmed")
    if not 1 <= args.limit <= 100 or not 1 <= args.max_total_mb <= 500 or not 1 <= args.max_file_mb <= 300:
        parser.error("Invalid limits")
    required = ("CF_ACCOUNT_ID", "CF_API_TOKEN", "R2_ACCESS_KEY_ID",
                "R2_SECRET_ACCESS_KEY", "GOOGLE_DRIVE_ACCESS_TOKEN")
    missing = [x for x in required if not os.environ.get(x)]
    if missing:
        parser.error("Missing credentials: " + ", ".join(missing))

    import boto3
    import requests
    account = os.environ["CF_ACCOUNT_ID"]
    base = (f"https://api.cloudflare.com/client/v4/accounts/{account}"
            f"/d1/database/{DB_ID}/query")
    session = requests.Session()
    cf = requests.Session()
    cf.headers.update({"Authorization": "Bearer " + os.environ["CF_API_TOKEN"]})
    owned_map = json.loads(
        (Path(__file__).parent / "data" / "owned_drive_id_map.json").read_text(encoding="utf-8")
    )["originalToCopy"]
    store = boto3.client("s3",
        endpoint_url=f"https://{account}.r2.cloudflarestorage.com",
        region_name="auto",
        aws_access_key_id=os.environ["R2_ACCESS_KEY_ID"],
        aws_secret_access_key=os.environ["R2_SECRET_ACCESS_KEY"])

    def sql(statement: str, params: list[Any] | None = None) -> list[dict]:
        reply = cf.post(base, json={"sql": statement, "params": params or []}, timeout=60)
        reply.raise_for_status()
        payload = reply.json()
        if not payload.get("success") or not payload.get("result", [{}])[0].get("success"):
            raise RuntimeError("D1 query failed: " + json.dumps(payload.get("errors", [])))
        return payload["result"][0]["results"]

    sql(FAILURE_SCHEMA)
    states = "'pending','failed'" if args.retry_failed else "'pending'"
    rows = sql(PENDING_SQL.format(states=states), [args.limit])
    budget = args.max_total_mb * 1024 * 1024
    max_file = args.max_file_mb * 1024 * 1024
    result: dict[str, Any] = {"examined": 0, "imported": 0, "duplicate": 0,
                               "failed": 0, "unavailable": 0, "bytes": 0}
    for row in rows:
        advertised = row["advertised_size"] or 0
        if advertised > max_file or advertised > budget:
            # Leave pending for another batch rather than claiming success.
            continue
        result["examined"] += 1
        file_id = row["drive_file_id"]
        try:
            with tempfile.TemporaryDirectory(prefix="mauri-study-") as directory:
                path = Path(directory) / "reference.pdf"
                # Prefer authorized MauriResults-owned copies. Keep the original
                # source ID for immutable audit/deduplication in app D1.
                source_id = owned_map.get(file_id, file_id)
                download_pdf(session, source_id, path,
                    os.environ["GOOGLE_DRIVE_ACCESS_TOKEN"], max_file)
                size, digest = verify_pdf(path, advertised)
                if size > budget:
                    continue
                same = sql("SELECT id FROM resources WHERE sha256=? AND published=1 LIMIT 1", [digest])
                if same:
                    sql("UPDATE site_source_files SET state='duplicate', resource_id=?, checked_at=CURRENT_TIMESTAMP WHERE drive_file_id=?",
                        [same[0]["id"], file_id])
                    sql("UPDATE migration_queue SET status='skipped' WHERE drive_file_id=?", [file_id])
                    result["duplicate"] += 1
                    continue
                key = make_key(row)
                try:
                    present = store.head_object(Bucket=BUCKET, Key=key)
                except store.exceptions.NoSuchKey:
                    present = None
                except Exception as error:
                    # S3's HEAD missing-object often reports ClientError 404.
                    if getattr(error, "response", {}).get("ResponseMetadata", {}).get("HTTPStatusCode") != 404:
                        raise
                    present = None
                if present is not None and (int(present["ContentLength"]) != size or
                    present.get("Metadata", {}).get("sha256") != digest):
                    raise ImportErrorWithStatus("Existing R2 key has unexpected content")
                if present is None:
                    store.upload_file(str(path), BUCKET, key, ExtraArgs={
                        "ContentType": "application/pdf", "Metadata": {"sha256": digest}})
                stored = store.head_object(Bucket=BUCKET, Key=key)
                if int(stored["ContentLength"]) != size or stored.get("Metadata", {}).get("sha256") != digest:
                    raise ImportErrorWithStatus("R2 size/metadata mismatch")
                # Independently read the stored bytes, not merely user-provided metadata.
                stream = store.get_object(Bucket=BUCKET, Key=key)["Body"]
                verified = hashlib.sha256()
                stored_bytes = 0
                try:
                    for block in iter(lambda: stream.read(1024 * 1024), b""):
                        verified.update(block)
                        stored_bytes += len(block)
                        if stored_bytes > size:
                            raise ImportErrorWithStatus("R2 object grew during verification")
                finally:
                    stream.close()
                if stored_bytes != size or verified.hexdigest() != digest:
                    raise ImportErrorWithStatus("R2 SHA256 mismatch")
                sql("""INSERT INTO resources
                     (subject_id,title_ar,title_fr,kind,exam_year,object_key,file_size,sha256,published)
                     VALUES(?,?,?, ?,?,?,?,?,1) ON CONFLICT(object_key) DO NOTHING""",
                    [row["subject_id"], row["original_title"], "", row["kind"],
                     row["exam_year"], key, size, digest])
                resource = sql("SELECT id,sha256,published FROM resources WHERE object_key=?", [key])
                if not resource or resource[0]["sha256"] != digest or resource[0]["published"] != 1:
                    raise ImportErrorWithStatus("D1 resource mismatch")
                resource_id = resource[0]["id"]
                sql("""INSERT OR IGNORE INTO import_audit
                      (drive_file_id,resource_id,original_filename,object_key)
                      VALUES(?,?,?,?)""", [file_id, resource_id, row["original_title"], key])
                sql("UPDATE site_source_files SET state='imported',resource_id=?,checked_at=CURRENT_TIMESTAMP WHERE drive_file_id=?",
                    [resource_id, file_id])
                sql("UPDATE migration_queue SET status='imported' WHERE drive_file_id=?", [file_id])
                sql("DELETE FROM site_import_failures WHERE drive_file_id=?", [file_id])
                result["imported"] += 1
                result["bytes"] += size
                budget -= size
                print(f"Imported: {file_id} => resource {resource_id} ({size} bytes)")
        except Exception as error:
            status = error.status if isinstance(error, ImportErrorWithStatus) else "failed"
            message = str(error)[:500]
            sql("""INSERT INTO site_import_failures(drive_file_id,attempts,last_error)
                   VALUES(?,1,?) ON CONFLICT(drive_file_id) DO UPDATE SET
                   attempts=attempts+1,last_error=excluded.last_error,updated_at=CURRENT_TIMESTAMP""",
                [file_id, message])
            sql("UPDATE site_source_files SET state=?,checked_at=CURRENT_TIMESTAMP WHERE drive_file_id=?",
                [status, file_id])
            sql("UPDATE migration_queue SET status='failed' WHERE drive_file_id=?", [file_id])
            result[status] += 1
            print(f"{status}: {file_id}: {message}")
        time.sleep(0.2)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == "__main__":
    main()
