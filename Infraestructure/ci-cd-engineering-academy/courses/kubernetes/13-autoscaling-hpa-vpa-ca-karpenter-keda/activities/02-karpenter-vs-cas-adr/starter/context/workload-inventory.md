# Workload inventory (hypothetical EKS cluster)

Region: `us-east-1`. 3 AZ.

| Group | Workloads | Requests/pod | Replica range | Capacity type |
|-------|-----------|--------------|---------------|---------------|
| Web | 30 microservices (HTTP APIs) | 100m–500m CPU, 128–512 MiB | 2–40 | spot OK |
| Batch | 2 nightly pipelines | 4–16 CPU, 8–32 GiB | 0–8 (burst) | spot OK |
| Workers | 4 KEDA-scaled worker fleets | 100m CPU, 128–256 MiB | 0–50 | spot OK |
| Inference | 1 GPU inference pool | 2 CPU + 1 GPU + 16 GiB | 0–8 (daytime) | on-demand only |

Current setup: Cluster Autoscaler + 3 ASGs (`web-amd64`, `batch-amd64`, `gpu`).
Monthly cost: ~$8,500. p50 scale-up: ~90 s. Reported pain: idle headroom, slow scale-down, Graviton untapped, inflexible instance types.

SLOs:
- Web p99 latency < 300 ms.
- Batch pipeline completion < 2 h.
- GPU inference p99 latency < 500 ms (cold start acceptable < 60 s).
