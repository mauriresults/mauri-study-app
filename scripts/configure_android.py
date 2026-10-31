#!/usr/bin/env python3
"""Configure Flutter-generated Android manifests for online PDF catalog access."""
from pathlib import Path
import re

manifest=Path(__file__).resolve().parents[1] / 'app/android/app/src/main/AndroidManifest.xml'
if not manifest.exists():
    raise SystemExit('Generate Android platform first with: flutter create --platforms android .')
s=manifest.read_text()
permission='<uses-permission android:name="android.permission.INTERNET" />'
if permission not in s:
    newer,n=re.subn(r'(<manifest\b[^>]*>)',r'\1\n    '+permission,s,count=1,flags=re.DOTALL)
    if n!=1:raise SystemExit('AndroidManifest.xml has an unknown format')
    manifest.write_text(newer)
print('Configured release Internet permission:',manifest)
