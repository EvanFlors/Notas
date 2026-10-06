## Real-World Scenario: E-Commerce Recommendation System
You are deploying a recommendation system for an e-commerce platform. Requirements: personalized recommendations on homepage, category pages, and product detail pages. Serve 5,000 requests per second at peak, respond within 200ms at p99, handle 50 million active users.

The model takes user history (last 20 interactions), current context (time, device, page), and candidate products as input. It outputs relevance scores. The model has 200 million parameters requiring 800MB memory.

Your challenge: design the complete production architecture from request ingestion to response delivery, including infrastructure, data flows, and operations.

Key components:

API layer: Receives HTTP requests with user ID, context, and parameters. Handles authentication, validation, rate limiting, and routing. AWS API Gateway or FastAPI.

Feature retrieval: Fetches user history from database or cache, product catalog from services, context from request. Must be fast—latency adds directly to total time. Redis caches frequently accessed data.

Model serving: Runs inference, computing relevance scores. Infrastructure choices (CPU/GPU, instance count, batch size) require measurement.

Response construction: Filters low-confidence predictions, applies business rules (no out-of-stock products), formats response. Logs predictions for monitoring.

Monitoring: Tracks system health and model performance.

Deployment: Updates models safely with rollback capability.


Making Key Architecture Decisions
Decision 1: Real-time vs batch serving

Real-time serving computes recommendations on-demand, providing fresh results based on recent behavior. If a user just browsed laptops, recommendations adapt immediately. This requires low-latency infrastructure within your 200ms budget.

Batch precomputation generates recommendations periodically for all users. Allows larger, more accurate models without latency constraints. However, recommendations become stale.

For e-commerce, use a hybrid approach: precompute homepage recommendations nightly with a large model; generate real-time recommendations for product detail pages.

Decision 2: Compute infrastructure

Testing: CPU inference takes 150ms per request. GPU inference takes 5ms with batch size 32.

At 5,000 peak requests per second:

CPUs: 150ms/request = ~6 requests/second/core. Need 833 cores (52 instances at 16 cores each). Cost: $26/hour = $18,720/month.
GPUs: 5ms/request with batch 32 = ~6,400 requests/second/GPU. Need 1 GPU (2 for redundancy). Cost: $6/hour = $4,320/month.
GPUs are clearly more cost-effective, but require request batching.

Decision 3: Caching strategy

Cache at multiple levels:

Homepage recommendations in CDN/Redis (daily refresh, ~100% hit rate)
User features in Redis with 60-second TTL (stable within sessions)
Product catalog with longer TTLs (changes infrequently)
Decision 4: Data pipeline

For real-time: stream events to Kafka/Kinesis, update user profiles in Redis within seconds.

For batch: load interaction data to warehouse nightly, run feature engineering, store in feature store.

Decision 5: Model deployment

Use blue-green deployment: deploy new model to separate instances, route small traffic percentage while monitoring, gradually increase, route back instantly if problems arise.

Resilience

Implement circuit breakers. If model servers fail, fall back to cached or rule-based recommendations. If feature database is slow, use cached or default values. Degrade gracefully rather than failing completely.


Evaluating Tradeoffs and Final Architecture
Every decision involves tradeoffs:

| Decision | Tradeoff |
|----------|-----------|
| Real-time vs batch | Freshness and complexity vs simplicity and staleness |
| GPU vs CPU | Cost-performance vs deployment simplicity |
| Caching | Memory cost vs reduced latency and compute |
| Streaming vs batch pipeline | Real-time freshness vs simplicity |
| Blue-green deployment | Safety (2x infra) vs speed |

Final architecture:

Frontend → API Gateway (authentication, rate limiting) → Recommendation service (FastAPI on ECS) → Redis cache check → On miss: user features from Redis, product data from PostgreSQL → Batch requests to TensorFlow Serving on GPU every 20ms → Filter, rank, return.

Deployment: Blue-green with traffic shifting over 30 minutes. Shadow traffic validation for 24 hours. CloudWatch for infrastructure, custom dashboards for prediction monitoring. Alerts on error rates and distribution shifts.

Results:

Handles 5,000 requests/second at p99 < 200ms
~$6,000/month for compute, storage, network
Scales to 10,000 requests/second by adding GPUs
Graceful degradation via cached/default recommendations
The architecture is evolvable. Add sophisticated models, expand caching, optimize further, scale horizontally. Modular design allows changing components without rewriting the system.

Summary
Production ML system design balances latency, cost, scalability, and operational complexity. Key decisions include deployment patterns, compute infrastructure, caching, data pipelines, and failure handling.

Every decision involves tradeoffs. Document reasoning to help future engineers understand choices. Production ML design is not about perfect solutions but appropriate solutions for your specific context.

Key concepts to remember
End-to-End Architecture - Production ML system design requires considering complete architecture from API layer through model serving to monitoring and operations
Hybrid Deployment Patterns - Combine batch precomputation and real-time serving to balance freshness, cost, and model quality
Data-Driven Infrastructure Choices - Base infrastructure choices between CPUs and GPUs on actual cost-performance analysis for your specific workload and scale
Multi-Level Caching - Multi-level caching strategies dramatically reduce latency and cost by eliminating redundant database queries and model inference
Gradual Deployment - Use blue-green and shadow deployments to enable safe model updates with quick rollback capabilities
This concludes the AIOps Foundations submodule. In the next submodule, you will learn about model deployment strategies and patterns for production systems.