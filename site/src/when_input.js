// Three-field "When" widget — Year · Month · Day. Replaces the smart-date
// text input with progressive disclosure: Year is always visible, Month
// reveals when Year is set, Day reveals (enables) when Month is set.
//
// The Y/M/D inputs are the source of truth. After every edit we re-assemble
// the YYYY[-MM[-DD]] string into a hidden #X-when input and dispatch an
// `input` event so the existing compute pipeline (events.js → onInput) picks
// it up unchanged. metadata.js's CPI-window clamp also reads / writes that
// hidden field; we sync the Y/M/D fields back from it on any external write.

// Side = "from" | "to". One widget per side.

function clampInt(v, min, max) {
  if (!Number.isFinite(v)) return null;
  if (v < min) return min;
  if (v > max) return max;
  return v;
}

// Derive the grain label from which fields are filled. Day requires Month;
// Month requires Year. The widget enforces that, but we re-derive defensively
// so the badge stays in sync after any external set.
export function grainOf(year, month, day) {
  if (!year) return "";
  if (!month) return "annual";
  if (!day) return "monthly";
  return "daily";
}

// Assemble the YYYY[-MM[-DD]] string the gem expects. Empty year → empty.
// Trailing partial pieces (Y+D with no M) collapse to year-only — invariant
// enforced by the disable rule on Day, but defended here too.
export function assemble(year, month, day) {
  if (!year) return "";
  if (!month) return year;
  if (!day) return `${year}-${month}`;
  return `${year}-${month}-${day}`;
}

// Split a YYYY, YYYY-MM, or YYYY-MM-DD string into the three parts. Anything
// off-shape returns blanks — keeps applyPoint() / clampSeed() forgiving when
// the gem evolves.
export function split(iso) {
  if (!iso) return { year: "", month: "", day: "" };
  const m = iso.match(/^(\d{4})(?:-(\d{2}))?(?:-(\d{2}))?$/);
  if (!m) return { year: "", month: "", day: "" };
  return { year: m[1] || "", month: m[2] || "", day: m[3] || "" };
}

