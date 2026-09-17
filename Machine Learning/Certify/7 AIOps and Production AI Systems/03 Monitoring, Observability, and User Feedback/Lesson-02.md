## The Three Pillars: Logs, Metrics, and Traces

Three pillars of observability showing logs, metrics, and traces with their key characteristics

![Logs, metrics, and traces as the three pillars of observability](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson02-three-pillars-observability.svg)

Observability extends beyond monitoring. Monitoring tells you something is wrong. Observability helps you understand why it is wrong and how to fix it. This requires three complementary data types: logs, metrics, and traces.

Logs provide detailed records of events. Each log entry describes something that happened: a request arrived, a prediction was made, an error occurred. Logs have rich context but are expensive to store and search. You use logs to investigate specific incidents or debug particular requests. When a user reports a problem, you search logs for their request to see what happened.

Metrics aggregate many events into numbers. Request count, average latency, error rate. Metrics are efficient to store and quick to query but lack detail. You use metrics for continuous monitoring and dashboards. Metrics tell you that error rates spiked, but logs tell you which specific errors occurred and why.

Traces show the path of individual requests through distributed systems. A request might flow from the API gateway to the model server to the feature service to a database. Traces connect all these steps, showing where time was spent and where errors occurred. You use traces to debug performance problems and understand complex request flows.

Together, these three provide comprehensive observability. Metrics alert you to problems. Logs provide details for investigation. Traces show request flow through systems. None alone is sufficient, but all three together enable effective debugging.

For AI systems specifically, logs should capture: input data summaries (not full data due to size), prediction outputs, confidence scores, model version used, features computed, latency breakdown by component, and any errors or warnings. This information helps debug prediction quality issues and performance problems.

Structured logging uses JSON or similar formats rather than plain text. Instead of "User 12345 got prediction fraud with confidence 0.89", log ```{"user_id": 12345, "prediction": "fraud", "confidence": 0.89, "model_version": "v1.3", "latency_ms": 45}```. Structured logs are easier to parse, search, and aggregate. Modern logging systems like Elasticsearch excel at querying structured data.

This observability approach combines structured logging (machine-parseable JSON) with distributed tracing (timing breakdown across operations), providing comprehensive visibility into ML system behavior for debugging and optimization.


Distributed Tracing for ML Pipelines
Distributed trace waterfall showing request flow through API Gateway, Model Server, Feature Service, and Database with timing

![Distributed trace showing ML pipeline request flow](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson02-distributed-trace.svg)

ML prediction requests often flow through multiple services: load balancer, API gateway, serving application, model server, feature service, database. Understanding request flow requires distributed tracing that connects these steps.

Distributed tracing works by propagating context through requests. When a request enters your system, generate a unique trace ID. Pass this trace ID in headers to downstream services. Each service reports timing and metadata with the trace ID. The tracing system collects all these reports and assembles a complete picture of the request path.

A trace consists of spans. Each span represents one operation: serving application took 100ms, model inference took 50ms, feature database query took 30ms. Spans have parent-child relationships showing the call hierarchy. The complete trace shows the entire request tree with timing for each component.

For ML pipelines, useful spans include: total request handling, input validation, feature retrieval from cache, feature computation, model inference, result post-processing, and response formatting. Timing each span reveals where latency is spent.

Implementing tracing requires instrumentation. Popular tracing systems include Jaeger, Zipkin, and cloud provider solutions like AWS X-Ray. You add tracing libraries to your applications that automatically create spans for common operations and provide APIs for custom spans.

Example instrumentation creates a span for model inference timing, records the model version and input shape as metadata, catches exceptions and marks the span as error, and ensures the span is reported even if the code fails. This provides visibility into model performance and errors.

Trace sampling manages costs. Recording every request generates massive data volumes. Sampling records 1 percent of requests (or adaptive percentages based on latency or errors) to keep costs reasonable while maintaining insight. High-latency or error requests should always be sampled to aid debugging.

Correlation between traces and logs enables powerful debugging. Logs include trace IDs, allowing you to find all logs for a specific trace. When investigating a slow request, you view the trace to see which component was slow, then view logs from that component to understand why.

