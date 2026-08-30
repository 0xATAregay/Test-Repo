# Testing EdgeLab

Run the verification sequence from a clean checkout:

```bash
npm run install:ci
npm run typecheck
npm run lint
npm test
npm run build
npm run validate:artifact
```

## Manual acceptance pass

Test at desktop and 360px viewport widths.

1. Clear local storage, set `profile.onboarded=false` in a dev fixture, complete onboarding, and verify Today appears with at most three missions.
2. Academy: answer both questions, provide a 30+ character application artifact, verify completion and a single XP event after refresh.
3. Analysis Lab: submit all required fields, verify the answer locks before future bars appear, inspect rubric feedback, and confirm a journal/evidence record is created.
4. Playbook: change notes, provide a revision reason, create a version, and confirm old decisions retain their original `playbookVersionId`.
5. Weekly Review: inspect evidence summary/sample warning, complete six prompts, save, and confirm journal/XP update.
6. Simulate `profile.lastActiveAt` more than four days ago and verify Comeback Mode hides normal backlog and offers one short re-entry task.
7. Export JSON, reset local data, paste the backup, restore, and compare case/journal/XP counts.
8. Navigate all primary areas with keyboard only. Confirm skip link, focus visibility, native form controls, modal focus visibility, and chart data table.
9. Enable reduced motion, high contrast, and 125% font size. Verify no clipped primary controls at 360px.
10. Leave all AI environment variables blank and verify every core workflow remains functional.

## Invariants

- `awardXP` is idempotent by event key.
- A lab case has at most one saved decision per user in the cloud model.
- Lab decisions are immutable after reveal in the UI flow.
- Process score never reads post-reveal bars.
- Playbook revision appends a version and requires a reason.
- Deleted journal entries are soft-deleted and restorable.
- Analytics are derived from saved state, never invented user results.
- Sample-size warnings appear for small blind-case counts.
