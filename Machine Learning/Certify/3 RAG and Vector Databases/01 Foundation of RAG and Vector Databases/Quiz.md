Foundations of RAG and Vector Databases
Your company is building a customer support chatbot that needs to answer questions about product features, refund policies, and technical documentation. The team is evaluating whether to use RAG, fine-tuning, or a hybrid approach.


Why is RAG preferred over fine-tuning for this customer support chatbot?

RAG responses are faster than fine-tuned models.

RAG allows easy updates when policies change without retraining.

RAG uses less computational resources overall.

RAG provides better reasoning capabilities.
The team notices the chatbot confidently states incorrect refund timeframes. What RAG component would address this?

Using a more powerful embedding model.

Retrieving verified policy documents before generating responses.

Increasing the LLM temperature parameter.

Fine-tuning the model on company data.
Correct Answer!
RAG grounds responses in retrieved documents, preventing hallucinations by providing actual policy content as context.

The system uses 'all-MiniLM-L6-v2' for embeddings during indexing. A developer wants to switch to 'all-mpnet-base-v2' for better accuracy. What must be done?

Only re-embed new documents with the new model.

Re-embed all existing documents with the new model.

Apply a conversion function to old embeddings.

Use both models and average their similarity scores.
Correct Answer!
Each embedding model creates its own meaning space. All documents must use the same model for accurate similarity comparisons.

When searching for 'refund policy', the system retrieves documents about 'returns and exchanges' with high similarity scores despite different words. What makes this possible?

The vector database uses fuzzy string matching.

Embeddings place semantically similar concepts close in vector space.

The LLM expands the query to include synonyms.

The system maintains a manual synonym dictionary.
Correct Answer!
Embeddings convert text to vectors where similar meanings cluster together, enabling semantic search beyond exact keywords.

Your RAG system indexes 1 million 768-dimensional vectors. Approximate search with HNSW returns results in 50ms with 97% recall. Why use approximate search instead of exact search?

Approximate search uses less memory than exact search.

Exact search would take several seconds per query.

Approximate search provides better semantic understanding.

Exact search cannot handle high-dimensional vectors.
Correct Answer!
Brute force search is O(n) complexity. With 1M vectors, exact search is too slow for production. Approximate indexes trade 3% accuracy for 100x speed.

SkillUp | Hackerrank