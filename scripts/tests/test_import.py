import importlib.util
import io
import hashlib
import tempfile
import unittest
from pathlib import Path

file = Path(__file__).parents[1] / 'import_library.py'
spec = importlib.util.spec_from_file_location('import_library', file)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class ImportValidationTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.good = self.root / 'lesson.pdf'
        self.good.write_bytes(b'%PDF-1.7\nminimal fixture')
        self.row = {'local_file': 'lesson.pdf', 'subject_id': 'bac-d-math',
                    'title_ar': 'تمارين', 'title_fr': '', 'kind': 'exercise',
                    'exam_year': '', 'object_key': 'bac/d/maths/lesson.pdf'}

    def tearDown(self):
        self.tmp.cleanup()

    def test_valid_file(self):
        path, key, *_ = module.validate(self.row, self.root)
        self.assertEqual(path, self.good)
        self.assertEqual(key, 'bac/d/maths/lesson.pdf')

    def test_rejects_outside_root(self):
        self.row['local_file'] = '../lesson.pdf'
        with self.assertRaises(ValueError): module.validate(self.row, self.root)

    def test_rejects_non_pdf(self):
        self.good.write_text('not pdf')
        with self.assertRaises(ValueError): module.validate(self.row, self.root)

    def test_rejects_incorrect_kind(self):
        self.row['kind'] = 'unknown'
        with self.assertRaises(ValueError): module.validate(self.row, self.root)

    def test_sha256(self):
        import hashlib
        self.assertEqual(module.sha256_file(self.good), hashlib.sha256(self.good.read_bytes()).hexdigest())

    def test_publication_requires_rights_evidence(self):
        with self.assertRaises(ValueError): module.validate_rights(self.row)
        self.row['rights_evidence'] = 'Written permission held by the publisher'
        module.validate_rights(self.row)

    def test_readback_checks_bytes_and_closes_stream(self):
        content = self.good.read_bytes()
        body = io.BytesIO(content)
        class Client:
            def get_object(self, **kwargs): return {'Body':body}
        module.verify_stored_pdf(Client(),'test','fixture.pdf',len(content),hashlib.sha256(content).hexdigest())
        self.assertTrue(body.closed)

    def test_readback_rejects_corruption_even_with_matching_size(self):
        content = self.good.read_bytes()
        body = io.BytesIO(content)
        class Client:
            def get_object(self, **kwargs): return {'Body':body}
        with self.assertRaises(RuntimeError):
            module.verify_stored_pdf(Client(),'test','fixture.pdf',len(content),'0' * 64)
        self.assertTrue(body.closed)

if __name__=='__main__':unittest.main()
