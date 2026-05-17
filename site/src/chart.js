// Tiny SVG renderer for the result-card "how did we get here" strip.
//
// Reads a series of `{ date: "YYYY-MM" | "YYYY-01", amount, measured, low?, high? }`
// objects and paints:
//   - a measured polyline (emerald) up to the last measured point,
//   - a forecast polyline (dashed emerald) past the last measured point,
//   - a striped fan polygon between `low` and `high` for the forecast tail,
//   - a thin vertical hairline at the measured/forecast hand-off.
//
// No JS dependencies. Pure DOM via the `#result-chart` <svg>.

const VIEW = { w: 600, h: 80, padL: 8, padR: 8, padT: 4, padB: 14 };

const SVG_NS = "http://www.w3.org/2000/svg";

function el(tag, attrs = {}) {
  const node = document.createElementNS(SVG_NS, tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v == null) continue;
    node.setAttribute(k, String(v));
  }
  return node;
}

// Map `(date, amount)` tuples to `(x, y)` in the SVG viewBox. Dates parse to
// fractional years so May 2026 lands between 2026-01 and 2027-01.
export function mapPoints(series) {
  if (!series || series.length < 2) return [];
  const years = series.map(toYear);
  const minX = Math.min(...years);
  const maxX = Math.max(...years);
  const lows = series.map((p) => (p.low != null ? p.low : p.amount));
  const highs = series.map((p) => (p.high != null ? p.high : p.amount));
  const minY = Math.min(...lows) * 0.95;
  const maxY = Math.max(...highs) * 1.05;
  const innerW = VIEW.w - VIEW.padL - VIEW.padR;
  const innerH = VIEW.h - VIEW.padT - VIEW.padB;
  const span = maxX === minX ? 1 : maxX - minX;
  const range = maxY === minY ? 1 : maxY - minY;
  return series.map((p, i) => {
    const x = VIEW.padL + ((years[i] - minX) / span) * innerW;
    const y = VIEW.padT + (1 - (p.amount - minY) / range) * innerH;
    const yLow = p.low != null
      ? VIEW.padT + (1 - (p.low - minY) / range) * innerH
      : y;
    const yHigh = p.high != null
      ? VIEW.padT + (1 - (p.high - minY) / range) * innerH
      : y;
    return { x, y, yLow, yHigh, measured: p.measured, year: years[i] };
  });
}

function toYear(p) {
  const [y, m] = p.date.split("-");
  const yi = Number(y);
  const mi = m ? Number(m) : 1;
  return yi + (mi - 1) / 12;
}

function pointsAttr(pts) {
  return pts.map((p) => `${p.x.toFixed(2)},${p.y.toFixed(2)}`).join(" ");
}

export function renderChart(series) {
  const svg = document.getElementById("result-chart");
  if (!svg) return;
  // Clear prior render.
  while (svg.firstChild) svg.removeChild(svg.firstChild);
  if (!series || series.length < 2) return;

  const pts = mapPoints(series);
  const measured = pts.filter((p) => p.measured);
  const forecast = pts.filter((p) => !p.measured);
  const handoffIdx = measured.length - 1;

  // Bridge point: chart should connect the last measured point to the first
  // forecast point so the polylines meet.
  const forecastChain = handoffIdx >= 0 && forecast.length > 0
    ? [measured[handoffIdx], ...forecast]
    : forecast;

  // Stripe pattern for the fan (forecast only).
  if (forecast.length > 0) {
    const defs = el("defs");
    const pattern = el("pattern", {
      id: "forecast-stripes",
      width: 6, height: 6, patternUnits: "userSpaceOnUse",
      patternTransform: "rotate(45)",
    });
    pattern.appendChild(el("line", {
      x1: 0, y1: 0, x2: 0, y2: 6, stroke: "currentColor",
      "stroke-width": 1, "stroke-opacity": 0.25,
    }));
    defs.appendChild(pattern);
    svg.appendChild(defs);

    // Fan polygon: high line forward, low line back.
    const fanPts = [
      ...forecastChain.map((p) => `${p.x.toFixed(2)},${p.yHigh.toFixed(2)}`),
      ...forecastChain.slice().reverse().map((p) => `${p.x.toFixed(2)},${p.yLow.toFixed(2)}`),
    ].join(" ");
    svg.appendChild(el("polygon", {
      class: "forecast-fan",
      points: fanPts,
      fill: "url(#forecast-stripes)",
      stroke: "none",
    }));
  }

  // Measured polyline.
  if (measured.length >= 2) {
    svg.appendChild(el("polyline", {
      class: "measured",
      points: pointsAttr(measured),
      fill: "none",
      stroke: "currentColor",
      "stroke-width": 1.5,
    }));
  }

  // Forecast polyline (dashed).
  if (forecastChain.length >= 2) {
    svg.appendChild(el("polyline", {
      class: "forecast",
      points: pointsAttr(forecastChain),
      fill: "none",
      stroke: "currentColor",
      "stroke-width": 1.5,
      "stroke-dasharray": "3 3",
      "stroke-opacity": 0.7,
    }));
  }

  // Vertical hand-off line at the last measured x.
  if (handoffIdx >= 0 && forecast.length > 0) {
    const hx = measured[handoffIdx].x;
    svg.appendChild(el("line", {
      class: "measured-end",
      x1: hx, x2: hx,
      y1: VIEW.padT, y2: VIEW.h - VIEW.padB,
      stroke: "currentColor",
      "stroke-width": 0.5,
      "stroke-opacity": 0.35,
      "stroke-dasharray": "2 2",
    }));
  }

  // Year tick labels every 5 years at the bottom edge.
  renderYearTicks(svg, pts);
}

function renderYearTicks(svg, pts) {
  if (pts.length < 2) return;
  const firstYear = Math.floor(pts[0].year);
  const lastYear  = Math.floor(pts[pts.length - 1].year);
  // Pick stride based on span: 5y default; bump to 10y for >40y spans.
  const stride = (lastYear - firstYear) > 40 ? 10 : 5;
  const startTick = Math.ceil(firstYear / stride) * stride;
  const innerW = VIEW.w - VIEW.padL - VIEW.padR;
  const span = pts[pts.length - 1].year - pts[0].year || 1;
  for (let y = startTick; y <= lastYear; y += stride) {
    const x = VIEW.padL + ((y - pts[0].year) / span) * innerW;
    const text = el("text", {
      class: "tick",
      x: x.toFixed(2),
      y: VIEW.h - 2,
      "text-anchor": "middle",
      "font-size": 9,
      fill: "currentColor",
      "fill-opacity": 0.55,
    });
    text.textContent = String(y);
    svg.appendChild(text);
  }
}
