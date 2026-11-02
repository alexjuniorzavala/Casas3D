#!/usr/bin/env node
const fs = require('fs');
const path = require('path');

const rootDir = __dirname;
const thumbsDir = path.join(rootDir, 'thumbnailsYT');
const translationsPath = path.join(thumbsDir, 'Nomes traduzidos');
const outputJsPath = path.join(rootDir, 'catalogo-titulos.js');

if (!fs.existsSync(translationsPath)) {
  console.error('Arquivo de traduções não encontrado:', translationsPath);
  process.exit(1);
}

const content = fs.readFileSync(translationsPath, 'utf8');
const parsed = {};

for (const line of content.split(/\r?\n/)) {
  const match = line.match(/^\|\s*(\d+)\s*\|\s*[^|]+\s*\|\s*(.*?)\s*\|\s*$/);
  if (!match) continue;

  const numero = Number(match[1]);
  const title = match[2]
    .replace(/\\\|/g, ' | ')
    .replace(/\s*\|\s*/g, ' | ')
    .replace(/\s{2,}/g, ' ')
    .trim();

  if (!Number.isFinite(numero) || !title) continue;
  parsed[numero] = title;
}

const currentFiles = fs.readdirSync(thumbsDir).filter((file) => /^\d{3}\s*-\s*.+\.jpg$/i.test(file));
const fileByNumber = new Map();

for (const file of currentFiles) {
  const match = file.match(/^(\d{3})\s*-\s*/);
  if (!match) continue;
  fileByNumber.set(Number(match[1]), file);
}

let renamed = 0;
for (const [numeroString, title] of Object.entries(parsed).sort((a, b) => Number(a[0]) - Number(b[0]))) {
  const numero = Number(numeroString);
  const pad = String(numero).padStart(3, '0');
  const safeTitle = title.replace(/\//g, ' - ');
  const targetName = `${pad} - ${safeTitle}.jpg`;
  const targetPath = path.join(thumbsDir, targetName);
  const sourceName = fileByNumber.get(numero);
  const sourcePath = sourceName ? path.join(thumbsDir, sourceName) : null;

  if (sourcePath && fs.existsSync(sourcePath) && sourceName !== targetName) {
    if (fs.existsSync(targetPath)) {
      fs.unlinkSync(sourcePath);
      console.log(`Removido duplicado: ${sourceName}`);
      continue;
    }

    fs.renameSync(sourcePath, targetPath);
    renamed += 1;
    console.log(`Renomeado: ${sourceName} -> ${targetName}`);
    fileByNumber.delete(numero);
    continue;
  }

  if (fs.existsSync(targetPath)) {
    console.log(`Já renomeado: ${targetName}`);
    continue;
  }

  console.log(`Arquivo ausente para ${pad}: ${title}`);
}

const jsOutput = `window.catalogoTitulos = {
${Object.entries(parsed)
  .sort((a, b) => Number(a[0]) - Number(b[0]))
  .map(([numero, title]) => `  ${numero}: ${JSON.stringify(title)}`)
  .join(',\n')}
};\n`;

fs.writeFileSync(outputJsPath, jsOutput, 'utf8');
console.log(`\n${renamed} arquivos renomeados.`);
console.log(`Mapa do catálogo exportado para: ${outputJsPath}`);
