"use client";

import type { CSSProperties, FormEvent } from "react";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  DIFFICULTIES,
  MAX_ENERGY,
  STORAGE_KEY,
  type AccentKey,
  type AppState,
  type DifficultyKey,
  addActivity,
  advanceStreak,
  applyDailyCheck,
  createDefaultState,
  createId,
  formatCompactNumber,
  getLastSevenDays,
  getLevelSnapshot,
  getRank,
  getStreakMultiplier,
  normalizeText,
  sanitizeState,
  toDateKey,
} from "./game";
import { deleteTrack, readTrack, type StoredTrack, writeTrack } from "./media";

type PanelName = "focus" | "profile" | "music" | "settings" | null;
type QuestFilter = "active" | "completed" | "all";
type Toast = { title: string; detail: string; tone: "success" | "danger" | "neutral" };

const categories = ["General", "Study", "Work", "Body", "Life", "Creative"];
const MAX_AUDIO_BYTES = 30 * 1024 * 1024;
const MAX_AVATAR_BYTES = 8 * 1024 * 1024;

const dateFormatter = new Intl.DateTimeFormat("en-US", {
  weekday: "long",
  month: "long",
  day: "numeric",
});
const shortTimeFormatter = new Intl.DateTimeFormat("en-US", { hour: "numeric", minute: "2-digit" });
const dayFormatter = new Intl.DateTimeFormat("en-US", { weekday: "short" });
const hydrationSafeWeekdays = ["M", "T", "W", "T", "F", "S", "S"];

function Icon({ name, size = 18 }: { name: string; size?: number }) {
  const common = {
    width: size,
    height: size,
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: 1.8,
    strokeLinecap: "round" as const,
    strokeLinejoin: "round" as const,
    "aria-hidden": true,
  };

  const content: Record<string, React.ReactNode> = {
    grid: <><rect x="3" y="3" width="7" height="7" rx="1" /><rect x="14" y="3" width="7" height="7" rx="1" /><rect x="3" y="14" width="7" height="7" rx="1" /><rect x="14" y="14" width="7" height="7" rx="1" /></>,
    quest: <><path d="M6 4h12v16H6z" /><path d="M9 8h6M9 12h6M9 16h3" /></>,
    timer: <><circle cx="12" cy="13" r="8" /><path d="M12 9v4l3 2M9 2h6" /></>,
    shop: <><path d="M4 9h16l-1 11H5L4 9Z" /><path d="M8 9V7a4 4 0 0 1 8 0v2" /></>,
    history: <><path d="M3 12a9 9 0 1 0 3-6.7L3 8" /><path d="M3 3v5h5M12 7v5l3 2" /></>,
    plus: <path d="M12 5v14M5 12h14" />,
    check: <path d="m5 12 4 4L19 6" />,
    trash: <><path d="M4 7h16M9 7V4h6v3M7 7l1 13h8l1-13" /><path d="M10 11v5M14 11v5" /></>,
    target: <><circle cx="12" cy="12" r="8" /><circle cx="12" cy="12" r="3" /><path d="m15 9 6-6M17 3h4v4" /></>,
    flame: <path d="M13 3s1 4-2 6c-2-2-1-4-1-4s-5 4-5 9a7 7 0 0 0 14 0c0-3-2-6-4-8 0 3-2 4-2 4" />,
    bolt: <path d="m13 2-8 12h7l-1 8 8-12h-7l1-8Z" />,
    coin: <><circle cx="12" cy="12" r="9" /><path d="M15 8.5c-.7-.5-1.6-.8-2.7-.8-1.6 0-2.8.7-2.8 1.8 0 2.8 5.5 1.3 5.5 4.2 0 1.2-1.2 2-3 2-1.2 0-2.3-.4-3-1M12 6v12" /></>,
    music: <><path d="M9 18V6l10-2v12" /><circle cx="6" cy="18" r="3" /><circle cx="16" cy="16" r="3" /></>,
    settings: <><circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1-2.8 2.8-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6v.2h-4V21a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1L4.2 17l.1-.1a1.7 1.7 0 0 0 .3-1.9A1.7 1.7 0 0 0 3 14H2.8v-4H3a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9L4.2 7 7 4.2l.1.1A1.7 1.7 0 0 0 9 4.6a1.7 1.7 0 0 0 1-1.6v-.2h4V3a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1L19.8 7l-.1.1a1.7 1.7 0 0 0-.3 1.9 1.7 1.7 0 0 0 1.6 1h.2v4H21a1.7 1.7 0 0 0-1.6 1Z" /></>,
    play: <path d="m8 5 11 7-11 7V5Z" />,
    pause: <><path d="M9 5v14M15 5v14" /></>,
    close: <path d="m6 6 12 12M18 6 6 18" />,
    trophy: <><path d="M8 4h8v5a4 4 0 0 1-8 0V4Z" /><path d="M8 6H4v2a4 4 0 0 0 4 4M16 6h4v2a4 4 0 0 1-4 4M12 13v4M8 21h8M9 17h6" /></>,
    upload: <><path d="M12 16V4M7 9l5-5 5 5" /><path d="M5 20h14" /></>,
    download: <><path d="M12 4v12M7 11l5 5 5-5" /><path d="M5 20h14" /></>,
    spark: <><path d="m12 2 1.5 5.5L19 9l-5.5 1.5L12 16l-1.5-5.5L5 9l5.5-1.5L12 2Z" /><path d="m19 15 .7 2.3L22 18l-2.3.7L19 21l-.7-2.3L16 18l2.3-.7L19 15Z" /></>,
    pin: <><path d="m9 3 6 6M8 10l-4 4 6 1 4 6 4-4-3-3 3-3-5-5-3 3-2-2Z" /><path d="m9 15-6 6" /></>,
    search: <><circle cx="10.5" cy="10.5" r="6.5" /><path d="m16 16 5 5" /></>,
    ritual: <><path d="M12 3v18M5 8h14M7 8c0 6 2 10 5 13M17 8c0 6-2 10-5 13" /></>,
    shield: <path d="M12 3 5 6v5c0 5 3 8 7 10 4-2 7-5 7-10V6l-7-3Z" />,
    arrow: <path d="m9 18 6-6-6-6" />,
    volume: <><path d="M11 5 6.5 9H3v6h3.5L11 19V5Z" /><path d="M15 9a4 4 0 0 1 0 6M18 6a8 8 0 0 1 0 12" /></>,
    more: <><circle cx="5" cy="12" r="1" fill="currentColor" stroke="none" /><circle cx="12" cy="12" r="1" fill="currentColor" stroke="none" /><circle cx="19" cy="12" r="1" fill="currentColor" stroke="none" /></>,
  };

  return <svg {...common}>{content[name] ?? content.spark}</svg>;
}

