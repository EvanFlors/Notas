## Horizontal versus Vertical Scaling

Comparison of vertical scaling using larger instances versus horizontal scaling using more instances

![Vertical vs horizontal scaling approaches](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson01-horizontal-vertical-scaling.svg)

Scaling AI systems to handle growth requires choosing between horizontal scaling (adding more instances) and vertical scaling (using larger instances). Each approach has distinct characteristics and tradeoffs.

Vertical scaling means using more powerful instances. Replace a 4-core, 8GB RAM instance with an 16-core, 32GB RAM instance. For GPU workloads, replace a T4 GPU with an A100 GPU. Vertical scaling is simple: change the instance type and redeploy. Your code needs no modifications. You get more capacity immediately.

The advantage of vertical scaling is simplicity. No changes to architecture or code. No coordination between multiple instances. Monitoring and operations remain straightforward. For many workloads, vertical scaling is the fastest path to more capacity.

However, vertical scaling has hard limits. You eventually reach the largest available instance types. Cloud providers offer instances with up to 128 cores and 2TB of RAM, but beyond that, vertical scaling ends. Cost efficiency often decreases at very large instance sizes. The largest instances cost more per unit of compute than medium-sized instances.

Horizontal scaling adds more instances of the same type. Run 10 instances instead of 5. For model serving, this means more model servers handling requests in parallel. Horizontal scaling is unlimited in theory. You can add as many instances as needed. This enables handling essentially any load.

Load balancing is required for horizontal scaling. Distribute incoming requests across instances evenly. Use layer 4 load balancers (TCP/IP level) or layer 7 load balancers (HTTP level). Health checks ensure traffic only goes to healthy instances. Load balancing adds some complexity but enables reliable horizontal scaling.

A production-ready implementation demonstrates load balancing with round-robin distribution and autoscaling that monitors CPU utilization to add or remove servers automatically, ensuring capacity matches demand.

State management affects horizontal scaling. Stateless services scale easily because any instance can handle any request. Stateful services where instances hold user-specific data scale harder. Model serving is mostly stateless (the model is shared, not per-user state), making horizontal scaling natural.

Cost efficiency favors horizontal scaling for most workloads. Running 10 medium instances costs about the same as running 3 large instances with the same total capacity. Medium instances provide better granularity. You can add instances one at a time rather than jumping from 8 cores to 16 cores.

Horizontal scaling provides better fault tolerance. If one instance fails, others continue serving traffic. With vertical scaling, if your single large instance fails, all capacity is lost. Multiple smaller instances provide redundancy automatically.

The optimal strategy often combines both. Use appropriately-sized instances (vertical scaling to a sweet spot) then scale horizontally by adding more of those instances. For example, use instances with 2 GPUs each, then scale horizontally by adding more 2-GPU instances.

Understanding the tradeoffs between horizontal and vertical scaling helps you choose the right strategy for your workload.

Auto-Scaling and Request Batching
Auto-scaling automatically adjusts capacity based on load, ensuring adequate resources without manual intervention. Request batching groups multiple requests for efficient processing.

Auto-scaling policies define when to scale. Scale up when average CPU exceeds 70 percent. Scale down when CPU drops below 30 percent. For GPU workloads, scale based on GPU utilization. For request-driven workloads, scale based on queue depth or request rate. Policies should include cooldown periods to prevent thrashing (rapidly scaling up and down).

Reactive auto-scaling responds to current load. When metrics exceed thresholds, add capacity. This approach is simple but reactive. By the time you detect high load and add capacity, requests might already be slow. New instances take time to start (30 seconds to several minutes), creating a gap between detecting need and having capacity.

Predictive auto-scaling uses historical patterns to scale proactively. If load increases every day at 9am, start scaling at 8:45am. If traffic doubles on weekends, pre-scale on Saturday morning. Predictive scaling eliminates the lag of reactive scaling. However, it requires stable, predictable traffic patterns.

Target tracking auto-scaling maintains metrics at target values. Set target CPU utilization to 60 percent. Auto-scaling adds or removes instances to stay near 60 percent. This approach is simple to configure and works well for many workloads. Cloud providers offer built-in target tracking policies.

