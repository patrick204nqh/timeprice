// Stores a compiled WebAssembly.Module in IndexedDB keyed by the build's
// content hash. Compiled modules are structured-cloneable, so the browser
// persists them in their post-compile form — second visit skips download,
// decompress, and compileStreaming entirely.

const DB_NAME = "timeprice";
const STORE = "wasm-modules";
const KEY = "compiled";

function openDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, 1);
    req.onupgradeneeded = () => req.result.createObjectStore(STORE);
    req.onsuccess = () => resolve(req.result);
    req.onerror = () => reject(req.error);
  });
}

function withStore(mode, fn) {
  return openDb().then((db) => new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, mode);
    const store = tx.objectStore(STORE);
    const result = fn(store);
    tx.oncomplete = () => resolve(result.value);
    tx.onerror = () => reject(tx.error);
    tx.onabort = () => reject(tx.error);
  }));
}

export async function loadCachedModule(sha) {
  try {
    const entry = await withStore("readonly", (store) => {
      const req = store.get(KEY);
      const result = { value: undefined };
      req.onsuccess = () => { result.value = req.result; };
      return result;
    });
    if (entry && entry.sha === sha && entry.module instanceof WebAssembly.Module) {
      return entry.module;
    }
    return null;
  } catch {
    return null;
  }
}

export async function saveCachedModule(sha, module) {
  try {
    await withStore("readwrite", (store) => {
      store.put({ sha, module }, KEY);
      return { value: undefined };
    });
  } catch {
    // Cache write failures are non-fatal — we'll just recompile next visit.
  }
}
