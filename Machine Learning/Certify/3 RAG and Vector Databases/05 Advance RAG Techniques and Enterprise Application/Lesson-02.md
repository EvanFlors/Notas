## Self-RAG and Adaptive Systems

In the previous lesson on hybrid and multi-modal RAG systems, you learned to combine different retrieval approaches and handle diverse content types. While these systems significantly improve retrieval capabilities, they still follow a static approach: retrieve documents, then generate responses without considering whether retrieval was necessary or successful.

Traditional RAG systems suffer from two fundamental limitations: they always retrieve regardless of query complexity, and they can not self-assess the quality of their retrieval or generation steps. Simple questions like "What is the capital of France?" do not require document retrieval, while complex queries might need multiple retrieval attempts with refined search strategies.

This lesson introduces Self-RAG (Self-Reflective Retrieval-Augmented Generation) and adaptive systems that make dynamic decisions about when to retrieve, how to validate their outputs, and how to iteratively improve through feedback loops. These systems represent the cutting edge of intelligent information retrieval, capable of self-assessment and continuous improvement. The next lesson will explore enterprise security and compliance considerations for these advanced systems.

Self-RAG Architecture and Dynamic Retrieval
Understanding Self-RAG Components
Self-RAG extends traditional RAG with reflection tokens that enable self-evaluation of decisions and outputs. The system uses four key mechanisms: Retrieve (decides if retrieval is needed), ISREL (Is Relevant) (evaluates passage relevance), ISSUP (Is Supported) (checks response support), and ISUSE (Is Useful) (assesses response quality).

This self-reflection enables dynamic behavior where systems adapt retrieval strategies based on query complexity and knowledge confidence.

Self-RAG System with Reflection Tokens

Below example demonstrates how to build a Self-RAG system that makes dynamic retrieval decisions and validates its outputs through reflection mechanisms.

