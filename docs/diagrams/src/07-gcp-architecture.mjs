// Diagram 07: the Google Cloud resources the Terraform creates, with product icons.
// Resource names come from stages/*/main.tf and labs/03-foundation/*.sh.
// One lane per workload (scheduler -> function -> what it touches), so no line leaves its lane.
// Shared stores (Firestore, the reports bucket) are drawn again in every lane that uses them.
import { canvas, spread } from './club.mjs';

const W = 1440, TOP = 140;
const GH_X = 40, GH_W = 260;
const PJ_X = 340, PJ_W = W - 40 - PJ_X;
const BAND_X = PJ_X + 20, BAND_W = PJ_W - 40;
const IN_X = BAND_X + 20, IN_W = BAND_W - 40;
const A = { x: IN_X, w: 230 }, B = { x: IN_X + 290, w: 260 }, C = { x: IN_X + IN_W - 300, w: 300 };
const CARD_H = 68, LANE_GAP = 16;

// Platform resources, Stage 0 and the foundation lab. [icon, title, note]
const PLATFORM = [
  ['gcloud-workload-identity-pool', 'WIF pool github', 'OIDC provider for your fork'],
  ['gcloud-cloud-build', 'Cloud Build', 'builds every function as grc-builder'],
  ['gcloud-cloud-apis', 'Service Usage', '15 APIs enabled as code'],
  ['gcloud-cloud-storage', '<project>-tfstate', 'Terraform state, versioned'],
  ['gcloud-cloud-storage', '<project>-fn-source', 'function source zips'],
  ['gcloud-iam', 'IAM', '6 service accounts, zero permissions at birth'],
];

// One lane per workload. a = trigger, b = actor, c = one or two targets [icon, title, note, arrow label].
const LANES = [
  { label: 'Stage 2 · audit logging', tag: 'AU-11',
    a: ['gcloud-cloud-audit-logs', 'Data Access logs', 'Cloud Storage, read + write'],
    b: ['gcloud-cloud-logging', 'grc-audit-sink', 'Log Router sink'], ab: 'route',
    c: [['gcloud-cloud-logging', 'grc-audit-logs', 'log bucket, 365 days', 'store']] },
  { label: 'Stage 3 · collect', tag: 'CA-7',
    a: ['gcloud-cloud-scheduler', 'grc-collect-daily', 'Cloud Scheduler'],
    b: ['gcloud-cloud-run', 'grc-collector', 'Cloud Run function · python312'],
    c: [['gcloud-asset-inventory', 'Cloud Asset Inventory', 'IAM policies, buckets, keys', 'read'],
        ['gcloud-firestore', 'Firestore (default)', 'assessments', 'write']] },
  { label: 'Stage 4 · report', tag: 'AU-9',
    a: ['gcloud-cloud-scheduler', 'grc-report-*', 'poam daily, sar and ssp weekly'],
    b: ['gcloud-cloud-run', 'grc-reporter', 'Cloud Run function · python312'],
    c: [['gcloud-firestore', 'Firestore (default)', 'assessments, mappings, frameworks', 'read'],
        ['gcloud-cloud-storage', '<project>-reports', 'retention policy locked', 'create']] },
  { label: 'Stage 5 · narrate, optional',
    a: ['gcloud-cloud-scheduler', 'grc-digest-weekly', 'Cloud Scheduler'],
    b: ['gcloud-cloud-run', 'grc-narrator', 'Cloud Run function · python312'],
    c: [['gcloud-cloud-storage', '<project>-reports', 'reads SAR, writes the digest', 'read + write'],
        ['gcloud-vertex-ai', 'Vertex AI', 'Gemini', 'generate']] },
  { label: 'Stage 6 · remediate', tag: 'CM-3', accent: true,
    a: ['gcloud-cloud-scheduler', 'grc-remediate-daily', 'Cloud Scheduler'],
    b: ['gcloud-cloud-run', 'grc-remediator', 'custom role grcBucketRemediator'],
    c: [['gcloud-cloud-storage', 'public buckets', 'IAM binding removed, PAP enforced', 'fix'],
        ['gcloud-firestore', 'Firestore (default)', 'remediations', 'record']] },
];

