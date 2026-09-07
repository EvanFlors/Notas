## Extending RAG Beyond Text

Traditional RAG systems retrieve text documents to augment language model responses. Multi-modal RAG extends this concept to retrieve and reason over images, audio, video, and other content types. This enables knowledge systems that can answer questions requiring visual, auditory, or multi-modal understanding.

Consider a technical support system that needs to help users troubleshoot hardware issues. Text documentation alone may be insufficient. The system needs to retrieve images showing component locations, diagrams illustrating connections, and potentially video demonstrations of procedures. Multi-modal RAG makes this possible.

Multi-Modal RAG Architecture:

Multi-Modal Embeddings: Convert images, audio, and other content into vectors that exist in the same semantic space as text embeddings. This enables retrieval across modalities.

Unified Vector Store: Store embeddings from all modalities in a single vector database. Queries can retrieve relevant content regardless of original modality.

Multi-Modal Retrieval: Search returns a mix of content types based on relevance to the query. A question about "how the circuit board looks" retrieves both descriptive text and actual images.

Multi-Modal Generation: The LLM receives retrieved content from multiple modalities and generates a coherent response that integrates all sources.

![Multi-modal RAG architecture showing text, image, and audio content being embedded into a unified vector store for retrieval and generation](https://hrcdn.net/ai-engineering/module-5/light/multimodal-lesson03-rag-architecture.svg)

![Multi-modal RAG: embed all content types into a unified vector space for cross-modal retrieval](https://hrcdn.net/ai-engineering/module-5/light/multimodal-lesson03-rag-architecture.svg)

```python
# Conceptual multi-modal RAG flow:

# 1. Index phase: Convert all content to embeddings
text_embeddings = embed_texts(documents)
image_embeddings = embed_images(images)  # Using CLIP or similar
# Store in unified vector database

# 2. Query phase:
query_embedding = embed_query(user_question)
relevant_texts = vector_search(query_embedding, text_index)
relevant_images = vector_search(query_embedding, image_index)

# 3. Generation phase:
response = llm.generate(
  query=user_question,
  text_context=relevant_texts,
  image_context=relevant_images
)
```

Image Embeddings for Retrieval
Images can be embedded into the same vector space as text using models like CLIP (Contrastive Language-Image Pre-training). This enables text-to-image and image-to-image retrieval.

```python
from openai import OpenAI
import base64

client = OpenAI(
    api_key="API_KEY",
    base_url="BASE_URL",
)

def get_image_description_embedding(image_path: str) -> list[float]:
  """
  Create searchable embedding for an image by generating a description
  and embedding that description.

  This approach works with text embedding models.
  """
  # First, describe the image
  with open(image_path, "rb") as f:
      base64_image = base64.standard_b64encode(f.read()).decode()

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[
          {
              "role": "user",
              "content": [
                  {
                      "type": "text",
                      "text": """
                            Describe this image in detail for search indexing.
                            Include: main subjects, colors, text visible, setting, actions, style.
                            Be specific and comprehensive.
                        """
                  },
                  {
                      "type": "image_url",
                      "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}
                  }
              ]
          }
      ],
      max_tokens=500
  )

  description = response.choices[0].message.content

  # Embed the description
  embedding_response = client.embeddings.create(
      model="text-embedding-3-small",
      input=description
  )

  return embedding_response.data[0].embedding, description

def build_image_index(image_paths: list[str]) -> list[dict]:
  """Build searchable index of images with their embeddings."""
  index = []

  for path in image_paths:
      embedding, description = get_image_description_embedding(path)

      index.append({
          "path": path,
          "description": description,
          "embedding": embedding
      })

  return index
```

Building a Multi-Modal RAG System
Here is a complete implementation of a multi-modal RAG system:

```python
from dataclasses import dataclass
from typing import Optional, Union
import numpy as np

@dataclass
class ContentItem:
  """A piece of content in the knowledge base."""
  id: str
  content_type: str  # "text", "image", "audio"
  content: str  # Text content, or path for media
  embedding: list[float]
  metadata: dict

@dataclass
class RetrievalResult:
  """Result from retrieval."""
  item: ContentItem
  score: float

class MultiModalRAG:
  """
  Multi-modal RAG system that retrieves text, images, and audio.
  """

  def __init__(self, client):
      self.client = client
      self.index: list[ContentItem] = []

  def add_text(self, text: str, metadata: dict = None) -> str:
      """Add text document to the index."""
      embedding = self._embed_text(text)

      item = ContentItem(
          id=f"text_{len(self.index)}",
          content_type="text",
          content=text,
          embedding=embedding,
          metadata=metadata or {}
      )

      self.index.append(item)
      return item.id

  def add_image(self, image_path: str, metadata: dict = None) -> str:
      """Add image to the index."""
      # Generate description and embed it
      description = self._describe_image(image_path)
      embedding = self._embed_text(description)

      item = ContentItem(
          id=f"image_{len(self.index)}",
          content_type="image",
          content=image_path,
          embedding=embedding,
          metadata={
              **(metadata or {}),
              "description": description
          }
      )

      self.index.append(item)
      return item.id

  def add_audio(self, audio_path: str, metadata: dict = None) -> str:
      """Add audio to the index by transcribing and embedding."""
      # Transcribe
      with open(audio_path, "rb") as f:
          transcript = self.client.audio.transcriptions.create(
              model="whisper-1",
              file=f
          )

      embedding = self._embed_text(transcript.text)

      item = ContentItem(
          id=f"audio_{len(self.index)}",
          content_type="audio",
          content=audio_path,
          embedding=embedding,
          metadata={
              **(metadata or {}),
              "transcript": transcript.text
          }
      )

      self.index.append(item)
      return item.id

  def _embed_text(self, text: str) -> list[float]:
      """Create embedding for text."""
      response = self.client.embeddings.create(
          model="text-embedding-3-small",
          input=text
      )
      return response.data[0].embedding

  def _describe_image(self, image_path: str) -> str:
      """Generate searchable description of image."""
      with open(image_path, "rb") as f:
          base64_image = base64.standard_b64encode(f.read()).decode()

      response = self.client.chat.completions.create(
          model="gpt-4.1-mini",
          messages=[
              {
                  "role": "user",
                  "content": [
                      {"type": "text", "text": "Describe this image comprehensively for search indexing."},
                      {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{base64_image}"}}
                  ]
              }
          ],
          max_tokens=500
      )

      return response.choices[0].message.content

  def retrieve(
      self,
      query: str,
      top_k: int = 5,
      content_types: list[str] = None
  ) -> list[RetrievalResult]:
      """
      Retrieve relevant content for a query.

      Args:
          query: Search query
          top_k: Number of results to return
          content_types: Filter by type (e.g., ["text", "image"])
      """
      query_embedding = self._embed_text(query)

      results = []
      for item in self.index:
          if content_types and item.content_type not in content_types:
              continue

          score = self._cosine_similarity(query_embedding, item.embedding)
          results.append(RetrievalResult(item=item, score=score))

      results.sort(key=lambda x: x.score, reverse=True)
      return results[:top_k]

  def _cosine_similarity(self, a: list[float], b: list[float]) -> float:
      """Calculate cosine similarity between vectors."""
      a = np.array(a)
      b = np.array(b)
      return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

  def query(self, question: str, top_k: int = 5) -> str:
      """
      Answer a question using multi-modal retrieval.
      """
      # Retrieve relevant content
      results = self.retrieve(question, top_k=top_k)

      if not results:
          return "I don't have enough information to answer that question."

      # Build context for LLM
      message_content = [
          {
              "type": "text",
              "text": f"Answer this question using the provided context:\n\nQuestion: {question}\n\nContext:"
          }
      ]

      for i, result in enumerate(results, 1):
          item = result.item

          if item.content_type == "text":
              message_content.append({
                  "type": "text",
                  "text": f"\n[Source {i} - Text]: {item.content}"
              })

          elif item.content_type == "image":
              message_content.append({
                  "type": "text",
                  "text": f"\n[Source {i} - Image]: Description: {item.metadata.get('description', 'N/A')}"
              })
              with open(item.content, "rb") as f:
                  base64_img = base64.standard_b64encode(f.read()).decode()
              message_content.append({
                  "type": "image_url",
                  "image_url": {"url": f"data:image/jpeg;base64,{base64_img}"}
              })

          elif item.content_type == "audio":
              message_content.append({
                  "type": "text",
                  "text": f"\n[Source {i} - Audio transcript]: {item.metadata.get('transcript', 'N/A')}"
              })

      # Generate answer
      response = self.client.chat.completions.create(
          model="gpt-4.1-mini",
          messages=[{"role": "user", "content": message_content}],
          max_tokens=1000
      )

      return response.choices[0].message.content
```

Consider how to structure retrieval across different content types in a multi-modal knowledge base.

Your multi-modal RAG system indexes product manuals (text), assembly videos (frames), and troubleshooting photos. A user asks 'How do I fix error E04?' How should the retrieval system find relevant content across all modalities?

Search only text documents since the query is text-based

Convert all content to text descriptions and use standard text search

Embed all content (text, image descriptions, video summaries) into a unified vector space and search semantically

Maintain separate indexes and search each modality with different queries

Advanced Multi-Modal Retrieval Strategies
Different strategies optimize retrieval for different use cases:

```python
class AdvancedMultiModalRAG(MultiModalRAG):
  """Extended RAG with advanced retrieval strategies."""

  def hybrid_retrieve(
      self,
      query: str,
      top_k: int = 5
  ) -> list[RetrievalResult]:
      """
      Hybrid retrieval that ensures diversity across modalities.

      Returns balanced results from different content types.
      """
      results_by_type = {}

      for content_type in ["text", "image", "audio"]:
          type_results = self.retrieve(query, top_k=top_k, content_types=[content_type])
          results_by_type[content_type] = type_results

      # Interleave results for diversity
      final_results = []
      indices = {t: 0 for t in results_by_type}

      while len(final_results) < top_k:
          for content_type in ["text", "image", "audio"]:
              if indices[content_type] < len(results_by_type[content_type]):
                  final_results.append(results_by_type[content_type][indices[content_type]])
                  indices[content_type] += 1

                  if len(final_results) >= top_k:
                      break
          else:
              # No more results in any category
              break

      return final_results[:top_k]

  def rerank_with_context(
      self,
      query: str,
      initial_results: list[RetrievalResult]
  ) -> list[RetrievalResult]:
      """
      Rerank results using LLM to assess relevance in context.
      """
      if not initial_results:
          return []

      # Build ranking prompt
      prompt = f"Query: {query}\n\nRank these sources by relevance (most to least relevant):\n\n"

      for i, result in enumerate(initial_results):
          item = result.item
          if item.content_type == "text":
              content_preview = item.content[:200] + "..."
          else:
              content_preview = item.metadata.get("description", item.metadata.get("transcript", ""))[:200]

          prompt += f"{i+1}. [{item.content_type}] {content_preview}\n"

      prompt += "\nReturn only the numbers in order of relevance, e.g., '3, 1, 4, 2'"

      response = self.client.chat.completions.create(
          model="gpt-4.1-mini",
          messages=[{"role": "user", "content": prompt}],
          max_tokens=50
      )

      # Parse ranking
      ranking_text = response.choices[0].message.content
      try:
          ranks = [int(x.strip()) - 1 for x in ranking_text.split(",")]
          reranked = [initial_results[i] for i in ranks if 0 <= i < len(initial_results)]
          return reranked
      except Exception:
          return initial_results  # Fall back to original order

  def query_with_mode(
      self,
      question: str,
      mode: str = "balanced"
  ) -> str:
      """
      Query with different retrieval modes.

      Modes:
          - "balanced": Mix of all content types
          - "visual": Prioritize images
          - "audio": Prioritize audio content
          - "comprehensive": More results, all types
      """
      if mode == "visual":
          results = self.retrieve(question, top_k=3, content_types=["image"])
          results += self.retrieve(question, top_k=2, content_types=["text"])

      elif mode == "audio":
          results = self.retrieve(question, top_k=3, content_types=["audio"])
          results += self.retrieve(question, top_k=2, content_types=["text"])

      elif mode == "comprehensive":
          results = self.hybrid_retrieve(question, top_k=10)

      else:  # balanced
          results = self.hybrid_retrieve(question, top_k=5)

      # Rerank for better precision
      results = self.rerank_with_context(question, results)

      return self._generate_answer(question, results)
```

Practical Multi-Modal Knowledge Base
Here is an example of building a product support knowledge base:

```python
class ProductSupportKB:
  """
  Product support knowledge base with documents, images, and tutorials.
  """

  def __init__(self, client):
      self.rag = MultiModalRAG(client)

  def ingest_manual(self, manual_path: str, product_id: str):
      """Ingest a product manual (text)."""
      with open(manual_path, "r") as f:
          content = f.read()

      # Split into sections
      sections = content.split("\n\n")

      for i, section in enumerate(sections):
          if len(section.strip()) > 100:  # Skip tiny sections
              self.rag.add_text(
                  section,
                  metadata={"product_id": product_id, "source": "manual", "section": i}
              )

  def ingest_product_images(self, image_paths: list[str], product_id: str):
      """Ingest product images with descriptions."""
      for path in image_paths:
          self.rag.add_image(
              path,
              metadata={"product_id": product_id, "source": "product_image"}
          )

  def ingest_tutorial_video(self, audio_path: str, product_id: str, topic: str):
      """Ingest audio from tutorial video."""
      self.rag.add_audio(
          audio_path,
          metadata={"product_id": product_id, "source": "tutorial", "topic": topic}
      )

  def answer_question(self, question: str, product_id: str = None) -> dict:
      """
      Answer a product support question.
      """
      # Optionally filter by product
      if product_id:
          question = f"[Product: {product_id}] {question}"

      answer = self.rag.query(question)

      return {
          "answer": answer,
          "product_id": product_id
      }
```

Common Pitfalls
Embedding Mismatch: Using different embedding models for indexing and querying produces poor results. Be consistent.

Ignoring Modality Strengths: Some questions are best answered by images, others by text. Consider which modalities are appropriate.

Expensive Image Processing: Describing every image with gpt-4.1-mini is costly. Consider caching or pre-computing descriptions.

No Fallback: If multi-modal retrieval finds nothing, fall back to text-only or provide helpful guidance.

Quality vs Quantity: More retrieved content is not always better. Irrelevant content confuses the LLM.

Summary
Multi-modal RAG extends retrieval-augmented generation to work with images, audio, and video alongside text. By converting all content to embeddings in a shared semantic space, queries can retrieve relevant information regardless of original modality.

Image embedding through description generation enables text-based retrieval of visual content. Audio transcription makes spoken content searchable. Advanced strategies like hybrid retrieval and LLM-based reranking improve result quality. Production systems need efficient indexing, appropriate fallbacks, and cost management for expensive operations like image description.

Key concepts to remember
Multi-modal RAG retrieves text, images, and audio in a unified semantic space
Images are made searchable by generating descriptions and embedding those
Audio content becomes searchable through transcription and embedding
Hybrid retrieval ensures diversity across content types
Reranking with LLMs improves precision for complex queries