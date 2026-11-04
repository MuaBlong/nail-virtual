const FINGERS = ['thumb', 'index', 'middle', 'ring', 'pinky'];

// MySQL stores finger_position as 1..5. Never rely on row order to assign fingers.
function groupNailSets(rows) {
  const sets = new Map();
  for (const row of rows) {
    const id = String(row.id);
    if (!sets.has(id)) sets.set(id, {
      id, name: row.name, description: row.description || '',
      category: row.category || 'Bộ mẫu', designs: {}, images: [],
    });
    const finger = FINGERS[Number(row.finger_position) - 1];
    if (finger && row.image_path) sets.get(id).designs[finger] = row.image_path;
  }
  return [...sets.values()].map(set => ({
    ...set, images: FINGERS.map(f => set.designs[f] || ''),
  }));
}
module.exports = { groupNailSets };
