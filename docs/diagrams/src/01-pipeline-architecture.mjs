// Diagram 01: the whole pipeline. GitHub on the left, one band per stage on the right.
// Arrows only run left-to-right inside a band; a resource used by two stages
// (Firestore, the reports bucket) is drawn again in each band that touches it.
import { canvas, spread } from './club.mjs';

const W = 1400, TOP = 140;
const GH_X = 40, GH_W = 260;
const PJ_X = 440, PJ_W = W - 40 - PJ_X;
const BAND_X = PJ_X + 20, BAND_W = PJ_W - 40, BAND_H = 124, BAND_GAP = 12;
const IN_X = BAND_X + 20, IN_W = BAND_W - 40, CARD_H = 60, GAP = 32;

// [stage label, control tag, cards [title, note, accent?], draw arrows between cards?]
const STAGES = [
  ['Stage 0 · foundation', 'AC-6', [
    ['15 APIs', 'enabled as code'],
    ['6 service accounts', 'created with zero permissions'],
    ['tfstate bucket', 'Terraform state, versioned'] ], false],
  ['Stage 1 · discovery', null, [
    ['discover.sh', 'read-only'],
    ['gap map', 'what is missing. Changes nothing'] ], true],
  ['Stage 2 · activation', 'AU-11', [
    ['Data Access logs', 'GCS reads and writes'],
    ['Log Router sink', 'routes audit logs'],
    ['grc-audit-logs', 'log bucket, 365 days'] ], true],
  ['Stage 3 · evidence store', 'CA-7', [
    ['Scheduler', 'grc-collect-daily'],
    ['collector', 'grc-collector'],
    ['Asset Inventory', 'five checks'],
    ['Firestore', 'assessments'],
    ['reports bucket', 'locked, WORM'] ], 'first4'],
  ['Stage 4 · reporting', 'AU-9', [
    ['Scheduler', 'daily'],
    ['reporter', 'grc-reporter'],
    ['Firestore', 'reads evidence'],
    ['reports bucket', 'POA&M, SAR, OSCAL SSP'] ], true],
  ['Stage 5 · narrative, optional', null, [
    ['Scheduler', 'weekly'],
    ['narrator', 'grc-narrator'],
    ['reports bucket', 'reads SAR, POA&M'],
    ['Vertex AI', 'Gemini'],
    ['weekly digest', 'describes, never decides'] ], true],
  ['Stage 6 · enforcement', 'CM-3', [
    ['Scheduler', 'grc-remediate-daily'],
    ['remediator', 'grc-remediator', true],
    ['public buckets', 'fixed on the ladder'],
    ['Firestore', 'remediations'] ], true],
];

export function build(t) {
  const PJ_H = 44 + STAGES.length * BAND_H + (STAGES.length - 1) * BAND_GAP + 20;
  const H = TOP + PJ_H + 40;
  const d = canvas(t, { width: W, height: H, meta: 'Architecture · seven stages',
    title: 'The CGE-GCP pipeline, from GitHub to your project',
    sub: 'Each stage is its own Terraform root and runs as its own identity. CI only reads; it never applies.' });

  // Your project: one band per stage.
  d.band('proj', PJ_X, TOP, PJ_W, PJ_H, 'Your Google Cloud project · no Organization needed');
  STAGES.forEach(([label, tag, cards, arrows], i) => {
    const by = TOP + 44 + i * (BAND_H + BAND_GAP);
    d.card(`s${i}`, BAND_X, by, BAND_W, BAND_H, { fill: t.page });
    d.text(`s${i}_label`, BAND_X + 20, by + 12, 400, label, { mono: true, size: 11, color: t.meta });
    if (tag) d.text(`s${i}_tag`, BAND_X + BAND_W - 120, by + 12, 100, tag, { mono: true, size: 11, color: t.meta, align: 'right' });
    const { bw, xs } = spread(IN_X, IN_W, cards.length, GAP);
    cards.forEach(([title, note, accent], j) => {
      d.card(`s${i}_c${j}`, xs[j], by + 44, bw, CARD_H, { title, note, accent, size: 12 });
      const linked = arrows === true || (arrows === 'first4' && j < 4);
      if (j > 0 && linked) d.arrow(`s${i}_c${j - 1}`, `s${i}_c${j}`, { accent: cards[j - 1][2] });
    });
  });

  // GitHub side: three stacked cards, then the one arrow into the project.
  const midY = TOP + PJ_H / 2;
  d.band('gh', GH_X, TOP, GH_W, PJ_H, 'GitHub · your fork');
  d.card('gate', GH_X + 20, midY - 242, GH_W - 40, 84, { icon: 'git-pull-request', title: 'gate.yml',
    note: 'plan + conftest on every pull request' });
  d.card('drift', GH_X + 20, midY - 142, GH_W - 40, 84, { icon: 'calendar-clock', title: 'drift.yml',
    note: 'nightly plan, opens an issue' });
  d.card('wif', GH_X + 20, midY - 42, GH_W - 40, 84, { icon: 'key-round', title: 'Workload Identity Federation',
    titleFont: 'clean', note: 'short-lived token, no keys' });
  d.text('gh_note', GH_X + 20, midY + 64, GH_W - 40,
    'Both workflows sign in through WIF with a read-only identity. Applying is done by you, from your machine.', { size: 11 });
  d.arrow('wif', 'proj', { label: 'read-only plan' });
  return d.done();
}
