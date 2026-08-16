# Questbound Ascension

Questbound turns a task list into a focused, local-first RPG command deck. Create quests, earn XP and Gold, build streaks, run distraction-light focus sprints, and exchange Gold for real-world rewards you define yourself.

## Highlights

- Four quest classes from quick wins to 100 XP boss battles
- Level, rank, streak, energy, Gold, achievements, and weekly momentum systems
- Prime directive targeting, categories, priorities, filters, and search
- 5, 15, 25, and 50 minute focus protocols with session rewards
- Repeatable daily rituals and a custom reward Tavern
- Editable username and compressed local profile photo
- Device-local soundtrack player for MP3, WAV, OGG, M4A, AAC, or WebM files
- Mint, violet, and amber interface signals with optional reduced effects
- JSON save export/import and automatic migration from the original dashboard
- Responsive desktop, tablet, and mobile layouts

## Privacy and persistence

Campaign data is stored in browser `localStorage`. Profile photos are compressed before storage, while music is kept in IndexedDB. Nothing is uploaded to Questbound or committed to GitHub. Clearing browser site data removes the local campaign unless it has first been exported from Settings.

Only load audio you have the right to use. Browsers require an initial user action before music can play.

## Development

Requires Node.js 22.13 or newer.

```bash
npm ci
npm run dev
```

Useful checks:

```bash
npm run lint
npm test
```

The application is built with React 19, TypeScript, Vinext, Vite, and Cloudflare Workers. It intentionally needs no backend or account system.
