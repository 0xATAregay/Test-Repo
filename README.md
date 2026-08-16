# Questbound

Questbound is a lightweight, single-page productivity RPG for turning concrete tasks into quests. It is designed to stay readable, calm, and fast: no account, no backend, and no build step.

## Features

- Four quest difficulties: Easy, Medium, Hard, and Boss
- Editable username and custom profile picture with local square-cropping and compression
- XP-based leveling with increasingly larger milestones
- Gold rewards and a custom real-life reward shop
- Daily streaks with an XP multiplier up to 1.5×
- Focus Energy that recovers when quests are completed
- Confetti, short synthesized reward tones, and a sound toggle
- A looping background-music player for user-selected MP3, WAV, OGG, M4A, AAC, or WebM files
- Active, cleared, and combined quest views
- Recent victory history
- LocalStorage and IndexedDB persistence with validation and safe fallbacks
- Keyboard-friendly controls, semantic markup, live announcements, and reduced-motion support
- Responsive dark retro-RPG interface

## File structure

```text
index.html   Semantic page structure, Tailwind CDN configuration, and UI shell
styles.css   Retro theme, responsive layouts, effects, and accessibility styles
script.js    State model, game rules, persistence, rendering, and interactions
README.md    Project documentation
```

## Run locally

No installation is required. Open `index.html` directly, or serve the directory with any static server:

```bash
python3 -m http.server 8080
```

Then open `http://localhost:8080`.

## Gameplay rules

| Difficulty | Base XP | Gold | Energy restored |
| --- | ---: | ---: | ---: |
| Easy | 10 | 2 | 4 |
| Medium | 25 | 5 | 6 |
| Hard | 50 | 10 | 9 |
| Boss | 100 | 20 | 14 |

Completing at least one quest on consecutive calendar days increases the XP multiplier by 0.1× per day, capped at 1.5×. XP advances levels; Gold is the spendable reward currency.

## Data and privacy

Game data, including the compressed profile picture, is stored under the `questbound-rpg-v1` LocalStorage key in the current browser. A user-selected background track is stored separately in the browser's `questbound-media-v1` IndexedDB database so larger audio files do not overload LocalStorage. Nothing is transmitted to a server or committed to GitHub. Clearing browser storage or using **Reset game data** permanently removes the local save and track.

Browsers require a user interaction before audio can begin. If a saved track cannot resume automatically after refresh, selecting **Play** in the music panel starts it.

## Browser support

Questbound targets current versions of Chrome, Edge, Firefox, and Safari. Tailwind CSS is loaded through its browser CDN as requested, so the first page load requires an internet connection. The custom stylesheet and application logic remain dependency-free.
