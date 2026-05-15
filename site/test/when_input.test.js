import { describe, it, expect, beforeEach } from "vitest";
import { bindWhenGroup, assemble, split, grainOf } from "../src/when_input.js";

// Drop in the side="from" widget DOM plus a hidden mirror. Mirrors what
// site/index.html ships.
function seedDom(side = "from", initialHidden = "") {
  document.body.innerHTML = `
    <input id="${side}-year" type="text" maxlength="4">
    <input id="${side}-month" type="text" maxlength="2">
    <input id="${side}-day" type="text" maxlength="2" disabled>
    <span id="${side}-grain"></span>
    <input id="${side}-when" type="hidden" value="${initialHidden}">
  `;
}

function $(id) { return document.getElementById(id); }

// Synthetic keystroke that lands a character in an input. JSDOM doesn't
// simulate native keystrokes — we set .value directly then dispatch input,
// matching the path the widget's listeners exercise.
function type(el, value) {
  el.value = value;
  el.dispatchEvent(new Event("input", { bubbles: true }));
}

function blur(el) {
  el.dispatchEvent(new Event("blur", { bubbles: true }));
}

function arrow(el, dir) {
  const ev = new window.KeyboardEvent("keydown", { key: dir > 0 ? "ArrowUp" : "ArrowDown", bubbles: true, cancelable: true });
  el.dispatchEvent(ev);
}

describe("pure helpers", () => {
  it("assemble: year only", () => {
    expect(assemble("2008", "", "")).toBe("2008");
  });
  it("assemble: year+month", () => {
    expect(assemble("2008", "03", "")).toBe("2008-03");
  });
  it("assemble: year+month+day", () => {
    expect(assemble("2008", "03", "14")).toBe("2008-03-14");
  });
  it("assemble: empty year → empty string", () => {
    expect(assemble("", "03", "14")).toBe("");
  });
  it("assemble: year+day without month collapses to year (day is meaningless without month)", () => {
    expect(assemble("2008", "", "14")).toBe("2008");
  });

  it("split: handles all three precisions", () => {
    expect(split("2008")).toEqual({ year: "2008", month: "", day: "" });
    expect(split("2008-03")).toEqual({ year: "2008", month: "03", day: "" });
    expect(split("2008-03-14")).toEqual({ year: "2008", month: "03", day: "14" });
  });
  it("split: empty / off-shape returns blanks", () => {
    expect(split("")).toEqual({ year: "", month: "", day: "" });
    expect(split("garbage")).toEqual({ year: "", month: "", day: "" });
  });

  it("grainOf reflects fill level", () => {
    expect(grainOf("", "", "")).toBe("");
    expect(grainOf("2008", "", "")).toBe("annual");
    expect(grainOf("2008", "03", "")).toBe("monthly");
    expect(grainOf("2008", "03", "14")).toBe("daily");
  });
});

describe("bindWhenGroup — serialization to hidden mirror", () => {
  beforeEach(() => seedDom("from"));

  it("empty year → empty hidden value", () => {
    bindWhenGroup("from");
    type($("from-year"), "");
    expect($("from-when").value).toBe("");
  });

  it("year only → YYYY + annual grain", () => {
    bindWhenGroup("from");
    type($("from-year"), "2008");
    expect($("from-when").value).toBe("2008");
    expect($("from-grain").textContent).toBe("annual");
  });

  it("year + month → YYYY-MM + monthly grain", () => {
    bindWhenGroup("from");
    type($("from-year"), "2008");
    type($("from-month"), "03");
    expect($("from-when").value).toBe("2008-03");
    expect($("from-grain").textContent).toBe("monthly");
  });

  it("year + month + day → YYYY-MM-DD + daily grain", () => {
    bindWhenGroup("from");
    type($("from-year"), "2008");
    type($("from-month"), "03");
    type($("from-day"), "14");
    expect($("from-when").value).toBe("2008-03-14");
    expect($("from-grain").textContent).toBe("daily");
  });
});

describe("bindWhenGroup — Day depends on Month", () => {
  beforeEach(() => seedDom("from"));

  it("Day is disabled when Month is empty", () => {
    bindWhenGroup("from");
    type($("from-year"), "2008");
    expect($("from-day").disabled).toBe(true);
  });

  it("Day enables once Month is filled", () => {
    bindWhenGroup("from");
    type($("from-year"), "2008");
    type($("from-month"), "03");
    expect($("from-day").disabled).toBe(false);
  });

  it("clearing Month clears Day and re-disables it", () => {
    bindWhenGroup("from");
    type($("from-year"), "2008");
    type($("from-month"), "03");
    type($("from-day"), "14");
    expect($("from-when").value).toBe("2008-03-14");
    // User wipes month.
    type($("from-month"), "");
    expect($("from-day").value).toBe("");
    expect($("from-day").disabled).toBe(true);
    expect($("from-when").value).toBe("2008");
    expect($("from-grain").textContent).toBe("annual");
  });
});

