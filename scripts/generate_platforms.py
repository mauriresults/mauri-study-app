#!/usr/bin/env python3
"""Generate missing native projects without adding Flutter's counter-app tests.

Existing platform projects and application Dart files are preserved.
"""
from pathlib import Path
import shutil
import subprocess
import tempfile


def main():
    app = Path(__file__).resolve().parents[1] / 'app'
    missing = [name for name in ('android', 'ios') if not (app / name).exists()]
    if not missing:
        print('Native projects already exist')
        return
    with tempfile.TemporaryDirectory(prefix='mauri-study-platforms-') as temporary:
        template = Path(temporary) / 'mauri_study'
        subprocess.run([
            'flutter', 'create', '--org', 'mr.mauri.study',
            '--project-name', 'mauri_study', '--platforms', ','.join(missing),
            '--no-pub', str(template),
        ], check=True)
        for platform in missing:
            shutil.copytree(template / platform, app / platform)
        if not (app / '.metadata').exists():
            shutil.copy2(template / '.metadata', app / '.metadata')
    print('Generated native projects:', ', '.join(missing))


if __name__ == '__main__':
    main()
