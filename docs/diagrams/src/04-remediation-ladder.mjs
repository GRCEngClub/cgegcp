// Diagram 04: the Stage 6 remediation ladder for one failing CHK-STG-01 bucket.
// A vertical spine of decisions, then three columns, one per mode, that never meet.
// Logic mirrors functions/remediator (recurrence rule, report_only / approve / auto).
import { canvas } from './club.mjs';

const W = 1200, TOP = 140;
const SP_X = 400, SP_W = 400;               // decision spine
const SIDE_X = 880, SIDE_W = 280;           // side outcomes (skip, recurrence)
const COL_W = 340, COL_XS = [40, 430, 820]; // three mode columns
const ROW = 100, CARD_H = 64;

export function build(t) {
  const colTop = TOP + 4 * ROW + 80;
  const H = colTop + 3 * ROW + 64;
  const d = canvas(t, { width: W, height: H, meta: 'Stage 6 · remediation ladder',
    title: 'How one public bucket gets fixed, or not',
    sub: 'One remediator run, for each assessment where check_id = CHK-STG-01 and status = fail.' });

  // Spine.
  const sy = (i) => TOP + i * ROW;
  d.card('start', SP_X, sy(0), SP_W, CARD_H, { icon: 'play', title: 'Remediator run',
    note: 'grc-remediate-daily · one pass per failing bucket' });
  d.card('d1', SP_X, sy(1), SP_W, CARD_H, { title: 'Already fixed for this failure?', titleFont: 'clean',
    note: 'prior status = fixed and fixed_at ≥ first_failed_at' });
  d.card('d2', SP_X, sy(2), SP_W, CARD_H, { title: 'Fixed before, failing again?', titleFont: 'clean',
    note: 'prior status = fixed, but before this failure began' });
  d.card('mode', SP_X, sy(3), SP_W, CARD_H + 8, { icon: 'sliders', title: 'MODE', tag: 'CM-3',
    note: 'Terraform variable. Raising it is a reviewed pull request' });
  d.arrow('start', 'd1', { fromPort: 'bottom', toPort: 'top' });
  d.arrow('d1', 'd2', { fromPort: 'bottom', toPort: 'top', label: 'no' });
  d.arrow('d2', 'mode', { fromPort: 'bottom', toPort: 'top', label: 'no' });

  // Side outcomes, to the right of their decision.
  d.card('skip', SIDE_X, sy(1), SIDE_W, CARD_H, { icon: 'check-circle', title: 'Skip', note: 'nothing to do' });
  d.card('recur', SIDE_X, sy(2), SIDE_W, CARD_H, { icon: 'rotate-ccw', title: 'Recurrence',
    note: 'reset the record, start the ladder over' });
  d.arrow('d1', 'skip', { label: 'yes' });
  d.arrow('d2', 'recur', { label: 'yes' });
  d.arrow('recur', 'mode', { fromPort: 'bottom', toPort: 'right', elbow: true });

  // Three columns, one per mode. Each fans out from the bottom of MODE.
  const cy = (i) => colTop + i * ROW;
  const cols = [
    { id: 'ro', label: 'report_only', cards: [
      ['would_fix', 'records the planned action and evidence. Bucket unchanged', 'eye'] ] },
    { id: 'ap', label: 'approve, not yet approved', cards: [
      ['pending_approval', 'logs the approve.py command to run', 'hourglass'],
      ['Human runs approve.py', '<project> <bucket>', 'user'],
      ['approved', 'approved_by = the human. Fixed on the next run', 'badge-check'] ] },
    { id: 'au', label: 'auto, or approve + approved', accent: true, cards: [
      ['Fix the bucket', 'remove allUsers / allAuthenticatedUsers, enforce public access prevention, keep UBLA on', 'tool'],
      ['fixed', 'fixed_at, removed, approved_by recorded', 'check-circle'],
      ['Next collect', 'CHK-STG-01 passes. The next POA&M drops the line', 'file-check'] ] },
  ];
  cols.forEach((col, c) => {
    col.cards.forEach(([title, note, icon], j) => {
      const id = `${col.id}${j}`;
      const titleFont = title.includes(' ') ? 'clean' : 'mono';
      d.card(id, COL_XS[c], cy(j), COL_W, CARD_H + (j === 0 && col.accent ? 16 : 0),
        { title, note, icon, titleFont, accent: col.accent && j === 0 });
      if (j > 0) d.arrow(`${col.id}${j - 1}`, id, { fromPort: 'bottom', toPort: 'top', accent: col.accent && j === 1 });
    });
    d.arrow('mode', `${col.id}0`, { fromPort: 'bottom', toPort: 'top', label: col.label, accent: col.accent });
  });

  d.text('foot', 40, cy(3) - 4, W - 80,
    'Raise the rung one step at a time: report_only, then approve, then auto. Each step is a pull request the gate checks.',
    { size: 12 });
  return d.done();
}