function PixelAvatar({ image, compact = false }: { image: string | null; compact?: boolean }) {
  return (
    <span className={`pixel-avatar ${compact ? "pixel-avatar--compact" : ""}`}>
      {image ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={image} alt="" />
      ) : (
        <span className="pixel-avatar__sprite" aria-hidden="true">
          <i className="pixel p-hair-1" /><i className="pixel p-hair-2" /><i className="pixel p-face" />
          <i className="pixel p-eye-1" /><i className="pixel p-eye-2" /><i className="pixel p-body" />
          <i className="pixel p-core" /><i className="pixel p-leg-1" /><i className="pixel p-leg-2" />
        </span>
      )}
    </span>
  );
}

function Modal({ title, kicker, onClose, children, wide = false }: { title: string; kicker: string; onClose: () => void; children: React.ReactNode; wide?: boolean }) {
  return (
    <div className="modal-layer" role="presentation" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section className={`modal-card ${wide ? "modal-card--wide" : ""}`} role="dialog" aria-modal="true" aria-labelledby="active-modal-title">
        <header className="modal-header">
          <div><p className="eyebrow">{kicker}</p><h2 id="active-modal-title">{title}</h2></div>
          <button className="icon-btn" type="button" onClick={onClose} aria-label="Close panel"><Icon name="close" /></button>
        </header>
        {children}
      </section>
    </div>
  );
}

