(() => {
  "use strict";

  const STORAGE_KEY = "questbound-rpg-v1";
  const STATE_VERSION = 1;
  const MAX_ENERGY = 100;
  const MAX_ACTIVITY_ITEMS = 30;

  const DIFFICULTIES = Object.freeze({
    easy: Object.freeze({ label: "Easy", xp: 10, gold: 2, energy: 4 }),
    medium: Object.freeze({ label: "Medium", xp: 25, gold: 5, energy: 6 }),
    hard: Object.freeze({ label: "Hard", xp: 50, gold: 10, energy: 9 }),
    boss: Object.freeze({ label: "Boss", xp: 100, gold: 20, energy: 14 }),
  });

  const RANKS = Object.freeze([
    { minimumLevel: 1, name: "Novice" },
    { minimumLevel: 3, name: "Pathfinder" },
    { minimumLevel: 5, name: "Vanguard" },
    { minimumLevel: 8, name: "Quest Knight" },
    { minimumLevel: 12, name: "Warden" },
    { minimumLevel: 16, name: "Legend" },
  ]);

  const ICONS = Object.freeze({
    check:
      '<svg aria-hidden="true" viewBox="0 0 24 24" fill="none"><path d="m5 12 4 4L19 6" /></svg>',
    trash:
      '<svg aria-hidden="true" viewBox="0 0 24 24" fill="none"><path d="M4 7h16M9 7V4h6v3m3 0-1 13H7L6 7m4 4v5m4-5v5" /></svg>',
  });

  const numberFormatter = new Intl.NumberFormat("en-US");
  const shortDateFormatter = new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
  });
  const fullTodayFormatter = new Intl.DateTimeFormat("en-US", {
    weekday: "long",
    month: "short",
    day: "numeric",
  });
  const timeFormatter = new Intl.DateTimeFormat("en-US", {
    hour: "numeric",
    minute: "2-digit",
  });

  let storageLoadFailed = false;
  let storageWriteFailed = false;
  let questFilter = "active";
  let pendingConfirmAction = null;
  let audioContext = null;
  let state = loadState();

  const getById = (id) => document.getElementById(id);
  const refs = {
    saveStatus: getById("save-status"),
    soundToggle: getById("sound-toggle"),
    soundOnIcon: getById("sound-on-icon"),
    soundOffIcon: getById("sound-off-icon"),
    todayLabel: getById("today-label"),
    avatarLevel: getById("avatar-level"),
    levelValue: getById("level-value"),
    rankValue: getById("rank-value"),
    totalXpValue: getById("total-xp-value"),
    goldValue: getById("gold-value"),
    tavernGoldValue: getById("tavern-gold-value"),
    streakValue: getById("streak-value"),
    multiplierValue: getById("multiplier-value"),
    streakHint: getById("streak-hint"),
    xpProgressLabel: getById("xp-progress-label"),
    xpProgressBar: getById("xp-progress-bar"),
    energyLabel: getById("energy-label"),
    energyProgressBar: getById("energy-progress-bar"),
    activeQuestCount: getById("active-quest-count"),
    questForm: getById("quest-form"),
    questTitle: getById("quest-title"),
    questDifficulty: getById("quest-difficulty"),
    questList: getById("quest-list"),
    questEmptyState: getById("quest-empty-state"),
    questEmptyTitle: getById("quest-empty-title"),
    questEmptyCopy: getById("quest-empty-copy"),
    rewardForm: getById("reward-form"),
    rewardName: getById("reward-name"),
    rewardCost: getById("reward-cost"),
    rewardList: getById("reward-list"),
    rewardEmptyState: getById("reward-empty-state"),
    activityList: getById("activity-list"),
    activityEmpty: getById("activity-empty"),
    completedTotal: getById("completed-total"),
    resetDataButton: getById("reset-data-button"),
    confettiLayer: getById("confetti-layer"),
    toastRegion: getById("toast-region"),
    announcer: getById("screen-reader-announcer"),
    confirmDialog: getById("confirm-dialog"),
    confirmTitle: getById("confirm-title"),
    confirmCopy: getById("confirm-copy"),
    confirmCancel: getById("confirm-cancel"),
    confirmAction: getById("confirm-action"),
  };

  initialize();

  function initialize() {
    applyDailyStateCheck();
    bindEvents();
    render();

    if (storageLoadFailed) {
      showToast("Save data could not be read", "A fresh game was loaded. Browser storage may be unavailable.", "error");
    }
  }

  function createDefaultState() {
    return {
      version: STATE_VERSION,
      player: {
        totalXp: 0,
        gold: 0,
        energy: MAX_ENERGY,
        streak: 0,
        lastCompletionDate: null,
        energyCheckedDate: null,
        totalCompleted: 0,
      },
      settings: {
        soundEnabled: true,
      },
      quests: [],
      rewards: [],
      activity: [],
    };
  }

  function loadState() {
    try {
      const raw = window.localStorage.getItem(STORAGE_KEY);
      if (!raw) return createDefaultState();
      return sanitizeState(JSON.parse(raw));
    } catch (error) {
      storageLoadFailed = true;
      return createDefaultState();
    }
  }

  function sanitizeState(candidate) {
    const fallback = createDefaultState();
    if (!candidate || typeof candidate !== "object") return fallback;

    const player = candidate.player && typeof candidate.player === "object" ? candidate.player : {};
    const settings = candidate.settings && typeof candidate.settings === "object" ? candidate.settings : {};

    return {
      version: STATE_VERSION,
      player: {
        totalXp: safeInteger(player.totalXp, 0, 1_000_000_000, 0),
        gold: safeInteger(player.gold, 0, 1_000_000_000, 0),
        energy: safeInteger(player.energy, 0, MAX_ENERGY, MAX_ENERGY),
        streak: safeInteger(player.streak, 0, 100_000, 0),
        lastCompletionDate: isDateKey(player.lastCompletionDate) ? player.lastCompletionDate : null,
        energyCheckedDate: isDateKey(player.energyCheckedDate) ? player.energyCheckedDate : null,
        totalCompleted: safeInteger(player.totalCompleted, 0, 1_000_000_000, 0),
      },
      settings: {
        soundEnabled: settings.soundEnabled !== false,
      },
      quests: sanitizeQuests(candidate.quests),
      rewards: sanitizeRewards(candidate.rewards),
      activity: sanitizeActivity(candidate.activity),
    };
  }

  function sanitizeQuests(candidate) {
    if (!Array.isArray(candidate)) return [];

    return candidate
      .slice(0, 500)
      .map((quest) => {
        if (!quest || typeof quest !== "object") return null;
        const title = normalizeText(quest.title, 80);
        const difficulty = Object.hasOwn(DIFFICULTIES, quest.difficulty) ? quest.difficulty : "easy";
        if (!title) return null;

        return {
          id: safeId(quest.id),
          title,
          difficulty,
          createdAt: safeTimestamp(quest.createdAt),
          completedAt: quest.completedAt ? safeTimestamp(quest.completedAt) : null,
          xpEarned: safeInteger(quest.xpEarned, 0, 100_000, 0),
          goldEarned: safeInteger(quest.goldEarned, 0, 100_000, 0),
          multiplier: safeNumber(quest.multiplier, 1, 1.5, 1),
        };
      })
      .filter(Boolean);
  }

  function sanitizeRewards(candidate) {
    if (!Array.isArray(candidate)) return [];

    return candidate
      .slice(0, 200)
      .map((reward) => {
        if (!reward || typeof reward !== "object") return null;
        const name = normalizeText(reward.name, 60);
        if (!name) return null;

        return {
          id: safeId(reward.id),
          name,
          cost: safeInteger(reward.cost, 1, 99_999, 1),
          createdAt: safeTimestamp(reward.createdAt),
          redeemedCount: safeInteger(reward.redeemedCount, 0, 1_000_000, 0),
          lastRedeemedAt: reward.lastRedeemedAt ? safeTimestamp(reward.lastRedeemedAt) : null,
        };
      })
      .filter(Boolean);
  }

  function sanitizeActivity(candidate) {
    if (!Array.isArray(candidate)) return [];

    return candidate
      .slice(0, MAX_ACTIVITY_ITEMS)
      .map((item) => {
        if (!item || typeof item !== "object") return null;
        const message = normalizeText(item.message, 100);
        if (!message) return null;

        return {
          id: safeId(item.id),
          type: item.type === "reward" ? "reward" : "quest",
          message,
          detail: normalizeText(item.detail, 100),
          timestamp: safeTimestamp(item.timestamp),
        };
      })
      .filter(Boolean);
  }

  function safeInteger(value, minimum, maximum, fallback) {
    const numericValue = Number(value);
    if (!Number.isFinite(numericValue)) return fallback;
    return Math.min(maximum, Math.max(minimum, Math.round(numericValue)));
  }

  function safeNumber(value, minimum, maximum, fallback) {
    const numericValue = Number(value);
    if (!Number.isFinite(numericValue)) return fallback;
    return Math.min(maximum, Math.max(minimum, numericValue));
  }

  function safeId(value) {
    return typeof value === "string" && value.length <= 100 && value.length > 0 ? value : createId();
  }

  function safeTimestamp(value) {
    if (typeof value === "string" && Number.isFinite(Date.parse(value))) return value;
    return new Date().toISOString();
  }

  function normalizeText(value, maximumLength) {
    if (typeof value !== "string") return "";
    return value.trim().replace(/\s+/g, " ").slice(0, maximumLength);
  }

  function isDateKey(value) {
    return typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value);
  }

  function createId() {
    if (window.crypto && typeof window.crypto.randomUUID === "function") {
      return window.crypto.randomUUID();
    }

    return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
  }

  function persistState() {
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
      storageWriteFailed = false;
      refs.saveStatus.textContent = "Saved locally";
    } catch (error) {
      refs.saveStatus.textContent = "Saving unavailable";
      if (!storageWriteFailed) {
        storageWriteFailed = true;
        showToast("Could not save", "Browser storage is blocked or full. Changes may disappear after refresh.", "error");
      }
    }
  }

  function bindEvents() {
    refs.questForm.addEventListener("submit", handleQuestSubmit);
    refs.rewardForm.addEventListener("submit", handleRewardSubmit);
    refs.questList.addEventListener("click", handleQuestListClick);
    refs.rewardList.addEventListener("click", handleRewardListClick);
    refs.soundToggle.addEventListener("click", toggleSound);
    refs.resetDataButton.addEventListener("click", requestReset);

    document.querySelectorAll(".quest-filter").forEach((button) => {
      button.addEventListener("click", () => setQuestFilter(button.dataset.filter));
    });

    refs.confirmDialog.addEventListener("close", () => {
      const confirmed = refs.confirmDialog.returnValue === "confirm";
      const action = pendingConfirmAction;
      pendingConfirmAction = null;
      if (confirmed && typeof action === "function") action();
    });

    refs.confirmDialog.addEventListener("click", (event) => {
      if (event.target === refs.confirmDialog) refs.confirmDialog.close("cancel");
    });
  }

  function applyDailyStateCheck() {
    const today = toDateKey(new Date());
    const checkedDate = state.player.energyCheckedDate;
    let changed = false;

    if (!checkedDate) {
      state.player.energyCheckedDate = today;
      changed = true;
    } else {
      const elapsedDays = daysBetween(checkedDate, today);
      if (elapsedDays > 0) {
        const lastCompletion = state.player.lastCompletionDate;

        if (lastCompletion) {
          let missedDays = elapsedDays;
          if (lastCompletion >= checkedDate && lastCompletion < today) {
            missedDays = Math.max(0, missedDays - 1);
          }

          const energyLoss = Math.min(24, missedDays * 6);
          state.player.energy = Math.max(0, state.player.energy - energyLoss);

          if (daysBetween(lastCompletion, today) > 1) {
            state.player.streak = 0;
          }
        }

        state.player.energyCheckedDate = today;
        changed = true;
      }
    }

    if (changed) persistState();
  }

  function handleQuestSubmit(event) {
    event.preventDefault();
    const title = normalizeText(refs.questTitle.value, 80);
    const difficulty = refs.questDifficulty.value;

    if (!title) {
      refs.questTitle.focus();
      showToast("Name the quest", "Use one clear action so future-you knows exactly where to start.", "error");
      return;
    }

    if (!Object.hasOwn(DIFFICULTIES, difficulty)) return;

    state.quests.unshift({
      id: createId(),
      title,
      difficulty,
      createdAt: new Date().toISOString(),
      completedAt: null,
      xpEarned: 0,
      goldEarned: 0,
      multiplier: 1,
    });

    questFilter = "active";
    refs.questForm.reset();
    persistState();
    render();
    refs.questTitle.focus();
    announce(`Quest added: ${title}`);
    showToast("Quest added", `${DIFFICULTIES[difficulty].label} · ${DIFFICULTIES[difficulty].xp} base XP`, "default");
  }

  function handleRewardSubmit(event) {
    event.preventDefault();
    const name = normalizeText(refs.rewardName.value, 60);
    const cost = safeInteger(refs.rewardCost.value, 1, 99_999, 0);

    if (!name) {
      refs.rewardName.focus();
      showToast("Name the reward", "Choose something specific you will enjoy claiming.", "error");
      return;
    }

    if (cost < 1) {
      refs.rewardCost.focus();
      showToast("Set a gold cost", "The cost must be at least 1 Gold.", "error");
      return;
    }

    state.rewards.unshift({
      id: createId(),
      name,
      cost,
      createdAt: new Date().toISOString(),
      redeemedCount: 0,
      lastRedeemedAt: null,
    });

    refs.rewardForm.reset();
    persistState();
    render();
    refs.rewardName.focus();
    announce(`Reward created: ${name}`);
    showToast("Reward stocked", `${name} costs ${numberFormatter.format(cost)} Gold.`, "gold");
  }

  function handleQuestListClick(event) {
    const button = event.target.closest("button[data-action]");
    if (!button) return;

    const quest = state.quests.find((item) => item.id === button.dataset.id);
    if (!quest) return;

    if (button.dataset.action === "complete") {
      completeQuest(quest, button.getBoundingClientRect());
    }

    if (button.dataset.action === "delete") {
      openConfirm({
        title: "Remove this quest?",
        copy: quest.completedAt
          ? "This removes it from the cleared log. Earned XP and Gold stay on your character."
          : "This removes it from your active log. No stats will change.",
        confirmLabel: "Remove",
        tone: "danger",
        onConfirm: () => deleteQuest(quest.id),
      });
    }
  }

  function handleRewardListClick(event) {
    const button = event.target.closest("button[data-action]");
    if (!button) return;

    const reward = state.rewards.find((item) => item.id === button.dataset.id);
    if (!reward) return;

    if (button.dataset.action === "redeem") {
      if (state.player.gold < reward.cost) {
        showToast("Not enough Gold yet", `You need ${numberFormatter.format(reward.cost - state.player.gold)} more.`, "error");
        return;
      }

      const rect = button.getBoundingClientRect();
      openConfirm({
        title: "Claim this reward?",
        copy: `Spend ${numberFormatter.format(reward.cost)} Gold on “${reward.name}”?`,
        confirmLabel: "Claim reward",
        tone: "gold",
        onConfirm: () => redeemReward(reward.id, rect),
      });
    }

    if (button.dataset.action === "delete") {
      openConfirm({
        title: "Remove this reward?",
        copy: "This deletes the reward from the Tavern. Previous claims and spent Gold are unchanged.",
        confirmLabel: "Remove",
        tone: "danger",
        onConfirm: () => deleteReward(reward.id),
      });
    }
  }

  function completeQuest(quest, originRect) {
    if (quest.completedAt) return;

    const oldLevel = getLevelSnapshot(state.player.totalXp).level;
    const multiplier = updateDailyStreak();
    const difficulty = DIFFICULTIES[quest.difficulty];
    const xpEarned = Math.round(difficulty.xp * multiplier);
    const goldEarned = difficulty.gold;

    quest.completedAt = new Date().toISOString();
    quest.xpEarned = xpEarned;
    quest.goldEarned = goldEarned;
    quest.multiplier = multiplier;

    state.player.totalXp += xpEarned;
    state.player.gold += goldEarned;
    state.player.energy = Math.min(MAX_ENERGY, state.player.energy + difficulty.energy);
    state.player.totalCompleted += 1;

    addActivity({
      type: "quest",
      message: `Cleared: ${quest.title}`,
      detail: `+${numberFormatter.format(xpEarned)} XP · +${numberFormatter.format(goldEarned)} Gold`,
    });

    const newLevel = getLevelSnapshot(state.player.totalXp).level;
    persistState();
    render();
    createConfetti(originRect, "quest", newLevel > oldLevel ? 38 : 24);
    playSuccessSound(newLevel > oldLevel);

    showToast(
      "Quest cleared",
      `+${numberFormatter.format(xpEarned)} XP · +${numberFormatter.format(goldEarned)} Gold${multiplier > 1 ? ` · ×${multiplier.toFixed(1)} streak` : ""}`,
      "success",
    );
    announce(`${quest.title} completed. Earned ${xpEarned} experience and ${goldEarned} gold.`);

    if (newLevel > oldLevel) {
      window.setTimeout(() => {
        showToast("Level up!", `You reached Level ${newLevel}: ${getRank(newLevel)}.`, "default");
      }, 220);
    }
  }

  function updateDailyStreak() {
    const today = toDateKey(new Date());
    const yesterday = offsetDateKey(today, -1);
    const lastCompletion = state.player.lastCompletionDate;

    if (lastCompletion !== today) {
      state.player.streak = lastCompletion === yesterday ? state.player.streak + 1 : 1;
      state.player.lastCompletionDate = today;
    }

    return getStreakMultiplier(state.player.streak);
  }

  function getStreakMultiplier(streak) {
    return Math.min(1.5, 1 + Math.max(0, streak - 1) * 0.1);
  }

  function deleteQuest(id) {
    const quest = state.quests.find((item) => item.id === id);
    if (!quest) return;
    state.quests = state.quests.filter((item) => item.id !== id);
    persistState();
    render();
    announce(`Quest removed: ${quest.title}`);
    showToast("Quest removed", "Your character stats were not changed.", "default");
  }

  function redeemReward(id, originRect) {
    const reward = state.rewards.find((item) => item.id === id);
    if (!reward || state.player.gold < reward.cost) return;

    state.player.gold -= reward.cost;
    reward.redeemedCount += 1;
    reward.lastRedeemedAt = new Date().toISOString();
    addActivity({
      type: "reward",
      message: `Claimed: ${reward.name}`,
      detail: `−${numberFormatter.format(reward.cost)} Gold`,
    });

    persistState();
    render();
    createConfetti(originRect, "gold", 28);
    playRewardSound();
    announce(`${reward.name} claimed for ${reward.cost} gold.`);
    showToast("Reward claimed", `${reward.name} · −${numberFormatter.format(reward.cost)} Gold`, "gold");
  }

  function deleteReward(id) {
    const reward = state.rewards.find((item) => item.id === id);
    if (!reward) return;
    state.rewards = state.rewards.filter((item) => item.id !== id);
    persistState();
    render();
    announce(`Reward removed: ${reward.name}`);
    showToast("Reward removed", "The Tavern has been updated.", "default");
  }

  function addActivity({ type, message, detail }) {
    state.activity.unshift({
      id: createId(),
      type,
      message,
      detail,
      timestamp: new Date().toISOString(),
    });
    state.activity = state.activity.slice(0, MAX_ACTIVITY_ITEMS);
  }

  function setQuestFilter(filter) {
    if (!new Set(["active", "completed", "all"]).has(filter)) return;
    questFilter = filter;
    renderQuestFilters();
    renderQuests();
  }

  function requestReset() {
    openConfirm({
      title: "Reset the entire game?",
      copy: "All quests, rewards, XP, Gold, streaks, and activity in this browser will be permanently erased.",
      confirmLabel: "Reset everything",
      tone: "danger",
      onConfirm: resetGame,
    });
  }

  function resetGame() {
    state = createDefaultState();
    state.player.energyCheckedDate = toDateKey(new Date());
    questFilter = "active";
    refs.questForm.reset();
    refs.rewardForm.reset();
    persistState();
    render();
    refs.questTitle.focus();
    announce("Game data reset.");
    showToast("Fresh save created", "Your dashboard is ready for a new first quest.", "default");
  }

  function toggleSound() {
    state.settings.soundEnabled = !state.settings.soundEnabled;
    persistState();
    renderSoundToggle();

    if (state.settings.soundEnabled) {
      playNotes([
        [523.25, 0, 0.07],
        [659.25, 0.08, 0.08],
      ]);
      showToast("Sound on", "Short reward tones are enabled.", "default");
    } else {
      showToast("Sound off", "The dashboard will stay quiet.", "default");
    }
  }

  function render() {
    renderDate();
    renderStats();
    renderQuestFilters();
    renderQuests();
    renderRewards();
    renderActivity();
    renderSoundToggle();
  }

  function renderDate() {
    refs.todayLabel.textContent = fullTodayFormatter.format(new Date());
  }

  function renderStats() {
    const snapshot = getLevelSnapshot(state.player.totalXp);
    const multiplier = getStreakMultiplier(state.player.streak);
    const progressPercent = Math.min(100, Math.max(0, (snapshot.currentXp / snapshot.requiredXp) * 100));
    const energyPercent = (state.player.energy / MAX_ENERGY) * 100;
    const completedToday = state.player.lastCompletionDate === toDateKey(new Date());

    refs.avatarLevel.textContent = `LV ${snapshot.level}`;
    refs.levelValue.textContent = numberFormatter.format(snapshot.level);
    refs.rankValue.textContent = getRank(snapshot.level);
    refs.totalXpValue.textContent = numberFormatter.format(state.player.totalXp);
    refs.goldValue.textContent = numberFormatter.format(state.player.gold);
    refs.tavernGoldValue.textContent = numberFormatter.format(state.player.gold);
    refs.streakValue.textContent = numberFormatter.format(state.player.streak);
    refs.multiplierValue.textContent = `×${multiplier.toFixed(1)}`;
    refs.streakHint.textContent = completedToday
      ? "Today’s chain secured"
      : state.player.streak > 0
        ? "One quest keeps it alive"
        : "Complete one quest today";

    refs.xpProgressLabel.textContent = `${numberFormatter.format(snapshot.currentXp)} / ${numberFormatter.format(snapshot.requiredXp)} XP`;
    refs.xpProgressBar.style.width = `${progressPercent}%`;
    refs.xpProgressBar.parentElement.setAttribute("aria-valuenow", String(Math.round(progressPercent)));
    refs.energyLabel.textContent = `${state.player.energy} / ${MAX_ENERGY}`;
    refs.energyProgressBar.style.width = `${energyPercent}%`;
    refs.energyProgressBar.parentElement.setAttribute("aria-valuenow", String(state.player.energy));
    refs.completedTotal.textContent = `${numberFormatter.format(state.player.totalCompleted)} cleared`;
    document.title = `LV ${snapshot.level} · Questbound`;
  }

  function getLevelSnapshot(totalXp) {
    let level = 1;
    let currentXp = Math.max(0, totalXp);
    let requiredXp = xpRequiredForLevel(level);

    while (currentXp >= requiredXp && level < 999) {
      currentXp -= requiredXp;
      level += 1;
      requiredXp = xpRequiredForLevel(level);
    }

    return { level, currentXp, requiredXp };
  }

  function xpRequiredForLevel(level) {
    return Math.min(1_000, 100 + (level - 1) * 50);
  }

  function getRank(level) {
    return RANKS.reduce(
      (currentRank, rank) => (level >= rank.minimumLevel ? rank.name : currentRank),
      RANKS[0].name,
    );
  }

  function renderQuestFilters() {
    document.querySelectorAll(".quest-filter").forEach((button) => {
      const isActive = button.dataset.filter === questFilter;
      button.classList.toggle("is-active", isActive);
      button.setAttribute("aria-pressed", String(isActive));
    });
  }

  function renderQuests() {
    const activeCount = state.quests.filter((quest) => !quest.completedAt).length;
    refs.activeQuestCount.textContent = numberFormatter.format(activeCount);
    refs.activeQuestCount.setAttribute("aria-label", `${activeCount} active ${activeCount === 1 ? "quest" : "quests"}`);

    const visibleQuests = state.quests
      .filter((quest) => {
        if (questFilter === "active") return !quest.completedAt;
        if (questFilter === "completed") return Boolean(quest.completedAt);
        return true;
      })
      .sort((first, second) => {
        if (questFilter === "all" && Boolean(first.completedAt) !== Boolean(second.completedAt)) {
          return first.completedAt ? 1 : -1;
        }

        const firstDate = first.completedAt || first.createdAt;
        const secondDate = second.completedAt || second.createdAt;
        return Date.parse(secondDate) - Date.parse(firstDate);
      });

    refs.questList.replaceChildren(...visibleQuests.map(createQuestCard));
    refs.questEmptyState.classList.toggle("hidden", visibleQuests.length > 0);

    if (questFilter === "completed") {
      refs.questEmptyTitle.textContent = "No cleared quests yet";
      refs.questEmptyCopy.textContent = "Complete any active quest and your victory will be archived here.";
    } else if (questFilter === "all") {
      refs.questEmptyTitle.textContent = "Your log is empty";
      refs.questEmptyCopy.textContent = "Add one small, concrete quest above. “Open the document” counts.";
    } else {
      refs.questEmptyTitle.textContent = "Your active log is clear";
      refs.questEmptyCopy.textContent = "Add one small, concrete quest above. “Open the document” counts.";
    }
  }

  function createQuestCard(quest) {
    const difficulty = DIFFICULTIES[quest.difficulty];
    const card = createElement("article", {
      className: `quest-card quest-card--${quest.difficulty}${quest.completedAt ? " quest-card--completed" : ""}`,
    });
    const content = createElement("div", { className: "quest-card__content" });
    const eyebrow = createElement("div", { className: "quest-card__eyebrow" });
    const badge = createElement("span", {
      className: "difficulty-badge",
      text: difficulty.label,
    });
    const date = createElement("span", {
      className: "quest-card__date",
      text: quest.completedAt ? `Cleared ${formatCalendarDate(quest.completedAt)}` : `Added ${formatCalendarDate(quest.createdAt)}`,
    });
    eyebrow.append(badge, date);

    const title = createElement("h3", { className: "quest-card__title", text: quest.title });
    const rewardText = quest.completedAt
      ? `Earned ${numberFormatter.format(quest.xpEarned)} XP · ${numberFormatter.format(quest.goldEarned)} Gold${quest.multiplier > 1 ? ` · ×${quest.multiplier.toFixed(1)}` : ""}`
      : `${numberFormatter.format(difficulty.xp)} base XP · ${numberFormatter.format(difficulty.gold)} Gold`;
    const reward = createElement("p", { className: "quest-card__reward", text: rewardText });
    content.append(eyebrow, title, reward);

    const actions = createElement("div", { className: "quest-card__actions" });

    if (quest.completedAt) {
      const cleared = createElement("span", { className: "cleared-badge" });
      cleared.innerHTML = ICONS.check;
      cleared.append(document.createTextNode(" Cleared"));
      actions.append(cleared);
    } else {
      const completeButton = createElement("button", {
        className: "quest-complete-button",
        attributes: {
          type: "button",
          "data-action": "complete",
          "data-id": quest.id,
          "aria-label": `Complete ${quest.title} for ${difficulty.xp} base experience`,
        },
      });
      completeButton.innerHTML = ICONS.check;
      completeButton.append(document.createTextNode(` Clear +${difficulty.xp} XP`));
      actions.append(completeButton);
    }

    const removeButton = createElement("button", {
      className: "quest-remove-button",
      attributes: {
        type: "button",
        "data-action": "delete",
        "data-id": quest.id,
        "aria-label": `Remove quest: ${quest.title}`,
        title: "Remove quest",
      },
    });
    removeButton.innerHTML = ICONS.trash;
    actions.append(removeButton);
    card.append(content, actions);
    return card;
  }

  function renderRewards() {
    refs.rewardList.replaceChildren(...state.rewards.map(createRewardCard));
    refs.rewardEmptyState.classList.toggle("hidden", state.rewards.length > 0);
  }

  function createRewardCard(reward) {
    const card = createElement("article", { className: "reward-card" });
    const content = createElement("div");
    const name = createElement("h3", { className: "reward-card__name", text: reward.name });
    const redemptionLabel = reward.redeemedCount
      ? ` · claimed ${numberFormatter.format(reward.redeemedCount)}×`
      : "";
    const meta = createElement("p", {
      className: "reward-card__meta",
      text: `${numberFormatter.format(reward.cost)} Gold${redemptionLabel}`,
    });
    content.append(name, meta);

    const actions = createElement("div", { className: "reward-card__actions" });
    const canAfford = state.player.gold >= reward.cost;
    const claimButton = createElement("button", {
      className: "reward-buy-button",
      text: canAfford ? `Claim · ${numberFormatter.format(reward.cost)}` : `Need ${numberFormatter.format(reward.cost)}`,
      attributes: {
        type: "button",
        "data-action": "redeem",
        "data-id": reward.id,
        "aria-label": `${canAfford ? "Claim" : "Cannot afford"} ${reward.name} for ${reward.cost} gold`,
      },
    });
    claimButton.disabled = !canAfford;

    const removeButton = createElement("button", {
      className: "reward-remove-button",
      attributes: {
        type: "button",
        "data-action": "delete",
        "data-id": reward.id,
        "aria-label": `Remove reward: ${reward.name}`,
        title: "Remove reward",
      },
    });
    removeButton.innerHTML = ICONS.trash;

    actions.append(claimButton, removeButton);
    card.append(content, actions);
    return card;
  }

  function renderActivity() {
    const recentActivity = state.activity.slice(0, 5);
    refs.activityList.replaceChildren(...recentActivity.map(createActivityItem));
    refs.activityEmpty.classList.toggle("hidden", recentActivity.length > 0);
  }

  function createActivityItem(item) {
    const row = createElement("li", { className: "activity-item" });
    const dot = createElement("span", {
      className: `activity-item__dot${item.type === "reward" ? " activity-item__dot--reward" : ""}`,
      attributes: { "aria-hidden": "true" },
    });
    const content = createElement("div", { className: "activity-item__content" });
    const message = createElement("p", { className: "activity-item__message", text: item.message });
    const detail = createElement("p", { className: "activity-item__detail", text: item.detail });
    const timestamp = createElement("time", {
      className: "activity-item__time",
      text: formatActivityTime(item.timestamp),
      attributes: { datetime: item.timestamp },
    });
    content.append(message, detail);
    row.append(dot, content, timestamp);
    return row;
  }

  function renderSoundToggle() {
    const enabled = state.settings.soundEnabled;
    refs.soundToggle.setAttribute("aria-pressed", String(enabled));
    refs.soundToggle.setAttribute("aria-label", enabled ? "Turn sound off" : "Turn sound on");
    refs.soundOnIcon.classList.toggle("hidden", !enabled);
    refs.soundOffIcon.classList.toggle("hidden", enabled);
  }

  function createElement(tagName, options = {}) {
    const element = document.createElement(tagName);
    if (options.className) element.className = options.className;
    if (Object.hasOwn(options, "text")) element.textContent = options.text;
    if (options.attributes) {
      Object.entries(options.attributes).forEach(([name, value]) => {
        element.setAttribute(name, String(value));
      });
    }
    return element;
  }

  function openConfirm({ title, copy, confirmLabel, tone, onConfirm }) {
    pendingConfirmAction = onConfirm;
    refs.confirmTitle.textContent = title;
    refs.confirmCopy.textContent = copy;
    refs.confirmAction.textContent = confirmLabel;
    refs.confirmAction.className =
      tone === "gold"
        ? "reward-buy-button justify-center"
        : tone === "danger"
          ? "danger-button justify-center"
          : "primary-button justify-center";
    refs.confirmDialog.returnValue = "";
    refs.confirmDialog.showModal();
  }

  function showToast(title, copy, type = "default") {
    const toast = createElement("div", {
      className: `toast${type !== "default" ? ` toast--${type}` : ""}`,
      attributes: { role: type === "error" ? "alert" : "status" },
    });
    const icon = createElement("span", {
      className: "toast__icon",
      text: type === "success" ? "✓" : type === "gold" ? "◆" : type === "error" ? "!" : "✦",
      attributes: { "aria-hidden": "true" },
    });
    const content = createElement("div");
    const heading = createElement("p", { className: "toast__title", text: title });
    const description = createElement("p", { className: "toast__copy", text: copy });
    content.append(heading, description);
    toast.append(icon, content);
    refs.toastRegion.append(toast);

    while (refs.toastRegion.children.length > 3) {
      refs.toastRegion.firstElementChild.remove();
    }

    window.setTimeout(() => {
      if (!toast.isConnected) return;
      toast.classList.add("is-leaving");
      window.setTimeout(() => toast.remove(), 220);
    }, 3_800);
  }

  function announce(message) {
    refs.announcer.textContent = "";
    window.setTimeout(() => {
      refs.announcer.textContent = message;
    }, 40);
  }

  function createConfetti(originRect, theme = "quest", pieceCount = 24) {
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const colors =
      theme === "gold"
        ? ["#f3c969", "#ffe09a", "#9b8cff", "#ffffff"]
        : ["#68e0b4", "#9b8cff", "#f3c969", "#75b7ff", "#ffffff"];
    const originX = originRect ? originRect.left + originRect.width / 2 : window.innerWidth / 2;
    const originY = originRect ? originRect.top + originRect.height / 2 : window.innerHeight / 2;

    for (let index = 0; index < pieceCount; index += 1) {
      const piece = createElement("span", { className: "confetti-piece" });
      const angle = (Math.PI * 2 * index) / pieceCount + (Math.random() - 0.5) * 0.45;
      const distance = 55 + Math.random() * 105;
      const x = Math.cos(angle) * distance;
      const y = Math.sin(angle) * distance + 38;

      piece.style.left = `${originX}px`;
      piece.style.top = `${originY}px`;
      piece.style.setProperty("--x", `${x}px`);
      piece.style.setProperty("--y", `${y}px`);
      piece.style.setProperty("--rotation", `${Math.round(Math.random() * 540 - 270)}deg`);
      piece.style.setProperty("--delay", `${Math.round(Math.random() * 65)}ms`);
      piece.style.setProperty("--piece-color", colors[index % colors.length]);
      if (index % 3 === 0) piece.style.borderRadius = "50%";
      refs.confettiLayer.append(piece);
      window.setTimeout(() => piece.remove(), 1_150);
    }
  }

  function playSuccessSound(isLevelUp) {
    if (isLevelUp) {
      playNotes([
        [523.25, 0, 0.09],
        [659.25, 0.1, 0.09],
        [783.99, 0.2, 0.11],
        [1046.5, 0.33, 0.16],
      ]);
      return;
    }

    playNotes([
      [523.25, 0, 0.07],
      [659.25, 0.075, 0.07],
      [783.99, 0.15, 0.1],
    ]);
  }

  function playRewardSound() {
    playNotes([
      [783.99, 0, 0.06],
      [987.77, 0.08, 0.06],
      [1318.51, 0.16, 0.11],
    ]);
  }

  function playNotes(notes) {
    if (!state.settings.soundEnabled) return;

    try {
      const AudioContextClass = window.AudioContext || window.webkitAudioContext;
      if (!AudioContextClass) return;
      audioContext ||= new AudioContextClass();
      if (audioContext.state === "suspended") audioContext.resume();

      const startTime = audioContext.currentTime + 0.01;
      notes.forEach(([frequency, offset, duration]) => {
        const oscillator = audioContext.createOscillator();
        const gain = audioContext.createGain();
        oscillator.type = "square";
        oscillator.frequency.setValueAtTime(frequency, startTime + offset);
        gain.gain.setValueAtTime(0.0001, startTime + offset);
        gain.gain.exponentialRampToValueAtTime(0.025, startTime + offset + 0.012);
        gain.gain.exponentialRampToValueAtTime(0.0001, startTime + offset + duration);
        oscillator.connect(gain);
        gain.connect(audioContext.destination);
        oscillator.start(startTime + offset);
        oscillator.stop(startTime + offset + duration + 0.02);
      });
    } catch (error) {
      // Audio is a progressive enhancement; gameplay never depends on it.
    }
  }

  function toDateKey(date) {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, "0");
    const day = String(date.getDate()).padStart(2, "0");
    return `${year}-${month}-${day}`;
  }

  function dateKeyToUtc(dateKey) {
    const [year, month, day] = dateKey.split("-").map(Number);
    return Date.UTC(year, month - 1, day);
  }

  function daysBetween(earlierDateKey, laterDateKey) {
    return Math.round((dateKeyToUtc(laterDateKey) - dateKeyToUtc(earlierDateKey)) / 86_400_000);
  }

  function offsetDateKey(dateKey, offsetInDays) {
    const date = new Date(dateKeyToUtc(dateKey));
    date.setUTCDate(date.getUTCDate() + offsetInDays);
    return `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, "0")}-${String(date.getUTCDate()).padStart(2, "0")}`;
  }

  function formatCalendarDate(timestamp) {
    const date = new Date(timestamp);
    const dateKey = toDateKey(date);
    const today = toDateKey(new Date());
    const difference = daysBetween(dateKey, today);
    if (difference === 0) return "today";
    if (difference === 1) return "yesterday";
    return shortDateFormatter.format(date);
  }

  function formatActivityTime(timestamp) {
    const date = new Date(timestamp);
    const dateKey = toDateKey(date);
    const today = toDateKey(new Date());
    const difference = daysBetween(dateKey, today);
    if (difference === 0) return timeFormatter.format(date);
    if (difference === 1) return "Yesterday";
    return shortDateFormatter.format(date);
  }
})();
