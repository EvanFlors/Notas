"""Head-based sampling demo: ParentBased(TraceIdRatioBased(0.1)).

Spawns N root spans, measures the sampled fraction, and shows that a parent
with sampled flag is always honored (ParentBased wrapper).
"""
from __future__ import annotations

from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.sampling import ParentBased, TraceIdRatioBased
from opentelemetry.trace import SpanContext, TraceFlags, NonRecordingSpan
from opentelemetry.context import attach, detach
from opentelemetry.trace.propagation import set_span_in_context

RATIO = 0.10
N = 1000


def build_tracer():
    sampler = ParentBased(root=TraceIdRatioBased(RATIO))
    provider = TracerProvider(sampler=sampler)
    trace.set_tracer_provider(provider)
    return trace.get_tracer("head-sampling-demo")


def count_root_sampled(tracer, n: int) -> int:
    sampled = 0
    for _ in range(n):
        with tracer.start_as_current_span("root") as span:
            if span.get_span_context().trace_flags.sampled:
                sampled += 1
    return sampled


def honored_parent_sampled(tracer) -> bool:
    """Craft a remote parent context with sampled=1 and verify we honor it."""
    parent_ctx = SpanContext(
        trace_id=0x0123456789ABCDEF0123456789ABCDEF,
        span_id=0x0011223344556677,
        is_remote=True,
        trace_flags=TraceFlags(TraceFlags.SAMPLED),
    )
    ctx = set_span_in_context(NonRecordingSpan(parent_ctx))
    token = attach(ctx)
    try:
        with tracer.start_as_current_span("child") as span:
            return bool(span.get_span_context().trace_flags.sampled)
    finally:
        detach(token)


def main() -> int:
    tracer = build_tracer()
    sampled = count_root_sampled(tracer, N)
    frac = sampled / N
    print(f"Root spans: {N}, sampled: {sampled}, fraction: {frac:.3f}")
    print(f"SAMPLED ~= {frac:.2f} (ratio={RATIO:.2f})")

    honored = honored_parent_sampled(tracer)
    print(f"Parent with sampled=1 honored by child: {honored}")

    ok = 0.03 <= frac <= 0.20 and honored
    print("OK" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
