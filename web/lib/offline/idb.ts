// A small key-value store in IndexedDB, for what the app keeps on the device
// to work offline. Every call fails quietly: without IndexedDB (private
// windows, old browsers) the app simply works online only.

const DB_NAME = "anchor-offline";
const STORE = "kv";

let opening: Promise<IDBDatabase> | null = null;

function open(): Promise<IDBDatabase> {
  opening ??= new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 1);
    request.onupgradeneeded = () => request.result.createObjectStore(STORE);
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
  return opening;
}

function run<T>(
  mode: IDBTransactionMode,
  action: (store: IDBObjectStore) => IDBRequest<T>,
): Promise<T | undefined> {
  if (typeof indexedDB === "undefined") return Promise.resolve(undefined);
  return open()
    .then(
      (db) =>
        new Promise<T>((resolve, reject) => {
          const request = action(
            db.transaction(STORE, mode).objectStore(STORE),
          );
          request.onsuccess = () => resolve(request.result);
          request.onerror = () => reject(request.error);
        }),
    )
    .catch(() => undefined);
}

export const idbGet = <T>(key: string) =>
  run<T>("readonly", (store) => store.get(key) as IDBRequest<T>);

export const idbSet = (key: string, value: unknown) =>
  run("readwrite", (store) => store.put(value, key));

export const idbDelete = (key: string) =>
  run("readwrite", (store) => store.delete(key));

export const idbClear = () => run("readwrite", (store) => store.clear());

export async function idbEntries<T>(): Promise<[string, T][]> {
  const keys = (await run("readonly", (store) => store.getAllKeys())) ?? [];
  const values =
    (await run<T[]>(
      "readonly",
      (store) => store.getAll() as IDBRequest<T[]>,
    )) ?? [];
  return keys.map((key, i) => [String(key), values[i]]);
}
