#!/usr/bin/env node
// Regenerate the timeprice site screenshot used in the README.
//
// Boots a loopback HTTP server over site/, drives playwright's bundled
// Chromium against it, waits for the Ruby/wasm VM to finish warming up
// (so the hero shows the live computation, not "Warming up Ruby VM…"),
// then saves a PNG. The bundled Chromium pulls @ruby/wasm-wasi from
// jsdelivr — internet access is required.
//
// Usage:
//   node site/bin/screenshot.mjs                              # dark mode -> docs/img/calculator.png
//   node site/bin/screenshot.mjs --theme=light                # light mode, same path
//   node site/bin/screenshot.mjs --out=/tmp/x.png              # custom output
//   node site/bin/screenshot.mjs --theme=light --out=docs/img/calculator-light.png
//
// Or via npm: `npm --prefix site run screenshot`.

import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { existsSync } from "node:fs";
import { extname, join, resolve, dirname, normalize, sep } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const SITE_ROOT = resolve(__dirname, "..");
const REPO_ROOT = resolve(SITE_ROOT, "..");
const DEFAULT_OUT = join(REPO_ROOT, "docs/img/calculator.png");
const PLAYWRIGHT = resolve(SITE_ROOT, "node_modules/playwright/index.js");

function parseArgs(argv) {
  const opts = { theme: "dark", out: DEFAULT_OUT, port: 0 };
  for (const arg of argv.slice(2)) {
    const m = arg.match(/^--([^=]+)(?:=(.*))?$/);
    if (!m) continue;
    const [, k, v] = m;
    if (k === "theme") opts.theme = v;
    else if (k === "out") opts.out = resolve(v);
    else if (k === "port") opts.port = Number(v);
  }
  if (!["light", "dark"].includes(opts.theme)) {
    throw new Error(`--theme must be light|dark (got ${opts.theme})`);
  }
  return opts;
}

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".mjs": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".svg": "image/svg+xml",
  ".png": "image/png",
  ".wasm": "application/wasm",
  ".bin": "application/octet-stream",
};

function startServer(root, port) {
  const server = createServer(async (req, res) => {
    try {
      const urlPath = decodeURIComponent(req.url.split("?")[0]);
      // Strip leading slash and normalise; reject paths that escape root.
      const rel = normalize(urlPath.replace(/^\/+/, ""));
      if (rel.startsWith("..") || rel.split(sep).includes("..")) {
        res.writeHead(403).end("forbidden");
        return;
      }
      let file = join(root, rel || "index.html");
      if ((await stat(file).catch(() => null))?.isDirectory()) {
        file = join(file, "index.html");
      }
      if (!existsSync(file)) {
        res.writeHead(404).end("not found");
        return;
      }
      const body = await readFile(file);
      res.writeHead(200, { "Content-Type": MIME[extname(file)] ?? "application/octet-stream" });
      res.end(body);
    } catch (err) {
      res.writeHead(500).end(String(err));
    }
  });
  return new Promise((resolveListen, reject) => {
    server.once("error", reject);
    server.listen(port, "127.0.0.1", () => {
      const { port: actualPort } = server.address();
      resolveListen({ server, port: actualPort });
    });
  });
}

async function main() {
  const opts = parseArgs(process.argv);

  if (!existsSync(PLAYWRIGHT)) {
    console.error(`playwright not installed at ${PLAYWRIGHT}`);
    console.error("Run `npm --prefix site install` first.");
    process.exit(2);
  }
  const { chromium } = await import(PLAYWRIGHT).then((m) => m.default ?? m);

  const { server, port } = await startServer(SITE_ROOT, opts.port);
  const url = `http://127.0.0.1:${port}/index.html`;
  console.error(`serving ${SITE_ROOT} at ${url}`);

  const browser = await chromium.launch();
  try {
    const ctx = await browser.newContext({
      viewport: { width: 1280, height: 900 },
      deviceScaleFactor: 2,
      colorScheme: opts.theme,
    });
    const page = await ctx.newPage();
    // Seed localStorage so the inline head theme script picks the right
    // mode before first paint (avoids a light-mode flash).
    await page.addInitScript((theme) => {
      try { localStorage.setItem("theme", theme); } catch (_) {}
    }, opts.theme);

    page.on("pageerror", (e) => console.error("[pageerror]", e.message));
    page.on("requestfailed", (r) =>
      console.error("[reqfail]", r.url(), r.failure()?.errorText),
    );

    await page.goto(url, { waitUntil: "networkidle" });
    // Wait for the Ruby VM warm-up text to flip to a real computed result.
    await page.waitForFunction(
      () => {
        const el = document.querySelector("#calc-detail");
        return el && !/Warming up/i.test(el.textContent);
      },
      { timeout: 60000 },
    );
    // Let fonts and the range hint settle.
    await page.waitForTimeout(500);
    await page.screenshot({ path: opts.out, fullPage: false });
    console.error(`wrote ${opts.out}`);
  } finally {
    await browser.close();
    server.close();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