describe("bindWhenGroup — blur padding", () => {
  beforeEach(() => seedDom("from"));

  it("Month: single digit pads on blur (3 → 03)", () => {
    bindWhenGroup("from");
    type($("from-year"), "2008");
    type($("from-month"), "3");
    blur($("from-month"));
    expect($("from-month").value).toBe("03");
    expect($("from-when").value).toBe("2008-03");
  });

  it("Day: single digit pads on blur (5 → 05)", () => {
    bindWhenGroup("from");
    type($("from-year"), "2008");
    type($("from-month"), "03");
    type($("from-day"), "5");
    blur($("from-day"));
    expect($("from-day").value).toBe("05");
    expect($("from-when").value).toBe("2008-03-05");
  });

  it("Month: out-of-range value clamps on blur", () => {
    bindWhenGroup("from");
    type($("from-year"), "2008");
    type($("from-month"), "99");
    // Already 2 digits → input handler clamps to 12.
    expect($("from-month").value).toBe("12");
  });
});

describe("bindWhenGroup — arrow keys step values", () => {
  beforeEach(() => seedDom("from"));

  it("Year: ArrowUp adds 1, ArrowDown subtracts 1", () => {
    bindWhenGroup("from");
    type($("from-year"), "2008");
    arrow($("from-year"), 1);
    expect($("from-year").value).toBe("2009");
    arrow($("from-year"), -1);
    expect($("from-year").value).toBe("2008");
  });

  it("Month: ArrowUp clamps at 12", () => {
    bindWhenGroup("from");
    type($("from-year"), "2008");
    type($("from-month"), "12");
    arrow($("from-month"), 1);
    expect($("from-month").value).toBe("12");
  });

  it("Day: ArrowUp clamps at 31", () => {
    bindWhenGroup("from");
    type($("from-year"), "2008");
    type($("from-month"), "03");
    type($("from-day"), "31");
    arrow($("from-day"), 1);
    expect($("from-day").value).toBe("31");
  });
});

describe("bindWhenGroup — auto-advance focus", () => {
  beforeEach(() => seedDom("from"));

  it("4-digit year moves focus to month", () => {
    bindWhenGroup("from");
    $("from-year").focus();
    type($("from-year"), "2008");
    expect(document.activeElement).toBe($("from-month"));
  });

  it("2-digit month moves focus to day (once day is enabled)", () => {
    bindWhenGroup("from");
    type($("from-year"), "2008");
    $("from-month").focus();
    type($("from-month"), "03");
    expect(document.activeElement).toBe($("from-day"));
  });
});

describe("bindWhenGroup — external set()", () => {
  beforeEach(() => seedDom("from"));

  it("set('2008-03-14') populates all three fields and enables day", () => {
    const widget = bindWhenGroup("from");
    widget.set("2008-03-14", { silent: true });
    expect($("from-year").value).toBe("2008");
    expect($("from-month").value).toBe("03");
    expect($("from-day").value).toBe("14");
    expect($("from-day").disabled).toBe(false);
    expect($("from-grain").textContent).toBe("daily");
  });

  it("set('2008') clears month/day and disables day", () => {
    const widget = bindWhenGroup("from");
    widget.set("2008-03-14", { silent: true });
    widget.set("2008", { silent: true });
    expect($("from-year").value).toBe("2008");
    expect($("from-month").value).toBe("");
    expect($("from-day").value).toBe("");
    expect($("from-day").disabled).toBe(true);
    expect($("from-grain").textContent).toBe("annual");
  });

  it("silent set still updates the hidden mirror but does not dispatch input", () => {
    bindWhenGroup("from");
    let fired = false;
    $("from-when").addEventListener("input", () => { fired = true; });
    const widget2 = bindWhenGroup("from");
    widget2.set("2010-06", { silent: true });
    expect($("from-when").value).toBe("2010-06");
    expect(fired).toBe(false);
  });
});

describe("bindWhenGroup — paste distribution", () => {
  beforeEach(() => seedDom("from"));

  it("typing/pasting 20080314 into Year distributes to Y/M/D", () => {
    bindWhenGroup("from");
    type($("from-year"), "20080314");
    expect($("from-year").value).toBe("2008");
    expect($("from-month").value).toBe("03");
    expect($("from-day").value).toBe("14");
    expect($("from-when").value).toBe("2008-03-14");
  });
});

describe("bindWhenGroup — initial state from hidden mirror", () => {
  it("populates Y/M/D from a pre-seeded hidden #X-when", () => {
    seedDom("to", "2024-12-25");
    bindWhenGroup("to");
    expect($("to-year").value).toBe("2024");
    expect($("to-month").value).toBe("12");
    expect($("to-day").value).toBe("25");
    expect($("to-day").disabled).toBe(false);
    expect($("to-grain").textContent).toBe("daily");
  });

  it("annual seed leaves day disabled", () => {
    seedDom("to", "2024");
    bindWhenGroup("to");
    expect($("to-year").value).toBe("2024");
    expect($("to-month").value).toBe("");
    expect($("to-day").disabled).toBe(true);
    expect($("to-grain").textContent).toBe("annual");
  });
});
