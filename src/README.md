# Soul Miners - Roblox Game

**"Mine souls, evolve your reaper, conquer the underworld."**

A simulator RPG built for Roblox with a dark-but-cute aesthetic (Undertale meets Pet Simulator X).

## Architecture

```
src/
├── ReplicatedStorage/Shared/       -- Shared between client & server
│   ├── Modules/
│   │   ├── DataConfig.lua          -- Game balance values, schema, upgrade tables
│   │   ├── RarityConfig.lua        -- Egg/spirit rarity definitions, weighted RNG
│   │   ├── ZoneConfig.lua          -- Zone definitions and progression
│   │   ├── QuestConfig.lua         -- Daily quest and achievement definitions
│   │   ├── GamepassConfig.lua      -- GamePass & DevProduct ID configuration
│   │   └── Util.lua                -- Shared utilities (formatting, deep copy, etc.)
│   └── Events/
│       ├── RemoteEvents.lua        -- All RemoteEvent/RemoteFunction registry
│       └── BindableEvents.lua      -- Server-side inter-service signals
│
├── ServerScriptService/            -- Server-only code
│   ├── Core/
│   │   └── Server.lua              -- Master bootstrapper
│   ├── Services/
│   │   ├── PlayerDataService.lua   -- ProfileService-based data persistence
│   │   ├── CurrencyService.lua     -- All currency read/write operations
│   │   ├── ClickRewardService.lua  -- Click-to-earn with anti-spam
│   │   ├── EggService.lua          -- Gacha system with pity mechanics
│   │   ├── UpgradeService.lua      -- Upgrade purchases and stat calculations
│   │   ├── RebirthService.lua      -- Rebirth & ascension meta-progression
│   │   ├── ZoneService.lua         -- Zone unlocks and teleportation
│   │   ├── QuestService.lua        -- Daily quests, login streaks, rewards
│   │   ├── ShopService.lua         -- GamePass & DevProduct handling
│   │   └── LeaderboardService.lua  -- OrderedDataStore leaderboards
│   └── Lib/
│       └── ProfileService.lua      -- Stub (replace with real ProfileService)
│
└── StarterPlayer/StarterPlayerScripts/  -- Client-only code
    ├── Core/
    │   └── Client.lua              -- Client bootstrapper
    └── Controllers/
        ├── UIController.lua        -- All UI state management
        ├── InputController.lua     -- Click/tap/keyboard input handling
        ├── NotificationController.lua  -- Toast notification system
        └── RewardJuiceController.lua   -- Floating numbers, screen shake, particles
```

## Core Systems

| System | Description |
|--------|-------------|
| **PlayerDataService** | ProfileService-based persistence with session locking, auto-save, migrations |
| **CurrencyService** | Centralized currency operations (souls, gems, reaperTokens, spiritShards) |
| **ClickRewardService** | Click-to-earn with rate limiting and spam detection |
| **EggService** | Gacha/egg system with weighted RNG and pity mechanics |
| **UpgradeService** | Stat upgrades with exponential cost scaling |
| **RebirthService** | Reset progression for permanent multipliers + ascension system |
| **ZoneService** | World progression with 5 themed zones |
| **QuestService** | Daily quests, login streaks, daily rewards |
| **ShopService** | GamePass ownership checks and DevProduct receipt processing |
| **LeaderboardService** | OrderedDataStore-based leaderboards with caching |

## Setup in Roblox Studio

1. **Clone this repo** and open in your editor
2. **Use Rojo** to sync the `src/` folder into Roblox Studio
3. **Replace ProfileService stub** (`src/ServerScriptService/Lib/ProfileService.lua`) with the [real ProfileService](https://github.com/MadStudioRoblox/ProfileService)
4. **Update GamePass/DevProduct IDs** in `GamepassConfig.lua` and `ShopService.lua` with your actual Roblox Creator Dashboard IDs
5. **Add Sound IDs** in `RewardJuiceController.lua`
6. **Build your workspace**: Create Zone folders under `workspace.Zones` with SpawnPoints matching zone IDs from `ZoneConfig.lua`

## Progression Flow

```
Click to Mine → Earn Souls → Buy Upgrades → Unlock Zones
                    ↓
              Open Eggs → Collect Spirits → Equip for Multipliers
                    ↓
              Hit Soul Threshold → REBIRTH → Permanent Multiplier
                    ↓
              10 Rebirths → ASCEND → God-Tier Multiplier
```

## Key Design Principles

- **Server authoritative**: All game logic runs server-side. Client only renders.
- **Never trust the client**: Currency, upgrades, RNG all validated on server.
- **Anti-exploit**: Rate limiting, spam detection, cooldowns on every action.
- **Data safety**: ProfileService session locking prevents duplication exploits.
- **Centralized config**: All balance values in `DataConfig.lua` for easy tuning.