Request batching improves throughput by processing multiple requests together. Instead of running model inference on one input at a time, batch 32 inputs and process them together. GPUs are designed for parallel processing and achieve much higher throughput with batching.

The batching tradeoff is latency versus throughput. Larger batches improve throughput (more requests per second) but increase latency (requests wait for batches to fill). Batch size 1 minimizes latency but wastes GPU capacity. Batch size 64 maximizes GPU utilization but requests wait longer.

Dynamic batching collects requests for a short time window then processes them together. Set a maximum batch size (32) and maximum wait time (20ms). As requests arrive, add them to the current batch. When batch reaches 32 or 20ms passes, process the batch. This balances latency and throughput automatically.

Queue-Based Architectures
Queue-based architecture showing producers, message queue buffer, and worker pool with auto-scaling

![Queue-based architecture for traffic buffering and scaling](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson01-queue-based-architecture.svg)

Queue-based architectures decouple request submission from processing, enabling better handling of traffic spikes and more efficient resource utilization.

Request queues buffer incoming requests before processing. Requests arrive at varying rates. Processing capacity is fixed in the short term. Queues absorb bursts, storing requests temporarily when arrivals exceed capacity. This prevents dropped requests during spikes.

Queue depth monitoring indicates capacity needs. If queues stay near empty, capacity exceeds demand. If queues grow continuously, demand exceeds capacity. Target queue depth around 10-20 requests provides buffer without excessive latency. Monitor queue depth to trigger auto-scaling.

Priority queues enable differentiated service. High-priority requests (from premium users or urgent requests) jump to the front. Low-priority requests (batch jobs) wait longer. Priority queues ensure critical requests get resources even during high load.

Rate limiting using queues provides fair access. Each API key gets a quota of requests per minute. When over quota, requests queue or are rejected. This prevents one client from monopolizing resources and ensures fair resource allocation across clients.

Back-pressure mechanisms signal when systems are overloaded. When queues reach capacity limits, stop accepting new requests temporarily. Return 503 Service Unavailable to clients. Back-pressure prevents system collapse under overload. Clients can retry later when capacity is available.

Queue-based scaling adjusts workers based on queue depth. If queue depth exceeds 50 requests, scale up workers. If queue depth drops below 10, scale down workers. This creates a self-regulating system where capacity matches demand automatically.

Dead letter queues handle failed requests. When request processing fails repeatedly (after retries), move requests to a dead letter queue for manual investigation. This prevents bad requests from clogging the main queue while preserving them for debugging.

Message durability ensures requests are not lost. Persistent queues write messages to disk before acknowledging receipt. If a worker crashes while processing a request, the request remains in the queue for reprocessing. Durability prevents request loss at the cost of slightly higher latency.

Distributed queues scale beyond single machines. AWS SQS, Google Pub/Sub, or Apache Kafka provide distributed queues handling millions of requests per second. These managed services handle durability, scaling, and monitoring, letting you focus on application logic.

Summary
Scaling strategies for AI systems include horizontal scaling (adding instances), vertical scaling (using larger instances), auto-scaling (adjusting capacity automatically), request batching (processing multiple requests together), and queue-based architectures (buffering requests for efficient processing).

Effective scaling balances performance, cost, and complexity. Horizontal scaling provides unlimited capacity and better fault tolerance. Auto-scaling ensures adequate capacity without over-provisioning. Request batching maximizes GPU utilization. Queue-based architectures handle traffic spikes gracefully.

Key concepts to remember
Horizontal versus Vertical - Horizontal scaling provides unlimited capacity and fault tolerance; vertical scaling is simpler but has hard limits
Proactive Scaling - Combine reactive (current metrics) and predictive (historical patterns) approaches to scale proactively
Batching Tradeoffs - Request batching dramatically improves GPU throughput at the cost of increased latency; dynamic batching balances both
Buffer Traffic Spikes - Queue-based architectures buffer traffic spikes and enable efficient resource utilization
Combined Strategy - Combine appropriately-sized instances with horizontal scaling and auto-scaling based on queue depth or utilization