## RAG Pipeline Architecture

Introduction
In the previous lessons, you learned about retrieval methods, similarity metrics, and chunking strategies. Now it's time to bring everything together into a complete, working RAG pipeline.

A RAG pipeline is more than just connecting components—it's an orchestrated system where document processing, vector storage, retrieval, and generation work together seamlessly. Understanding the architecture, data flow, and interaction patterns between components is essential for building reliable production systems.

This lesson teaches you to build a production-ready RAG pipeline, understand component interactions, and implement essential debugging practices. You'll learn to identify bottlenecks, troubleshoot common issues, and ensure reliable performance in production environments.

RAG Pipeline Overview
A RAG pipeline operates in two main phases:

Indexing Phase (Offline)

```python
Documents → Chunking → Embedding → Vector Storage
```

Document Processing: Extract and clean text from various sources
Chunking: Split documents using chunking strategies
Embedding Generation: Convert chunks to vectors using embedding models
Vector Storage: Index embeddings for fast similarity search

Retrieval-Generation Phase (Online)

```python
User Query → Embed Query → Retrieve → Generate → Response
```

Query Embedding: Convert user question to vector representation
Similarity Search: Find relevant chunks using retrieval methods
Context Assembly: Combine retrieved chunks into coherent context
Response Generation: Use LLM to generate answer from context

Core Components Integration
The complete RAG pipeline includes these essential components:

Document Processor: Handles text extraction, cleaning, and chunking
Embedding Model: Converts text into dense vector representations
Vector Database: Stores embeddings and enables fast similarity search
Retriever: Finds relevant documents for queries using similarity metrics
LLM Generator: Produces final responses using retrieved context
Pipeline Orchestrator: Coordinates all components seamlessly

The  pipeline's effectiveness depends on how well these components work together:

Document Processor + Chunking: Quality chunks improve retrieval accuracy
Embedding Model + Vector Database: Consistent similarity calculations
Retriever + Generator: Relevant context produces better responses

Component Integration
Building a complete RAG pipeline requires careful integration of all components. Here's how they work together:

Complete RAG Pipeline

Below example demonstrates a complete RAG system including document indexing, retrieval, and LLM-powered response generation using a customer support knowledge base.

