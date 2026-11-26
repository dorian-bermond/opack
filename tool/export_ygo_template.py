"""Exports the pieces of a Yu-Gi-Oh! card template (a layered .psd) as the
assets the app draws cards from: one flattened frame per card kind, the
attribute, level, spell/trap and link pictures, and their places.

    python tool/export_ygo_template.py <YuGiOhTemplate.psd> [assets/ygo_template]

Needs `psd-tools` and `Pillow`. Everything is cut to the card (its black
border, no bleed) and halved: the card is 1389 x 2026 in the template,
drawn from pictures half that size. `layout.json` gives every picture's
box in template pixels, relative to the card's corner.
"""

import json
import os
import sys

from PIL import Image
from psd_tools import PSDImage

SCALE = 0.5

# Frame name in the app -> texture layer of the template.
FRAMES = {
    'normal': 'Normal Texture',
    'effect': 'Effect Texture',
    'ritual': 'Ritual Texture',
    'fusion': 'Fusion Texture',
    'synchro': 'Synchro Texture',
    'xyz': 'Xyz Texture',
    'link': 'Link Texture',
    'spell': 'Spell Texture',
    'trap': 'Trap Texture',
    'token': 'Token Texture',
}

# Drawn over every frame's texture, bottom first.
FRAME_PARTS = ['Header', 'Texture Bevel', 'Art Box', 'ArtBoxShade', 'Lore Background', 'Lore Border']

ATTRIBUTES_EN = ['DARK', 'DIVINE', 'EARTH', 'FIRE', 'LIGHT', 'WATER', 'WIND']
ATTRIBUTES_FR = {'TENEBRES': 'DARK', 'DIVIN': 'DIVINE', 'TERRE': 'EARTH', 'FEU': 'FIRE',
                 'LUMIERE': 'LIGHT', 'EAU': 'WATER', 'VENT': 'WIND'}
SPELL_TRAP_TYPES = ['Continuous', 'Counter', 'Equip', 'Field', 'Quick-Play', 'Ritual']
LINK_ARROWS = {'Top': 'top', 'Upper Left': 'top-left', 'Upper Right': 'top-right', 'Bottom': 'bottom',
               'Right': 'right', 'Left': 'left', 'Lower Right': 'bottom-right', 'Lower Left': 'bottom-left'}


