#!/usr/bin/env python3
"""Configure Flutter-generated Android manifests for online PDF catalog access."""
from pathlib import Path
import re
import plistlib

manifest=Path(__file__).resolve().parents[1] / 'app/android/app/src/main/AndroidManifest.xml'
if not manifest.exists():
    raise SystemExit('Generate Android platform first with: flutter create --platforms android .')
s=manifest.read_text()
permission='<uses-permission android:name="android.permission.INTERNET" />'
if permission not in s:
    newer,n=re.subn(r'(<manifest\b[^>]*>)',r'\1\n    '+permission,s,count=1,flags=re.DOTALL)
    if n!=1:raise SystemExit('AndroidManifest.xml has an unknown format')
    s=newer
s,n=re.subn(r'android:label="[^"]*"','android:label="Mauri student"',s,count=1)
if n!=1:raise SystemExit('Android application label was not found')
s=re.sub(r'android:icon="[^"]*"','android:icon="@drawable/ic_mauri_student"',s,count=1)
manifest.write_text(s)
icon=manifest.parent/'res/drawable/ic_mauri_student.xml'
icon.parent.mkdir(parents=True,exist_ok=True)
icon.write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <path android:fillColor="#176349" android:pathData="M0,0h108v108h-108z" />
    <path android:fillColor="#E6BC61" android:pathData="M20,29Q39,25 52,35L52,78Q37,68 20,72z" />
    <path android:fillColor="#FFFFFF" android:pathData="M56,35Q70,25 88,29L88,72Q70,68 56,78z" />
    <path android:strokeColor="#176349" android:strokeWidth="3" android:strokeLineCap="round" android:pathData="M64,43L80,39M64,53L80,49M64,63L77,60" />
    <path android:strokeColor="#FFFFFF" android:strokeWidth="3" android:strokeLineCap="round" android:pathData="M29,40L43,45M29,50L43,55" />
</vector>''')
ios_plist=manifest.parents[4]/'ios/Runner/Info.plist'
if ios_plist.exists():
    with ios_plist.open('rb') as source: data=plistlib.load(source)
    data['CFBundleDisplayName']='Mauri student'
    with ios_plist.open('wb') as target: plistlib.dump(data,target,sort_keys=False)
print('Configured release Internet permission:',manifest)
