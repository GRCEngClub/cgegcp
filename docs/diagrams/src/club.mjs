// Shared GRC Engineering Club styling for every course diagram.
// Palette and type rules come from GRCEngClub/design-system (BRAND.md):
// warm graphite / white surfaces, hairline borders, Inter + JetBrains Mono,
// orange only on the one element that matters, no gradients or shadows.

export const THEMES = {
  light: {
    page: '#FFFFFF', alt: '#FAFAFA', card: '#F5F5F5', hairline: '#E5E5E5', chip: '#EFEFEF',
    text: '#171717', secondary: '#525252', meta: '#737373',
    orange: '#E8650A', orangeText: '#C45200',
  },
  dark: {
    page: '#111110', alt: '#161514', card: '#1C1B19', hairline: '#2B2925', chip: '#2B2925',
    text: '#EFE9DE', secondary: '#AAA398', meta: '#8A847A',
    orange: '#E8650A', orangeText: '#FF8533',
  },
};

// Start a diagram: page background plus the meta / title / subtitle header.
// Returns a small builder; call .done() for the {entities, connections} document.
export function canvas(t, { width, height, meta, title, sub }) {
  const entities = [];
  const connections = [];

  entities.push({ tag: 'Shape', id: 'bg', shape: 'rectangle', styleMode: 'plain', cornerRadius: [0, 0, 0, 0],
    x: 0, y: 0, width, height, bgColor: t.page, borderColor: t.page, borderWidth: 0, texts: [] });
  const textW = width - 80;
  entities.push({ tag: 'Textbox', id: 'h_meta', x: 40, y: 32, width: textW, fixedWidth: true,
    text: meta, typeface: 'mono', fontSize: 12, color: t.meta });
  entities.push({ tag: 'Textbox', id: 'h_title', x: 40, y: 52, width: textW, fixedWidth: true,
    text: title, typeface: 'clean', fontSize: 26, color: t.text });
  if (sub) entities.push({ tag: 'Textbox', id: 'h_sub', x: 40, y: 92, width: textW, fixedWidth: true,
    text: sub, typeface: 'clean', fontSize: 14, color: t.secondary });

  const tagBadge = (text) => ({ text, bgColor: t.chip, color: t.secondary, shape: 'rectangle',
    placement: 'top-right', fontSize: 11 });

  const api = {
    t,
    // A hairline card. `title` is mono (an identifier), `note` is plain text beneath it
    // (pass an array for several lines).
    card(id, x, y, w, h, { title, note, icon, accent, tag, align, fill, titleFont = 'mono', size = 13 } = {}) {
      const texts = [];
      if (title) texts.push({ text: title, typeface: titleFont, fontSize: size, color: t.text, hAlign: align });
      for (const line of [note].flat().filter(Boolean)) {
        texts.push({ text: line, typeface: 'clean', fontSize: 11, color: t.secondary, hAlign: align });
      }
      // Official Google Cloud icons (gcloud-*, vendored in icons/) keep their own colors and
      // render larger; generic line icons are tinted to match the text.
      const brand = icon && icon.startsWith('gcloud-');
      entities.push({ tag: 'Shape', id, shape: 'rectangle', styleMode: 'plain', cornerRadius: 'round',
        x, y, width: w, height: h, bgColor: fill ?? t.card, borderColor: accent ? t.orange : t.hairline,
        borderWidth: accent ? 1.5 : 1, ...(brand ? { iconProps: { size: 'lg' } } : { iconColor: accent ? t.orangeText : t.secondary }),
        ...(icon ? { icon } : {}), ...(tag ? { badge: tagBadge(tag) } : {}), texts });
      return { id, x, y, w, h };
    },
    // A band: a faint container with a mono label in its top-left corner.
    band(id, x, y, w, h, label, { tag } = {}) {
      entities.push({ tag: 'Shape', id, shape: 'rectangle', styleMode: 'plain', cornerRadius: 'round',
        x, y, width: w, height: h, bgColor: t.alt, borderColor: t.hairline, borderWidth: 1, texts: [] });
      entities.push({ tag: 'Textbox', id: `${id}_label`, x: x + 20, y: y + 12, width: w - 40, fixedWidth: true,
        text: label, typeface: 'mono', fontSize: 11, color: t.meta,
        ...(tag ? { badge: tagBadge(tag) } : {}) });
    },
    text(id, x, y, w, text, { size = 12, color, mono, align } = {}) {
      entities.push({ tag: 'Textbox', id, x, y, width: w, fixedWidth: true, text,
        typeface: mono ? 'mono' : 'clean', fontSize: size, color: color ?? t.secondary, hAlign: align });
    },
    divider(id, x, y, w) {
      entities.push({ tag: 'Divider', id, orientation: 'horizontal', x, y, width: w, color: t.hairline, lineWidth: 1 });
    },
    // Arrow between two entities. Defaults to a straight left-to-right line.
    arrow(from, to, { fromPort = 'right', toPort = 'left', label, accent, elbow } = {}) {
      connections.push({ from, to, fromPort, toPort, connectorStyle: elbow ? 'elbow' : 'straight',
        endArrowhead: 'triangle', color: accent ? t.orange : t.meta, lineWidth: 1,
        ...(label ? { label, typeface: 'mono', fontSize: 11, labelColor: t.secondary } : {}) });
    },
    done() { return { entities, connections }; },
  };
  return api;
}

// Lay out n equal-width boxes across [x, x + w] with a fixed gap. Returns their x positions and width.
export function spread(x, w, n, gap) {
  const bw = (w - gap * (n - 1)) / n;
  return { bw, xs: Array.from({ length: n }, (_, i) => x + i * (bw + gap)) };
}