Tracing helps identify bottlenecks. If 80 percent of request time is spent retrieving features from a database, optimize database queries or add caching. If 80 percent is model inference, optimize the model or use faster infrastructure. Without tracing, optimization is guesswork.


Correlating Model Behavior with Infrastructure
Understanding how model behavior relates to infrastructure helps debug performance issues and optimize resource usage. Correlation between model metrics and infrastructure metrics reveals important patterns.

GPU utilization affects model throughput and latency. Low GPU utilization (under 50 percent) suggests inefficient batching or CPU bottlenecks. High utilization (near 100 percent) is good but leaves no headroom for traffic spikes. Track GPU utilization alongside request rate and latency to understand the relationship.

Memory pressure affects stability. As memory usage approaches limits, systems slow down due to garbage collection or swapping. Worse, they crash with out-of-memory errors. Correlate memory usage with latency and error rates. If latency increases as memory approaches limits, you need more memory or better memory management.

CPU utilization for request processing (pre and post model inference) affects overall latency. Even with fast GPU inference, slow CPU processing bottlenecks the system. Correlate CPU usage with request latency broken down by component to identify CPU bottlenecks.

Network bandwidth affects systems with large payloads. If requests contain 5MB images and network bandwidth is saturated, latency increases. Correlate network throughput with latency to identify network bottlenecks versus compute bottlenecks.

Instance health affects prediction quality. If an instance has hardware issues, predictions might be wrong or slow. Correlate error rates or latency by instance to identify problematic instances. If one instance has 10x higher error rate than others, investigate or replace it.

Input data characteristics affect resource usage. Larger inputs consume more memory and processing time. Correlate input size with latency and memory usage. This helps set appropriate resource limits and identify optimization opportunities.

Batch size dramatically affects GPU utilization and throughput. Small batches underutilize GPUs. Large batches maximize utilization but increase latency (requests wait for batches to fill). Correlate batch size with GPU utilization and latency to find optimal settings.

Cache hit rates affect latency and load on backend systems. High cache hit rates (over 80 percent) mean most requests avoid slow operations. Low hit rates mean cache provides little benefit. Correlate cache hit rate with database load and request latency to understand cache effectiveness.

Model version changes might affect resource usage. A new model version might be faster or slower, use more or less memory, or have different characteristics. When deploying new models, compare infrastructure metrics between versions to understand resource implications.

Temporal patterns reveal capacity planning needs. Does latency increase during peak hours? Does it decrease on weekends? Understanding daily and weekly patterns helps plan capacity and identify when to scale up or down.

Anomaly detection on correlated metrics helps identify problems. If GPU utilization suddenly drops while request rate stays constant, something changed. If memory usage increases while request volume is flat, investigate for memory leaks. Correlation context makes anomalies more actionable.

Visualization of correlated metrics uses tools like Grafana to create dashboards showing multiple metrics over the same time range. Seeing GPU utilization, latency, and request rate together reveals patterns that individual metrics miss.

Summary
Observability for AI systems requires logs, metrics, and traces working together. Structured logs provide detailed event records for debugging. Metrics aggregate behavior for monitoring and alerting. Distributed traces show request flow through multiple services, revealing where time is spent and where errors occur.

Correlating model behavior with infrastructure metrics helps debug performance issues and optimize resource usage. Understanding relationships between GPU utilization, memory pressure, network bandwidth, and model behavior enables effective troubleshooting and capacity planning.

Key concepts to remember
Three Pillars - Logs provide rich detail, metrics provide aggregated data, and traces show request flow through distributed systems
Structured Logging - JSON format enables powerful search and aggregation of log data across ML pipelines
Distributed Tracing - Unique trace IDs propagated through service calls reveal performance bottlenecks and request flow issues
Resource Correlation - Correlating GPU utilization, memory usage, and request characteristics reveals optimization opportunities
Smart Sampling - Sampling strategies balance comprehensive visibility with manageable storage costs by recording representative subsets