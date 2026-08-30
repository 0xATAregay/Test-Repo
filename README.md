# EdgeLab

EdgeLab is a six-month, education-only futures-market apprenticeship application. It is designed to turn passive content consumption into deliberate practice: learn a concept, analyze an unseen chart, classify the situation, explain the evidence, reveal additional information, grade the process, record the mistake, and receive the next appropriate drill.

It deliberately does **not** implement real-money trading, broker connections, order execution, funded-account integrations, copying, live signals, leverage/position-size recommendations, profit projections, money targets, or simulated P/L. Hypothetical exercises have limitations and do not predict real performance. Completing 24 weeks is an evidence checkpoint, not a readiness guarantee.

## Product areas

- **Today**: at most three primary missions, current focus, recent mistake, one-click focus session, and calm Comeback Mode after inactivity.
- **Roadmap**: complete 24-week / six-phase curriculum from foundations through education-only validation.
- **Academy**: 48 original seeded lessons, vocabulary, quizzes, application artifacts, search, and verified completion.
- **Analysis Lab**: 48 deterministic synthetic OHLC cases, hidden future, EMA, zoom/pan, accessible data table, pre-reveal classification, locked decisions, transparent process rubric, journal/evidence integration, adaptive next case.
- **Playbook**: one active primary playbook, immutable versions, mandatory revision reasons, historical version binding, comparison history.
- **Journal**: structured case/lesson/review evidence, search, tags, favorites, edit, soft-delete, restore.
- **Weekly Review**: evidence aggregation, sample warnings, six guided prompts, next-focus recommendation.
- **Analytics**: process adherence, recognition signal, correct unclear calls, false-positive signal, context breakdown, recurring mistakes, accessible tables and explicit limitations.
- **Evidence Library**: searchable grid/list of saved learning artifacts.
- **Settings**: theme, high contrast, reduced motion, font scaling, profile/session settings, JSON/CSV export, validated restore, reset, and AI fallback status.

## Architecture

The repository keeps the existing Next.js 16 / React 19 / Cloudflare-compatible deployment scaffolding and replaces the product layer with EdgeLab.

```text
app/
  page.tsx       route entry
  edgelab.tsx    application shell + complete product workflows
  chart.tsx      dependency-free educational candlestick visualization
  domain.ts      deterministic domain rules and data contracts
  seed.ts        24-week curriculum, 48 lessons, 48 deterministic lab cases, demo records
  store.ts       local-first persistence, CSV/download helpers, analytics selectors
  globals.css    tokenized responsive design system
  layout.tsx     metadata/root shell
db/
  schema.ts      cloud relational model and constraints
drizzle/         generated migration output
scripts/         inherited verified build/deployment scripts
tests/           domain + rendered application checks
docs/            architecture and testing notes
```

### Local-first repository decision

The default app uses browser local storage behind a small state/repository boundary so it remains fully functional with no external credentials. This is intentional for guest/demo mode. The relational Drizzle schema isolates the future cloud adapter. Production cloud synchronization should implement the same domain operations and preserve the idempotency/versioning constraints already represented in the schema.

For larger user attachments, a production adapter should use object storage and IndexedDB rather than localStorage. The current local demo intentionally stores structured records only.

## Data model

`db/schema.ts` defines User, Profile, UserSettings, CurriculumPhase, CurriculumWeek, Lesson, LessonProgress, VocabularyCard, Quiz, QuizQuestion, QuizAttempt, StudySession, FocusSession, Playbook, PlaybookVersion, ChecklistItem, LabCase, LabCaseRubric, LabDecision, JournalEntry, MistakeTag, JournalMistakeTag, WeeklyReview, EvidenceArtifact, Attachment, CoachInsight, XPEvent, Achievement, UserAchievement, Notification, and ImportExportRecord.

Important constraints include one lesson-progress row per user/lesson, one lab decision per user/case, immutable playbook version numbers, one weekly review per user/week, and one XP event per user/event key. UTC timestamps are used in persistence; UI display uses the browser/user locale.

## Setup

Requirements: Node >= 22.13 and npm.

```bash
npm run install:ci
npm run dev
```

The inherited Cloudflare/vinext environment scripts are preserved because the repository was already configured for that deployment environment.

## Environment variables

Copy `.env.example` to `.env.local` for optional integrations. EdgeLab requires no AI or cloud key to run locally.

