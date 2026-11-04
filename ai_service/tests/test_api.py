import io
import unittest

from fastapi import HTTPException, UploadFile
from PIL import Image

from app import detect_hand


class ApiTests(unittest.TestCase):
    def test_invalid_image_is_400(self):
        with self.assertRaises(HTTPException) as error:
            detect_hand(UploadFile(filename='bad.png', file=io.BytesIO(b'invalid')))
        self.assertEqual(error.exception.status_code, 400)

    def test_empty_image_is_400(self):
        with self.assertRaises(HTTPException) as error:
            detect_hand(UploadFile(filename='empty.png', file=io.BytesIO()))
        self.assertEqual(error.exception.status_code, 400)

    def test_blank_image_has_no_hand(self):
        buffer = io.BytesIO()
        Image.new('RGB', (320, 320), 'white').save(buffer, format='PNG')
        buffer.seek(0)
        result = detect_hand(UploadFile(filename='blank.png', file=buffer))
        self.assertFalse(result['success'])
        self.assertEqual(result['nails'], [])