// Wire one Y/M/D group. Returns a `set(iso)` function callers (url.js,
// app.js, metadata.js) can use to push an assembled string back into the
// widget without re-implementing the split.
export function bindWhenGroup(side) {
  const yEl = document.getElementById(`${side}-year`);
  const mEl = document.getElementById(`${side}-month`);
  const dEl = document.getElementById(`${side}-day`);
  const hidden = document.getElementById(`${side}-when`);
  const grainEl = document.getElementById(`${side}-grain`);
  if (!yEl || !mEl || !dEl || !hidden) return { set: () => {} };

  function syncDayEnabled() {
    // Day is gated on Month. We don't gate Month on Year (lets the user fill
    // M before Y if they want — keystroke order shouldn't trap them), but Day
    // without Month is meaningless to the gem's date parser, so it stays gated.
    const monthFilled = mEl.value.trim() !== "";
    dEl.disabled = !monthFilled;
    if (!monthFilled && dEl.value) dEl.value = "";
  }

  function syncGrain() {
    if (!grainEl) return;
    grainEl.textContent = grainOf(yEl.value.trim(), mEl.value.trim(), dEl.value.trim());
  }

  // Push the assembled string into the hidden #X-when input and fire `input`
  // so events.js's onInput handler re-runs the compute pipeline. We don't
  // call compute() directly — keeps this module decoupled from the rest.
  function syncHidden() {
    const next = assemble(yEl.value.trim(), mEl.value.trim(), dEl.value.trim());
    if (hidden.value !== next) {
      hidden.value = next;
      hidden.dispatchEvent(new Event("input", { bubbles: true }));
    }
  }

  function syncAll() {
    syncDayEnabled();
    syncGrain();
    syncHidden();
  }

  // --- Year ---------------------------------------------------------------
  yEl.addEventListener("input", () => {
    // Strip non-digits, cap at 4. Paste of "2008-03-14" lands as "20080314"
    // here, then we redistribute below.
    let v = yEl.value.replace(/\D/g, "").slice(0, 8);
    // Paste / quick-type: if user dropped 6+ digits into Year, peel off the
    // extras into Month/Day. Avoids forcing them through tab-tab-tab.
    if (v.length >= 6) {
      const y = v.slice(0, 4);
      const m = v.slice(4, 6);
      const d = v.length >= 8 ? v.slice(6, 8) : "";
      yEl.value = y;
      mEl.value = m;
      if (d) dEl.value = d;
      syncAll();
      // Focus the trailing field for keyboard continuity.
      if (d) dEl.focus(); else mEl.focus();
      return;
    }
    yEl.value = v.slice(0, 4);
    if (yEl.value.length === 4) {
      mEl.focus();
    }
    syncAll();
  });
  yEl.addEventListener("blur", () => { syncAll(); });

  // --- Month --------------------------------------------------------------
  mEl.addEventListener("input", () => {
    let v = mEl.value.replace(/\D/g, "").slice(0, 2);
    mEl.value = v;
    if (v.length === 2) {
      // Clamp once they've committed to 2 digits — partial "1" mid-typing
      // shouldn't be clamped to "01" yet (they may be heading to "12").
      const n = clampInt(parseInt(v, 10), 1, 12);
      if (n !== null) mEl.value = String(n).padStart(2, "0");
      // Don't auto-focus Day until syncDayEnabled() has flipped its disabled
      // bit. syncAll() handles that, then we move focus.
      syncAll();
      if (!dEl.disabled) dEl.focus();
      return;
    }
    syncAll();
  });
  mEl.addEventListener("blur", () => {
    if (mEl.value) {
      const n = clampInt(parseInt(mEl.value, 10), 1, 12);
      mEl.value = n === null ? "" : String(n).padStart(2, "0");
    }
    syncAll();
  });
  mEl.addEventListener("keydown", (e) => {
    if (e.key === "Backspace" && mEl.value === "") {
      // Hop back to Year so the user can correct without grabbing the mouse.
      yEl.focus();
      e.preventDefault();
    }
  });

  // --- Day ----------------------------------------------------------------
  dEl.addEventListener("input", () => {
    let v = dEl.value.replace(/\D/g, "").slice(0, 2);
    dEl.value = v;
    if (v.length === 2) {
      const n = clampInt(parseInt(v, 10), 1, 31);
      if (n !== null) dEl.value = String(n).padStart(2, "0");
    }
    syncAll();
  });
  dEl.addEventListener("blur", () => {
    if (dEl.value) {
      const n = clampInt(parseInt(dEl.value, 10), 1, 31);
      dEl.value = n === null ? "" : String(n).padStart(2, "0");
    }
    syncAll();
  });
  dEl.addEventListener("keydown", (e) => {
    if (e.key === "Backspace" && dEl.value === "") {
      mEl.focus();
      e.preventDefault();
    }
  });

  // --- Arrow stepping on all three ---------------------------------------
  function bindArrows(el, { min, max, pad, wrap = false }) {
    el.addEventListener("keydown", (e) => {
      if (e.key !== "ArrowUp" && e.key !== "ArrowDown") return;
      const dir = e.key === "ArrowUp" ? 1 : -1;
      const current = parseInt(el.value, 10);
      let next;
      if (!Number.isFinite(current)) {
        next = dir > 0 ? min : max;
      } else {
        next = current + dir;
        if (wrap) {
          if (next < min) next = max;
          if (next > max) next = min;
        } else {
          next = clampInt(next, min, max);
        }
      }
      el.value = pad ? String(next).padStart(2, "0") : String(next);
      e.preventDefault();
      syncAll();
    });
  }
  bindArrows(yEl, { min: 1900, max: 9999, pad: false });
  bindArrows(mEl, { min: 1, max: 12, pad: true });
  bindArrows(dEl, { min: 1, max: 31, pad: true });

  // External setter — used by app.js seed, url.js applyPoint, metadata.js
  // clamp. Pushes through the same sync path so the badge + disabled state
  // + hidden mirror stay coherent. `silent` skips firing the input event on
  // the hidden mirror (used by seeding so we don't trigger a compute before
  // the VM is up).
  function set(iso, { silent = false } = {}) {
    const { year, month, day } = split(iso);
    yEl.value = year;
    mEl.value = month;
    dEl.value = day;
    syncDayEnabled();
    syncGrain();
    if (silent) {
      hidden.value = assemble(year, month, day);
    } else {
      syncHidden();
    }
  }

  // Initial paint from whatever the hidden input was seeded with (app.js
  // sets `2008-01-02` before we bind). Silent — caller drives the first
  // compute() through readForm().
  if (hidden.value) {
    const { year, month, day } = split(hidden.value);
    yEl.value = year;
    mEl.value = month;
    dEl.value = day;
  }
  syncDayEnabled();
  syncGrain();

  return { set };
}
