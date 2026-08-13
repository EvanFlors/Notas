Retrieval Strategies and Query Optimization
Your team is building a technical documentation search system for a software company. Users search for API endpoints, code examples, and troubleshooting guides. The system needs to handle both exact technical terms and natural language questions.


A user searches for 'API authentication' but dense retrieval misses documents containing the exact endpoint name 'auth/v2/token'. What retrieval approach would capture this?

Use a larger embedding model with more dimensions.

Add sparse retrieval (TF-IDF or BM25) for keyword matching.

Increase the number of retrieved documents.

Fine-tune the embedding model on technical terms.
When comparing query and document vectors, cosine similarity returns 0.85 and Euclidean distance returns 0.3. Why is cosine similarity preferred for text retrieval?

Cosine similarity is faster to compute.

Cosine similarity ignores vector magnitude, focusing on direction.

Euclidean distance cannot handle high-dimensional vectors.

Cosine similarity provides better semantic understanding.
Correct Answer!
Long documents have larger vectors but cosine similarity focuses on meaning direction, not length. This prevents bias toward longer texts.

The team chunks a 5,000-word API documentation into 200-word segments with no overlap. Users report missing information about rate limiting that spans chunk boundaries. What should be done?

Reduce chunk size to 100 words.

Implement 10-20% overlap between consecutive chunks.

Use semantic chunking instead of fixed-size chunks.

Increase chunk size to 500 words.
Correct Answer!
Overlap ensures concepts spanning boundaries appear in multiple chunks, improving retrieval recall without losing context.

A RAG pipeline takes 2 seconds per query: 50ms for embedding, 100ms for retrieval, 1,800ms for LLM generation, 50ms for formatting. Where should optimization focus?

Optimize embedding generation by caching common queries.

Optimize LLM generation by using streaming or smaller models.

Optimize retrieval by switching from HNSW to flat index.

Optimize all components equally for balanced improvement.
Correct Answer!
LLM generation is 90% of latency (1,800ms). Streaming responses or using faster models provides the biggest impact.

A complete RAG pipeline retrieves documents with similarity scores of 0.42, 0.39, and 0.35. The generated response is vague and generic. What is the most likely cause?

The LLM model is too small and needs upgrading.

Retrieved documents have low relevance to the query.

The context window is too small for the LLM.

The vector database needs reindexing.
Correct Answer!
Scores below 0.5 suggest weak matches. Poor retrieval provides irrelevant context, causing generic responses.

SkillUp | Hackerrank