```python

import numpy as np
import faiss
from sentence_transformers import SentenceTransformer
import re
from typing import List, Dict, Any

class DocumentProcessor:
  """Handles text chunking and document preparation"""

  def __init__(self, max_chunk_size: int = 300):
      self.max_chunk_size = max_chunk_size

  def chunk_text(self, text: str) -> List[str]:
      """Split text into chunks preserving sentence boundaries"""
      sentences = re.split(r'(?<=[.!?])\s+', text.strip())
      chunks = []
      current_chunk = ""

      for sentence in sentences:
          if len(current_chunk) + len(sentence) <= self.max_chunk_size:
              current_chunk = (current_chunk + " " + sentence).strip()
          else:
              if current_chunk:
                  chunks.append(current_chunk)
              current_chunk = sentence

      if current_chunk:
          chunks.append(current_chunk)

      return chunks

  def prepare_documents(self, documents: List[Dict]) -> List[Dict]:
      """Process and prepare documents for indexing"""
      processed_docs = []

      for doc in documents:
          chunks = self.chunk_text(doc['text'])
          for i, chunk in enumerate(chunks):
              processed_docs.append({
                  'content': chunk,
                  'metadata': {
                      **doc['metadata'],
                      'chunk_index': i,
                      'total_chunks': len(chunks)
                  }
              })

      return processed_docs

class VectorStore:
  """Handles embedding generation and vector search"""

  def __init__(self, embedding_model_name='all-MiniLM-L6-v2'):
      self.embedding_model = SentenceTransformer(embedding_model_name, local_files_only=True)
      embedding_dim = self.embedding_model.get_sentence_embedding_dimension()
      self.index = faiss.IndexFlatIP(embedding_dim)
      self.documents = []

  def add_documents(self, docs: List[Dict]):
      """Add documents to vector store"""
      texts = [doc['content'] for doc in docs]
      embeddings = self.embedding_model.encode(texts)
      embeddings = embeddings / np.linalg.norm(embeddings, axis=1, keepdims=True)

      self.index.add(embeddings.astype('float32'))
      self.documents.extend(docs)

  def search(self, query: str, top_k: int = 3) -> List[Dict]:
      """Search for relevant documents"""
      if len(self.documents) == 0:
          return []

      query_embedding = self.embedding_model.encode([query])
      query_embedding = query_embedding / np.linalg.norm(query_embedding, axis=1, keepdims=True)

      similarities, indices = self.index.search(query_embedding.astype('float32'), top_k)

      results = []
      for similarity, idx in zip(similarities[0], indices[0]):
          if idx < len(self.documents):
              results.append({
                  **self.documents[idx],
                  'similarity': float(similarity)
              })

      return results

class ResponseGenerator:
  """Handles context creation and response generation"""

  def create_context(self, retrieved_docs: List[Dict]) -> str:
      """Combine retrieved documents into context"""
      if not retrieved_docs:
          return ""

      context_parts = []
      for i, doc in enumerate(retrieved_docs):
          context_parts.append(f"Source {i+1}: {doc['content']}")
      return "\n\n".join(context_parts)

  def generate_response(self, question: str, context: str) -> str:
      """Generate response using context"""
      if not context:
          return "I do not have enough information to answer your question."

      # Simplified response generation (in production, this would call an LLM)
      return f"Based on the available information: {context[:200]}..."

class RAGPipeline:
  """Main pipeline that orchestrates all components"""

  def __init__(self):
      self.processor = DocumentProcessor()
      self.vector_store = VectorStore()
      self.generator = ResponseGenerator()

  def add_documents(self, documents: List[Dict]):
      """Index documents into the pipeline"""
      processed_docs = self.processor.prepare_documents(documents)
      self.vector_store.add_documents(processed_docs)
      return len(processed_docs)

  def query(self, question: str, top_k: int = 3) -> Dict:
      """Execute complete RAG query"""
      # Retrieve relevant documents
      retrieved_docs = self.vector_store.search(question, top_k)

      # Generate context and response
      context = self.generator.create_context(retrieved_docs)
      response = self.generator.generate_response(question, context)

      return {
          'query': question,
          'response': response,
          'retrieved_documents': retrieved_docs,
          'sources': [doc['metadata']['source'] for doc in retrieved_docs],
          'num_sources': len(retrieved_docs)
      }

# Demonstration
print("=== RAG Pipeline Demo ===\n")

# Initialize pipeline
rag = RAGPipeline()

# Sample customer support documents
support_docs = [
  {
      'text': "Our refund policy allows customers to return products within 30 days of purchase for a full refund. The item must be in original condition with all packaging. Digital products cannot be refunded after download.",
      'metadata': {'source': 'refund_policy', 'category': 'billing', 'last_updated': '2024-01-15'}
  },
  {
      'text': "To reset your password, go to the login page and click 'Forgot Password'. Enter your email address and we will send you a reset link. The link expires in 24 hours.",
      'metadata': {'source': 'password_help', 'category': 'account', 'last_updated': '2024-01-10'}
  },
  {
      'text': "Our premium plan includes unlimited storage, priority support, advanced analytics, and custom integrations. It costs $29.99 per month or $299.99 per year.",
      'metadata': {'source': 'pricing_info', 'category': 'billing', 'last_updated': '2024-01-20'}
  }
]

# Index documents
print("=== INDEXING PHASE ===")
total_chunks = rag.add_documents(support_docs)
print(f"Indexed {len(support_docs)} documents into {total_chunks} chunks\n")

# Test queries
print("=== QUERY PHASE ===")
test_queries = [
  "How can I get a refund?",
  "I forgot my password, what should I do?",
  "What features are included in the premium plan?"
]

for i, query in enumerate(test_queries, 1):
  print(f"Query {i}: {query}")
  result = rag.query(query, top_k=2)

  print(f"Response: {result['response']}")
  print(f"Sources: {', '.join(result['sources'])}")
  similarity_scores = [f"{doc['similarity']:.3f}" for doc in result['retrieved_documents']]
  print(f"Similarity scores: {similarity_scores}")
  print("-" * 80)
```

Try It: Experiment with different customer support queries to see how the complete RAG pipeline retrieves relevant information and generates natural responses using OpenAI's GPT model.

Pipeline Debugging and Troubleshooting
Common Issues and Solutions
Poor Retrieval Quality
Symptoms: Retrieved documents do not match query intent, low similarity scores

Diagnosis: Check if similarity scores and content relevance align with expectations

