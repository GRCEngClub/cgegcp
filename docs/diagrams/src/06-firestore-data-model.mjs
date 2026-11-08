// Diagram 06: the Firestore evidence store. Four collections, each a field table.
// The references form one chain (remediations -> assessments -> mappings -> frameworks),
// laid out as a U so every arrow is a single straight line.
// Field names come from functions/collector, functions/remediator and the seed script.
import { canvas } from './club.mjs';

const W = 1200, TOP = 140;
const XS = [40, 660], CW = 500;
const ROW_H = 26, HEAD = 64;

// [name, type, note]
const COLLECTIONS = {
  frameworks: { writer: 'seeded', fields: [
    ['id', 'string · pk', 'e.g. PR.AA-05'],
    ['framework', 'string', 'NIST CSF 2.0'],
    ['title', 'string', ''] ] },
  mappings: { writer: 'seeded', fields: [
    ['id', 'string · pk', 'e.g. CHK-STG-01'],
    ['title', 'string', ''],
    ['csf', 'string[] · fk', 'frameworks ids'],
    ['sp800_53', 'string[]', 'AC-3, AC-6, SC-7'],
    ['severity', 'string', ''] ] },
  assessments: { writer: 'written by grc-collector', accent: true, fields: [
    ['id', 'string · pk', 'check + resource hash'],
    ['check_id', 'string · fk', 'mappings id'],
    ['resource', 'string', ''],
    ['status', 'enum', 'pass, fail, resolved'],
    ['evidence', 'string', 'what was observed'],
    ['title', 'string', ''],
    ['severity', 'string', ''],
    ['csf', 'string[]', ''],
    ['sp800_53', 'string[]', ''],
    ['first_failed_at', 'timestamp', 'POA&M age'],
    ['collected_at', 'timestamp', ''],
    ['run_id', 'string', ''],
    ['collector', 'string', 'grc-collector'],
    ['resolved_reason', 'string?', ''] ] },
  remediations: { writer: 'written by grc-remediator, approve.py', fields: [
    ['id', 'string · pk', 'same as the assessment id'],
    ['assessment', 'string · fk', 'assessments id'],
    ['bucket', 'string', ''],
    ['check_id', 'string', ''],
    ['action', 'string', ''],
    ['evidence', 'string', ''],
    ['mode', 'enum', 'report_only, approve, auto'],
    ['status', 'enum', 'would_fix → fixed, 4 states'],
    ['approved_by', 'string?', ''],
    ['removed', 'string[]', 'members taken off'],
    ['fixed_at', 'timestamp?', ''],
    ['updated_at', 'timestamp', ''] ] },
};

export function build(t) {
  const height = (n) => HEAD + n * ROW_H + 16;
  const topH = Math.max(height(3), height(5));
  const botH = Math.max(height(14), height(12));
  const BOT = TOP + topH + 72;
  const H = BOT + botH + 72;
  const d = canvas(t, { width: W, height: H, meta: 'Data model · Firestore',
    title: 'The evidence store: four collections, one chain of references',
    sub: 'Reference data is seeded. Assessments are facts from the collector. Remediations record every change.' });

  const table = (name, x, y, h) => {
    const c = COLLECTIONS[name];
    d.card(name, x, y, CW, h, { accent: c.accent });
    d.text(`${name}_name`, x + 20, y + 16, 260, name, { mono: true, size: 15, color: t.text });
    d.text(`${name}_writer`, x + 240, y + 19, CW - 260, c.writer, { mono: true, size: 11, color: c.accent ? t.orangeText : t.meta, align: 'right' });
    d.divider(`${name}_div`, x + 1, y + HEAD - 12, CW - 2);
    c.fields.forEach(([f, type, note], i) => {
      const fy = y + HEAD + i * ROW_H - 4;
      d.text(`${name}_f${i}`, x + 20, fy, 150, f, { mono: true, size: 12, color: t.text });
      d.text(`${name}_t${i}`, x + 170, fy, 170, type, { mono: true, size: 11, color: t.meta });
      if (note) d.text(`${name}_n${i}`, x + 340, fy, CW - 356, note, { size: 11 });
    });
  };
  table('frameworks', XS[0], TOP, topH);
  table('mappings', XS[1], TOP, topH);
  table('remediations', XS[0], BOT, botH);
  table('assessments', XS[1], BOT, botH);

  d.arrow('mappings', 'frameworks', { fromPort: 'left', toPort: 'right', label: 'csf[]' });
  d.arrow('assessments', 'mappings', { fromPort: 'top', toPort: 'bottom', label: 'check_id → id' });
  d.arrow('remediations', 'assessments', { fromPort: 'right', toPort: 'left', label: '1 : 1' });
  d.text('foot', 40, H - 52, W - 80,
    'A failing assessment keeps its first_failed_at across runs, so the POA&M shows how long it has been open.', { size: 12 });
  return d.done();
}
