#!/usr/bin/env python3
"""Validate a built debug APK's structure and signature, then record SHA-256."""
from pathlib import Path
import hashlib
import os
import subprocess
import zipfile


def main():
    app = Path(__file__).resolve().parents[1] / 'app'
    apk = app / 'build/app/outputs/flutter-apk/app-debug.apk'
    with zipfile.ZipFile(apk) as archive:
        assert archive.testzip() is None, 'APK ZIP integrity check failed'
        assert {'AndroidManifest.xml', 'classes.dex'} <= set(archive.namelist())
        assert 'lib/arm64-v8a/libflutter.so' in archive.namelist()
    sdk = os.environ.get('ANDROID_HOME') or os.environ.get('ANDROID_SDK_ROOT')
    if not sdk:
        raise RuntimeError('Android SDK location is not configured')
    tools = [p for p in (Path(sdk) / 'build-tools').glob('*/apksigner') if p.is_file()]
    if not tools:
        raise RuntimeError('apksigner is unavailable')
    tools.sort(key=lambda p: tuple(int(n) for n in p.parent.name.split('.') if n.isdigit()))
    subprocess.run([str(tools[-1]), 'verify', '--verbose', '--print-certs', str(apk)],check=True)
    badging=subprocess.check_output([str(tools[-1].with_name('aapt')),'dump','badging',str(apk)],text=True)
    if "application-label:'Mauri student'" not in badging:
        raise RuntimeError('APK application label is not Mauri student')
    print('Verified Android application label: Mauri student')
    checksum = hashlib.sha256()
    with apk.open('rb') as source:
        for block in iter(lambda: source.read(8 * 1024 * 1024), b''):
            checksum.update(block)
    line = f'{checksum.hexdigest()}  {apk.name}\n'
    apk.with_suffix('.apk.sha256').write_text(line)
    print(f'Verified APK: {apk.stat().st_size} bytes')
    print(line,end='')


if __name__ == '__main__':
    main()
