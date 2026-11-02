const fs = require('fs');
const path = require('path');
const vm = require('vm');

const rootDir = __dirname;
const thumbnailsDir = path.join(rootDir, 'thumbnailsYT');
const data = fs.readFileSync(path.join(rootDir, 'catalogo-titulos.js'), 'utf8');
const context = { window: {} };
vm.runInNewContext(data, context);
const catalogoTitulos = context.window.catalogoTitulos || {};

function sanitizeTitle(title) {
  return String(title || '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[<>:"/\\|?*]+/g, ' ')
    .replace(/\s+/g, ' ')
    .replace(/\s*\|\s*/g, ' | ')
    .replace(/\s*[-–—]\s*/g, ' - ')
    .trim();
}

function getExpectedName(number, title) {
  const cleanTitle = sanitizeTitle(title);
  return `${String(number).padStart(3, '0')} - ${cleanTitle}.jpg`;
}

const files = fs.readdirSync(thumbnailsDir).filter((file) => /\.jpe?g$/i.test(file));
const renamed = [];
const missing = [];

for (const [rawNumber, title] of Object.entries(catalogoTitulos)) {
  const number = Number(rawNumber);
  if (!Number.isInteger(number)) continue;

  const expectedName = getExpectedName(number, title);
  const exactExists = files.includes(expectedName);
  if (exactExists) continue;

  const candidates = files.filter((file) => {
    const match = /^\s*(\d{1,3})\b/.exec(file);
    return match && Number(match[1]) === number;
  });

  if (!candidates.length) {
    missing.push(`${number}: ${title}`);
    continue;
  }

  const currentName = candidates[0];
  const currentPath = path.join(thumbnailsDir, currentName);
  const targetPath = path.join(thumbnailsDir, expectedName);

  if (fs.existsSync(targetPath) && targetPath !== currentPath) {
    console.log(`Arquivo destino já existe: ${number} -> ${expectedName}`);
    continue;
  }

  fs.renameSync(currentPath, targetPath);
  renamed.push({ from: currentName, to: expectedName });
  console.log(`Renomeado: ${currentName} -> ${expectedName}`);
}

console.log(`\nResumo: ${renamed.length} arquivos renomeados`);
if (missing.length) {
  console.log(`Arquivos sem candidato para renomear: ${missing.length}`);
  console.log(missing.slice(0, 10).join('\n'));
}
