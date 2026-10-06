Performance Optimization and Scalability
Your company's RAG system currently handles 100K documents with flat index search. The business is scaling to 5 million documents over the next quarter. Query latency is currently 80ms but must stay under 100ms at scale. The system runs on a single server with 32GB RAM.


With 5 million 768-dimensional vectors, which indexing strategy should replace the flat index?

Keep the flat index but upgrade to a server with more RAM.

Implement HNSW indexing for fast approximate search.

Split documents into multiple smaller flat indexes.

Reduce vector dimensions to speed up flat index search.
Correct Answer!
HNSW provides O(log n) search with 95-99% recall, enabling sub-100ms queries at million-vector scale.

After implementing HNSW with default parameters, recall drops to 85% (15% of relevant documents missing). What HNSW parameter adjustment would improve recall?

Increase ef_construction to build more graph connections.

Decrease M (number of connections per node).

Use a smaller vector dimension to improve accuracy.

Switch from HNSW to IVF indexing.
Correct Answer!
Higher ef_construction creates denser graphs with more paths to each node, improving recall at the cost of longer build time.

Memory usage spikes when adding new documents to the HNSW index. What causes this?

HNSW stores graph connections in addition to vectors.

The embedding model loads into memory during indexing.

Vector databases duplicate data during indexing.

The system is creating temporary backup files.
Correct Answer!
HNSW indexes include multi-layer graphs with node connections, requiring 30-50% more memory than flat indexes.

Average query latency is 120ms: 20ms embedding, 80ms retrieval, 20ms post-processing. Target is 100ms. Which optimization provides the most impact?

Cache query embeddings to eliminate embedding time.

Optimize retrieval by tuning index parameters or using metadata filters.

Optimize post-processing by removing unnecessary steps.

Optimize all components equally for balanced improvement.
Correct Answer!
Retrieval is 67% of latency. Optimizing parameters or pre-filtering can reduce it by 20-30ms, meeting the target.

The RAG system serves global users. Users in Asia experience 300ms latency while US users see 80ms. What architectural change would help?

Upgrade to faster HNSW indexing parameters.

Deploy regional vector database replicas closer to users.

Use a CDN to cache query results.

Switch to a different vector database vendor.
Correct Answer!
Geographic distribution reduces network latency. Regional replicas serve users from nearby locations.