function playFeedback(
  enabled: boolean,
  contextRef: React.MutableRefObject<AudioContext | null>,
  kind: "complete" | "focus" | "buy" | "error",
) {
  if (!enabled || typeof window === "undefined") return;
  try {
    const Context = window.AudioContext ?? (window as typeof window & { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Context) return;
    const context = contextRef.current ?? new Context();
    contextRef.current = context;
    const patterns = { complete: [523.25, 659.25, 783.99], focus: [392, 523.25, 659.25], buy: [440, 587.33], error: [220, 174.61] };
    patterns[kind].forEach((frequency, index) => {
      const oscillator = context.createOscillator();
      const gain = context.createGain();
      oscillator.type = "square";
      oscillator.frequency.value = frequency;
      gain.gain.setValueAtTime(0.0001, context.currentTime + index * 0.07);
      gain.gain.exponentialRampToValueAtTime(0.035, context.currentTime + index * 0.07 + 0.01);
      gain.gain.exponentialRampToValueAtTime(0.0001, context.currentTime + index * 0.07 + 0.12);
      oscillator.connect(gain).connect(context.destination);
      oscillator.start(context.currentTime + index * 0.07);
      oscillator.stop(context.currentTime + index * 0.07 + 0.13);
    });
  } catch { return; }
}

export default function Home() {
  const [state, setState] = useState<AppState>(() => createDefaultState());
  const [hydrated, setHydrated] = useState(false);
  const [panel, setPanel] = useState<PanelName>(null);
  const [questFilter, setQuestFilter] = useState<QuestFilter>("active");
  const [search, setSearch] = useState("");
  const [questTitle, setQuestTitle] = useState("");
  const [questDifficulty, setQuestDifficulty] = useState<DifficultyKey>("easy");
  const [questCategory, setQuestCategory] = useState("General");
  const [ritualTitle, setRitualTitle] = useState("");
  const [rewardTitle, setRewardTitle] = useState("");
  const [rewardCost, setRewardCost] = useState("50");
  const [toast, setToast] = useState<Toast | null>(null);
  const [celebrating, setCelebrating] = useState(0);
  const [now, setNow] = useState<Date | null>(null);
  const [storageWarning, setStorageWarning] = useState(false);
  const toastTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const audioContext = useRef<AudioContext | null>(null);

  const [focusPreset, setFocusPreset] = useState(25);
  const [focusSeconds, setFocusSeconds] = useState(25 * 60);
  const [focusRunning, setFocusRunning] = useState(false);
  const [focusQuestId, setFocusQuestId] = useState("");
  const focusAwarded = useRef(false);

  const [profileName, setProfileName] = useState("");
  const [profileAvatar, setProfileAvatar] = useState<string | null>(null);
  const [profileBusy, setProfileBusy] = useState(false);
  const avatarInput = useRef<HTMLInputElement>(null);

  const audio = useRef<HTMLAudioElement>(null);
  const trackObjectUrl = useRef<string | null>(null);
  const musicInput = useRef<HTMLInputElement>(null);
  const [track, setTrack] = useState<StoredTrack | null>(null);
  const [musicPlaying, setMusicPlaying] = useState(false);
  const [musicBusy, setMusicBusy] = useState(false);
  const importInput = useRef<HTMLInputElement>(null);
  const [confirmReset, setConfirmReset] = useState(false);

  const showToast = (next: Toast) => {
    setToast(next);
    if (toastTimer.current) clearTimeout(toastTimer.current);
    toastTimer.current = setTimeout(() => setToast(null), 3800);
  };

  useEffect(() => {
    window.queueMicrotask(() => {
      try {
        const saved = window.localStorage.getItem(STORAGE_KEY);
        const loaded = saved ? sanitizeState(JSON.parse(saved)) : createDefaultState();
        setState(applyDailyCheck(loaded));
      } catch {
        setStorageWarning(true);
        setState(createDefaultState());
      }
      setNow(new Date());
      setHydrated(true);
    });
    const clock = window.setInterval(() => setNow(new Date()), 30_000);
    return () => window.clearInterval(clock);
  }, []);

  useEffect(() => {
    if (!hydrated) return;
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch {
      window.queueMicrotask(() => setStorageWarning(true));
    }
  }, [hydrated, state]);

  useEffect(() => {
    if (!panel) return;
    const handleKey = (event: KeyboardEvent) => event.key === "Escape" && setPanel(null);
    document.addEventListener("keydown", handleKey);
    document.body.classList.add("modal-open");
    return () => {
      document.removeEventListener("keydown", handleKey);
      document.body.classList.remove("modal-open");
    };
  }, [panel]);

  useEffect(() => {
    if (!focusRunning) return;
    const timer = window.setInterval(() => setFocusSeconds((seconds) => Math.max(0, seconds - 1)), 1000);
    return () => window.clearInterval(timer);
  }, [focusRunning]);

  useEffect(() => {
    if (!focusRunning || focusSeconds !== 0 || focusAwarded.current) return;
    focusAwarded.current = true;
    setFocusRunning(false);
    const xp = Math.max(5, Math.round(focusPreset / 5));
    setState((current) => ({
      ...current,
      player: {
        ...current.player,
        totalXp: current.player.totalXp + xp,
        gold: current.player.gold + 1,
        energy: Math.min(MAX_ENERGY, current.player.energy + 4),
        focusMinutes: current.player.focusMinutes + focusPreset,
        focusSessions: current.player.focusSessions + 1,
      },
      dailyFocus: { ...current.dailyFocus, [toDateKey()]: (current.dailyFocus[toDateKey()] ?? 0) + focusPreset },
      activity: addActivity(current, {
        type: "focus",
        message: `${focusPreset}-minute focus sprint complete`,
        detail: `+${xp} XP · +1 Gold · attention locked`,
      }),
    }));
    setCelebrating((value) => value + 1);
    playFeedback(state.settings.soundEnabled, audioContext, "focus");
    showToast({ title: "Focus sprint cleared", detail: `+${xp} XP and +1 Gold. Clean work.`, tone: "success" });
  }, [focusPreset, focusRunning, focusSeconds, state.settings.soundEnabled]);

  useEffect(() => {
    let cancelled = false;
    readTrack()
      .then((savedTrack) => {
        if (cancelled || !savedTrack) return;
        if (!audio.current) return;
        if (trackObjectUrl.current) URL.revokeObjectURL(trackObjectUrl.current);
        const objectUrl = URL.createObjectURL(savedTrack.blob);
        trackObjectUrl.current = objectUrl;
        audio.current.src = objectUrl;
        audio.current.load();
        setTrack(savedTrack);
      })
      .catch(() => undefined);
    return () => {
      cancelled = true;
      if (trackObjectUrl.current) URL.revokeObjectURL(trackObjectUrl.current);
    };
  }, []);

  useEffect(() => {
    if (audio.current) audio.current.volume = state.settings.musicVolume;
  }, [state.settings.musicVolume]);

  const level = useMemo(() => getLevelSnapshot(state.player.totalXp), [state.player.totalXp]);
  const rank = getRank(level.level);
  const levelProgress = Math.round((level.currentXp / level.requiredXp) * 100);
  const activeQuests = useMemo(() => state.quests.filter((quest) => !quest.completedAt), [state.quests]);
  const priorityQuest = activeQuests.find((quest) => quest.isPriority) ?? activeQuests[0] ?? null;
  const completedToday = state.quests.filter((quest) => quest.completedAt?.slice(0, 10) === toDateKey()).length;
  const multiplier = getStreakMultiplier(state.player.streak);
  const todayFocus = state.dailyFocus[toDateKey()] ?? 0;

  const visibleQuests = useMemo(() => {
    const needle = search.trim().toLowerCase();
    return state.quests.filter((quest) => {
      const matchesFilter = questFilter === "all" || (questFilter === "active" ? !quest.completedAt : Boolean(quest.completedAt));
      return matchesFilter && (!needle || `${quest.title} ${quest.category}`.toLowerCase().includes(needle));
    });
  }, [questFilter, search, state.quests]);

  const weeklyData = useMemo(() => {
    if (!now) {
      return ["2020-01-06", "2020-01-07", "2020-01-08", "2020-01-09", "2020-01-10", "2020-01-11", "2020-01-12"].map((date) => ({
        date,
        completed: 0,
        focus: 0,
      }));
    }

    return getLastSevenDays(now).map((date) => ({
      date,
      completed: state.quests.filter((quest) => quest.completedAt?.slice(0, 10) === date).length,
      focus: state.dailyFocus[date] ?? 0,
    }));
  }, [now, state.dailyFocus, state.quests]);
  const maxWeeklyScore = Math.max(1, ...weeklyData.map((day) => day.completed * 20 + day.focus));

  const achievements = [
    { name: "First Signal", detail: "Complete your first quest", unlocked: state.player.totalCompleted >= 1, icon: "spark" },
    { name: "Hot Streak", detail: "Reach a 3-day streak", unlocked: state.player.streak >= 3, icon: "flame" },
    { name: "Deep Diver", detail: "Log 60 focus minutes", unlocked: state.player.focusMinutes >= 60, icon: "timer" },
    { name: "Boss Breaker", detail: "Clear a Boss Battle", unlocked: state.quests.some((quest) => quest.difficulty === "boss" && quest.completedAt), icon: "trophy" },
    { name: "Ascension", detail: "Reach level 10", unlocked: level.level >= 10, icon: "shield" },
  ];

  function submitQuest(event: FormEvent) {
    event.preventDefault();
    const title = normalizeText(questTitle, 100);
    if (!title) {
      showToast({ title: "Quest needs a name", detail: "Make the next action stupidly obvious.", tone: "danger" });
      return;
    }
    const quest = { id: createId(), title, difficulty: questDifficulty, category: questCategory, createdAt: new Date().toISOString(), completedAt: null, xpEarned: 0, goldEarned: 0, multiplier: 1, isPriority: activeQuests.length === 0 };
    setState((current) => ({ ...current, quests: [quest, ...current.quests] }));
    setQuestTitle("");
    setQuestFilter("active");
    showToast({ title: "Quest locked in", detail: `${DIFFICULTIES[questDifficulty].xp} base XP on the table.`, tone: "neutral" });
  }

  function completeQuest(id: string) {
    const target = state.quests.find((quest) => quest.id === id && !quest.completedAt);
    if (!target) return;
    const beforeLevel = level.level;
    const difficulty = DIFFICULTIES[target.difficulty];
    setState((current) => {
      const currentTarget = current.quests.find((quest) => quest.id === id && !quest.completedAt);
      if (!currentTarget) return current;
      const streakPlayer = advanceStreak(current.player);
      const earnedMultiplier = getStreakMultiplier(streakPlayer.streak);
      const earnedXp = Math.round(difficulty.xp * earnedMultiplier);
      const nextPlayer = { ...streakPlayer, totalXp: streakPlayer.totalXp + earnedXp, gold: streakPlayer.gold + difficulty.gold, energy: Math.min(MAX_ENERGY, streakPlayer.energy + difficulty.energy), totalCompleted: streakPlayer.totalCompleted + 1 };
      const afterLevel = getLevelSnapshot(nextPlayer.totalXp).level;
      let activity = addActivity(current, { type: "quest", message: currentTarget.title, detail: `+${earnedXp} XP · +${difficulty.gold} Gold · ${difficulty.label}` });
      if (afterLevel > beforeLevel) activity = [{ id: createId(), type: "level" as const, message: `Level ${afterLevel} reached`, detail: `${getRank(afterLevel)} rank online`, timestamp: new Date().toISOString() }, ...activity].slice(0, 60);
      return { ...current, player: nextPlayer, quests: current.quests.map((quest) => quest.id === id ? { ...quest, completedAt: new Date().toISOString(), xpEarned: earnedXp, goldEarned: difficulty.gold, multiplier: earnedMultiplier, isPriority: false } : quest), activity };
    });
    setCelebrating((value) => value + 1);
    playFeedback(state.settings.soundEnabled, audioContext, "complete");
    showToast({ title: difficulty.label === "Boss battle" ? "Boss defeated" : "Quest cleared", detail: `+${Math.round(difficulty.xp * multiplier)} XP · +${difficulty.gold} Gold`, tone: "success" });
  }

  function deleteQuest(id: string) {
    setState((current) => ({ ...current, quests: current.quests.filter((quest) => quest.id !== id) }));
    showToast({ title: "Quest removed", detail: "No guilt. The log should only hold what matters.", tone: "neutral" });
  }

  function setPriority(id: string) {
    setState((current) => ({ ...current, quests: current.quests.map((quest) => ({ ...quest, isPriority: quest.id === id })) }));
    document.getElementById("command")?.scrollIntoView({ behavior: "smooth" });
  }

  function submitRitual(event: FormEvent) {
    event.preventDefault();
    const title = normalizeText(ritualTitle, 70);
    if (!title) return;
    setState((current) => ({ ...current, rituals: [{ id: createId(), title, xp: 5, lastCompletedDate: null, createdAt: new Date().toISOString() }, ...current.rituals] }));
    setRitualTitle("");
  }

  function completeRitual(id: string) {
    const target = state.rituals.find((ritual) => ritual.id === id);
    if (!target || target.lastCompletedDate === toDateKey()) return;
    setState((current) => {
      const ritual = current.rituals.find((item) => item.id === id);
      if (!ritual || ritual.lastCompletedDate === toDateKey()) return current;
      const streakPlayer = advanceStreak(current.player);
      return { ...current, player: { ...streakPlayer, totalXp: streakPlayer.totalXp + ritual.xp, energy: Math.min(MAX_ENERGY, streakPlayer.energy + 3) }, rituals: current.rituals.map((item) => item.id === id ? { ...item, lastCompletedDate: toDateKey() } : item), activity: addActivity(current, { type: "ritual", message: ritual.title, detail: `Daily ritual · +${ritual.xp} XP` }) };
    });
    playFeedback(state.settings.soundEnabled, audioContext, "complete");
    showToast({ title: "Ritual complete", detail: `+${target.xp} XP · consistency beats intensity`, tone: "success" });
  }

  function submitReward(event: FormEvent) {
    event.preventDefault();
    const name = normalizeText(rewardTitle, 70);
    const cost = Math.max(1, Math.min(999999, Math.round(Number(rewardCost))));
    if (!name || !Number.isFinite(cost)) return;
    setState((current) => ({ ...current, rewards: [{ id: createId(), name, cost, createdAt: new Date().toISOString(), claimedCount: 0 }, ...current.rewards] }));
    setRewardTitle("");
  }

  function claimReward(id: string) {
    const reward = state.rewards.find((item) => item.id === id);
    if (!reward) return;
    if (state.player.gold < reward.cost) {
      playFeedback(state.settings.soundEnabled, audioContext, "error");
      showToast({ title: "Not enough Gold", detail: `${reward.cost - state.player.gold} more Gold to unlock this.`, tone: "danger" });
      return;
    }
    setState((current) => ({ ...current, player: { ...current.player, gold: current.player.gold - reward.cost }, rewards: current.rewards.map((item) => item.id === id ? { ...item, claimedCount: item.claimedCount + 1 } : item), activity: addActivity(current, { type: "reward", message: reward.name, detail: `Claimed for ${reward.cost} Gold` }) }));
    playFeedback(state.settings.soundEnabled, audioContext, "buy");
    showToast({ title: "Reward unlocked", detail: reward.name, tone: "success" });
  }

  function openFocus(questId = priorityQuest?.id ?? "") { setFocusQuestId(questId); setPanel("focus"); }
  function selectFocusPreset(minutes: number) { if (focusRunning) return; setFocusPreset(minutes); setFocusSeconds(minutes * 60); focusAwarded.current = false; }
  function toggleFocus() { if (focusSeconds === 0) { setFocusSeconds(focusPreset * 60); focusAwarded.current = false; } setFocusRunning((value) => !value); }
  function resetFocus() { setFocusRunning(false); setFocusSeconds(focusPreset * 60); focusAwarded.current = false; }

  function openProfile() { setProfileName(state.player.profileName); setProfileAvatar(state.player.avatarDataUrl); setPanel("profile"); }

  async function processAvatar(file: File) {
    if (!new Set(["image/png", "image/jpeg", "image/webp", "image/gif"]).has(file.type)) throw new Error("Choose a PNG, JPEG, WebP, or GIF image.");
    if (file.size > MAX_AVATAR_BYTES) throw new Error("That image is over 8 MB.");
    const objectUrl = URL.createObjectURL(file);
    try {
      const image = await new Promise<HTMLImageElement>((resolve, reject) => { const next = new Image(); next.onload = () => resolve(next); next.onerror = () => reject(new Error("That image could not be decoded.")); next.src = objectUrl; });
      const size = Math.min(image.naturalWidth, image.naturalHeight);
      const canvas = document.createElement("canvas");
      canvas.width = 384; canvas.height = 384;
      const context = canvas.getContext("2d", { alpha: false });
      if (!context) throw new Error("This browser could not process the image.");
      context.fillStyle = "#0b0e13"; context.fillRect(0, 0, 384, 384); context.imageSmoothingEnabled = true; context.imageSmoothingQuality = "high";
      context.drawImage(image, (image.naturalWidth - size) / 2, (image.naturalHeight - size) / 2, size, size, 0, 0, 384, 384);
      return canvas.toDataURL("image/webp", 0.82);
    } finally { URL.revokeObjectURL(objectUrl); }
  }

  async function handleAvatar(file: File | undefined) {
    if (!file) return;
    setProfileBusy(true);
    try { setProfileAvatar(await processAvatar(file)); }
    catch (error) { showToast({ title: "Photo rejected", detail: error instanceof Error ? error.message : "Choose another image.", tone: "danger" }); }
    finally { setProfileBusy(false); if (avatarInput.current) avatarInput.current.value = ""; }
  }

  function saveProfile(event: FormEvent) {
    event.preventDefault();
    const name = normalizeText(profileName, 28);
    if (!name) return;
    setState((current) => ({ ...current, player: { ...current.player, profileName: name, avatarDataUrl: profileAvatar } }));
    setPanel(null);
    showToast({ title: "Identity synced", detail: `Welcome back, ${name}.`, tone: "success" });
  }

  function attachTrack(nextTrack: StoredTrack) {
    if (!audio.current) return;
    if (trackObjectUrl.current) URL.revokeObjectURL(trackObjectUrl.current);
    const objectUrl = URL.createObjectURL(nextTrack.blob);
    trackObjectUrl.current = objectUrl;
    audio.current.src = objectUrl;
    audio.current.load();
    setTrack(nextTrack);
  }

  async function handleMusicFile(file: File | undefined) {
    if (!file) return;
    if (!/\.(mp3|wav|ogg|m4a|aac|webm)$/i.test(file.name) && !file.type.startsWith("audio/")) { showToast({ title: "Unsupported audio", detail: "Use MP3, WAV, OGG, M4A, AAC, or WebM.", tone: "danger" }); return; }
    if (!file.size || file.size > MAX_AUDIO_BYTES) { showToast({ title: "File too large", detail: "Choose an audio file under 30 MB.", tone: "danger" }); return; }
    setMusicBusy(true);
    try {
      const nextTrack = { name: file.name.slice(0, 80), type: file.type || "audio/mpeg", size: file.size, updatedAt: new Date().toISOString(), blob: file };
      await writeTrack(nextTrack); attachTrack(nextTrack);
      setState((current) => ({ ...current, settings: { ...current.settings, musicShouldPlay: true } }));
      try { await audio.current?.play(); } catch { /* Browsers may require another click. */ }
      showToast({ title: "Soundtrack installed", detail: `${nextTrack.name} will loop locally.`, tone: "success" });
    } catch (error) { showToast({ title: "Track could not be saved", detail: error instanceof Error ? error.message : "Browser storage refused the file.", tone: "danger" }); }
    finally { setMusicBusy(false); if (musicInput.current) musicInput.current.value = ""; }
  }

  async function toggleMusic() {
    if (!track) { musicInput.current?.click(); return; }
    if (!audio.current) return;
    if (audio.current.paused) {
      setState((current) => ({ ...current, settings: { ...current.settings, musicShouldPlay: true } }));
      try { await audio.current.play(); } catch { showToast({ title: "Playback blocked", detail: "Press Play once more after interacting with the page.", tone: "danger" }); }
    } else { audio.current.pause(); setState((current) => ({ ...current, settings: { ...current.settings, musicShouldPlay: false } })); }
  }

  async function removeMusic() {
    try { await deleteTrack(); } catch { /* Keep UI cleanup deterministic. */ }
    audio.current?.pause(); audio.current?.removeAttribute("src");
    if (trackObjectUrl.current) URL.revokeObjectURL(trackObjectUrl.current);
    trackObjectUrl.current = null; setTrack(null); setMusicPlaying(false);
    setState((current) => ({ ...current, settings: { ...current.settings, musicShouldPlay: false } }));
  }

  function exportSave() {
    const blob = new Blob([JSON.stringify(state, null, 2)], { type: "application/json" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a"); link.href = url; link.download = `questbound-save-${toDateKey()}.json`; link.click(); URL.revokeObjectURL(url);
  }

  async function importSave(file: File | undefined) {
    if (!file) return;
    try { setState(applyDailyCheck(sanitizeState(JSON.parse(await file.text())))); showToast({ title: "Save restored", detail: "Your command deck has been rebuilt from the file.", tone: "success" }); setPanel(null); }
    catch { showToast({ title: "Invalid save file", detail: "That JSON file is not a valid Questbound save.", tone: "danger" }); }
    finally { if (importInput.current) importInput.current.value = ""; }
  }

  async function resetEverything() { setState(createDefaultState()); await removeMusic(); setConfirmReset(false); setPanel(null); showToast({ title: "New campaign created", detail: "Everything is clear. Start with one small quest.", tone: "neutral" }); }
  function scrollTo(id: string) { document.getElementById(id)?.scrollIntoView({ behavior: state.settings.reducedFx ? "auto" : "smooth", block: "start" }); }

  const focusProgress = 100 - (focusSeconds / (focusPreset * 60)) * 100;
  const focusMinutes = String(Math.floor(focusSeconds / 60)).padStart(2, "0");
  const focusRemainder = String(focusSeconds % 60).padStart(2, "0");

  return (
    <div className="app-shell" data-accent={state.settings.accent} data-reduced-fx={state.settings.reducedFx ? "true" : "false"}>
      <audio ref={audio} loop preload="metadata" onPlay={() => setMusicPlaying(true)} onPause={() => setMusicPlaying(false)} />
      <div className="ambient-grid" aria-hidden="true" /><div className="ambient-glow ambient-glow--one" aria-hidden="true" /><div className="ambient-glow ambient-glow--two" aria-hidden="true" />

      <aside className="sidebar">
        <button className="brand" type="button" onClick={() => scrollTo("command")} aria-label="Questbound home"><span className="brand-mark"><span /><span /><span /></span><span><strong>QUESTBOUND</strong><small>ASCENSION OS</small></span></button>
        <button className="sidebar-profile" type="button" onClick={openProfile}><PixelAvatar image={state.player.avatarDataUrl} compact /><span className="sidebar-profile__copy"><small>OPERATIVE</small><strong>{state.player.profileName}</strong><em>LV {level.level} · {rank}</em></span><Icon name="arrow" size={15} /></button>
        <nav className="side-nav" aria-label="Dashboard sections">{[["command", "grid", "Command"], ["quests", "quest", "Quest log"], ["rituals", "ritual", "Rituals"], ["tavern", "shop", "Tavern"], ["chronicle", "history", "Chronicle"]].map(([id, icon, label], index) => <button className={index === 0 ? "is-active" : ""} type="button" key={id} onClick={() => scrollTo(id)}><Icon name={icon} /><span>{label}</span>{id === "quests" && activeQuests.length > 0 && <b>{activeQuests.length}</b>}</button>)}</nav>
        <div className="sidebar-level"><div><span>Level {level.level}</span><span>{level.currentXp}/{level.requiredXp} XP</span></div><div className="micro-progress"><span style={{ width: `${levelProgress}%` }} /></div><p>{rank} · progression active</p></div>
      </aside>

      <div className="main-frame">
        <header className="topbar">
          <button className="mobile-brand" type="button" onClick={() => scrollTo("command")}><span className="brand-mark"><span /><span /><span /></span><strong>QUESTBOUND</strong></button>
          <div className="topbar-status"><span className="status-dot" /><span>{hydrated ? "SYSTEM ONLINE" : "BOOTING"}</span><i /><span>{now ? shortTimeFormatter.format(now) : "--:--"}</span></div>
          <div className="top-actions"><button className={`icon-btn ${musicPlaying ? "is-live" : ""}`} type="button" onClick={() => setPanel("music")} aria-label="Open music player"><Icon name="music" />{track && <span className="live-dot" />}</button><button className="icon-btn" type="button" onClick={() => setPanel("settings")} aria-label="Open settings"><Icon name="settings" /></button><button className="focus-launch" type="button" onClick={() => openFocus()}><Icon name="timer" /><span>Focus chamber</span></button></div>
        </header>

        <main>
          <section id="command" className="command-hero section-anchor">
            <div className="command-hero__noise" aria-hidden="true" />
            <div className="hero-copy"><p className="eyebrow"><span className="pulse-dot" />{now ? dateFormatter.format(now) : "Today’s campaign"}</p><h1>Ready, <span>{state.player.profileName}</span>.</h1><p className="hero-subtitle">One target. One clean move. Let momentum handle the rest.</p>
              <article className={`prime-directive ${priorityQuest ? `tone-${DIFFICULTIES[priorityQuest.difficulty].tone}` : "is-empty"}`}>
                <div className="prime-directive__signal"><Icon name="target" size={20} /><span>PRIME DIRECTIVE</span></div>
                {priorityQuest ? <><div className="prime-directive__content"><div><small>{priorityQuest.category} · {DIFFICULTIES[priorityQuest.difficulty].label}</small><h2>{priorityQuest.title}</h2></div><div className="quest-yield"><span>+{DIFFICULTIES[priorityQuest.difficulty].xp} XP</span><span>+{DIFFICULTIES[priorityQuest.difficulty].gold} G</span></div></div><div className="prime-directive__actions"><button className="primary-action" type="button" onClick={() => completeQuest(priorityQuest.id)}><Icon name="check" />Complete quest</button><button className="ghost-action" type="button" onClick={() => openFocus(priorityQuest.id)}><Icon name="timer" />Start focused</button></div></> : <div className="prime-empty"><div><small>NO ACTIVE TARGET</small><h2>Your field is clear.</h2></div><button className="primary-action" type="button" onClick={() => document.getElementById("quest-title")?.focus()}><Icon name="plus" />Create a quest</button></div>}
              </article>
            </div>
            <div className="hero-orbit" aria-label={`Level ${level.level}, ${levelProgress}% toward next level`}><div className="orbit-lines" aria-hidden="true"><span /><span /><span /></div><div className="level-orb" style={{ "--level-progress": `${levelProgress}%` } as CSSProperties}><PixelAvatar image={state.player.avatarDataUrl} /><span className="level-orb__scan" aria-hidden="true" /></div><div className="level-orb__label"><small>LEVEL</small><strong>{level.level}</strong><span>{rank.toUpperCase()}</span></div></div>
          </section>

          <section className="stat-ribbon" aria-label="Player statistics">
            <article><span className="stat-icon tone-flame"><Icon name="flame" /></span><div><small>DAILY STREAK</small><strong>{state.player.streak} <em>days</em></strong></div><b>{multiplier.toFixed(1)}× XP</b></article>
            <article><span className="stat-icon tone-bolt"><Icon name="bolt" /></span><div><small>FOCUS ENERGY</small><strong>{state.player.energy}<em>/100</em></strong></div><div className="tiny-gauge"><span style={{ width: `${state.player.energy}%` }} /></div></article>
            <article><span className="stat-icon tone-coin"><Icon name="coin" /></span><div><small>GOLD RESERVE</small><strong>{formatCompactNumber(state.player.gold)}</strong></div><b>SPENDABLE</b></article>
            <article><span className="stat-icon tone-spark"><Icon name="spark" /></span><div><small>TODAY</small><strong>{completedToday} <em>cleared</em></strong></div><b>{todayFocus} MIN FOCUS</b></article>
          </section>

          {storageWarning && <div className="system-alert"><Icon name="shield" /><span><strong>Local saving is blocked.</strong> Your browser may erase changes after refresh.</span></div>}

          <div className="dashboard-grid">
            <section id="quests" className="panel quest-panel section-anchor">
              <header className="panel-heading"><div><p className="eyebrow">MISSION CONTROL</p><h2>Quest log</h2></div><span className="panel-count">{activeQuests.length} ACTIVE</span></header>
              <form className="quest-composer" onSubmit={submitQuest}><div className="composer-main"><Icon name="plus" /><input id="quest-title" value={questTitle} onChange={(event) => setQuestTitle(event.target.value)} maxLength={100} placeholder="What needs to get done?" aria-label="New quest title" /></div><div className="composer-options"><label><span>Class</span><select value={questDifficulty} onChange={(event) => setQuestDifficulty(event.target.value as DifficultyKey)}>{Object.entries(DIFFICULTIES).map(([key, value]) => <option key={key} value={key}>{value.label} · {value.xp} XP</option>)}</select></label><label><span>Realm</span><select value={questCategory} onChange={(event) => setQuestCategory(event.target.value)}>{categories.map((category) => <option key={category}>{category}</option>)}</select></label><button className="primary-action" type="submit">Deploy quest <Icon name="arrow" /></button></div></form>
              <div className="quest-toolbar"><div className="filter-tabs" role="group" aria-label="Filter quests">{(["active", "completed", "all"] as QuestFilter[]).map((filter) => <button className={questFilter === filter ? "is-active" : ""} type="button" key={filter} onClick={() => setQuestFilter(filter)}>{filter}</button>)}</div><label className="search-field"><Icon name="search" size={15} /><input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search" aria-label="Search quests" /></label></div>
              <div className="quest-list">{visibleQuests.length ? visibleQuests.map((quest) => { const config = DIFFICULTIES[quest.difficulty]; return <article className={`quest-row ${quest.completedAt ? "is-complete" : ""} ${quest.isPriority ? "is-priority" : ""}`} key={quest.id}><button className="quest-check" type="button" onClick={() => !quest.completedAt && completeQuest(quest.id)} disabled={Boolean(quest.completedAt)} aria-label={quest.completedAt ? `${quest.title} completed` : `Complete ${quest.title}`}><Icon name="check" size={16} /></button><div className="quest-row__body"><div><span className={`difficulty-dot tone-${config.tone}`} /><small>{config.label} · {quest.category}</small>{quest.isPriority && <b>PRIME</b>}</div><h3>{quest.title}</h3><p>{quest.completedAt ? `Earned ${quest.xpEarned} XP · ${quest.goldEarned} Gold` : `${config.xp} base XP · ${config.gold} Gold`}</p></div><div className="quest-row__actions">{!quest.completedAt && <><button type="button" onClick={() => setPriority(quest.id)} aria-label={`Make ${quest.title} the prime directive`} title="Set as prime directive"><Icon name="pin" size={16} /></button><button className="row-focus" type="button" onClick={() => openFocus(quest.id)} aria-label={`Focus on ${quest.title}`}><Icon name="timer" size={16} /><span>Focus</span></button></>}<button type="button" onClick={() => deleteQuest(quest.id)} aria-label={`Delete ${quest.title}`}><Icon name="trash" size={16} /></button></div></article>; }) : <div className="empty-state"><span><Icon name={questFilter === "completed" ? "trophy" : "target"} size={25} /></span><h3>{questFilter === "completed" ? "No victories logged yet" : "Quest log clear"}</h3><p>{questFilter === "completed" ? "Finish one quest and your first win appears here." : "Add one clear action above. Small is legal."}</p></div>}</div>
            </section>

            <aside className="right-stack">
              <section id="rituals" className="panel ritual-panel section-anchor"><header className="panel-heading panel-heading--compact"><div><p className="eyebrow">REPEATABLE POWER</p><h2>Daily rituals</h2></div><span className="daily-chip">RESETS DAILY</span></header><form className="mini-composer" onSubmit={submitRitual}><input value={ritualTitle} onChange={(event) => setRitualTitle(event.target.value)} placeholder="Add a tiny daily ritual" maxLength={70} aria-label="New ritual" /><button type="submit" aria-label="Add ritual"><Icon name="plus" size={16} /></button></form><div className="ritual-list">{state.rituals.length ? state.rituals.map((ritual) => { const done = ritual.lastCompletedDate === toDateKey(); return <article className={done ? "is-done" : ""} key={ritual.id}><button type="button" onClick={() => completeRitual(ritual.id)} disabled={done} aria-label={`${done ? "Completed" : "Complete"} ${ritual.title}`}><Icon name="check" size={14} /></button><span><strong>{ritual.title}</strong><small>+{ritual.xp} XP</small></span><button className="ritual-delete" type="button" onClick={() => setState((current) => ({ ...current, rituals: current.rituals.filter((item) => item.id !== ritual.id) }))} aria-label={`Delete ${ritual.title}`}><Icon name="close" size={13} /></button></article>; }) : <div className="mini-empty"><Icon name="ritual" /><p>Add a ritual so consistency has somewhere to land.</p></div>}</div></section>
              <section className="panel focus-card"><div className="focus-card__top"><span className="focus-glyph"><Icon name="timer" size={22} /></span><div><p className="eyebrow">ATTENTION ENGINE</p><h2>Focus chamber</h2></div></div><p>Strip the screen down to one mission and one timer.</p><div className="focus-card__stats"><span><small>TODAY</small><strong>{todayFocus}m</strong></span><span><small>ALL TIME</small><strong>{state.player.focusMinutes}m</strong></span><span><small>SESSIONS</small><strong>{state.player.focusSessions}</strong></span></div><button className="primary-action primary-action--wide" type="button" onClick={() => openFocus()}><Icon name="play" />Enter focus chamber</button></section>
              <section className="panel weekly-panel"><header className="panel-heading panel-heading--compact"><div><p className="eyebrow">LAST 7 DAYS</p><h2>Momentum signal</h2></div><span className="signal-live"><i /> LIVE</span></header><div className="weekly-chart" aria-label="Seven day quest and focus activity chart">{weeklyData.map((day, index) => { const score = day.completed * 20 + day.focus; return <div className="weekly-bar" key={day.date}><span className="weekly-bar__value">{day.completed || day.focus ? day.completed + day.focus / 60 : ""}</span><div><i style={{ height: `${Math.max(5, (score / maxWeeklyScore) * 100)}%` }} /></div><small>{now ? dayFormatter.format(new Date(`${day.date}T12:00:00`)).slice(0, 1) : hydrationSafeWeekdays[index]}</small></div>; })}</div><div className="chart-legend"><span><i className="legend-accent" />Quests + focus</span><strong>{state.player.totalCompleted} lifetime clears</strong></div></section>
            </aside>
          </div>

          <section id="tavern" className="lower-grid section-anchor">
            <article className="panel tavern-panel"><header className="panel-heading"><div><p className="eyebrow">REAL-WORLD LOOT</p><h2>The Tavern</h2></div><span className="gold-balance"><Icon name="coin" size={15} />{formatCompactNumber(state.player.gold)} GOLD</span></header><form className="reward-composer" onSubmit={submitReward}><input value={rewardTitle} onChange={(event) => setRewardTitle(event.target.value)} placeholder="Create a reward worth earning" maxLength={70} aria-label="Reward name" /><label><input type="number" min="1" max="999999" value={rewardCost} onChange={(event) => setRewardCost(event.target.value)} aria-label="Reward Gold cost" /><span>G</span></label><button type="submit"><Icon name="plus" size={16} />Add</button></form><div className="reward-grid">{state.rewards.length ? state.rewards.map((reward) => <article className="reward-card" key={reward.id}><div className="reward-card__icon"><Icon name="shop" /></div><div><small>PERSONAL REWARD</small><h3>{reward.name}</h3><p>{reward.claimedCount ? `Claimed ${reward.claimedCount}×` : "Never claimed"}</p></div><button type="button" onClick={() => claimReward(reward.id)} disabled={state.player.gold < reward.cost}><span>{reward.cost} G</span><small>{state.player.gold >= reward.cost ? "UNLOCK" : `${reward.cost - state.player.gold} SHORT`}</small></button><button className="reward-delete" type="button" onClick={() => setState((current) => ({ ...current, rewards: current.rewards.filter((item) => item.id !== reward.id) }))} aria-label={`Delete ${reward.name}`}><Icon name="close" size={12} /></button></article>) : <div className="wide-empty"><Icon name="shop" size={22} /><span><strong>Your Tavern is empty.</strong><small>Make real rewards part of the system, not an accident.</small></span></div>}</div></article>
            <article className="panel achievement-panel"><header className="panel-heading"><div><p className="eyebrow">MILESTONES</p><h2>Achievements</h2></div><span className="panel-count">{achievements.filter((item) => item.unlocked).length}/{achievements.length}</span></header><div className="achievement-list">{achievements.map((achievement) => <article className={achievement.unlocked ? "is-unlocked" : ""} key={achievement.name}><span><Icon name={achievement.icon} /></span><div><strong>{achievement.name}</strong><small>{achievement.detail}</small></div>{achievement.unlocked && <b>UNLOCKED</b>}</article>)}</div></article>
          </section>

          <section id="chronicle" className="panel chronicle-panel section-anchor"><header className="panel-heading"><div><p className="eyebrow">CAMPAIGN RECORD</p><h2>Chronicle</h2></div><button className="text-action" type="button" onClick={() => setState((current) => ({ ...current, activity: [] }))} disabled={!state.activity.length}>Clear history</button></header><div className="chronicle-list">{state.activity.length ? state.activity.slice(0, 12).map((item) => <article key={item.id}><span className={`chronicle-icon type-${item.type}`}><Icon name={item.type === "reward" ? "shop" : item.type === "focus" ? "timer" : item.type === "level" ? "trophy" : item.type === "ritual" ? "ritual" : "check"} size={15} /></span><div><strong>{item.message}</strong><small>{item.detail}</small></div><time>{shortTimeFormatter.format(new Date(item.timestamp))}</time></article>) : <div className="wide-empty"><Icon name="history" size={22} /><span><strong>No campaign events yet.</strong><small>Your victories, focus sessions, and rewards will appear here.</small></span></div>}</div></section>
          <footer><span>QUESTBOUND ASCENSION · LOCAL-FIRST PRODUCTIVITY OS</span><span>{storageWarning ? "SAVE LINK OFFLINE" : "ALL PROGRESS SAVED LOCALLY"}</span></footer>
        </main>
      </div>

      <nav className="mobile-nav" aria-label="Mobile navigation">{[["command", "grid", "Home"], ["quests", "quest", "Quests"], ["rituals", "ritual", "Rituals"], ["tavern", "shop", "Tavern"]].map(([id, icon, label]) => <button type="button" key={id} onClick={() => scrollTo(id)}><Icon name={icon} /><span>{label}</span></button>)}<button type="button" onClick={() => setPanel("settings")}><Icon name="more" /><span>More</span></button></nav>

      {panel === "focus" && <Modal title="Focus chamber" kicker="ATTENTION ENGINE" onClose={() => setPanel(null)} wide><div className="focus-modal"><div className="focus-visual"><div className={`focus-ring ${focusRunning ? "is-running" : ""}`} style={{ "--focus-progress": `${focusProgress}%` } as CSSProperties}><span><small>{focusRunning ? "LOCKED IN" : focusSeconds === 0 ? "COMPLETE" : "READY"}</small><strong>{focusMinutes}:{focusRemainder}</strong><em>{focusPreset} MIN PROTOCOL</em></span></div><div className="focus-presets" role="group" aria-label="Focus duration">{[5, 15, 25, 50].map((minutes) => <button type="button" className={focusPreset === minutes ? "is-active" : ""} key={minutes} onClick={() => selectFocusPreset(minutes)} disabled={focusRunning}>{minutes}m</button>)}</div></div><div className="focus-controls"><p className="eyebrow">CURRENT TARGET</p><select value={focusQuestId} onChange={(event) => setFocusQuestId(event.target.value)} disabled={focusRunning} aria-label="Quest for focus session"><option value="">Open focus session</option>{activeQuests.map((quest) => <option key={quest.id} value={quest.id}>{quest.title}</option>)}</select><div className="focus-target-card"><Icon name="target" /><div><small>MISSION</small><strong>{activeQuests.find((quest) => quest.id === focusQuestId)?.title ?? "Hold one intention. Ignore the rest."}</strong></div></div><div className="focus-rules"><span><Icon name="shield" size={15} />No penalty for pausing</span><span><Icon name="spark" size={15} />Earn XP when the timer ends</span><span><Icon name="music" size={15} />Your soundtrack keeps playing</span></div><div className="focus-buttons"><button className="primary-action" type="button" onClick={toggleFocus}><Icon name={focusRunning ? "pause" : "play"} />{focusRunning ? "Pause sprint" : focusSeconds === 0 ? "Run again" : "Begin sprint"}</button><button className="ghost-action" type="button" onClick={resetFocus}>Reset</button></div></div></div></Modal>}

      {panel === "profile" && <Modal title="Operative profile" kicker="IDENTITY MODULE" onClose={() => setPanel(null)}><form className="profile-form" onSubmit={saveProfile}><div className="profile-avatar-editor"><PixelAvatar image={profileAvatar} /><button type="button" onClick={() => avatarInput.current?.click()} disabled={profileBusy}><Icon name="upload" size={15} />{profileBusy ? "Processing" : "Change photo"}</button>{profileAvatar && <button className="profile-remove" type="button" onClick={() => setProfileAvatar(null)}>Use pixel operative</button>}<input ref={avatarInput} type="file" hidden accept="image/png,image/jpeg,image/webp,image/gif" onChange={(event) => void handleAvatar(event.target.files?.[0])} /></div><label className="field-label"><span>Display name</span><input value={profileName} onChange={(event) => setProfileName(event.target.value)} maxLength={28} required /></label><p className="privacy-note"><Icon name="shield" size={15} />Your photo is cropped, compressed, and stored only in this browser.</p><button className="primary-action primary-action--wide" type="submit" disabled={profileBusy}>Save identity</button></form></Modal>}

      {panel === "music" && <Modal title="Soundtrack console" kicker="LOCAL AUDIO" onClose={() => setPanel(null)}><div className="music-console"><div className={`music-now ${musicPlaying ? "is-playing" : ""}`}><div className="equalizer" aria-hidden="true">{Array.from({ length: 7 }, (_, index) => <i key={index} />)}</div><div><small>{track ? musicPlaying ? "NOW PLAYING" : "READY" : "NO TRACK INSTALLED"}</small><strong>{track?.name ?? "Choose your lobby soundtrack"}</strong><span>{track ? `${(track.size / 1024 / 1024).toFixed(1)} MB · loops continuously` : "MP3, WAV, OGG, M4A, AAC, or WebM"}</span></div><button type="button" onClick={() => void toggleMusic()} disabled={musicBusy} aria-label={musicPlaying ? "Pause music" : "Play music"}><Icon name={musicPlaying ? "pause" : "play"} size={20} /></button></div><label className="volume-control"><Icon name="volume" size={17} /><input type="range" min="0" max="100" value={Math.round(state.settings.musicVolume * 100)} onChange={(event) => setState((current) => ({ ...current, settings: { ...current.settings, musicVolume: Number(event.target.value) / 100 } }))} aria-label="Music volume" /><span>{Math.round(state.settings.musicVolume * 100)}%</span></label><div className="music-actions"><button className="ghost-action" type="button" onClick={() => musicInput.current?.click()} disabled={musicBusy}><Icon name="upload" />{musicBusy ? "Saving…" : track ? "Replace track" : "Choose audio"}</button><button className="danger-action" type="button" onClick={() => void removeMusic()} disabled={!track}><Icon name="trash" />Remove</button></div><input ref={musicInput} type="file" hidden accept="audio/mpeg,audio/wav,audio/ogg,audio/mp4,audio/aac,audio/webm,.mp3,.wav,.ogg,.m4a,.aac,.webm" onChange={(event) => void handleMusicFile(event.target.files?.[0])} /><p className="privacy-note"><Icon name="shield" size={15} />Audio stays in this browser. It is never uploaded to Questbound or GitHub.</p></div></Modal>}

      {panel === "settings" && <Modal title="System settings" kicker="CONTROL CENTER" onClose={() => setPanel(null)} wide><div className="settings-grid"><section><h3>Interface signal</h3><p>Choose the accent that cuts through the noise.</p><div className="accent-picker">{(["mint", "violet", "amber"] as AccentKey[]).map((accent) => <button className={state.settings.accent === accent ? "is-active" : ""} type="button" key={accent} onClick={() => setState((current) => ({ ...current, settings: { ...current.settings, accent } }))}><i data-color={accent} /><span>{accent}</span><Icon name="check" size={14} /></button>)}</div></section><section><h3>Feedback</h3><p>Keep effects useful instead of turning the app into a damn slot machine.</p><label className="toggle-row"><span><strong>Reward sounds</strong><small>Short synthesized completion tones</small></span><input type="checkbox" checked={state.settings.soundEnabled} onChange={(event) => setState((current) => ({ ...current, settings: { ...current.settings, soundEnabled: event.target.checked } }))} /></label><label className="toggle-row"><span><strong>Reduced effects</strong><small>Calmer movement and celebrations</small></span><input type="checkbox" checked={state.settings.reducedFx} onChange={(event) => setState((current) => ({ ...current, settings: { ...current.settings, reducedFx: event.target.checked } }))} /></label></section><section><h3>Save control</h3><p>Back up or restore the entire campaign as JSON.</p><div className="data-actions"><button className="ghost-action" type="button" onClick={exportSave}><Icon name="download" />Export save</button><button className="ghost-action" type="button" onClick={() => importInput.current?.click()}><Icon name="upload" />Import save</button><input ref={importInput} type="file" hidden accept="application/json,.json" onChange={(event) => void importSave(event.target.files?.[0])} /></div></section><section className="danger-zone"><h3>Reset campaign</h3><p>This removes profile data, quests, progression, rewards, rituals, history, and local music.</p>{confirmReset ? <div className="reset-confirm"><strong>Actually erase everything?</strong><div><button className="danger-action" type="button" onClick={() => void resetEverything()}>Yes, wipe it</button><button className="ghost-action" type="button" onClick={() => setConfirmReset(false)}>Cancel</button></div></div> : <button className="danger-action" type="button" onClick={() => setConfirmReset(true)}><Icon name="trash" />Reset all data</button>}</section></div></Modal>}

      {toast && <div className={`toast toast--${toast.tone}`} role="status"><span><Icon name={toast.tone === "success" ? "check" : toast.tone === "danger" ? "shield" : "spark"} /></span><div><strong>{toast.title}</strong><small>{toast.detail}</small></div><button type="button" onClick={() => setToast(null)} aria-label="Dismiss notification"><Icon name="close" size={14} /></button></div>}
      {celebrating > 0 && !state.settings.reducedFx && <div className="celebration" key={celebrating} aria-hidden="true">{Array.from({ length: 26 }, (_, index) => <i key={index} style={{ "--particle": index } as CSSProperties} />)}</div>}
    </div>
  );
}
