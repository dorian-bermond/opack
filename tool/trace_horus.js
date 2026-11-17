const sharp = require('sharp');
const potrace = require('potrace');
const fs = require('fs');
const src = 'C:/Users/DorianBermond/Downloads/yu_gi_oh_eye_of_horus_by_realafonso_dc0haci.png';
const trace = (png, opts) => new Promise((res, rej) => potrace.trace(png, opts, (e, svg) => e ? rej(e) : res(svg)));
const paths = svg => [...svg.matchAll(/ d="([^"]+)"/g)].map(m => m[1].replace(/\s+/g, ' ').trim());
(async () => {
  const size = 600;
  const base = sharp(src).flatten({ background: '#ffffff' }).resize(size, size, { fit: 'contain', background: '#ffffff' });
  // Silhouette: anything not near white.
  const silhouette = await base.clone().greyscale().threshold(235).png().toBuffer();
  // Dark details: the pupil, the black of the eye, the ink lines.
  const dark = await base.clone().greyscale().threshold(70).png().toBuffer();
  const solid = await trace(silhouette, { threshold: 128, turdSize: 20, optTolerance: 0.4 });
  const holes = await trace(dark, { threshold: 128, turdSize: 30, optTolerance: 0.4 });
  const vb = `0 0 ${size} ${size}`;
  let out = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vb}" width="${size}" height="${size}">\n`;
  out += '  <!-- The Eye of Wdjat, traced from a drawing: the black path is its silhouette, the white ones the dark\n       details (pupil, ink lines) cut out of it (the app subtracts them). Traced paths use the even-odd rule. -->\n';
  for (const d of paths(solid)) out += `  <path fill="#000000" fill-rule="evenodd" d="${d}"/>\n`;
  for (const d of paths(holes)) out += `  <path fill="#ffffff" fill-rule="evenodd" d="${d}"/>\n`;
  out += '</svg>\n';
  fs.writeFileSync('C:/repos/Opack/assets/icons/ygo.svg', out);
  await sharp(Buffer.from(out)).resize(200, 200).flatten({ background: '#fff' }).png().toFile('C:/repos/Opack/build/trace/ygo_preview.png');
  console.log('solid paths', paths(solid).length, 'hole paths', paths(holes).length, 'bytes', out.length);
})();
