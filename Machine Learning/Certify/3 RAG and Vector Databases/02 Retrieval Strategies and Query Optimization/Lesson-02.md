## Chunking & Indexing

In the previous lesson, you learned about retrieval methods and similarity metrics. Now we address a fundamental challenge: most documents are longer than what embedding models can process or what fits effectively in an LLM's context window.

Consider a research paper that's 20 pages long. Embedding models typically handle only 512 tokens (roughly 300-400 words), and even if you could embed the entire document, providing it as context would overwhelm the LLM and dilute relevant information.

Document chunking solves this problem by breaking large documents into smaller, manageable pieces that maintain semantic coherence. The quality of your chunking strategy directly impacts retrieval accuracy and, consequently, your RAG system's response quality.

This lesson explores chunking strategies, their impact on retrieval performance, and indexing optimization techniques that prepare your documents for the complete RAG pipeline we'll build in the next lesson.

Why Chunking Matters
Chunking serves critical purposes in RAG systems by addressing both technical constraints and quality requirements:

Technical Constraints:

Token Limits: Embedding models have maximum input lengths (typically 512 tokens)
Context Windows: LLMs have limited context capacity for effective processing
Memory Efficiency: Smaller chunks require less memory for storage and processing

Quality Improvements:

Precision: Smaller chunks contain more focused information relevant to specific queries
Relevance: Reduces noise by avoiding large blocks of mixed content
Granularity: Enables retrieval of specific facts rather than entire documents
Example: Poor vs. Good Chunking

Poor Chunking:

```python
Chunk: "Our company was founded in 1995... We specialize in software development...
Our refund policy states that customers can return products within 30 days...
We also offer technical support..."

Query: "What is your refund policy?"
Result: Relevant information buried in irrelevant context
```

Good Chunking:

```python
Chunk 1: "Company History: Founded in 1995..."
Chunk 2: "Refund Policy: Customers can return products within 30 days for a full refund."
Chunk 3: "Technical Support: Available through email and phone..."

Query: "What is your refund policy?"
Result: Directly retrieves Chunk 2 with focused, relevant information
```

Chunking Strategies
Fixed-Size Chunking
The simplest approach divides text into chunks of predetermined size.

Advantages:

Simple to implement and predictable chunk sizes
Fast processing with minimal computational overhead

Disadvantages:

May split sentences or concepts inappropriately
No consideration of semantic boundaries
Sentence-Based Chunking
This approach respects sentence boundaries, grouping complete sentences together until reaching a target size.

Advantages:

Preserves sentence integrity and readability
Natural semantic boundaries
Better context preservation than fixed-size chunking

Disadvantages:

Variable chunk sizes may affect processing consistency
Still may split related concepts across chunks

Paragraph-Based Chunking
Groups content by paragraphs, which often represent coherent topics or ideas.

Advantages:

Respects natural content organization
Maintains topical coherence
Good for structured documents with clear sections

Disadvantages:

Highly variable chunk sizes
May create very large or very small chunks
Depends on document structure and formatting

Semantic Chunking
Advanced approach that groups content based on semantic similarity, ensuring related concepts stay together.

Semantic Chunking Implementation

Below example demonstrates how to use embeddings to group semantically related sentences, producing more coherent chunks for better retrieval.

```python

from sentence_transformers import SentenceTransformer
import numpy as np
from sklearn.metrics.pairwise import cosine_similarity

def semantic_chunking(text, similarity_threshold=0.5):
  """
  Split text into semantically coherent chunks

  similarity_threshold: How similar sentences need to be to group together (0-1)
  Higher threshold = stricter grouping, more chunks
  """
  model = SentenceTransformer('all-MiniLM-L6-v2', local_files_only=True)

  sentences = [s.strip() for s in text.split('.') if s.strip()]
  embeddings = model.encode(sentences)

  chunks = []
  current_chunk = [sentences[0]]
  current_embedding = embeddings[0:1]

  for i in range(1, len(sentences)):
      sentence_embedding = embeddings[i:i+1]

      # Calculate the "center" of current chunk's meaning
      chunk_centroid = np.mean(current_embedding, axis=0).reshape(1, -1)

      # Cosine similarity: 0 (completely different) to 1 (identical meaning)
      similarity = cosine_similarity(sentence_embedding, chunk_centroid)[0][0]

      if similarity >= similarity_threshold:
          # Similar enough - add to current chunk
          current_chunk.append(sentences[i])
          current_embedding = np.vstack([current_embedding, sentence_embedding])
      else:
          # Too different - start new chunk
          chunks.append('. '.join(current_chunk) + '.')
          current_chunk = [sentences[i]]
          current_embedding = sentence_embedding

  if current_chunk:
      chunks.append('. '.join(current_chunk) + '.')

  return chunks

# Test with mixed topics
document = """
Python is a high-level programming language. It emphasizes code readability and simplicity.
Python supports multiple programming paradigms. Machine learning libraries like TensorFlow use Python.
JavaScript runs in web browsers. It enables interactive web pages.
Node.js allows JavaScript to run on servers.
"""

chunks = semantic_chunking(document, similarity_threshold=0.3)
for i, chunk in enumerate(chunks):
  print(f"Chunk {i+1}: {chunk}\n")
```

Key Learning Points:

Uses embedding similarity to group related content
Adapts to content structure automatically
Produces more coherent chunks than fixed-size methods
Try It: Experiment with different similarity thresholds to see how it affects chunk boundaries.

Advantages:

Groups semantically related content together
Improves retrieval relevance by maintaining context
Disadvantages:

Computationally expensive due to embedding generation
Requires careful parameter tuning
Overlap Strategies

Overlapping Chunks

Below example shows how overlap ensures that concepts spanning chunk boundaries are preserved, improving retrieval recall.