```bash
cp .env.example .env.local
```

## Database and migrations

The Drizzle schema is in `db/schema.ts`.

```bash
npm run db:generate
```

Apply generated SQL using the database tooling appropriate to the deployment environment. Never claim a cloud connection succeeded unless `DATABASE_URL` is actually configured and verified.

## Seed behavior

`app/seed.ts` ships deterministic educational content:

- 24 substantive curriculum weeks across six phases
- 48 original lesson units (two per week), each with objective, explanation, misconception, quiz, exercise, reflection, vocabulary and estimated time
- 48 deterministic synthetic OHLC lab cases across trend, range, transition, breakout, failed-breakout, pullback and ambiguous conditions
- starter two-legged-pullback/21-EMA educational playbook template
- labeled example journal/evidence records
- demo progression state

Seed records are client-side demo data and do not contaminate a cloud user account.

## AI coach

The product is provider-agnostic by design. A future server endpoint should accept only educational operations (Socratic questions, note-derived quizzes, reasoning quality checks, playbook comparison, mistake summaries, weekly-review drafts, drill recommendations, general concept explanation) and return citations to saved EdgeLab record IDs.

When `AI_API_KEY` is absent, the app remains functional. Current local fallback uses deterministic rules: process rubric feedback, thin-reasoning detection, checklist consistency, sample-size warnings, recurring mistake counts, and adaptive drill selection.

Never place provider secrets in `NEXT_PUBLIC_*` variables or client code.

## Import/export format

Full backups are JSON:

```json
{
  "schemaVersion": 2,
  "exportedAt": "UTC ISO timestamp",
  "app": "EdgeLab",
  "data": { "...": "complete personal state" }
}
```

Imports validate app identity, supported schema version, profile presence, and XP ledger shape before replacing local state. Schema v1 is accepted and normalized to v2. Journal CSV export is also available. A production attachment adapter should include an attachment manifest and verify referenced blobs before commit.

## Accessibility

Target is WCAG 2.2 AA. The implementation includes semantic regions, a skip link, visible keyboard focus, native labeled controls, dialog semantics, 44px mobile controls, non-color text labels, high-contrast mode, adjustable font size, reduced-motion mode, chart `<title>` plus tabular OHLC alternative, responsive tables, and status messaging. Keyboard behavior relies primarily on robust native controls rather than custom ARIA widgets.

## Security and privacy

- No real-money execution or financial-service integrations.
- No client secrets.
- Cloud schema is scoped by user IDs and expects authorization at the server/repository boundary.
- XP event keys and lab decision constraints prevent duplicate awards/answers at the database layer.
- Playbook versions are append-only domain records.
- Journal deletion is soft where restore is promised.
- A production attachment endpoint must enforce authentication, authorization, MIME allowlists, size limits, filename normalization, malware scanning where available, and object-store isolation.
- AI endpoints should validate payloads server-side and rate-limit by authenticated user/IP.
- Rich text should be rendered from a sanitized Markdown AST, never raw user HTML.
- Do not log journal content or AI prompts by default.
- EdgeLab makes no compliance-certification claims.

## Verification

```bash
npm run typecheck
npm run lint
npm test
npm run build
npm run validate:artifact
```

The domain tests cover XP idempotency, playbook versioning, process scoring, sample warnings, import/export, comeback behavior, adaptive drill selection, weekly aggregation, deterministic case count and curriculum count. Existing rendered-artifact checks remain useful for deployment validation.

## Deployment

The existing repository is Cloudflare/vinext-oriented. Use the repository's verified build script and deployment environment. Configure cloud variables only in the host's secret manager. The application itself does not require external services for guest/local mode.

## Educational limitations

EdgeLab is an educational deliberate-practice tool, not an investment adviser, broker, signal service, or prediction engine. Synthetic and historical exercises simplify reality. Process scores describe consistency with an educational rubric; they do not establish expected returns. Six months is a checkpoint. The final validation phase should recommend more study, playbook refinement, a larger blind-practice sample, repeated structured observation, or another education-only validation phase according to evidence.

## Known limitations

The local-first implementation intentionally favors structured text records and deterministic synthetic charts. Cloud authentication/synchronization, binary attachment object storage, provider-backed AI, push scheduling, and licensed historical-data ingestion require external infrastructure/credentials and are therefore represented by the cloud schema/interface guidance rather than falsely reported as connected. The app remains usable without them.
