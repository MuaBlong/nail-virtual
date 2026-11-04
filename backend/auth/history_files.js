const fs = require('node:fs/promises');
const path = require('node:path');

const backendRoot = path.resolve(__dirname, '..');
const storageRoot = path.join(backendRoot, 'storage', 'try-on');
function managedPath(relative) {
  if (typeof relative !== 'string' || !/^storage\/try-on\/[a-f0-9-]{36}\/(before|result)\.(png|jpg)$/.test(relative)) {
    throw new Error('Invalid history image path');
  }
  const absolute = path.resolve(backendRoot, relative);
  if (!absolute.startsWith(storageRoot + path.sep)) throw new Error('Invalid history image location');
  return absolute;
}
async function removeFiles(beforePath, resultPath) {
  const before = managedPath(beforePath), result = managedPath(resultPath);
  if (path.dirname(before) !== path.dirname(result)) throw new Error('Mismatched history paths');
  for (const file of [before, result, path.join(path.dirname(result), 'set.json')]) {
    await fs.unlink(file).catch(error => { if (error.code !== 'ENOENT') throw error; });
  }
  await fs.rmdir(path.dirname(result)).catch(error => { if (error.code !== 'ENOENT') throw error; });
}
async function writeFiles(record) {
  if (!/^[a-f0-9-]{36}$/.test(record.id)) throw new Error('Invalid storage ID');
  const extension = bytes => bytes[0] === 137 ? 'png' : 'jpg';
  const prefix = `storage/try-on/${record.id}`;
  const beforePath = `${prefix}/before.${extension(record.before)}`;
  const resultPath = `${prefix}/result.${extension(record.result)}`;
  await fs.mkdir(storageRoot, { recursive: true });
  await fs.mkdir(path.dirname(managedPath(resultPath)));
  try {
    await fs.writeFile(managedPath(beforePath), record.before, { flag: 'wx' });
    await fs.writeFile(managedPath(resultPath), record.result, { flag: 'wx' });
    await fs.writeFile(path.join(path.dirname(managedPath(resultPath)), 'set.json'), JSON.stringify(record.set), { flag: 'wx' });
    return { beforePath, resultPath };
  } catch (error) {
    await removeFiles(beforePath, resultPath);
    throw error;
  }
}
async function readFiles(row) {
  const before = managedPath(row.image_path), result = managedPath(row.result_path);
  const [beforeImage, resultImage, metadata] = await Promise.all([
    fs.readFile(before), fs.readFile(result),
    fs.readFile(path.join(path.dirname(result), 'set.json'), 'utf8'),
  ]);
  return { before: beforeImage.toString('base64'), result: resultImage.toString('base64'), set: JSON.parse(metadata) };
}
module.exports = { writeFiles, readFiles, removeFiles, managedPath };
