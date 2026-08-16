export const STORAGE_KEY = "questbound-rpg-v1";
export const STATE_VERSION = 2;
export const MAX_ENERGY = 100;
export const MAX_ACTIVITY_ITEMS = 60;

export type DifficultyKey = "easy" | "medium" | "hard" | "boss";
export type AccentKey = "mint" | "violet" | "amber";

export type Quest = {
  id: string;
  title: string;
  difficulty: DifficultyKey;
  category: string;
  createdAt: string;
  completedAt: string | null;
  xpEarned: number;
  goldEarned: number;
  multiplier: number;
  isPriority: boolean;
};

export type Ritual = {
  id: string;
  title: string;
  xp: number;
  lastCompletedDate: string | null;
  createdAt: string;
};

export type Reward = {
  id: string;
  name: string;
  cost: number;
  createdAt: string;
  claimedCount: number;
};

export type ActivityItem = {
  id: string;
  type: "quest" | "reward" | "ritual" | "focus" | "level" | "system";
  message: string;
  detail: string;
  timestamp: string;
};

export type Player = {
  profileName: string;
  avatarDataUrl: string | null;
  totalXp: number;
  gold: number;
  energy: number;
  streak: number;
  lastCompletionDate: string | null;
  energyCheckedDate: string | null;
  totalCompleted: number;
  focusMinutes: number;
  focusSessions: number;
};

export type AppState = {
  version: number;
  player: Player;
  settings: {
    soundEnabled: boolean;
    musicVolume: number;
    musicShouldPlay: boolean;
    accent: AccentKey;
    reducedFx: boolean;
  };
  quests: Quest[];
  rewards: Reward[];
  rituals: Ritual[];
  activity: ActivityItem[];
  dailyFocus: Record<string, number>;
};

export const DIFFICULTIES: Record<
  DifficultyKey,
  { label: string; xp: number; gold: number; energy: number; tone: string }
> = {
  easy: { label: "Quick win", xp: 10, gold: 3, energy: 4, tone: "mint" },
  medium: { label: "Standard", xp: 25, gold: 7, energy: 7, tone: "blue" },
  hard: { label: "Deep work", xp: 50, gold: 15, energy: 11, tone: "violet" },
  boss: { label: "Boss battle", xp: 100, gold: 30, energy: 18, tone: "amber" },
};

export const RANKS = [
  { minimumLevel: 1, name: "Initiate" },
  { minimumLevel: 3, name: "Pathfinder" },
  { minimumLevel: 5, name: "Vanguard" },
  { minimumLevel: 8, name: "Starforged" },
  { minimumLevel: 12, name: "Warden" },
  { minimumLevel: 16, name: "Ascendant" },
  { minimumLevel: 25, name: "Mythic" },
] as const;

export function createId() {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

export function createDefaultState(): AppState {
  return {
    version: STATE_VERSION,
    player: {
      profileName: "Pixel Hero",
      avatarDataUrl: null,
      totalXp: 0,
      gold: 0,
      energy: MAX_ENERGY,
      streak: 0,
      lastCompletionDate: null,
      energyCheckedDate: null,
      totalCompleted: 0,
      focusMinutes: 0,
      focusSessions: 0,
    },
    settings: {
      soundEnabled: true,
      musicVolume: 0.35,
      musicShouldPlay: false,
      accent: "mint",
      reducedFx: false,
    },
    quests: [],
    rewards: [],
    rituals: [],
    activity: [],
    dailyFocus: {},
  };
}

function safeInteger(value: unknown, minimum: number, maximum: number, fallback: number) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return fallback;
  return Math.min(maximum, Math.max(minimum, Math.round(numeric)));
}

function safeNumber(value: unknown, minimum: number, maximum: number, fallback: number) {
  const numeric = Number(value);
  if (!Number.isFinite(numeric)) return fallback;
  return Math.min(maximum, Math.max(minimum, numeric));
}

export function normalizeText(value: unknown, maximumLength: number) {
  if (typeof value !== "string") return "";
  return value.trim().replace(/\s+/g, " ").slice(0, maximumLength);
}

function safeDate(value: unknown): string | null {
  return typeof value === "string" && Number.isFinite(Date.parse(value)) ? value : null;
}

function safeDateKey(value: unknown): string | null {
  return typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value) ? value : null;
}