```python
import re
import numpy as np
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
from enum import Enum

class ReflectionToken(Enum):
  RETRIEVE_YES = "RETRIEVE_YES"
  RETRIEVE_NO = "RETRIEVE_NO"
  ISREL_RELEVANT = "ISREL_RELEVANT"
  ISREL_IRRELEVANT = "ISREL_IRRELEVANT"
  ISSUP_SUPPORTED = "ISSUP_SUPPORTED"
  ISSUP_PARTIAL = "ISSUP_PARTIAL"
  ISSUP_UNSUPPORTED = "ISSUP_UNSUPPORTED"
  ISUSE_USEFUL = "ISUSE_USEFUL"
  ISUSE_UNCLEAR = "ISUSE_UNCLEAR"

@dataclass
class RetrievalCandidate:
  content: str
  relevance_score: float
  source: str

@dataclass
class GenerationResult:
  response: str
  reflection_tokens: List[ReflectionToken]
  confidence_score: float
  retrieved_docs: List[RetrievalCandidate]

class SelfRAGSystem:
  """Self-Reflective RAG system with dynamic retrieval and validation"""

  def __init__(self, knowledge_threshold: float = 0.7):
      self.knowledge_threshold = knowledge_threshold
      self.document_store = {}
      self.query_patterns = {
          'factual': ['what is', 'who is', 'when did', 'where is'],
          'complex': ['how to', 'explain', 'compare', 'analyze'],
          'definitional': ['define', 'meaning of', 'definition']
      }

  def _classify_query_complexity(self, query: str) -> Tuple[str, float]:
      """Classify query complexity and estimate knowledge confidence"""
      query_lower = query.lower()

      # Simple pattern matching for demonstration
      for pattern_type, patterns in self.query_patterns.items():
          if any(pattern in query_lower for pattern in patterns):
              if pattern_type == 'factual':
                  return pattern_type, 0.8  # High confidence for factual queries
              elif pattern_type == 'definitional':
                  return pattern_type, 0.7  # Medium confidence
              else:
                  return pattern_type, 0.4  # Low confidence for complex queries

      return 'unknown', 0.3  # Low confidence for unknown patterns

  def _should_retrieve(self, query: str) -> Tuple[bool, ReflectionToken]:
      """Decide whether retrieval is necessary based on query and confidence"""
      query_type, confidence = self._classify_query_complexity(query)

      # Simple factual queries with high confidence do not need retrieval
      if confidence > self.knowledge_threshold and query_type == 'factual':
          return False, ReflectionToken.RETRIEVE_NO

      # Complex queries or low confidence require retrieval
      return True, ReflectionToken.RETRIEVE_YES

  def _retrieve_documents(self, query: str, top_k: int = 3) -> List[RetrievalCandidate]:
      """Simulate document retrieval with relevance scoring"""
      # Mock document store for demonstration
      mock_docs = [
          "Self-RAG uses reflection tokens to evaluate retrieval necessity and response quality.",
          "Traditional RAG systems always retrieve documents regardless of query complexity.",
          "Adaptive systems can improve through iterative feedback and query refinement.",
          "Vector databases store embeddings for semantic similarity search.",
          "Machine learning models require training data and computational resources."
      ]

      # Simple keyword-based relevance for demonstration
      candidates = []
      for i, doc in enumerate(mock_docs):
          # Calculate basic relevance score
          query_words = set(query.lower().split())
          doc_words = set(doc.lower().split())
          relevance = len(query_words.intersection(doc_words)) / len(query_words.union(doc_words))

          if relevance > 0.1:  # Basic threshold
              candidates.append(RetrievalCandidate(
                  content=doc,
                  relevance_score=relevance,
                  source=f"doc_{i}"
              ))

      # Sort by relevance and return top_k
      candidates.sort(key=lambda x: x.relevance_score, reverse=True)
      return candidates[:top_k]

  def _evaluate_relevance(self, query: str, documents: List[RetrievalCandidate]) -> List[ReflectionToken]:
      """Evaluate if retrieved documents are relevant to the query"""
      relevance_tokens = []

      for doc in documents:
          # Simple relevance check based on score threshold
          if doc.relevance_score > 0.3:
              relevance_tokens.append(ReflectionToken.ISREL_RELEVANT)
          else:
              relevance_tokens.append(ReflectionToken.ISREL_IRRELEVANT)

      return relevance_tokens

  def _generate_response(self, query: str, documents: List[RetrievalCandidate]) -> str:
      """Generate response based on query and retrieved documents"""
      if not documents:
          return f"Based on my knowledge, I can provide a general answer to: {query}"

      # Simple response generation using retrieved documents
      response = f"Based on the retrieved information: "
      for doc in documents[:2]:  # Use top 2 documents
          response += f"{doc.content} "

      return response.strip()

  def _evaluate_support(self, response: str, documents: List[RetrievalCandidate]) -> ReflectionToken:
      """Evaluate if response is supported by retrieved documents"""
      if not documents:
          return ReflectionToken.ISSUP_UNSUPPORTED

      # Simple support evaluation based on content overlap
      response_words = set(response.lower().split())
      doc_words = set()
      for doc in documents:
          doc_words.update(doc.content.lower().split())

      overlap_ratio = len(response_words.intersection(doc_words)) / len(response_words)

      if overlap_ratio > 0.6:
          return ReflectionToken.ISSUP_SUPPORTED
      elif overlap_ratio > 0.3:
          return ReflectionToken.ISSUP_PARTIAL
      else:
          return ReflectionToken.ISSUP_UNSUPPORTED

  def _evaluate_utility(self, query: str, response: str) -> ReflectionToken:
      """Evaluate overall utility and quality of the response"""
      # Simple utility evaluation based on response length and query coverage
      if len(response) < 20:
          return ReflectionToken.ISUSE_UNCLEAR

      query_words = set(query.lower().split())
      response_words = set(response.lower().split())
      coverage = len(query_words.intersection(response_words)) / len(query_words)

      if coverage > 0.4:
          return ReflectionToken.ISUSE_USEFUL
      else:
          return ReflectionToken.ISUSE_UNCLEAR

  def process_query(self, query: str) -> GenerationResult:
      """Main Self-RAG processing pipeline with reflection"""
      reflection_tokens = []

      # Step 1: Decide whether to retrieve
      should_retrieve, retrieve_token = self._should_retrieve(query)
      reflection_tokens.append(retrieve_token)

      retrieved_docs = []
      if should_retrieve:
          # Step 2: Retrieve documents
          retrieved_docs = self._retrieve_documents(query)

          # Step 3: Evaluate relevance
          relevance_tokens = self._evaluate_relevance(query, retrieved_docs)
          reflection_tokens.extend(relevance_tokens)

      # Step 4: Generate response
      response = self._generate_response(query, retrieved_docs)

      # Step 5: Evaluate support
      support_token = self._evaluate_support(response, retrieved_docs)
      reflection_tokens.append(support_token)

      # Step 6: Evaluate utility
      utility_token = self._evaluate_utility(query, response)
      reflection_tokens.append(utility_token)

      # Calculate confidence based on reflection tokens
      positive_tokens = [
          ReflectionToken.ISREL_RELEVANT,
          ReflectionToken.ISSUP_SUPPORTED,
          ReflectionToken.ISUSE_USEFUL
      ]
      confidence = sum(1 for token in reflection_tokens if token in positive_tokens) / max(1, len([t for t in reflection_tokens if 'ISREL' in t.value or 'ISSUP' in t.value or 'ISUSE' in t.value]))

      return GenerationResult(
          response=response,
          reflection_tokens=reflection_tokens,
          confidence_score=confidence,
          retrieved_docs=retrieved_docs
      )

# Demonstration
self_rag = SelfRAGSystem()

# Test different query types
test_queries = [
  "What is Self-RAG?",  # Should retrieve
  "Define machine learning",  # May not retrieve if high confidence
  "How to implement adaptive systems?"  # Should retrieve
]

for query in test_queries:
  print(f"\nQuery: '{query}'")
  result = self_rag.process_query(query)

  print(f"Response: {result.response}")
  print(f"Confidence: {result.confidence_score:.2f}")
  print(f"Reflection Tokens: {[token.value for token in result.reflection_tokens]}")
  print(f"Retrieved {len(result.retrieved_docs)} documents")
```

