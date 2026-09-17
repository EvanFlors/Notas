## When and What to Cache in AI Systems

Multi-level caching architecture showing in-memory cache, distributed cache, and model inference layers with hit rates

![Multi-level caching architecture for ML serving](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson02-caching-layers.svg)

Caching reduces latency and compute costs by storing and reusing frequently accessed data or expensive computation results. For AI systems, strategic caching can dramatically improve performance and reduce infrastructure costs.

Feature caching stores computed features to avoid recalculation. Features often require database queries, API calls, or expensive transformations. A user profile feature might aggregate the user's last 100 actions. Computing this feature takes 200ms. Caching it reduces feature retrieval to under 5ms. Cache features with short time-to-live (TTLs) to balance freshness and performance.

Prediction caching stores model outputs for common inputs. If many users request recommendations for the same popular product, cache the results. The first request computes predictions; subsequent requests return cached results instantly. Prediction caching works well when input diversity is low and predictions change slowly.

Embedding caching stores vector representations of frequently accessed items. Computing embeddings requires model inference. For a catalog of 100,000 products, computing embeddings on-demand is expensive. Cache product embeddings and update them periodically. This trades freshness for performance.

Model caching keeps loaded models in memory. Loading large models from disk takes seconds. Once loaded, keep models in memory across requests. This is standard practice but worth mentioning as a critical caching layer. Model loading latency dominates request latency if not properly cached.

Intermediate result caching stores outputs from pipeline stages. A recommendation pipeline might have steps: retrieve user history, compute user embedding, find similar items, rank items. Cache intermediate results like user embeddings to avoid recomputation when the final ranking changes.

Negative caching stores information about what is NOT present. If a user queries for an item that does not exist, cache that negative result. This prevents repeatedly querying databases for non-existent data. Negative caching reduces load on backend systems.

The decision to cache depends on the cost-benefit ratio. Calculate cache hit rate, cost saved per hit, and cache storage cost. If cache hit rate is 80 percent, each hit saves 100ms, and you serve 1000 requests per second, caching saves 80,000ms (80 seconds) of compute per second. This dramatic saving justifies cache complexity and cost.

A production-ready prediction caching implementation shows how caching can dramatically reduce latency and compute costs, especially for repeated predictions on popular inputs. The cache hit rate and latency savings directly translate to infrastructure cost savings.

Cache Invalidation Strategies
Cache invalidation is notoriously difficult. Stale cached data causes models to serve outdated results. Effective invalidation strategies balance freshness and performance.

Time-based expiration (TTL) is the simplest strategy. Set each cache entry to expire after a fixed duration. User feature cache might have 60-second TTL. After 60 seconds, entries expire and must be recomputed. Short TTLs provide freshness at the cost of more cache misses. Long TTLs improve hit rates but risk stale data.

Adaptive TTLs adjust expiration based on data characteristics. Frequently changing data gets short TTLs. Stable data gets long TTLs. Popular items that rarely change can be cached for hours. Unpopular items that change frequently should have short TTLs or not be cached.

Event-based invalidation triggers cache updates when underlying data changes. When a user makes a purchase, invalidate their cached user profile. When a product is updated, invalidate cached product embeddings. Event-based invalidation provides the best freshness but requires infrastructure to propagate events.

Version-based invalidation uses version numbers to track cache validity. Store data version alongside cached values. When data changes, increment the version. Queries include the expected version. If cached version matches, use cache. If not, recompute. Version-based invalidation provides precise control over staleness.

Lazy invalidation delays recomputation until the next request. When data changes, mark cache entries as stale but do not delete them. The next request detects staleness, recomputes, and updates the cache. Other requests continue using stale data briefly. Lazy invalidation spreads recomputation load over time.

Write-through caching updates cache synchronously with data updates. When data changes, update both the database and cache immediately. This ensures cache is always fresh but adds latency to write operations. Write-through works well for read-heavy workloads where write latency is acceptable.

Write-behind (write-back) caching updates cache immediately but updates database asynchronously. Writes complete fast but risk data loss if cache fails before database update. Write-behind is complex and risky for critical data but provides the best write performance.

Cache warming preloads caches before they are needed. Before deploying a new model version, warm the cache with popular items. Before traffic spikes (holiday sales), precompute and cache predictions for popular items. Cache warming eliminates cold start latency.

Different invalidation strategies serve different use cases: TTL for simplicity, event-based for freshness, version-based for precise control, and lazy for load spreading. Choose based on your data characteristics and freshness requirements.

Distributed Caching for Scale
Single-machine caches work for small scale. Distributed caches enable caching at large scale across many machines.

Redis is the most popular distributed cache. It stores data in memory for fast access. Redis supports various data structures (strings, hashes, lists, sets) and operations. Redis replication provides redundancy. Redis Cluster enables horizontal scaling across machines. Most production AI systems use Redis for caching.

Memcached is a simpler alternative to Redis. It focuses on basic key-value caching without advanced features. Memcached is faster for simple workloads but less versatile. Choose Memcached when you need only basic caching and want maximum performance.

Cache topology affects performance and reliability. A single centralized cache is simple but creates a single point of failure and potential bottleneck. Distributed caches with sharding split data across machines. Consistent hashing ensures requests for the same key always go to the same shard.

Cache aside (lazy loading) is a common pattern. Application checks cache for data. If present (cache hit), return it. If absent (cache miss), fetch from database, store in cache, and return it. Cache aside is simple and works well for read-heavy workloads.

Read-through caching abstracts database access behind the cache. Application always reads from cache. Cache handles fetching from database on misses. This simplifies application code but requires cache libraries that support read-through.

Local caching near compute instances reduces network latency. Use a local in-process cache for extremely hot data. Back it with distributed cache for data accessed across instances. Multi-level caching balances latency and shared state.

Cache coherence becomes important with multiple cache layers. When data changes, how do you ensure all cache layers update? Options include invalidating all layers, propagating updates through layers, or accepting eventual consistency where different layers briefly have different data.

Monitoring cache performance is essential. Track cache hit rate, miss rate, eviction rate, and latency. Low hit rates suggest cache is too small or TTLs are too short. High eviction rates suggest cache is undersized for working set. Monitor these metrics to optimize cache configuration.

Cache sizing requires balancing memory cost against hit rate. Larger caches improve hit rates but cost more. Use monitoring data to determine optimal cache size. A common approach: start small, measure hit rates, and increase size until hit rate improvements diminish (hitting diminishing returns).

Summary
Caching strategies for AI systems include feature caching, prediction caching, embedding caching, and intermediate result caching. Effective caching requires careful decisions about what to cache and appropriate invalidation strategies balancing freshness and performance.

Distributed caching with Redis or Memcached enables scaling caching across multiple machines. Cache patterns like cache-aside and read-through simplify implementation. Multi-level caching with local and distributed layers optimizes latency. Monitoring cache metrics guides optimization of cache size and configuration.

Key concepts to remember
Dramatic Latency Reduction - Feature caching and prediction caching can reduce latency by 10-100x for frequently accessed data
Invalidation Strategies - Time-based expiration (TTL) is simplest; event-based invalidation provides better freshness at cost of complexity
Distributed Caching Tools - Redis provides rich features; Memcached offers simpler but faster basic caching for high-throughput scenarios
Simple Pattern - Cache-aside pattern where applications check cache before database is simple and effective for read-heavy workloads
Data-Driven Optimization - Monitor hit rates and eviction rates to guide optimization of cache size and TTL configuration