"""Optional calculator for the head-vs-tail cost estimate.

Prints a table for strategies A, B, C under the assumptions documented in the
activity README. Students may use it to cross-check their math.
"""
from __future__ import annotations

RPS = 1000              # req/s
SPANS_PER_TRACE = 10
SPAN_BYTES = 1500       # 1.5 KB
ERROR_RATE = 0.01
SLOW_RATE = 0.05        # p(latency > 500ms)
DECISION_WAIT = 10      # seconds
INGEST_USD_PER_GB = 0.10
STORAGE_USD_PER_GB_MO = 0.03
RETENTION_DAYS = 7
OVERHEAD = 1.5          # memory bloat factor


def cost(spans_per_s: float) -> tuple[float, float]:
    gb_day = spans_per_s * SPAN_BYTES * 86_400 / 1e9
    usd_ingest = gb_day * INGEST_USD_PER_GB
    usd_storage_mo = gb_day * RETENTION_DAYS * STORAGE_USD_PER_GB_MO
    usd_day = usd_ingest + usd_storage_mo / 30
    return gb_day, usd_day


def memory_mb() -> float:
    traces = RPS * DECISION_WAIT
    return traces * SPANS_PER_TRACE * SPAN_BYTES * OVERHEAD / 1e6


def main() -> int:
    base_spans = RPS * SPANS_PER_TRACE  # 10 000 spans/s with AlwaysOn

    # A: uniform head 10%
    a_frac = 0.10
    a_spans = base_spans * a_frac

    # B: errors(1%) + slow_no_err(~5%) + prob_10% of the remaining (~94%)
    # fractions over TRACES, not spans
    b_frac = ERROR_RATE + SLOW_RATE + 0.10 * (1 - ERROR_RATE - SLOW_RATE)
    b_spans = base_spans * b_frac

    # C: same as B but capped at 1500 spans/s
    c_spans = min(b_spans, 1500)
    c_frac = c_spans / base_spans

    mem = memory_mb()

    print(f"{'strategy':<10}{'frac':>10}{'spans/s':>12}{'GB/day':>10}{'$/day':>10}{'mem_MB':>10}")
    for name, frac, spans, needs_mem in [
        ("A head10", a_frac, a_spans, False),
        ("B tail",   b_frac, b_spans, True),
        ("C tail+cap", c_frac, c_spans, True),
    ]:
        gb, usd = cost(spans)
        mm = f"{mem:.0f}" if needs_mem else "-"
        print(f"{name:<10}{frac:>10.3f}{spans:>12.0f}{gb:>10.2f}{usd:>10.2f}{mm:>10}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
