const { test } = require('node:test');
const assert = require('node:assert/strict');
const { groupNailSets } = require('../routes/nailSets');

test('unordered DB rows preserve per-finger design assignments', () => {
  const rows = [5, 2, 4, 1, 3].map(finger => ({ id: 1, name: 'Pink',
    finger_position: finger, image_path: `finger-${finger}.png` }));
  const [set] = groupNailSets(rows);
  assert.deepEqual(set.images, [1,2,3,4,5].map(i => `finger-${i}.png`));
  assert.equal(set.designs.thumb, 'finger-1.png');
  assert.equal(set.designs.pinky, 'finger-5.png');
});
test('missing fingers keep empty slots instead of shifting every design', () => {
  const [set] = groupNailSets([{ id: 7, name: 'Partial', finger_position: 3, image_path: 'middle.png' }]);
  assert.deepEqual(set.images, ['', '', 'middle.png', '', '']);
});
