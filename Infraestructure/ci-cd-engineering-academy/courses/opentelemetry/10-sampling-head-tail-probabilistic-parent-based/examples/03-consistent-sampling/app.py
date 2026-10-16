"""Consistent vs divergent sampling, two simulated services.

For each incoming "request":
- Service A decides (root span) with its sampler.
- Service B receives a propagated context (trace_id + flags) and either
  honors it (ParentBased) or redecides independently (divergent anti-pattern).

We measure:
- A's sampled count
- B's sampled count
- "both" (trace fully sampled → complete)
- "orphans" (one sampled, the other dropped → incomplete trace)
"""
from __future__ import annotations

import secrets
from dataclasses import dataclass

from opentelemetry.sdk.trace.sampling import (
    ParentBased,
    TraceIdRatioBased,
    Decision,
)
from opentelemetry.trace import (
    SpanContext,
    TraceFlags,
    NonRecordingSpan,
    SpanKind,
    set_span_in_context,
)
from opentelemetry.context import Context

N = 1000
RATIO = 0.10


@dataclass
class Counts:
    a_sampled: int = 0
    b_sampled: int = 0
    both: int = 0
    orphan: int = 0


_RNG = secrets.SystemRandom(42)  # deterministic-ish within one run, uniform in 128 bits


def make_trace_id(_: int) -> int:
    # uniform across the whole 128-bit space; TraceIdRatioBased looks at the high 64 bits.
    return _RNG.getrandbits(128) | 1  # ensure non-zero


def run(label: str, service_a, service_b, b_honors_parent: bool) -> Counts:
    c = Counts()
    for i in range(N):
        tid = make_trace_id(i)
        # --- Service A: root decision ---
        res_a = service_a.should_sample(
            parent_context=None,
            trace_id=tid,
            name="root",
            kind=SpanKind.SERVER,
            attributes={},
            links=None,
        )
        a_sampled = res_a.decision != Decision.DROP
        if a_sampled:
            c.a_sampled += 1

        # --- propagate to B ---
        flags = TraceFlags(TraceFlags.SAMPLED if a_sampled else TraceFlags.DEFAULT)
        parent_sc = SpanContext(trace_id=tid, span_id=0xA1, is_remote=True, trace_flags=flags)
        parent_ctx: Context = set_span_in_context(NonRecordingSpan(parent_sc))

        # --- Service B: child decision ---
        if b_honors_parent:
            res_b = service_b.should_sample(
                parent_context=parent_ctx,
                trace_id=tid,
                name="child",
                kind=SpanKind.SERVER,
                attributes={},
                links=None,
            )
        else:
            # divergent anti-pattern: ignore parent, redecide from scratch
            res_b = service_b.should_sample(
                parent_context=None,
                trace_id=tid,
                name="child",
                kind=SpanKind.SERVER,
                attributes={},
                links=None,
            )
        b_sampled = res_b.decision != Decision.DROP
        if b_sampled:
            c.b_sampled += 1

        if a_sampled and b_sampled:
            c.both += 1
        elif a_sampled ^ b_sampled:
            c.orphan += 1

    print(f"== {label} ==")
    print(f"  A sampled: {c.a_sampled}")
    print(f"  B sampled: {c.b_sampled}")
    print(f"  Complete traces (both): {c.both}")
    print(f"  Orphan traces (one only): {c.orphan}")
    return c


def main() -> int:
    # Scenario 1: consistent — B wraps with ParentBased, so parent decision wins.
    sampler_consistent = ParentBased(root=TraceIdRatioBased(RATIO))
    consistent = run("CONSISTENT (ParentBased in B)", sampler_consistent, sampler_consistent, b_honors_parent=True)

    # Scenario 2: divergent — B uses raw TraceIdRatioBased with same ratio BUT ignores parent.
    # With same ratio and determinism on trace_id, decisions should still match: that's the
    # power of consistent probability sampling. We illustrate it below.
    sampler_raw_same = TraceIdRatioBased(RATIO)
    same_ratio = run("DIVERGENT structure, SAME ratio (determinism saves us)",
                     sampler_raw_same, sampler_raw_same, b_honors_parent=False)

    # Scenario 3: divergent AND different ratios — the real anti-pattern.
    sampler_a = TraceIdRatioBased(0.10)
    sampler_b = TraceIdRatioBased(0.50)
    diff_ratio = run("DIVERGENT ratios (A=0.10, B=0.50) — orphans appear",
                     sampler_a, sampler_b, b_honors_parent=False)

    # Assertions
    ok = True
    if consistent.orphan != 0:
        print("FAIL: consistent scenario produced orphans")
        ok = False
    if same_ratio.orphan != 0:
        print("FAIL: same-ratio determinism should also produce 0 orphans")
        ok = False
    if diff_ratio.orphan < 20:
        print(f"FAIL: diff-ratio scenario should show many orphans; got {diff_ratio.orphan}")
        ok = False

    print("OK" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