Key Learning Points:

Self-RAG systems make dynamic decisions about when retrieval is necessary
Reflection tokens enable self-assessment of retrieval relevance and response quality
Confidence scoring helps identify when additional retrieval or refinement is needed
Different query types require different retrieval strategies and validation approaches
Try It: Modify the knowledge_threshold parameter and observe how it affects retrieval decisions for different query types. Test with threshold values of 0.5, 0.7, and 0.9.

Pseudo-Relevance Feedback and Query Refinement
Iterative Query Improvement
Pseudo-relevance feedback uses top-retrieved documents to extract terms that improve subsequent queries. This technique enhances Self-RAG systems by informing query refinement strategies based on initial retrieval results.

```python
# Step 1: Find helpful terms from retrieved documents
def find_helpful_terms(documents, original_query):
  """Find new terms from good documents to improve the query"""
  helpful_terms = []

  # Look at documents that seem relevant
  for doc in documents:
      if doc.relevance_score > 0.3:  # Only use relevant docs
          # Split document into words
          doc_words = doc.content.lower().split()
          query_words = original_query.lower().split()

          # Find words in the document that are not in our query
          for word in doc_words:
              if word not in query_words and len(word) > 2:
                  helpful_terms.append(word)

  # Return the 3 most common new terms
  from collections import Counter
  common_terms = Counter(helpful_terms).most_common(3)
  return [term for term, count in common_terms]

# Step 2: Try to improve the query if first attempt was not good enough
def improve_query_if_needed(original_query):
  """Try the query, and if it is not good enough, add helpful terms"""
  # First attempt
  result = search_with_query(original_query)

  # If result is good enough (confidence > 0.7), we are done
  if result.confidence_score > 0.7:
      return result

  # If not good enough, find helpful terms and try again
  helpful_terms = find_helpful_terms(result.documents, original_query)
  improved_query = original_query + " " + " ".join(helpful_terms)

  # Try with improved query
  return search_with_query(improved_query)
```

