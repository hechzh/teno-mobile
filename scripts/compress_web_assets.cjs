/* Deterministic precompression, using Node's bundled Brotli and gzip. */
const fs = require('node:fs');
const path = require('node:path');
const zlib = require('node:zlib');
const root = path.resolve(process.argv[2]);
function* walk(folder) {
  for (const entry of fs.readdirSync(folder, {withFileTypes:true})) {
    const p = path.join(folder, entry.name);
    if (entry.isDirectory()) yield* walk(p);
    else if (entry.isFile()) yield p;
  }
}
let original = 0, compressed = 0, count = 0;
for (const file of walk(root)) {
  if (!/\.(?:js|wasm|json|ttf|otf|html|css)$/.test(file) || file.endsWith('release.json')) continue;
  const bytes = fs.readFileSync(file);
  if (bytes.length < 1024) continue;
  const br = zlib.brotliCompressSync(bytes, {params:{[zlib.constants.BROTLI_PARAM_QUALITY]:9}});
  const gzip = zlib.gzipSync(bytes, {level:9});
  fs.writeFileSync(file+'.br',br); fs.writeFileSync(file+'.gz',gzip);
  original += bytes.length; compressed += br.length; count++;
}
console.log(JSON.stringify({precompressedFiles:count,originalBytes:original,brotliBytes:compressed}));
