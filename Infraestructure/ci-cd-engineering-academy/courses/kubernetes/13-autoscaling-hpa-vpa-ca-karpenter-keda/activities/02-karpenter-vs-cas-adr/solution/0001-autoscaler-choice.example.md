# ADR 0001: Autoscaler choice for EKS production cluster

## Status

Accepted: Karpenter v1 (migrate from Cluster Autoscaler)

## Context

We run a single EKS cluster in `us-east-1` with ~30 web microservices, 2 nightly batch pipelines (4–16 CPU jobs), 4 KEDA-scaled worker fleets, and a small GPU inference pool (`g5.xlarge`, on-demand only). Current cost ~$8,500/month with Cluster Autoscaler managing 3 ASGs (`web-amd64`, `batch-amd64`, `gpu`). Observed pain: idle headroom around 25 %, p50 scale-up ~90 s, no Graviton adoption, and modifying instance types requires rotating entire ASGs.

Targets: node cost ≤ $6,500/mo, p95 Pod startup < 90 s, Graviton ≥ 40 % of web workloads, spot ≥ 70 % of eligible workloads, idle headroom ≤ 15 %, zero downtime during migration.

## Decision

Migrate to **Karpenter v1** with four `NodePool`s: `web-spot` (c/m/r generation > 3, amd64 + arm64, spot preferred), `web-ondemand` (fallback), `batch-spot` (large instances, spot, taint `batch=true:NoSchedule`), and `gpu` (`g5.xlarge`, on-demand only, taint `gpu=true:NoSchedule`). Enable `consolidationPolicy: WhenEmptyOrUnderutilized` with `consolidateAfter: 30s` on web and batch pools. Keep CA installed and scaled to zero node groups for 2 weeks as rollback.

Rationale: Karpenter's scheduler-driven provisioning picks per-pod instance shapes, which is the direct answer to "idle headroom" and "no Graviton". Scale-up via EC2 `RunInstances` reaches ~45 s vs 90 s of ASG. Consolidation closes the scale-down gap. The GPU pool is naturally expressed as a separate `NodePool` with on-demand-only requirements.

## Comparison

| Dimension | Cluster Autoscaler (modernized) | Karpenter v1 |
|-----------|---------------------------------|--------------|
| Scale-up latency (p50) | ~90 s (ASG round-trip) | ~45 s (direct EC2 RunInstances) |
| Bin packing granularity | Per ASG shape (coarse) | Per Pod shape (fine) |
| Spot support | Mixed instances policy; manual lists | Native `karpenter.sh/capacity-type`; interrupt handler bundled |
| GPU support | Dedicated ASG per shape | Dedicated NodePool with taints + requirements |
| Consolidation | External add-on (descheduler) | Native (`WhenEmptyOrUnderutilized`) |
| Operability | 3 ASGs in Terraform; AMI roll = ASG rotation | NodePools in K8s API; `expireAfter: 720h` rolls AMIs continuously |
| Multi-AMI (amd64 + arm64) | Multiple ASGs | One NodePool via `kubernetes.io/arch` requirement |
| Cost impact (est.) | Baseline $8,500/mo | ~$6,000/mo (idle headroom down, Graviton on web, aggressive spot) |
| Cloud dependencies | Cloud-agnostic (same ops shape in GKE/AKS) | AWS-first; Azure provider beta |
| Maturity (as of 2026) | GA since 2018, boring | v1 GA since 2024-10; stable but newer |

## Alternatives

- **Alternative A — Keep Cluster Autoscaler, modernized.** Add `--balance-similar-node-groups`, switch `--expander` to `price`, enable mixed instances for Graviton, add Descheduler for consolidation. *Rejected*: still bound to ASG shapes; Graviton requires maintaining parallel ASGs; scale-up stays ~90 s.
- **Alternative B — Karpenter v1 (chosen).** See Decision.
- **Alternative C — Dual run (Karpenter for web, CA for GPU).** Considered as a transitional state but rejected as long-term because it doubles operational surface. Used only during the 2-week rollback window.

## Consequences

Positive:

- Expected ~30 % node cost reduction via consolidation + Graviton + aggressive spot.
- Faster scale-up (~45 s) improves tail latency during morning spike.
- Single API-driven surface (K8s objects) vs Terraform-managed ASGs; ops team edits `NodePool` without a Terraform apply.
- Continuous AMI rollout via `expireAfter: 720h` removes the "AMI drift" tech-debt line item.

Negative:

- Lock-in to AWS; a future multi-cloud push would require re-introducing CA or Karpenter Azure provider (beta).
- Spot interruptions now span more diverse instance types; must verify every workload tolerates 2-min notice (PDB + preStop + graceful shutdown).
- New IAM role (`KarpenterNodeRole`) + controller role via IRSA — SecOps review required.
- Observability needs updating: Karpenter metrics (`karpenter_*`) replace CA metrics in dashboards and alerts.

Neutral:

- GPU workload shape and cost unchanged (same `g5.xlarge`, same quantity).

## Rollback Plan

Trigger: within 14 days of cutover, if any of (a) p95 Pod startup > 120 s sustained for 1 h, (b) interrupt-driven Pod loss > 0.1 %/h on web, (c) Karpenter controller crash loop > 3 times/day, (d) unaccounted spend spike > 20 %.

Steps:

1. Freeze new `NodePool` changes.
2. Scale Karpenter controller to zero (`kubectl -n karpenter scale deploy karpenter --replicas=0`). Existing nodes keep running.
3. Re-enable CA by scaling up the original ASGs (desired = current Karpenter node count per group).
4. Cordon Karpenter nodes; let CA + scheduler rebalance over 30–60 min, respecting PDBs.
5. Once CA-managed nodes serve traffic, drain and terminate the Karpenter nodes group by group.
6. Open a post-mortem; do not retry migration without addressing the root cause.

Data cost: zero — all state is stateless workload. GPU pool is untouched. Expected rollback duration: 2–3 hours. Rollback is practiced in a staging cluster before cutover.

## References

- Karpenter v1 concepts and NodePool reference — https://karpenter.sh/docs/concepts/ (visited 2026-10)
- Cluster Autoscaler on AWS — https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md (visited 2026-10)
- AWS blog: "How Pinterest migrated from CA to Karpenter" — https://aws.amazon.com/blogs/containers/ (search by title; dated 2024)
- Kubernetes HPA/VPA/CA/Karpenter SIG-Autoscaling overview — https://github.com/kubernetes/community/blob/master/sig-autoscaling/README.md (visited 2026-10)
