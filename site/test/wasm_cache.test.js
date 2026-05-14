import { describe, it, expect, beforeEach } from "vitest";
import "fake-indexeddb/auto";
import { IDBFactory } from "fake-indexeddb";
import { loadCachedModule, saveCachedModule } from "../src/wasm_cache.js";

const MINIMAL_WASM = new Uint8Array([0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00]);

function freshModule() {
  return new WebAssembly.Module(MINIMAL_WASM);
}

describe("wasm_cache", () => {
  beforeEach(() => {
    globalThis.indexedDB = new IDBFactory();
  });

  it("returns null on empty store", async () => {
    expect(await loadCachedModule("sha-anything")).toBeNull();
  });

  it("round-trips a compiled module under a matching sha", async () => {
    const sha = "abc123";
    await saveCachedModule(sha, freshModule());
    const loaded = await loadCachedModule(sha);
    expect(loaded).toBeInstanceOf(WebAssembly.Module);
  });

  it("returns null when the stored sha does not match the requested sha", async () => {
    await saveCachedModule("old-sha", freshModule());
    expect(await loadCachedModule("new-sha")).toBeNull();
  });

  it("overwrites the prior entry on a fresh save (single-slot cache)", async () => {
    await saveCachedModule("v1", freshModule());
    await saveCachedModule("v2", freshModule());
    expect(await loadCachedModule("v1")).toBeNull();
    expect(await loadCachedModule("v2")).toBeInstanceOf(WebAssembly.Module);
  });

  it("swallows save errors without throwing", async () => {
    // Force a write failure by handing the cache a non-cloneable value.
    // The module field has to be structured-cloneable; a function isn't.
    await expect(saveCachedModule("bad", () => {})).resolves.toBeUndefined();
  });

  it("swallows load errors and returns null when indexedDB is broken", async () => {
    globalThis.indexedDB = {
      open() {
        const req = {};
        queueMicrotask(() => req.onerror && req.onerror({ target: { error: new Error("boom") } }));
        return req;
      },
    };
    expect(await loadCachedModule("sha")).toBeNull();
  });
});