```python
# Target: Similarity scores above 0.5 for relevant content, decreasing scores for less relevant
query_result = rag.query("How do I reset my password?", top_k=5)
for doc in query_result['retrieved_documents']:
  print(f"Score: {doc['similarity']:.3f} - {doc['content'][:100]}...")

# What to look for:
# - Top result should contain password reset information with score > 0.5
# - Scores should decrease from most to least relevant
# - Irrelevant content should have scores < 0.3
```

Solutions:

Improve chunking strategy (use semantic chunking for better context preservation)
Use domain-specific embedding models
Implement query expansion for better matching
Context Window Overflow
Symptoms: LLM truncates context, degraded response quality

Diagnosis: Check if total context exceeds token limits

```python
# Target: Stay under 4000 tokens while keeping highest-relevance documents
def estimate_tokens(retrieved_docs):
  total_tokens = sum(len(doc['content']) * 0.25 for doc in retrieved_docs)
  print(f"Total estimated tokens: {total_tokens:.0f}")
  for i, doc in enumerate(retrieved_docs):
      doc_tokens = len(doc['content']) * 0.25
      print(f"Doc {i+1}: {doc_tokens:.0f} tokens, similarity: {doc['similarity']:.3f}")
  return total_tokens

# Check if context is too large
retrieved_docs = rag.query("your query", top_k=5)['retrieved_documents']
estimate_tokens(retrieved_docs)
```

Solutions:

Prioritize highest-relevance documents by taking top-scoring results first
Implement dynamic context truncation to stay within token limits
Use document summarization to compress large chunks while preserving key information
Split long documents into smaller, focused chunks during indexing phase

Inconsistent Performance
Symptoms: Variable quality across different queries or topics

Diagnosis: Identify which query types or topics perform poorly

```python
# Target: Consistent similarity scores (>0.4) across different query types
test_queries = [
  "How do I reset my password?",  # Account queries
  "What is your refund policy?",  # Policy queries
  "How much does premium cost?"   # Pricing queries
]

performance_logs = []
for query in test_queries:
  result = rag.query(query)
  avg_similarity = np.mean([doc['similarity'] for doc in result['retrieved_documents']])
  performance_logs.append({'query': query, 'avg_similarity': avg_similarity})

# What to look for:
for log in performance_logs:
  status = "✓ Good" if log['avg_similarity'] > 0.4 else "⚠ Poor"
  print(f"{status}: '{log['query']}' - avg similarity: {log['avg_similarity']:.3f}")

# Poor performance (<0.4) indicates missing content or embedding issues for that topic
```

Solutions:

Add more documents covering poorly performing topics
Use topic-specific embedding models for specialized domains
Implement query preprocessing to standardize question formats
Create topic-specific indexes for different content categories

Production Considerations
When deploying RAG pipelines in production, address these key areas:

Error Handling and Monitoring
Graceful Degradation: Implement fallback responses when components fail rather than system crashes
Error Logging: Capture detailed error information for debugging while showing user-friendly messages
Health Checks: Monitor embedding model availability, vector database connectivity, and LLM API status
Performance Metrics: Track response times, similarity scores, and user satisfaction rates
Alert Systems: Set up notifications for system failures, high error rates, or performance degradation

Scalability Patterns
Async Processing: Handle multiple queries concurrently
Caching: Cache frequently requested embeddings and results
Batch Operations: Process multiple documents efficiently
Load Balancing: Distribute queries across multiple pipeline instances

Common Pitfalls
Tight Component Coupling: Hardcoding dependencies makes systems brittle. Use modular design with clear interfaces between components.

Missing Error Handling: RAG pipelines have multiple failure points. Implement graceful degradation and meaningful error messages.

Ignoring Performance: Each component adds latency. Set performance targets and optimize the critical path.

Insufficient Testing: Test end-to-end pipeline behavior with realistic data, not just individual components.

Summary
Building a production-ready RAG pipeline requires careful integration of multiple components, comprehensive error handling, and systematic debugging approaches. The architecture must balance performance, reliability, and maintainability while providing mechanisms for monitoring and continuous improvement.

The key to successful RAG implementation lies in understanding how each component affects the others and implementing robust testing and monitoring from the beginning. Start with a simple implementation, add complexity gradually, and always maintain clear visibility into system performance.

In the next module, we will explore how to build RAG-powered applications that integrate these pipelines into user-facing systems with proper interfaces and user experience considerations.

Key concepts to remember
RAG pipelines require careful orchestration of indexing and retrieval-generation phases
Component integration patterns determine overall system reliability and performance
Systematic debugging and monitoring are essential for production deployments
End-to-end testing validates pipeline behavior across different scenarios