function safeAvatar(value: unknown): string | null {
  if (typeof value !== "string" || value.length > 1_200_000) return null;
  return /^data:image\/(?:png|jpeg|webp);base64,[a-z0-9+/=]+$/i.test(value) ? value : null;
}

function safeDifficulty(value: unknown): DifficultyKey {
  return value === "medium" || value === "hard" || value === "boss" ? value : "easy";
}

export function sanitizeState(candidate: unknown): AppState {
  const fallback = createDefaultState();
  if (!candidate || typeof candidate !== "object") return fallback;

  const source = candidate as Record<string, unknown>;
  const player = source.player && typeof source.player === "object" ? (source.player as Record<string, unknown>) : {};
  const settings =
    source.settings && typeof source.settings === "object" ? (source.settings as Record<string, unknown>) : {};

  const quests = Array.isArray(source.quests)
    ? source.quests
        .slice(0, 1000)
        .map((item): Quest | null => {
          if (!item || typeof item !== "object") return null;
          const quest = item as Record<string, unknown>;
          const title = normalizeText(quest.title, 100);
          if (!title) return null;
          return {
            id: normalizeText(quest.id, 100) || createId(),
            title,
            difficulty: safeDifficulty(quest.difficulty),
            category: normalizeText(quest.category, 24) || "General",
            createdAt: safeDate(quest.createdAt) ?? new Date().toISOString(),
            completedAt: safeDate(quest.completedAt),
            xpEarned: safeInteger(quest.xpEarned, 0, 100_000, 0),
            goldEarned: safeInteger(quest.goldEarned, 0, 100_000, 0),
            multiplier: safeNumber(quest.multiplier, 1, 1.5, 1),
            isPriority: quest.isPriority === true,
          };
        })
        .filter((item): item is Quest => Boolean(item))
    : [];

  const rewards = Array.isArray(source.rewards)
    ? source.rewards
        .slice(0, 200)
        .map((item): Reward | null => {
          if (!item || typeof item !== "object") return null;
          const reward = item as Record<string, unknown>;
          const name = normalizeText(reward.name, 70);
          if (!name) return null;
          return {
            id: normalizeText(reward.id, 100) || createId(),
            name,
            cost: safeInteger(reward.cost, 1, 999_999, 1),
            createdAt: safeDate(reward.createdAt) ?? new Date().toISOString(),
            claimedCount: safeInteger(reward.claimedCount, 0, 100_000, 0),
          };
        })
        .filter((item): item is Reward => Boolean(item))
    : [];

  const rituals = Array.isArray(source.rituals)
    ? source.rituals
        .slice(0, 30)
        .map((item): Ritual | null => {
          if (!item || typeof item !== "object") return null;
          const ritual = item as Record<string, unknown>;
          const title = normalizeText(ritual.title, 70);
          if (!title) return null;
          return {
            id: normalizeText(ritual.id, 100) || createId(),
            title,
            xp: safeInteger(ritual.xp, 3, 20, 5),
            lastCompletedDate: safeDateKey(ritual.lastCompletedDate),
            createdAt: safeDate(ritual.createdAt) ?? new Date().toISOString(),
          };
        })
        .filter((item): item is Ritual => Boolean(item))
    : [];

  const activityTypes = new Set(["quest", "reward", "ritual", "focus", "level", "system"]);
  const activity = Array.isArray(source.activity)
    ? source.activity
        .slice(0, MAX_ACTIVITY_ITEMS)
        .map((item): ActivityItem | null => {
          if (!item || typeof item !== "object") return null;
          const entry = item as Record<string, unknown>;
          const message = normalizeText(entry.message, 120);
          if (!message) return null;
          return {
            id: normalizeText(entry.id, 100) || createId(),
            type: activityTypes.has(String(entry.type)) ? (entry.type as ActivityItem["type"]) : "system",
            message,
            detail: normalizeText(entry.detail, 160),
            timestamp: safeDate(entry.timestamp) ?? new Date().toISOString(),
          };
        })
        .filter((item): item is ActivityItem => Boolean(item))
    : [];

  const dailyFocus: Record<string, number> = {};
  if (source.dailyFocus && typeof source.dailyFocus === "object") {
    for (const [key, value] of Object.entries(source.dailyFocus as Record<string, unknown>).slice(-120)) {
      if (/^\d{4}-\d{2}-\d{2}$/.test(key)) dailyFocus[key] = safeInteger(value, 0, 1440, 0);
    }
  }

  const accent: AccentKey = settings.accent === "violet" || settings.accent === "amber" ? settings.accent : "mint";

  return {
    version: STATE_VERSION,
    player: {
      profileName: normalizeText(player.profileName, 28) || "Pixel Hero",
      avatarDataUrl: safeAvatar(player.avatarDataUrl),
      totalXp: safeInteger(player.totalXp, 0, 1_000_000_000, 0),
      gold: safeInteger(player.gold, 0, 1_000_000_000, 0),
      energy: safeInteger(player.energy, 0, MAX_ENERGY, MAX_ENERGY),
      streak: safeInteger(player.streak, 0, 100_000, 0),
      lastCompletionDate: safeDateKey(player.lastCompletionDate),
      energyCheckedDate: safeDateKey(player.energyCheckedDate),
      totalCompleted: safeInteger(player.totalCompleted, 0, 1_000_000_000, 0),
      focusMinutes: safeInteger(player.focusMinutes, 0, 10_000_000, 0),
      focusSessions: safeInteger(player.focusSessions, 0, 1_000_000, 0),
    },
    settings: {
      soundEnabled: settings.soundEnabled !== false,
      musicVolume: safeNumber(settings.musicVolume, 0, 1, 0.35),
      musicShouldPlay: settings.musicShouldPlay === true,
      accent,
      reducedFx: settings.reducedFx === true,
    },
    quests,
    rewards,
    rituals,
    activity,
    dailyFocus,
  };
}

