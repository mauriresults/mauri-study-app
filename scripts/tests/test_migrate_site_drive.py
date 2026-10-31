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

    def test_storage_keys_never_include_unsafe_segments(self):
        row = {'level_id':'bac','track_id':'site-bac-d','drive_file_id':'123_Ab-c'}
        self.assertEqual(module.make_key(row),'site-import/bac/site-bac-d/123_Ab-c.pdf')
        row['track_id'] = '../website'
        with self.assertRaises(ValueError):module.make_key(row)

if __name__ == '__main__':
    unittest.main()
