import { describe, it, expect, beforeEach } from "vitest";
import { renderChart, mapPoints } from "../src/chart.js";

describe("renderChart", () => {
  beforeEach(() => {
    document.body.innerHTML = `<svg id="result-chart" viewBox="0 0 600 80"></svg>`;
  });

  it("draws an emerald polyline for measured-only series", () => {
    const series = [
      { date: "2010-01", amount: 1.0e6, measured: true },
      { date: "2015-01", amount: 1.5e6, measured: true },
      { date: "2020-01", amount: 2.0e6, measured: true },
    ];
    renderChart(series);
    const svg = document.getElementById("result-chart");
    const polyline = svg.querySelector("polyline.measured");
    expect(polyline).not.toBeNull();
    expect(polyline.getAttribute("points").split(" ").length).toBe(3);
    expect(svg.querySelector("polyline.forecast")).toBeNull();
    expect(svg.querySelector(".forecast-fan")).toBeNull();
  });

  it("draws a striped fan and hand-off line when series contains forecast points", () => {
    const series = [
      { date: "2010-01", amount: 1.0e6, measured: true },
      { date: "2025-01", amount: 3.0e6, measured: true },
      { date: "2026-01", amount: 3.2e6, low: 3.1e6, high: 3.3e6, measured: false },
      { date: "2030-01", amount: 4.5e6, low: 4.2e6, high: 4.8e6, measured: false },
    ];
    renderChart(series);
    const svg = document.getElementById("result-chart");
    expect(svg.querySelector("polyline.measured")).not.toBeNull();
    expect(svg.querySelector("polyline.forecast")).not.toBeNull();
    expect(svg.querySelector(".forecast-fan")).not.toBeNull();
    expect(svg.querySelector(".measured-end")).not.toBeNull();
  });

  it("renders empty when series has 0 or 1 point (no chart)", () => {
    const svg = document.getElementById("result-chart");
    renderChart([]);
    expect(svg.children.length).toBe(0);
    renderChart([{ date: "2020-01", amount: 100, measured: true }]);
    expect(svg.children.length).toBe(0);
  });

  it("re-renders cleanly when called twice", () => {
    const series = [
      { date: "2010-01", amount: 1, measured: true },
      { date: "2020-01", amount: 2, measured: true },
    ];
    renderChart(series);
    renderChart(series);
    const svg = document.getElementById("result-chart");
    expect(svg.querySelectorAll("polyline.measured").length).toBe(1);
  });
});

describe("mapPoints", () => {
  it("returns empty for < 2 points", () => {
    expect(mapPoints([])).toEqual([]);
    expect(mapPoints([{ date: "2020-01", amount: 1, measured: true }])).toEqual([]);
  });

  it("maps endpoints to the inset viewBox bounds", () => {
    const pts = mapPoints([
      { date: "2010-01", amount: 100, measured: true },
      { date: "2020-01", amount: 200, measured: true },
    ]);
    expect(pts[0].x).toBeLessThan(pts[1].x);
    // Larger amount sits higher in SVG coordinates (smaller y).
    expect(pts[1].y).toBeLessThan(pts[0].y);
  });
});
