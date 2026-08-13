## Hybrid and Multi-modal RAG Systems

In the previous lessons on performance optimization and monitoring, you built efficient RAG systems with advanced indexing and evaluation frameworks. While these systems perform well with dense vector embeddings, enterprise applications face two critical limitations: missing exact keyword matches that users expect, and inability to process visual content like diagrams and charts.

Dense embeddings excel at semantic relationships but can miss precise terminology. Traditional keyword search (BM25) handles exact matches well but struggles with synonyms. Additionally, enterprise content increasingly includes images, diagrams, and multimedia that pure text-based RAG cannot process.

This lesson teaches you to build hybrid retrieval systems that combine dense and sparse search methods, and multi-modal architectures that handle both text and visual content. These advanced techniques prepare your systems for complex enterprise scenarios requiring comprehensive content understanding. The next lesson will build on these foundations to explore domain-specific applications like code search and technical documentation.

Hybrid Retrieval Systems
Combining Dense and Sparse Methods
Hybrid retrieval addresses the complementary strengths and weaknesses of different search approaches:

Dense retrieval (embeddings): Excels at semantic relationships but may miss exact keyword matches
Sparse retrieval (BM25 - Best Matching 25): Perfect for exact term matching but struggles with synonyms and concepts
By combining both approaches, you create systems that handle both conceptual queries ("vacation policies") and precise searches ("PTO-2024-Q3-POLICY").

Hybrid Dense-Sparse Retrieval System

Below example demonstrates how to combine BM25 keyword search with dense embeddings to create a more robust retrieval system that handles both exact matches and semantic similarity.

```python
import numpy as np
import re
from typing import Dict, List, Tuple
from dataclasses import dataclass
from collections import Counter
import math

@dataclass
class Document:
  doc_id: str
  title: str
  content: str

class HybridRetriever:
  """Hybrid retrieval combining dense and sparse methods"""

  def __init__(self, dense_weight: float = 0.6, sparse_weight: float = 0.4):
      self.dense_weight = dense_weight
      self.sparse_weight = sparse_weight
      self.documents: Dict[str, Document] = {}
      self.doc_embeddings: Dict[str, np.ndarray] = {}
      self.bm25_stats = {}

  def _generate_embedding(self, text: str) -> np.ndarray:
      """Simple mock embedding (use real embedding model in practice)"""
      # Hash-based embedding for demonstration
      import hashlib
      text_hash = hashlib.md5(text.encode()).hexdigest()
      embedding = np.array([int(text_hash[i:i+2], 16) / 255.0 for i in range(0, 32, 2)])
      return embedding / np.linalg.norm(embedding)

  def _bm25_score(self, query: str, doc: Document) -> float:
      """Calculate BM25 score for document"""
      query_terms = re.findall(r'\b\w+\b', query.lower())
      doc_terms = re.findall(r'\b\w+\b', doc.content.lower())
      doc_term_counts = Counter(doc_terms)

      score = 0.0
      for term in query_terms:
          if term in doc_term_counts:
              tf = doc_term_counts[term]
              # Simplified BM25 calculation
              idf = math.log(len(self.documents) / max(1, self.bm25_stats.get(term, 1)))
              score += idf * tf / (tf + 1.5)  # Simplified BM25 formula

      return score

  def add_documents(self, documents: List[Document]) -> None:
      """Add documents to hybrid index"""
      for doc in documents:
          self.documents[doc.doc_id] = doc
          self.doc_embeddings[doc.doc_id] = self._generate_embedding(doc.content)

      # Calculate BM25 statistics
      all_terms = []
      for doc in documents:
          terms = re.findall(r'\b\w+\b', doc.content.lower())
          all_terms.extend(terms)

      term_counts = Counter(all_terms)
      self.bm25_stats = {
          'avg_length': len(all_terms) / len(documents),
          **{term: count for term, count in term_counts.items()}
      }

  def search(self, query: str, top_k: int = 5) -> List[Tuple[str, float, str]]:
      """Hybrid search combining dense and sparse results"""
      query_embedding = self._generate_embedding(query)
      results = []

      for doc_id, doc in self.documents.items():
          # Dense similarity
          dense_score = np.dot(query_embedding, self.doc_embeddings[doc_id])

          # Sparse BM25 score
          sparse_score = self._bm25_score(query, doc)

          # Normalize and combine scores
          dense_norm = max(0, min(1, dense_score))  # Clamp to [0,1]
          sparse_norm = max(0, min(1, sparse_score / 10))  # Simple normalization

          hybrid_score = self.dense_weight * dense_norm + self.sparse_weight * sparse_norm

          explanation = f"Dense: {dense_norm:.2f}, Sparse: {sparse_norm:.2f}"
          results.append((doc_id, hybrid_score, explanation))

      # Sort by hybrid score
      results.sort(key=lambda x: x[1], reverse=True)
      return results[:top_k]

# Demonstration
documents = [
  Document("doc1", "Employee Vacation Policy",
           "Employees receive 20 vacation days per year. Submit requests through HR system."),
  Document("doc2", "Remote Work Guidelines",
           "Work from home up to 3 days per week with manager approval."),
  Document("doc3", "Expense Reimbursement",
           "Business expenses reimbursed with receipts within 30 days.")
]

retriever = HybridRetriever()
retriever.add_documents(documents)

# Test queries
test_queries = ["vacation policy", "working from home", "expense receipts"]
for query in test_queries:
  print(f"\nQuery: '{query}'")
  results = retriever.search(query, top_k=2)
  for i, (doc_id, score, explanation) in enumerate(results, 1):
      doc = retriever.documents[doc_id]
      print(f"  {i}. {doc.title} (Score: {score:.3f}, {explanation})")
```