export function toDateKey(date = new Date()) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function fromDateKey(key: string) {
  const [year, month, day] = key.split("-").map(Number);
  return new Date(year, month - 1, day);
}

export function daysBetween(start: string, end: string) {
  return Math.round((fromDateKey(end).getTime() - fromDateKey(start).getTime()) / 86_400_000);
}

export function offsetDateKey(key: string, amount: number) {
  const date = fromDateKey(key);
  date.setDate(date.getDate() + amount);
  return toDateKey(date);
}

export function applyDailyCheck(input: AppState): AppState {
  const today = toDateKey();
  const checked = input.player.energyCheckedDate;
  if (checked === today) return input;

  const elapsed = checked ? Math.max(0, daysBetween(checked, today)) : 0;
  const lastCompletion = input.player.lastCompletionDate;
  let energy = input.player.energy;
  let streak = input.player.streak;

  if (elapsed > 0 && lastCompletion) {
    const missed = Math.max(0, daysBetween(lastCompletion, today) - 1);
    energy = Math.max(20, energy - Math.min(18, missed * 5));
    if (daysBetween(lastCompletion, today) > 1) streak = 0;
  }

  return {
    ...input,
    player: { ...input.player, energy, streak, energyCheckedDate: today },
  };
}

export function getLevelSnapshot(totalXp: number) {
  let level = 1;
  let remaining = Math.max(0, totalXp);
  let required = 100;

  while (remaining >= required && level < 999) {
    remaining -= required;
    level += 1;
    required = 100 + (level - 1) * 50;
  }

  return { level, currentXp: remaining, requiredXp: required };
}

export function getRank(level: number) {
  return [...RANKS].reverse().find((rank) => level >= rank.minimumLevel)?.name ?? RANKS[0].name;
}

export function getStreakMultiplier(streak: number) {
  if (streak <= 1) return 1;
  return Math.min(1.5, 1 + (streak - 1) * 0.1);
}

export function advanceStreak(player: Player) {
  const today = toDateKey();
  if (player.lastCompletionDate === today) return player;
  const yesterday = offsetDateKey(today, -1);
  return {
    ...player,
    streak: player.lastCompletionDate === yesterday ? player.streak + 1 : 1,
    lastCompletionDate: today,
  };
}

export function addActivity(state: AppState, item: Omit<ActivityItem, "id" | "timestamp">): ActivityItem[] {
  return [
    { ...item, id: createId(), timestamp: new Date().toISOString() },
    ...state.activity,
  ].slice(0, MAX_ACTIVITY_ITEMS);
}

export function getLastSevenDays(baseDate = new Date()) {
  const today = toDateKey(baseDate);
  return Array.from({ length: 7 }, (_, index) => offsetDateKey(today, index - 6));
}

export function formatCompactNumber(value: number) {
  return new Intl.NumberFormat("en-US", { notation: value >= 10_000 ? "compact" : "standard" }).format(value);
}
