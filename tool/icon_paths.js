// Writes lib/shared/widgets/<game>_icon_path.dart from assets/icons/<game>.svg:
// each <path> in file order, black ones as solids ('+'), white ones as holes
// ('-'), an 'e' appended for the even-odd fill rule; the app unions and
// subtracts them in that order. A group transform
// of the form translate(a,b) scale(c,d) (potrace's output) is kept.
//   node tool/icon_paths.js
const fs = require('fs');
for (const game of ['mtg', 'ygo', 'opc']) {
  const svg = fs.readFileSync(`assets/icons/${game}.svg`, 'utf8');
  const vb = svg.match(/viewBox="([^"]+)"/)[1].split(/\s+/).map(Number);
  const t = svg.match(/transform="translate\(([^,]+),([^)]+)\)\s*scale\(([^,]+),([^)]+)\)"/);
  const transform = t ? t.slice(1, 5).map(Number) : [0, 0, 1, 1];
  const shapes = [...svg.matchAll(/<path([^>]*?)\/?>/g)].map(m => {
    const attrs = m[1];
    const d = attrs.match(/ d="([^"]+)"/)[1].replace(/\s+/g, ' ').trim();
    const fill = (attrs.match(/fill="([^"]+)"/) || [, '#000000'])[1].toLowerCase();
    const evenOdd = /fill-rule="evenodd"/.test(attrs) ? 'e' : '';
    return [(fill === '#ffffff' || fill === 'white' ? '-' : '+') + evenOdd, d];
  });
  let out = `// Generated from assets/icons/${game}.svg by tool/icon_paths.js. Do not edit by hand.\n\n`;
  out += `/// The SVG view box: origin, then width and height.\nconst ${game}IconViewBox = (${vb.map(v => v.toFixed(1)).join(', ')});\n\n`;
  out += `/// The transform the shapes are drawn under: translate x, y, then scale x, y.\nconst ${game}IconTransform = (${transform.map(v => v.toFixed(3)).join(', ')});\n\n`;
  out += `/// The emblem's shapes in order: solids ('+') and holes ('-'), as SVG path data.\nconst ${game}IconShapes = <(String, String)>[\n`;
  for (const [kind, d] of shapes) {
    const lines = [];
    for (let i = 0; i < d.length; i += 96) lines.push(`    '${d.slice(i, i + 96)}'`);
    out += `  ('${kind}',\n${lines.join('\n')}),\n`;
  }
  out += '];\n';
  fs.writeFileSync(`lib/shared/widgets/${game}_icon_path.dart`, out);
  console.log(game, shapes.length, 'shapes, transform', transform.join(' '));
}