Key Learning Points:

Hybrid retrieval combines complementary strengths of dense and sparse methods
Score normalization ensures fair combination of different scoring approaches
Dense retrieval excels at semantic matching while sparse retrieval handles exact keywords
Weighting parameters can be tuned based on domain requirements and query patterns
Try It: Experiment with different dense/sparse weight combinations (try 0.8/0.2 vs 0.4/0.6) and observe how they affect retrieval results for different query types.

Multi-modal RAG Systems
Handling Text and Visual Content
Enterprise documents contain both text and visual elements like diagrams, charts, and screenshots. Multi-modal RAG systems process and retrieve from both content types, enabling comprehensive enterprise search.

Multi-modal systems require specialized embedding approaches for different content types:

```python
# Multi-modal document structure
@dataclass
class MultimodalDocument:
  doc_id: str
  title: str
  content_type: str  # "text", "image", or "mixed"
  text_content: Optional[str] = None
  image_description: Optional[str] = None

# Embedding generation for different modalities
def generate_text_embedding(text: str) -> np.ndarray:
  # Use sentence-transformers or similar
  return model.encode(text)

def generate_image_embedding(image_description: str) -> np.ndarray:
  # Use CLIP or similar vision-language models
  return clip_model.encode_text(image_description)

def combine_embeddings(text_emb: np.ndarray, image_emb: np.ndarray,
                    text_weight: float = 0.6) -> np.ndarray:
  # Weighted concatenation strategy
  combined = np.concatenate([text_emb * text_weight, image_emb * (1 - text_weight)])
  return combined / np.linalg.norm(combined)

# Cross-modal search example
query = "company organization chart"
text_embedding = generate_text_embedding(query)
# This can find both text documents and image descriptions that match
results = search_multimodal_index(text_embedding, top_k=5)
```

Key Learning Points:

Multi-modal RAG systems process both text and visual content for comprehensive search
Cross-modal search enables finding images using text queries and vice versa
Combined embeddings capture relationships between different content modalities
Image descriptions and alt-text significantly improve visual content searchability
Common Pitfalls and Best Practices
Poor Score Normalization: Combining retrieval scores without proper normalization leads to one method dominating results. Always normalize scores to comparable ranges before fusion.

Over-Complicating Query Routing: Start with simple heuristics and add complexity only when needed for specific use cases to avoid introducing latency and errors.

Ignoring Modality Mismatch: Use specialized models for different content types rather than forcing all content into the same embedding space.

Inadequate Fallback Strategies: When hybrid approaches fail, systems should gracefully degrade to simpler methods rather than returning no results.

Summary
Hybrid and multi-modal RAG systems represent the next evolution of enterprise information retrieval. By combining dense semantic search with sparse keyword matching, these systems capture both conceptual relationships and exact term matches that users expect.

Multi-modal capabilities extend RAG beyond text to include images, diagrams, and other visual content that contains critical enterprise information. Complex query processing ensures that sophisticated user queries are properly understood and routed to appropriate retrieval strategies.

In the next lesson, you will explore domain-specific RAG applications that leverage these hybrid and multi-modal foundations for specialized use cases like code search and technical documentation systems.

Key concepts to remember
Hybrid retrieval combines dense and sparse methods to leverage complementary strengths
Multi-modal RAG enables comprehensive search across text, images, and mixed content
Score normalization is crucial for fair combination of different retrieval methods
Complex query processing requires analysis of query complexity and appropriate routing
Different query types benefit from specialized processing strategies