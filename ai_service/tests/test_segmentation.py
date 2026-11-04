import unittest

import cv2
import numpy as np

from nail_segmentation import segment_nail


class SegmentationTests(unittest.TestCase):
    def test_uniform_skin_does_not_invent_a_nail(self):
        image = np.full((300, 300, 3), (190, 140, 120), np.uint8)
        self.assertIsNone(segment_nail(image, (150, 70), (150, 180)))

    def test_tiny_finger_is_rejected(self):
        image = np.zeros((100, 100, 3), np.uint8)
        self.assertIsNone(segment_nail(image, (50, 40), (50, 44)))

    def test_boundary_matches_visible_colour_region(self):
        image = np.full((300, 300, 3), (190, 140, 120), np.uint8)
        cv2.ellipse(image, (150, 112), (28, 39), 0, 0, 360, (180, 25, 80), -1)
        result = segment_nail(image, (150, 70), (150, 180))
        self.assertIsNotNone(result)
        self.assertLess(abs(result['x'] * 300 - 150), 4)
        self.assertLess(abs(result['y'] * 300 - 112), 4)
        self.assertLess(abs(result['width'] * 300 - 56), 6)
        self.assertLess(abs(result['height'] * 300 - 78), 6)
        self.assertGreater(len(result['polygon']), 6)
        self.assertTrue(result['needs_review'])

    def test_horizontal_finger_keeps_position_and_rotation(self):
        image = np.full((300, 300, 3), (190, 140, 120), np.uint8)
        cv2.ellipse(image, (188, 150), (39, 28), 0, 0, 360, (180, 25, 80), -1)
        result = segment_nail(image, (230, 150), (120, 150))
        self.assertIsNotNone(result)
        self.assertLess(abs(result['x'] * 300 - 188), 4)
        self.assertLess(abs(result['y'] * 300 - 150), 4)
        self.assertAlmostEqual(result['rotation'], np.pi / 2)


if __name__ == '__main__':
    unittest.main()