export function build(t) {
  const platH = 44 + 2 * CARD_H + 12 + 20;
  const laneH = (l) => 44 + (l.c.length === 2 ? 2 * CARD_H + 12 : CARD_H) + 20;
  let y = TOP + 44 + platH + LANE_GAP;
  const laneYs = LANES.map((l) => { const v = y; y += laneH(l) + LANE_GAP; return v; });
  const PJ_H = y - TOP + 4;
  const H = TOP + PJ_H + 76;

  const d = canvas(t, { width: W, height: H, meta: 'Architecture · Google Cloud resources',
    title: 'What the Terraform builds in your project',
    sub: 'Every box is a resource in stages/ or the foundation lab, with its real name. <project> is your project ID.' });
  const card = (id, x, y, w, [icon, title, note], accent) =>
    d.card(id, x, y, w, CARD_H, { icon, title, note, accent, size: 12, align: 'left' });

  d.band('proj', PJ_X, TOP, PJ_W, PJ_H, 'Google Cloud project · one region (var.region) · no Organization');

  // Platform strip.
  const py = TOP + 44;
  d.card('plat', BAND_X, py, BAND_W, platH, { fill: t.page });
  d.text('plat_label', BAND_X + 20, py + 12, 600, 'Stage 0 and the foundation lab · platform', { mono: true, size: 11, color: t.meta });
  d.text('plat_tag', BAND_X + BAND_W - 120, py + 12, 100, 'AC-6', { mono: true, size: 11, color: t.meta, align: 'right' });
  const { bw, xs } = spread(IN_X, IN_W, 3, 20);
  PLATFORM.forEach((p, i) => card(`p${i}`, xs[i % 3], py + 44 + Math.floor(i / 3) * (CARD_H + 12), bw, p));

  // GitHub, level with the WIF pool.
  d.band('gh', GH_X, TOP, GH_W, PJ_H, 'GitHub · your fork');
  card('gate', GH_X + 20, py + 44, GH_W - 40, ['github', 'gate.yml', 'every pull request']);
  card('drift', GH_X + 20, py + 44 + CARD_H + 12, GH_W - 40, ['github', 'drift.yml', 'nightly']);
  d.arrow('gate', 'p0', { label: 'OIDC' });
  d.arrow('drift', 'p0');
  d.text('gh_note', GH_X + 20, py + 44 + 2 * (CARD_H + 12) + 8, GH_W - 40,
    'Both plan with a read-only identity. Neither ever applies.', { size: 11 });

  // Workload lanes.
  LANES.forEach((l, i) => {
    const ly = laneYs[i], h = laneH(l);
    d.card(`l${i}`, BAND_X, ly, BAND_W, h, { fill: t.page });
    d.text(`l${i}_label`, BAND_X + 20, ly + 12, 500, l.label, { mono: true, size: 11, color: t.meta });
    if (l.tag) d.text(`l${i}_tag`, BAND_X + BAND_W - 120, ly + 12, 100, l.tag, { mono: true, size: 11, color: t.meta, align: 'right' });
    const mid = ly + 44 + (h - 64 - CARD_H) / 2;
    card(`a${i}`, A.x, mid, A.w, l.a);
    card(`b${i}`, B.x, mid, B.w, l.b, l.accent);
    d.arrow(`a${i}`, `b${i}`, { label: l.ab ?? 'invoke' });
    l.c.forEach((c, j) => {
      card(`c${i}_${j}`, C.x, ly + 44 + j * (CARD_H + 12), C.w, c);
      d.arrow(`b${i}`, `c${i}_${j}`, { label: c[3], accent: l.accent && j === 0 });
    });
  });

  d.text('foot', 40, H - 56, W - 80,
    'Each function runs as its own service account. Only grc-scheduler can invoke them, one service at a time. Only grc-remediator can change a resource.',
    { size: 12 });
  return d.done();
}