```python
def chunking_with_overlap(text, chunk_size=200, overlap_size=50):
  """Create overlapping chunks to maintain context continuity"""
  chunks = []
  start = 0

  while start < len(text):
      end = min(start + chunk_size, len(text))
      chunk = text[start:end].strip()

      if chunk:
          chunks.append(chunk)

      start += chunk_size - overlap_size
      if end >= len(text):
          break

  return chunks

# Test with sample text
sample_text = """
Machine learning algorithms require large datasets for training. The quality of training data directly impacts model performance. Poor quality data leads to poor model predictions. Data preprocessing is essential for cleaning and preparing datasets.
"""

chunks = chunking_with_overlap(sample_text, chunk_size=150, overlap_size=40)
print(f"Number of overlapping chunks: {len(chunks)}")
for i, chunk in enumerate(chunks):
  print(f"\nChunk {i+1}: {chunk}")
```

Key Learning Points:

Preserves concepts that span chunk boundaries
Improves retrieval recall for edge cases
Trade-off: increases storage requirements
Try It: Experiment with different overlap sizes to see their impact on chunk content.

Indexing Optimization Techniques
Efficient indexing is crucial for production RAG systems handling large document collections.

Batch Processing
Process documents in batches to improve efficiency and resource utilization: Batch Processing:

```python
# Process documents in batches for better performance
def batch_indexing(documents, embedding_model, batch_size=32):
  all_embeddings = []
  for i in range(0, len(documents), batch_size):
      batch = documents[i:i + batch_size]
      batch_embeddings = embedding_model.encode(batch)
      all_embeddings.extend(batch_embeddings)
  return all_embeddings
```

Metadata Enhancement
Metadata adds contextual information to chunks, enabling more precise retrieval and powerful filtering capabilities. Without metadata, you can only search by content similarity, but with metadata, you can combine semantic search with structured filtering.

Why Metadata Matters:

Precision: Filter results by document type, date, or section
Context: Preserve document structure and source information
User Control: Allow users to specify search constraints

Metadata Enhancement Example:

```python
def create_enhanced_chunk(content, source_info, chunk_index):
  """Create a chunk with comprehensive metadata"""
  return {
      'content': content,
      'metadata': {
          # Source information
          'source_file': source_info['filename'],
          'document_title': source_info['title'],
          'document_type': source_info['type'],  # 'manual', 'faq', 'policy'
          'created_date': source_info['date'],

          # Chunk-specific data
          'chunk_index': chunk_index,
          'chunk_size': len(content),
          'section': extract_section_from_content(content),

          # Searchable attributes
          'keywords': extract_keywords(content),
          'language': 'en',
          'category': determine_category(content)
      }
  }

# Example usage
chunk_with_metadata = create_enhanced_chunk(
  content="Our refund policy allows returns within 30 days...",
  source_info={
      'filename': 'customer_policies.pdf',
      'title': 'Customer Service Guidelines',
      'type': 'policy',
      'date': '2024-01-15'
  },
  chunk_index=5
)
```

Filtering Examples:

```python
# Find only recent policy documents
policy_chunks = [c for c in chunks if c['metadata']['document_type'] == 'policy'
               and c['metadata']['created_date'] > '2024-01-01']

# Search within specific document sections
intro_chunks = [c for c in chunks if c['metadata']['section'] == 'Introduction']
```

Incremental Indexing
In production systems, you often need to add new documents without rebuilding the entire index from scratch. Incremental indexing allows you to append new content efficiently while keeping existing embeddings intact.

Why Incremental Indexing Matters:

Performance: Avoid re-processing thousands of existing documents
Cost: Save computational resources and embedding API calls
Availability: Keep the system running while adding new content
Incremental Indexing Implementation:

```python
class IncrementalIndex:
  def __init__(self, embedding_model):
      self.embedding_model = embedding_model
      self.chunks = []
      self.embeddings = []
      self.metadata = []

  def add_document(self, document, source_info):
      """Add new document to existing index without rebuilding"""
      # Process only the new document
      new_chunks = self._chunk_document(document, source_info)
      new_embeddings = self.embedding_model.encode([c['content'] for c in new_chunks])

      # Append to existing collections
      self.chunks.extend(new_chunks)
      self.embeddings.extend(new_embeddings)
      self.metadata.extend([c['metadata'] for c in new_chunks])

  def _chunk_document(self, document, source_info):
      """Helper method to chunk and add metadata"""
      # Use your preferred chunking strategy
      chunks = paragraph_based_chunking(document)
      return [{'content': chunk, 'metadata': source_info} for chunk in chunks]
```

Common Pitfalls
Chunk Size Issues: Avoid chunks smaller than 100 words (lose context) or larger than 1000 words (dilute relevance). Aim for 200-500 words.

Ignoring Document Structure: Blindly splitting text without considering semantic boundaries leads to fragmented chunks that hurt retrieval performance.

No Overlap Strategy: Implement 10-20% overlap to ensure important information is not split across chunk boundaries.

Missing Metadata: Always preserve document structure information (source, section, timestamp) in chunk metadata for better filtering and ranking.

Summary
Effective chunking and indexing form the foundation of successful RAG systems. The choice of chunking strategy depends on your document types, query patterns, and performance requirements. Semantic chunking provides the best retrieval accuracy but requires more computational resources, while simpler approaches like sentence-based chunking offer good performance with lower complexity.

Indexing optimization techniques such as batch processing, metadata enhancement, and incremental updates enable production systems to handle large document collections efficiently while maintaining retrieval quality.

Key concepts to remember
Chunking strategy directly impacts retrieval accuracy and system performance
Semantic chunking provides superior context preservation but requires more computational resources
Metadata enhancement and overlap strategies improve retrieval precision and recall
Production systems require careful consideration of memory management and processing efficiency