Key Learning Points:

Pseudo-relevance feedback improves query specificity through term extraction from relevant documents
Iterative refinement enables adaptive systems to improve retrieval quality automatically
Confidence thresholds determine when additional refinement iterations are beneficial
Query expansion must balance specificity with maintaining original query intent

Advanced Feedback Loops and Continuous Learning
Implementation of Learning Mechanisms
Adaptive systems implement feedback loops for continuous improvement based on user interactions and performance metrics. These mechanisms learn from retrieval patterns to enhance future performance.

```python
# Learn from user feedback to improve the system
def learn_from_feedback(query_type, user_was_happy, system_memory):
  """Adjust how the system behaves based on whether users were satisfied"""

  # Get current success rate for this type of query (default: 50%)
  current_success_rate = system_memory.get(query_type, 0.5)

  # Update success rate: if user was happy, increase it slightly
  if user_was_happy:
      new_success_rate = current_success_rate + 0.1 * (1 - current_success_rate)
  else:
      new_success_rate = current_success_rate - 0.1 * current_success_rate

  # Remember this new success rate
  system_memory[query_type] = new_success_rate

  # Adjust system behavior based on success patterns
  if new_success_rate > 0.8:
      # If we are doing well, be more confident (retrieve less often)
      return "be_more_confident"
  elif new_success_rate < 0.4:
      # If we are struggling, be more careful (retrieve more often)
      return "be_more_careful"
  else:
      # Normal performance, use default behavior
      return "use_normal_settings"
```

Common Pitfalls and Best Practices
Over-Complex Reflection Logic: Implementing too many reflection tokens or overly complex validation logic can introduce latency and reduce system reliability. Start with essential reflection tokens (RETRIEVE, ISREL, ISSUP) and add complexity only when needed.

Inadequate Confidence Thresholds: Setting confidence thresholds too high or too low can lead to poor retrieval decisions. Monitor system performance and adjust thresholds based on actual query patterns and user satisfaction metrics.

Ignoring Query Context: Self-RAG systems should consider query context and user intent, not just individual query complexity. Simple queries in complex domains may still require retrieval, while complex queries in well-covered domains might not.

Poor Feedback Loop Design: Implementing feedback loops without proper validation can lead to system degradation over time. Ensure feedback mechanisms include safeguards against adversarial inputs and maintain system stability.

Reflection Token Overhead: Reflection tokens add computational overhead to generation. Balance the benefits of self-assessment with performance requirements, especially for high-throughput applications.

Summary
Self-RAG and adaptive systems introduce intelligence and self-awareness to retrieval-augmented generation. These systems evaluate their own performance, make dynamic retrieval decisions, and continuously improve through feedback mechanisms.

Reflection tokens enable multi-layered validation of retrieval necessity, document relevance, response support, and overall utility. This approach significantly improves response quality and reduces hallucinations compared to traditional RAG systems.

Pseudo-relevance feedback and iterative query refinement adapt search strategies based on initial results, leading to more precise information retrieval. Combined with continuous learning mechanisms, these systems improve over time through user interactions and successful retrieval patterns.

The next lesson explores enterprise security and compliance considerations for deploying these advanced RAG systems in production environments.

Key concepts to remember
Self-RAG systems use reflection tokens to evaluate and validate their own retrieval and generation decisions
Dynamic retrieval decisions improve efficiency by avoiding unnecessary retrieval for simple queries
Pseudo-relevance feedback enables iterative query refinement and improved retrieval accuracy
Adaptive learning mechanisms allow systems to improve continuously based on user feedback and performance patterns
Multi-layered validation through reflection significantly reduces hallucinations and improves response quality