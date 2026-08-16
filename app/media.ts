const DATABASE_NAME = "questbound-media-v1";
const STORE_NAME = "media";
const TRACK_KEY = "background-track";

export type StoredTrack = {
  name: string;
  type: string;
  size: number;
  updatedAt: string;
  blob: Blob;
};

function openDatabase() {
  return new Promise<IDBDatabase>((resolve, reject) => {
    if (typeof window === "undefined" || !window.indexedDB) {
      reject(new Error("Private audio storage is unavailable in this browser."));
      return;
    }

    const request = window.indexedDB.open(DATABASE_NAME, 1);
    request.onupgradeneeded = () => {
      if (!request.result.objectStoreNames.contains(STORE_NAME)) request.result.createObjectStore(STORE_NAME);
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error ?? new Error("Could not open private audio storage."));
    request.onblocked = () => reject(new Error("Close other Questbound tabs and try again."));
  });
}

export async function readTrack() {
  const database = await openDatabase();
  return new Promise<StoredTrack | null>((resolve, reject) => {
    const request = database.transaction(STORE_NAME, "readonly").objectStore(STORE_NAME).get(TRACK_KEY);
    request.onsuccess = () => {
      database.close();
      const value = request.result as StoredTrack | undefined;
      resolve(value?.blob instanceof Blob ? value : null);
    };
    request.onerror = () => {
      database.close();
      reject(request.error ?? new Error("Could not read the saved track."));
    };
  });
}

export async function writeTrack(track: StoredTrack) {
  const database = await openDatabase();
  return new Promise<void>((resolve, reject) => {
    const transaction = database.transaction(STORE_NAME, "readwrite");
    transaction.objectStore(STORE_NAME).put(track, TRACK_KEY);
    transaction.oncomplete = () => {
      database.close();
      resolve();
    };
    transaction.onerror = () => {
      database.close();
      reject(transaction.error ?? new Error("Could not save that audio file."));
    };
    transaction.onabort = () => {
      database.close();
      reject(transaction.error ?? new Error("Browser storage is full."));
    };
  });
}

export async function deleteTrack() {
  const database = await openDatabase();
  return new Promise<void>((resolve, reject) => {
    const transaction = database.transaction(STORE_NAME, "readwrite");
    transaction.objectStore(STORE_NAME).delete(TRACK_KEY);
    transaction.oncomplete = () => {
      database.close();
      resolve();
    };
    transaction.onerror = () => {
      database.close();
      reject(transaction.error ?? new Error("Could not remove the saved track."));
    };
  });
}
