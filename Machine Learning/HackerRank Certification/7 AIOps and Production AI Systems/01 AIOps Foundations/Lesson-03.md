## Compute Requirements for AI Workloads
Choosing compute infrastructure for AI systems requires understanding different workload characteristics than traditional applications. The wrong choice can mean paying 10x more or getting 10x worse performance.

CPUs are general-purpose processors that excel at sequential operations and memory-intensive tasks. For AI, CPUs work for simple models, small-scale inference, and preprocessing. A logistic regression serving a few predictions per second runs fine on CPUs. However, CPUs struggle with the matrix operations dominating neural networks.

GPUs are specialized for parallel computation with thousands of cores performing the same operation on different data simultaneously. A model taking 10 seconds per prediction on CPU might take 10 milliseconds on GPU. For large models or high-throughput inference, GPUs are essential.

The choice is about cost-effectiveness, not just speed. A GPU instance costs 5x more than CPU. If GPU runs 10x faster, total cost is lower. If only 2x faster, CPUs might be cheaper. The math depends on your workload, volume, and latency requirements.

Specialized accelerators like Google TPUs, AWS Inferentia, or Apple Neural Engine offer better performance for specific workloads. TPUs are designed for TensorFlow. AWS Inferentia is optimized for inference. These require careful evaluation due to constraints on architecture, framework support, and portability.

Batch size dramatically affects requirements. Single predictions underutilize GPU cores. A GPU serving single predictions might handle 20 requests per second. With batch size 32, it might handle 200 requests per second. However, batching adds latency—you wait to form batches. This throughput-latency tradeoff drives many infrastructure decisions.

Memory is often the limiting factor. A 7-billion parameter model requires at least 28GB just for weights (4 bytes per parameter). Training might require 80GB or more. Memory exhaustion is not a performance issue—it is a hard failure.

Auto-scaling for AI differs from traditional applications. GPU utilization is better than CPU utilization, but a GPU at 100% might still have capacity with better batching. Request queue depth is often the best scaling signal.

Example: A computer vision model uses 8 A100 GPUs for 12-hour training at $3/GPU-hour ($288 per run). Inference runs on 4 T4 GPUs at $0.35/GPU-hour ($1,200/month) for 50 million predictions ($0.000024 each). AWS Inferentia might reduce this to $600/month.

There is no universal best infrastructure. Measure your workload, understand tradeoffs, and optimize for actual requirements.


Storage Considerations for Models and Data
Storage for AI systems requires different strategies than traditional applications: larger volumes, different access patterns, and unique performance requirements.

Model storage is the obvious requirement. A small BERT model is 400MB; a large language model might be 100GB. You need storage handling these sizes with fast access and versioning support.

Object storage (AWS S3, Google Cloud Storage, Azure Blob) is the most common choice. It is cheap ($0.023/GB/month), durable, and scales indefinitely with versioning and lifecycle policies. However, object storage has high latency for individual reads—downloading 10GB might take seconds. Cache models locally on serving instances: download once at startup, serve from memory or local disk.

Training data storage is more complex, requiring terabytes or petabytes with high-throughput reads and parallel access. Data lakes using object storage work for massive datasets accessed via Spark. However, small file access is slow. If training data is millions of small images, package them into larger files (TFRecords, tar archives) or use specialized file systems.

Distributed file systems like HDFS or AWS FSx provide better training performance. FSx for Lustre costs $0.14/GB/month (6x more than S3), but offers lower latency and higher throughput. Evaluate whether performance justifies cost for your workload.

Database storage is needed for structured feature data. Serving predictions might require looking up user preferences or product catalogs. Database choice depends on access patterns, latency, and volume.

Caching is critical. Cache feature data in Redis or Memcached to avoid per-prediction database queries. Cache predictions for frequent inputs. Cache hit rate dramatically affects latency and cost.

Log storage is often underestimated. Thousands of requests per second generate gigabytes of logs daily. You need cost-effective storage and efficient search tools.

Retention policies manage costs. Keep training data indefinitely, but not 3-year-old logs. Use tiered storage: hot for recent data, warm for occasional access, cold for archives (S3 Standard, Infrequent Access, Glacier).

Data transfer costs matter. Moving data between storage and compute incurs charges, especially across regions. Keep data and compute co-located to reduce costs.


Network Architecture and Cost-Performance Tradeoffs
Network architecture for AI systems handles different traffic patterns: larger payloads, different latency requirements, and unique integration patterns.

Payload sizes are typically larger than traditional APIs. A REST API might handle hundreds of bytes. An image classification model receives multi-megabyte images. Language models receive and generate kilobytes of text. Larger payloads affect capacity, latency, and costs.

Bandwidth becomes a bottleneck quickly. If your model receives 5MB images at 100 requests per second, you need 4Gbps inbound. Standard instances might not suffice—plan for higher bandwidth or optimize payloads through compression.

Latency requirements vary by use case. Real-time applications need milliseconds. Batch processing tolerates minutes. Chatbots need subsecond responses. Network latency adds directly to request time—50ms inference plus 100ms network equals 150ms user experience.

Geographic distribution affects latency and architecture. Multi-region deployment reduces latency for distant users but increases complexity and cost. Balance global coverage with operational overhead.

API gateways are common in AI architectures. Route requests through a gateway handling authentication, rate limiting, and routing to different models. This adds network hops but provides flexibility and control.

Internal networking matters for training. Distributed training across multiple GPUs requires high-bandwidth, low-latency communication. Training large models might need dozens of GPUs communicating continuously via AWS EFA or NVIDIA NVLink. Without adequate networking, training becomes communication-bound.

CDNs have limited benefit for AI. Most workloads are dynamic and personalized. CDNs are better for distributing model binaries to edge locations than caching predictions.

Cost optimization requires understanding traffic patterns. Cloud egress charges add up—10TB/month costs around $900 in AWS egress. Deploy in regions where most traffic originates.

Security is essential. AI models are valuable intellectual property. Protect access through authentication, encryption, private VPCs, and API keys. Security adds latency but is necessary.

Failure handling requires redundancy, health checks, and failover. Deploy across availability zones with load balancers and circuit breakers.

Summary
Infrastructure for AI differs significantly from traditional applications. Compute choices range from CPUs for simple models to GPUs for neural networks to specialized accelerators. The right choice depends on your model, throughput, latency, and cost targets.

Storage handles large model files, massive training datasets, and high-volume logs through object storage, distributed file systems, databases, and caching. Network architecture accommodates larger payloads, varying latency requirements, and specialized distributed training communication.

Key concepts to remember
GPU Cost-Effectiveness - GPU infrastructure provides 10x or more speedup for neural networks, but cost-effectiveness depends on specific utilization and batch size
Tiered Storage Strategy - Use object storage for models and training data, caching for frequently accessed data, and tiered storage for logs and archives
Higher Bandwidth Needs - Network bandwidth requirements for AI workloads are often higher than traditional applications due to larger payloads
Specialized Networking - Distributed training requires specialized high-bandwidth, low-latency networking between compute nodes to avoid communication bottlenecks
Measure Before Optimizing - Cost optimization requires measuring actual workload characteristics and balancing compute, storage, and network tradeoffs