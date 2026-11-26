"""Downloads the Yu-Gi-Oh! monster type icons (Master Duel's, from Yugipedia)
the card editor shows beside a type: one small PNG per type, named after
the type in lowercase letters only (`beastwarrior.png`, `seaserpent.png`).

    python tool/fetch_ygo_type_icons.py [assets/ygo_types]
"""

import json
import os
import re
import sys
import urllib.parse
import urllib.request

CATEGORY = 'Category:Yu-Gi-Oh!_Master_Duel_Type_icons'
AGENT = {'User-Agent': 'Mozilla/5.0 (card-tool)'}


def get(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers=AGENT)) as response:
        return response.read()


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else 'assets/ygo_types'
    os.makedirs(out, exist_ok=True)
    query = urllib.parse.urlencode({
        'action': 'query', 'generator': 'categorymembers', 'gcmtitle': CATEGORY, 'gcmlimit': 100,
        'gcmtype': 'file', 'prop': 'imageinfo', 'iiprop': 'url', 'format': 'json',
    })
    pages = json.loads(get(f'https://yugipedia.com/api.php?{query}'))['query']['pages']
    for page in sorted(pages.values(), key=lambda p: p['title']):
        match = re.match(r'File:Type-(.+)-MADU\.png$', page['title'])
        if not match:
            continue
        name = re.sub(r'[^a-z]', '', match.group(1).lower())
        with open(os.path.join(out, f'{name}.png'), 'wb') as f:
            f.write(get(page['imageinfo'][0]['url']))
        print(name)


if __name__ == '__main__':
    main()
