const fs = require('fs');
const path = require('path');

const folderArg = process.argv[2] || process.env.THUMBNAILS_DIR;
const folder = path.resolve(folderArg || path.join(__dirname, 'Thumbnails_sdesign'));
const extensions = new Set(['.jpg', '.jpeg', '.png', '.webp', '.gif']);

function isMediaFile(fileName) {
  return extensions.has(path.extname(fileName).toLowerCase());
}

const files = fs
  .readdirSync(folder)
  .filter((fileName) => fs.statSync(path.join(folder, fileName)).isFile())
  .filter(isMediaFile)
  .sort((a, b) => a.localeCompare(b, undefined, { numeric: true, sensitivity: 'base' }));

if (!files.length) {
  console.log(`Nenhum ficheiro de imagem encontrado em ${folder}`);
  process.exit(0);
}

let renamed = 0;
for (let index = 0; index < files.length; index += 1) {
  const originalName = files[index];
  const originalPath = path.join(folder, originalName);
  const extension = path.extname(originalName);
  const number = String(index + 1).padStart(3, '0');
  const targetName = `${number} - ${originalName.replace(new RegExp(`${escapeRegExp(extension)}$`), '')}${extension}`;
  const targetPath = path.join(folder, targetName);

  if (originalName === targetName) {
    console.log(`Já numerado: ${originalName}`);
    continue;
  }

  if (fs.existsSync(targetPath)) {
    console.log(`Ignorado: destino já existe -> ${targetName}`);
    continue;
  }

  fs.renameSync(originalPath, targetPath);
  console.log(`Renomeado: ${originalName} -> ${targetName}`);
  renamed += 1;
}

console.log(`\nResumo: ${renamed} ficheiros renomeados em ${folder}`);

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}
