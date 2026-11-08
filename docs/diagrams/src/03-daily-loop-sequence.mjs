// Diagram 03: one day of the loop, as four steps top to bottom.
// Each step is a band. Who acts is in column B, what it touches in column C,
// and anything it reads or writes on the side sits directly under column B.
// Arrows stay inside their band, so the steps read like a sequence without crossing lines.
import { canvas } from './club.mjs';

const W = 1200, TOP = 140;
const A_X = 60, A_W = 200;    // trigger
const B_X = 360, B_W = 300;   // actor
const C_X = 800, C_W = 340;   // target
const CARD_H = 60;

const STEPS = [
  { label: '1 · collect', tag: 'CA-7',
    a: ['Cloud Scheduler', 'grc-collect-daily', 'clock'],
    b: ['collector', 'grc-collector · changes nothing', 'scan-search'],
    c: ['Firestore · assessments', 'pass or fail with evidence, run_id, first_failed_at. A prior fail not seen this run is set to resolved', 'database'],
    bc: 'upsert',
    below: ['Cloud Asset Inventory', 'bucket IAM, SA roles, SA keys, audit configs', 'list-tree'], belowLabel: 'searchAllIamPolicies' },
  { label: '2 · remediate', tag: 'CM-3', accent: true,
    a: ['Cloud Scheduler', 'grc-remediate-daily', 'clock'],
    b: ['remediator', 'grc-remediator · reads failing CHK-STG-01', 'tool'],
    c: ['Public bucket', 'approve or auto: remove allUsers, enforce public access prevention, keep UBLA on', 'archive'],
    bc: 'fix',
    below: ['Firestore · remediations', 'would_fix, pending_approval, approved, fixed', 'database'], belowLabel: 'record',
    side: ['Human approver', 'approve.py sets approved_by', 'user'] },
  { label: '3 · re-collect',
    a: ['Cloud Scheduler', 'next collection', 'clock'],
    b: ['collector', 'grc-collector', 'scan-search'],
    c: ['Firestore · assessments', 'CHK-STG-01 now passes for that bucket', 'database'],
    bc: 'upsert' },
  { label: '4 · report', tag: 'AU-9',
    a: ['Cloud Scheduler', 'daily', 'clock'],
    b: ['reporter', 'grc-reporter · create-only', 'file-text'],
    c: ['Reports bucket · locked', 'POA&M CSV, SAR, OSCAL 1.1.2 SSP. The fixed finding has dropped off the POA&M', 'lock'],
    bc: 'write',
    below: ['Firestore', 'assessments, mappings, frameworks', 'database'], belowLabel: 'read' },
];

export function build(t) {
  const bandH = (s) => (s.below ? 44 + CARD_H + 40 + CARD_H + 20 : 44 + CARD_H + 20) + (s.c[1].length > 70 ? 12 : 0);
  let y = TOP;
  const ys = STEPS.map((s) => { const v = y; y += bandH(s) + 16; return v; });
  const H = y + 24;
  const d = canvas(t, { width: W, height: H, meta: 'Daily loop · detect, remediate, re-collect, report',
    title: 'One day of the pipeline, step by step',
    sub: 'Cloud Scheduler starts each step. Every write lands in Firestore or the locked reports bucket.' });

  STEPS.forEach((s, i) => {
    const by = ys[i], h = bandH(s), cy = by + 44;
    d.band(`b${i}`, 40, by, W - 80, h, s.label, { tag: s.tag });
    d.card(`a${i}`, A_X, cy, A_W, CARD_H, { title: s.a[0], note: s.a[1], icon: s.a[2], titleFont: 'clean', size: 12 });
    d.card(`m${i}`, B_X, cy, B_W, CARD_H, { title: s.b[0], note: s.b[1], icon: s.b[2], accent: s.accent });
    const cH = CARD_H + (s.c[1].length > 70 ? 12 : 0);
    d.card(`c${i}`, C_X, cy, C_W, cH, { title: s.c[0], note: s.c[1], icon: s.c[2], titleFont: 'clean', size: 12 });
    d.arrow(`a${i}`, `m${i}`, { label: 'invoke' });
    d.arrow(`m${i}`, `c${i}`, { label: s.bc, accent: s.accent });
    if (s.below) {
      const ly = cy + cH + 40;
      d.card(`l${i}`, B_X, ly, B_W, CARD_H, { title: s.below[0], note: s.below[1], icon: s.below[2], titleFont: 'clean', size: 12 });
      d.arrow(`m${i}`, `l${i}`, { fromPort: 'bottom', toPort: 'top', label: s.belowLabel });
      if (s.side) {
        d.card(`s${i}`, A_X, ly, A_W, CARD_H, { title: s.side[0], note: s.side[1], icon: s.side[2], titleFont: 'clean', size: 12 });
        d.arrow(`s${i}`, `l${i}`, { label: 'approve' });
      }
    }
  });
  return d.done();
}
