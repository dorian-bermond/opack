// Traces a raster drawing into an SVG silhouette, for a game emblem:
//   cd tool && npm install sharp potrace && node trace_icon.js <in.webp|png> <out.svg>
// Black bars around the drawing are trimmed; the result goes to
// assets/icons/, and its path data to lib/shared/widgets/*_icon_path.dart.
const sharp = require('sharp');
const potrace = require('potrace');
const fs = require('fs');
const src = process.argv[2], out = process.argv[3];
(async () => {
  const png = await sharp(src).flatten({ background: '#ffffff' }).trim({ background: '#000000', threshold: 60 }).extend({ top: 20, bottom: 20, left: 20, right: 20, background: '#ffffff' }).resize(600, 600, { fit: 'contain', background: '#ffffff' }).png().toBuffer();
  potrace.trace(png, { threshold: 160, turdSize: 8, optTolerance: 0.3, color: 'black', background: 'transparent' }, (err, svg) => {
    if (err) throw err;
    fs.writeFileSync(out, svg);
    const d = (svg.match(/ d="([^"]+)"/) || [])[1] || '';
    console.log('svg bytes', svg.length, 'path chars', d.length, 'viewBox', (svg.match(/viewBox="[^"]+"/) || [''])[0], (svg.match(/width="[^"]+" height="[^"]+"/) || [''])[0]);
  });
})();
