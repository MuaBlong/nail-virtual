import unittest
from pathlib import Path

import numpy as np
from fastapi import UploadFile
from app import detect_hand, extract_nail_design
from nail_texture import illumination_grid
from nail_model import detect_nail_instances, match_instances, MODEL


class NailModelTests(unittest.TestCase):
    @staticmethod
    def fixture_instances(count=5):
        xs = [40., 80., 120., 160., 200., 235.][:count]
        return [{'center': np.array([x, 65.]),
                 'contour': np.array([[x-8, 50], [x+8, 50], [x+8, 80], [x-8, 80]], np.float32),
                 'score': .9} for x in xs]

    @staticmethod
    def fixture_fingers():
        return [(name, (x, 40.), (x, 110.)) for name, x in
                zip(['thumb', 'index', 'middle', 'ring', 'pinky'], [40., 80., 120., 160., 200.])]

    def test_four_visible_nails_are_kept_without_inventing_a_fifth(self):
        result = match_instances(self.fixture_instances(4), self.fixture_fingers(), (280, 200), include_extras=True)
        self.assertEqual(len(result), 4)
        self.assertTrue(all(n['visible'] for n in result.values()))

    def test_six_distinct_nails_are_kept(self):
        result = match_instances(self.fixture_instances(6), self.fixture_fingers(), (280, 200),
            include_extras=True, hand_points=[(20, 30), (200, 30), (200, 170), (20, 170)])
        self.assertEqual(len(result), 6)
        extras = [n for n in result.values() if n.get('extra_nail')]
        self.assertEqual(len(extras), 1)
        self.assertTrue(0 <= extras[0]['design_index'] < 5)

    def test_duplicate_detection_is_not_a_sixth_nail(self):
        instances = self.fixture_instances(5)
        instances.append(dict(instances[2]))
        result = match_instances(instances, self.fixture_fingers(), (280, 200), include_extras=True)
        self.assertEqual(len(result), 5)

    def test_distant_or_low_confidence_extra_region_is_rejected(self):
        instances = self.fixture_instances(6)
        instances[-1]['score'] = .4
        result = match_instances(instances, self.fixture_fingers(), (280, 200), include_extras=True)
        self.assertEqual(len(result), 5)
        instances[-1]['score'] = .9
        instances[-1]['center'] = np.array([700., 700.])
        result = match_instances(instances, self.fixture_fingers(), (800, 800), include_extras=True)
        self.assertEqual(len(result), 5)

    def test_uniform_illumination_produces_neutral_shading(self):
        rgb=np.full((100,100,3),128,np.uint8)
        nail={'rotation':0.,'x':.5,'y':.5,'width':.2,'height':.4,
              'polygon':[[0,0],[1,0],[1,1],[0,1]]}
        self.assertEqual(illumination_grid(rgb,nail),[.5]*128)

    @unittest.skipUnless(MODEL.is_file(), 'checkpoint not installed')
    def test_extract_reference_photo_returns_five_png_textures(self):
        path = Path(__file__).with_name('hand_example.jpg')
        if not path.is_file(): self.skipTest('sample not installed')
        with path.open('rb') as stream:
            result=extract_nail_design(UploadFile(filename=path.name,file=stream))
        self.assertEqual(len(result['designs']),5)
        self.assertTrue(all(v.startswith('data:image/png;base64,') for v in result['designs'].values()))
    def test_same_instance_cannot_be_assigned_to_two_fingers(self):
        contour = np.array([[90, 50], [110, 50], [110, 80], [90, 80]])
        instances = [{'center': np.array([100., 65.]), 'contour': contour, 'score': .9}]
        fingers = [('index', (100., 40.), (100., 110.)),
                   ('middle', (105., 40.), (105., 110.))]
        result = match_instances(instances, fingers, (200, 200))
        self.assertEqual(len(result), 1)
        self.assertIn('index', result)

    def test_far_away_instance_is_not_forced_onto_a_finger(self):
        result = match_instances([{'center': np.array([400., 400.]),
            'contour': np.array([[390, 390], [410, 390], [400, 410]]), 'score': .9}],
            [('index', (100., 40.), (100., 110.))], (500, 500))
        self.assertEqual(result, {})

    @unittest.skipUnless(MODEL.is_file(), 'checkpoint not installed')
    def test_model_does_not_detect_nails_on_uniform_image(self):
        self.assertEqual(detect_nail_instances(np.full((320, 320, 3), 255, np.uint8)), [])

    @unittest.skipUnless(MODEL.is_file(), 'checkpoint not installed')
    def test_real_hand_fixture_has_five_distinct_segmented_nails(self):
        path = Path(__file__).with_name('hand_example.jpg')
        if not path.is_file():
            self.skipTest('upstream sample not downloaded')
        with path.open('rb') as stream:
            result = detect_hand(UploadFile(filename=path.name, file=stream))
        self.assertTrue(result['success'])
        self.assertEqual(result['segmented_count'], 5)
        for nail in result['nails']:
            self.assertEqual(nail['method'], 'nail_model')
            self.assertGreaterEqual(len(nail['polygon']), 3)
            self.assertTrue(nail['visible'])
            self.assertTrue(all(0 <= v <= 1 for p in nail['polygon'] for v in p))
