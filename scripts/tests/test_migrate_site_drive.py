import hashlib
import importlib.util
import tempfile
import unittest
from pathlib import Path

file = Path(__file__).parents[1] / 'migrate_site_drive.py'
spec = importlib.util.spec_from_file_location('migrate_site_drive', file)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ResumeMigrationValidationTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.path = Path(self.tmp.name) / 'sample.pdf'

    def tearDown(self):
        self.tmp.cleanup()

    def test_valid_pdf_checksum(self):
        pdf = b'%PDF-1.7\\n' + b'valid document fixture\\n' + b'%%EOF'
        self.path.write_bytes(pdf)
        self.assertEqual(module.verify_pdf(self.path, len(pdf)), (len(pdf), hashlib.sha256(pdf).hexdigest()))

    def test_html_cannot_be_published(self):
        self.path.write_bytes(b'<html>sign in</html>')
        with self.assertRaises(module.ImportErrorWithStatus):
            module.verify_pdf(self.path, 0)

    def test_rejects_size_mismatch(self):
        self.path.write_bytes(b'%PDF-1.7\\n%%EOF')
        with self.assertRaises(module.ImportErrorWithStatus):
            module.verify_pdf(self.path, 100)

    def test_missing_pdf_trailer(self):
        self.path.write_bytes(b'%PDF-1.7\\n' + b'not really a finished PDF file')
        with self.assertRaises(module.ImportErrorWithStatus):
            module.verify_pdf(self.path, 0)

    def test_batch_scans_past_oversized_files(self):
        rows = [
            {'drive_file_id': 'big', 'advertised_size': 90 * 1024 * 1024},
            {'drive_file_id': 'small-1', 'advertised_size': 2 * 1024 * 1024},
            {'drive_file_id': 'small-2', 'advertised_size': 3 * 1024 * 1024},
        ]
        selected, skipped = module.select_batch(rows, 2, 10 * 1024 * 1024, 75 * 1024 * 1024)
        self.assertEqual([r['drive_file_id'] for r in selected], ['small-1', 'small-2'])
        self.assertEqual(skipped, 1)

    def test_batch_respects_total_byte_budget(self):
        rows = [
            {'drive_file_id': 'a', 'advertised_size': 6},
            {'drive_file_id': 'b', 'advertised_size': 6},
            {'drive_file_id': 'c', 'advertised_size': 4},
        ]
        selected, skipped = module.select_batch(rows, 3, 10, 10)
        self.assertEqual([r['drive_file_id'] for r in selected], ['a', 'c'])
        self.assertEqual(skipped, 1)

    def test_batch_ignores_unknown_sizes_until_metadata_verified(self):
        self.assertIn('advertised_size > 0', module.PENDING_SQL)

    def test_expired_drive_token_does_not_mark_source_unavailable(self):
        class DeniedResponse:
            status_code = 401
            def __enter__(self): return self
            def __exit__(self, *args): return False
        class Session:
            def get(self, *args, **kwargs): return DeniedResponse()
        with self.assertRaises(SystemExit):
            module.download_pdf(Session(), 'sample', self.path, 'bad-token', 1024)

    def test_storage_keys_never_include_unsafe_segments(self):
        row = {'level_id':'bac','track_id':'site-bac-d','drive_file_id':'123_Ab-c'}
        self.assertEqual(module.make_key(row),'site-import/bac/site-bac-d/123_Ab-c.pdf')
        row['track_id'] = '../website'
        with self.assertRaises(ValueError):module.make_key(row)

if __name__ == '__main__':
    unittest.main()
