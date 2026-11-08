// Diagram 05: the preventive gate (gate.yml) and detective drift check (drift.yml).
// Two side-by-side columns that never connect, then the rego rules the gate enforces.
// Rule text comes from policy/*.rego and docs/CONTROLS.md.
import { canvas, spread } from './club.mjs';

const W = 1200, TOP = 140;
const COL_W = 540, XS = [40, 620];
const STEP = 84, CARD_H = 60;

const GATE = [
  ['git-pull-request', 'Pull request opened', 'every change to stages/ or policy/'],
  ['key-round', 'OIDC token', 'GitHub mints it for this run'],
  ['gcloud-workload-identity-pool', 'Workload Identity Federation', 'short-lived token, read-only CI identity'],
  ['terminal', 'terraform init', 'one job per stage, state in the tfstate bucket'],
  ['terminal', 'terraform plan', 'then terraform show -json'],
  ['shield-check', 'conftest test', 'the plan against policy/*.rego', true],
];
const DRIFT = [
  ['calendar-clock', 'Scheduled run', 'nightly'],
  ['key-round', 'OIDC token', 'GitHub mints it for this run'],
  ['gcloud-workload-identity-pool', 'Workload Identity Federation', 'same read-only CI identity'],
  ['terminal', 'terraform plan -detailed-exitcode', 'every stage. Exit code 2 means changes'],
  ['github', 'Open a GitHub issue', 'with the diff: reality and code disagree'],
  ['eye', 'Reported, never fixed by CI', 'you decide: revert the change, or codify it'],
];

const RULES = [
  ['iam.rego', ['CHK-IAM-01 · no basic roles (owner, editor, viewer)', 'CHK-IAM-02 · no service account keys'], 'AC-6 · IA-5'],
  ['storage.rego', ['CHK-STG-01 · public access prevention on, no allUsers', 'CHK-STG-02 · uniform bucket-level access on'], 'AC-3 · SC-7'],
  ['remediation.rego', 'The remediator runs as grc-remediator and no other identity', 'AC-5'],
];

export function build(t) {
  const colH = 52 + GATE.length * STEP + STEP + 8;
  const rulesY = TOP + colH + 32;
  const H = rulesY + 44 + 96 + 64;
  const d = canvas(t, { width: W, height: H, meta: 'CI · prevent and detect',
    title: 'The gate stops bad plans, the drift check reports bad reality',
    sub: 'Both run in GitHub Actions with no keys. Neither one ever runs terraform apply.' });

  const column = (key, x, label, steps) => {
    d.band(key, x, TOP, COL_W, colH, label);
    steps.forEach(([icon, title, note, accent], i) => {
      const id = `${key}${i}`;
      const titleFont = title.startsWith('terraform') || title.startsWith('conftest') ? 'mono' : 'clean';
      d.card(id, x + 20, TOP + 44 + i * STEP, COL_W - 40, CARD_H, { icon, title, note, titleFont, accent, size: 13 });
      if (i > 0) d.arrow(`${key}${i - 1}`, id, { fromPort: 'bottom', toPort: 'top' });
    });
  };
  column('g', XS[0], 'gate.yml · every pull request', GATE);
  column('d', XS[1], 'drift.yml · nightly', DRIFT);

  // Gate outcome: pass and fail side by side under conftest.
  const oy = TOP + 44 + GATE.length * STEP;
  const half = (COL_W - 40 - 20) / 2;
  d.card('pass', XS[0] + 20, oy, half, CARD_H, { icon: 'check', title: 'Pass', note: 'merge allowed', titleFont: 'clean' });
  d.card('fail', XS[0] + 40 + half, oy, half, CARD_H, { icon: 'x', title: 'Fail', note: 'names each rule it broke', titleFont: 'clean' });
  d.arrow(`g${GATE.length - 1}`, 'pass', { fromPort: 'bottom', toPort: 'top', accent: true });
  d.arrow(`g${GATE.length - 1}`, 'fail', { fromPort: 'bottom', toPort: 'top', accent: true });

  // The rules.
  d.text('rules_label', 40, rulesY, W - 80, 'policy/ · the rules conftest enforces', { mono: true, size: 11, color: t.meta });
  const { bw, xs } = spread(40, W - 80, RULES.length, 20);
  RULES.forEach(([file, body, tag], i) => {
    d.card(`r${i}`, xs[i], rulesY + 28, bw, 96, { title: file, note: body, tag, align: 'left' });
  });
  d.text('foot', 40, rulesY + 140, W - 80,
    'The four CHK rules also run daily in the collector as detective checks. Prevention and detection report under the same check ID.',
    { size: 12 });
  return d.done();
}
