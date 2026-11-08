// Diagram 02: each pipeline identity and exactly what it is granted.
// Grants come from stages/*/main.tf. One row per identity; a resource used by two
// identities is drawn once in each row, so no line ever crosses another.
import { canvas } from './club.mjs';

const ROWS = [
  { id: 'builder', name: 'grc-builder', note: 'Stage 3+ · build only', icon: 'hammer', grants: [
    ['objectViewer', 'Function source bucket', 'package'],
    ['cloudbuild.builds.builder', 'Cloud Build', 'hammer'] ] },
  { id: 'collector', name: 'grc-collector', note: 'Stage 3 · changes nothing', icon: 'scan-search', grants: [
    ['cloudasset.viewer', 'Cloud Asset Inventory', 'list-tree'],
    ['datastore.user', 'Firestore · writes assessments', 'database'] ] },
  { id: 'reporter', name: 'grc-reporter', note: 'Stage 4 · create-only on reports', icon: 'file-text', grants: [
    ['datastore.viewer', 'Firestore · reads evidence', 'database'],
    ['objectCreator', 'Reports bucket · locked, AU-9', 'lock'] ] },
  { id: 'narrator', name: 'grc-narrator', note: 'Stage 5 · optional', icon: 'sparkles', grants: [
    ['objectViewer + objectCreator', 'Reports bucket · digest', 'lock'],
    ['aiplatform.user', 'Vertex AI', 'brain'] ] },
  { id: 'remediator', name: 'grc-remediator', note: 'Stage 6 · the only identity that changes resources', icon: 'tool', accent: true, grants: [
    ['grcBucketRemediator · 4 permissions', 'Bucket IAM + settings', 'archive'],
    ['datastore.user', 'Firestore · remediations', 'database'] ] },
  { id: 'scheduler', name: 'grc-scheduler', note: 'Invoke only', icon: 'clock', grants: [
    ['run.invoker', 'Collector, reporter, narrator, remediator', 'zap'] ] },
  { id: 'ci', name: 'GitHub Actions CI', note: 'Workload Identity Federation · no keys · never applies', icon: 'github', grants: [
    ['read-only roles + state lock', 'Project (read) + tfstate bucket', 'file-lock'] ] },
];

const W = 1200, ROW_H = 132, TOP = 132, ID_X = 40, ID_W = 340, ID_H = 76, RES_X = 820, RES_W = 340, RES_H = 52;

export function build(t) {
  const H = TOP + ROWS.length * ROW_H + 120;
  const d = canvas(t, { width: W, height: H, meta: 'Identities · least privilege',
    title: 'Six identities, each granted only what its job needs',
    sub: 'Created in Stage 0 with zero permissions. Each later stage grants its own identity.' });

  ROWS.forEach((row, i) => {
    const y = TOP + i * ROW_H;
    if (i > 0) d.divider(`div${i}`, 40, y - 4, W - 80);
    d.card(row.id, ID_X, y + (ROW_H - 8 - ID_H) / 2, ID_W, ID_H,
      { title: row.name, note: row.note, icon: row.icon, accent: row.accent, size: 15 });
    const n = row.grants.length;
    row.grants.forEach(([perm, res, icon], j) => {
      const rid = `${row.id}_r${j}`;
      const ry = n === 1 ? y + (ROW_H - 8 - RES_H) / 2 : y + 8 + j * (RES_H + 12);
      d.card(rid, RES_X, ry, RES_W, RES_H, { title: res, icon, titleFont: 'clean' });
      d.arrow(row.id, rid, { label: perm, accent: row.accent });
    });
  });

  const cy = TOP + ROWS.length * ROW_H + 24;
  d.card('sod', ID_X, cy, 540, 56, { icon: 'split', tag: 'AC-5', align: 'left',
    note: "Collector writes facts, reporter writes reports. Neither can do the other's job" });
  d.card('gate', 620, cy, 540, 56, { icon: 'shield-check', tag: 'AC-6', align: 'left',
    note: 'The policy gate fails any plan that runs the remediator as another identity' });
  return d.done();
}
