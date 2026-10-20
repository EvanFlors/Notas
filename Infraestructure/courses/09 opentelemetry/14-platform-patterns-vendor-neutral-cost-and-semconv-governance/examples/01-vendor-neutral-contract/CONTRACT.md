# Platform Observability Contract — v1

**Owner:** Platform / Observability Guild
**Status:** Active
**Review cadence:** quarterly

## 1. Scope

All production and preproduction services of Company. Applies to any workload emitting telemetry (apps, batch jobs, infra agents).

## 2. Teams MUST

1. Emit telemetry via **OTLP** (gRPC on `4317`, HTTP on `4318`) to the local Collector agent (`otel-agent.observability.svc:4317` in cluster, `localhost:4317` on VMs).
2. Use the SemConv package pinned by the platform:
   - Upstream: `semconv/v1.27.0`.
   - Internal extensions: namespace `company.*`.
3. Populate the Resource with:
   - `service.name` (required, non-empty, lowercase, no spaces).
   - `service.namespace` (team/BU, e.g. `payments`, `catalog`).
   - `service.version` (semver or git short SHA).
   - `deployment.environment` (one of: `dev`, `stg`, `prod`).
4. Propagate W3C `traceparent` + `tracestate` on every outbound call (HTTP, gRPC, Kafka, SQS).
5. Attach the OTel logging bridge/handler so logs carry `trace_id`/`span_id` when a span is active.

## 3. Teams MUST NOT

1. Export directly to any vendor backend from the SDK.
2. Add vendor-prefixed attributes in code:
   - Forbidden prefixes: `dd.*`, `datadog.*`, `newrelic.*`, `nr.*`, `splunk.*`, `sfx.*`, `honeycomb.*`, `dynatrace.*`, `dt.*`.
3. Hardcode histogram bucket boundaries or temporality in SDK config. Use the platform `View` preset exported by the shared OTel-config package.
4. Emit more than **50 unique label combinations per metric**. Soft limit; the Collector hard-drops over this threshold.
5. Put identifiers of individual users, requests, or orders into metric labels (ever). They belong in spans and logs, not metrics.

## 4. Platform guarantees

| SLI | Target |
| --- | --- |
| OTLP gateway availability | 99.9% monthly |
| p99 ingest-to-queryable (traces) | < 60s |
| p99 ingest-to-queryable (metrics) | < 30s |
| p99 ingest-to-queryable (logs) | < 90s |
| Drop rate | < 0.1% |

Backend choice is a **platform decision**. Changes are announced with 2 weeks notice via `#observability-announce`. **No code change is required** for any backend swap.

## 5. Deprecations

- Upstream SemConv deprecations are handled via **dual-emit** in the Collector for N = 8 weeks.
- Cutover date is announced at week 0 and enforced at week 8.
- Teams are responsible for migrating their *dashboards* and *alerts*; the platform does not auto-rewrite them.

## 6. Exceptions

Exceptions to this contract require an ADR filed in `platform/adrs/` and sign-off from the Observability Guild lead. Exceptions expire after 90 days unless renewed.
