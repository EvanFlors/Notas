# SLA and cost targets

- Platform SLA for the API tier: 99.9 % monthly (≤ 43 min of downtime).
- Node provisioning SLO: p95 Pod startup time (from Pending to Ready) < 90 s.
- Monthly node cost target: ≤ $6,500 (reduction from current $8,500).
- Idle headroom budget: ≤ 15 % cluster CPU on average.
- Graviton adoption target: ≥ 40 % of web workloads within 2 quarters (if images support arm64).
- Spot proportion target: ≥ 70 % for web + batch + workers.

Constraints:
- Multi-AZ mandatory. No workload may be concentrated in a single AZ > 60 %.
- Zero planned downtime during the autoscaler migration itself.
- IAM changes must be reviewed by SecOps; attach only required policies.