def main():
    source = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else 'assets/ygo_template'
    os.makedirs(out, exist_ok=True)
    psd = PSDImage.open(source)
    layers = {}
    for layer in psd.descendants():
        layers.setdefault(layer.name, layer)

    border = layers['Card Border']
    ox, oy = border.bbox[0], border.bbox[1]
    card_w, card_h = border.width, border.height
    layout = {'card': [card_w, card_h], 'pictures': {}}

    def pil(layer):
        """A layer's own pixels, with its opacity."""
        if layer.kind in ('smartobject', 'group'):
            # Drawn even when the template hides it.
            layer.visible = True
            image = layer.composite(layer_filter=lambda _: True)
        else:
            image = layer.topil()
        image = image.convert('RGBA')
        if layer.opacity < 255:
            alpha = image.getchannel('A').point(lambda a: a * layer.opacity // 255)
            image.putalpha(alpha)
        return image

    def box(layer):
        left, top, right, bottom = layer.bbox
        return [left - ox, top - oy, right - left, bottom - top]

    def save(name, image, where, opaque=False):
        """Halves [image] and writes it, noting its box in the template."""
        size = (max(1, round(image.width * SCALE)), max(1, round(image.height * SCALE)))
        small = image.resize(size, Image.LANCZOS)
        if opaque:
            file = f'{name}.jpg'
            small.convert('RGB').save(os.path.join(out, file), quality=90, optimize=True)
        else:
            file = f'{name}.png'
            small.save(os.path.join(out, file), optimize=True)
        layout['pictures'][name] = {'file': file, 'box': where}

    def hard_light(base, top):
        """Photoshop's hard light of [top] over [base], both RGB 0..255."""
        return tuple(
            (2 * b * t // 255) if t < 128 else (255 - 2 * (255 - b) * (255 - t) // 255)
            for b, t in zip(base, top)
        )

    def over(canvas, layer):
        image = pil(layer)
        left, top = layer.bbox[0] - ox, layer.bbox[1] - oy
        if layer.blend_mode.name == 'HARD_LIGHT':
            # Blend by hand: only the header uses it, a small strip.
            region = canvas.crop((left, top, left + image.width, top + image.height)).convert('RGBA')
            blended = Image.new('RGBA', image.size)
            source, under = image.load(), region.load()
            target = blended.load()
            for y in range(image.height):
                for x in range(image.width):
                    r, g, b, a = source[x, y]
                    target[x, y] = (*hard_light(under[x, y][:3], (r, g, b)), a)
            image = blended
        canvas.alpha_composite(image, (left, top))

    # One flattened, opaque picture per frame: border, texture and boxes.
    for name, texture in FRAMES.items():
        canvas = Image.new('RGBA', (card_w, card_h), (0, 0, 0, 255))
        canvas.alpha_composite(pil(border))
        over(canvas, layers[texture])
        if name == 'link':
            # Under the lore box, as in the template's own link group.
            over(canvas, layers['Link (Flavour BG)'])
        for part in FRAME_PARTS:
            over(canvas, layers[part])
        save(f'frame-{name}', canvas, [0, 0, card_w, card_h], opaque=True)
        print('frame', name)

    for attribute in ATTRIBUTES_EN + ['SPELL', 'TRAP']:
        save(f'attribute-{attribute.lower()}', pil(layers[attribute]), box(layers[attribute]))
    for french, attribute in ATTRIBUTES_FR.items():
        save(f'attribute-{attribute.lower()}-fr', pil(layers[french]), box(layers[french]))

    # One star of each row: the rows hold twelve, evenly spread.
    for name, row in (('level', 'Levels'), ('rank', 'Ranks')):
        layer = layers[row]
        image = pil(layer)
        star = image.height
        save(name, image.crop((image.width - star, 0, image.width, star)), box(layer))
        layout['pictures'][name]['count'] = 12

    for kind in SPELL_TRAP_TYPES:
        save(f'icon-{kind.lower()}', pil(layers[kind]), box(layers[kind]))

    arrows = {g.name: g for g in psd.descendants() if g.is_group() and g.name.startswith('Link: ')}
    for label, name in LINK_ARROWS.items():
        group = arrows[f'Link: {label} Arrow']
        for state in group:
            parts = list(state)
            left = min(p.bbox[0] for p in parts)
            top = min(p.bbox[1] for p in parts)
            right = max(p.bbox[2] for p in parts)
            bottom = max(p.bbox[3] for p in parts)
            canvas = Image.new('RGBA', (right - left, bottom - top), (0, 0, 0, 0))
            for part in parts:
                canvas.alpha_composite(pil(part), (part.bbox[0] - left, part.bbox[1] - top))
            save(f'link-{name}-{state.name.lower()}', canvas, [left - ox, top - oy, right - left, bottom - top])

    save('link-label', pil(layers['LINK Label']), box(layers['LINK Label']))

    # Where the app writes and draws, from the template's own bounds layers.
    def bounds(name):
        return box(layers[name])

    layout['boxes'] = {
        'artwork': bounds('Current Artwork'),
        'name': bounds('Card Name - Bounds'),
        'attribute': bounds('DARK'),
        'levels': bounds('Levels'),
        'monsterType': [bounds('Monster Race')[0], bounds('Monster Race')[1], 1170, bounds('Monster Race')[3]],
        'monsterText': bounds('Monster Effect - Bounds'),
        'spellText': bounds('Spell/Trap Effect - Bounds'),
        'spellType': [bounds('(Type) Spell')[0] - 300, bounds('(Type) Spell')[1], bounds('(Type) Spell')[2] + 300,
                      bounds('(Type) Spell')[3]],
        'spellIcon': bounds('Continuous'),
        'statsLine': bounds('ATK/DEF Line'),
        'atk': bounds('ATKLabel')[:1] + bounds('ATKLabel')[1:2] + [bounds('ATK')[0] + bounds('ATK')[2] - bounds('ATKLabel')[0], bounds('ATKLabel')[3]],
        'def': bounds('DEF'),
        'linkNumber': bounds('Link Number'),
        'setNumber': bounds('Set Number (General)'),
        'setNumberLink': bounds('Set Number (Link)'),
        'code': bounds('Code'),
    }
    with open(os.path.join(out, 'layout.json'), 'w', encoding='utf-8') as f:
        json.dump(layout, f, indent=1)
    total = sum(os.path.getsize(os.path.join(out, f)) for f in os.listdir(out))
    print(f'{len(layout["pictures"])} pictures, {total // 1024} KB in {out}')


if __name__ == '__main__':
    main()
