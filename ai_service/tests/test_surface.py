import base64
import io
import unittest

import numpy as np
from PIL import Image
from nail_texture import surface_maps


def decode(uri):
    return np.asarray(Image.open(io.BytesIO(base64.b64decode(uri.split(',', 1)[1]))))


class SurfaceTests(unittest.TestCase):
    nail = {'rotation': 0., 'x': .5, 'y': .5, 'width': .5, 'height': .7,
            'polygon': [[0, 0], [1, 0], [1, 1], [0, 1]]}

    def test_flat_surface_has_neutral_illumination_without_invented_reflections(self):
        maps = surface_maps(np.full((100, 100, 3), 128, np.uint8), self.nail)
        lighting = decode(maps['lighting'])
        self.assertTrue(np.all(lighting == 128))
        self.assertEqual(int(decode(maps['highlights'])[:, :, 3].max()), 0)

    def test_edges_feather_inward_while_center_remains_opaque(self):
        alpha = decode(surface_maps(np.full((100, 100, 3), 128, np.uint8), self.nail)['coverage'])[:, :, 3]
        self.assertEqual(alpha[48, 32], 255)
        self.assertLess(alpha[0, 32], alpha[48, 32])

    def test_measured_light_gradient_is_continuous(self):
        ramp = np.tile(np.linspace(70, 220, 100, dtype=np.uint8), (100, 1))
        rgb = np.repeat(ramp[:, :, None], 3, axis=2)
        lighting = decode(surface_maps(rgb, self.nail)['lighting'])
        self.assertGreater(int(lighting[48, 55]), int(lighting[48, 8]))
        self.assertLess(int(np.abs(np.diff(lighting[48].astype(int))).max()), 8)

    def test_no_coverage_outside_detected_nail(self):
        nail = {**self.nail, 'polygon': [[.5, 0], [1, 1], [0, 1]]}
        alpha = decode(surface_maps(np.full((100, 100, 3), 128, np.uint8), nail)['coverage'])[:, :, 3]
        self.assertEqual(alpha[4, 4], 0)
        self.assertEqual(alpha[4, -5], 0)
        self.assertGreater(alpha[70, 32], 200)
