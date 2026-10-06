## Embedding

Introduction
In the previous lesson, we saw how RAG solves hallucination by retrieving relevant information. But how does a computer actually find "relevant" information? How does it know that a query about "refund policies" should retrieve documents about "returns and exchanges"?

The answer lies in embeddings - mathematical representations that capture the meaning of text. Think of embeddings as coordinates in "meaning space" - just as GPS coordinates tell you exactly where you are in physical space, embeddings tell you where words and sentences exist in a multidimensional space of meaning.

In this lesson, you'll understand what embeddings are, why they're crucial for RAG systems, and see how computers can mathematically compare the meanings of different texts.

The Challenge: Teaching Computers About Meaning
When you search for "refund policy," you expect to find documents about "returns," "money back," or "cancellations" - even though they use different words. Humans understand these are related concepts, but computers only see different letter combinations.

Traditional Computer Approach:

"refund" ≠ "return" (different letters = different things)
No matches found, even for identical concepts
What We Need: A way for computers to understand that words with similar meanings should be treated as similar, regardless of the exact letters used.

What Embeddings Are & Why They Matter
Embeddings solve this by converting words into numbers that capture their meaning. Think of it like giving each word a set of coordinates that describe what it means.

![Embeddings Visualization](https://hrcdn.net/ai-engineering/module-3/light/cat-dog-3d.svg)

The Key Insight: Similar meanings = similar coordinates

This means computers can now mathematically compare meanings by comparing these numbers.

Select two phrases to see their semantic similarity score. "Cancel subscription" and "terminate account" score 0.98 (nearly identical), while "cancel subscription" and "chocolate recipe" score near 0.0 (unrelated). Each phrase becomes a vector of numbers, and cosine similarity measures alignment.

Experiment: Compare related phrases like "password reset" and "forgot password" versus unrelated ones like "play music" and "stock market" to see how embeddings capture meaning.

How Embeddings Power RAG Systems
Now you can see how RAG finds relevant information:

![RAG Process](https://hrcdn.net/ai-engineering/module-3/light/03-embedding-pipeline.svg)

Step 1: Query Conversion The user's natural language query gets converted into an embedding vector using the same model that processed your documents. This ensures both query and documents exist in the same "meaning space."

Step 2: Database Comparison Your knowledge base contains pre-computed embeddings for all documents. The system mathematically compares the query vector against every document vector using cosine similarity.

Step 3: Similarity Matching Documents are ranked by similarity scores. High scores (95%, 87%) indicate strong semantic matches, while low scores (15%) show unrelated content. The system typically returns the top 3-5 most relevant documents.

Step 4: Document Retrieval The most similar documents become context for the LLM, which then generates an accurate, grounded response based on your actual documentation rather than potentially hallucinated information.

This works because embeddings capture intent, not just keywords. The system understands that "cancel" and "terminate" mean similar things, even though they're different words.

See Semantic Search in Action
Let's explore a simple example to see how embeddings find similar meanings even with different words:

```python
import numpy as np
from sentence_transformers import SentenceTransformer

# Load a pre-trained embedding model
model = SentenceTransformer('all-MiniLM-L6-v2', local_files_only=True)

# Three sentences with varying similarity
sentences = [
  "I need to cancel my subscription",
  "How do I terminate my account",  # Similar meaning
  "What's the weather like today"   # Different meaning
]

# Generate embeddings
embeddings = model.encode(sentences)

# Calculate cosine similarity between first sentence and others
def cosine_similarity(a, b):
  return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

similarity_1_to_2 = cosine_similarity(embeddings[0], embeddings[1])
similarity_1_to_3 = cosine_similarity(embeddings[0], embeddings[2])

print(f"'{sentences[0]}'")
print(f"vs '{sentences[1]}'")
print(f"Similarity: {similarity_1_to_2:.3f}\n")

print(f"'{sentences[0]}'")
print(f"vs '{sentences[2]}'")
print(f"Similarity: {similarity_1_to_3:.3f}")

# Expected: First pair has high similarity (~0.7-0.8)
# Expected: Second pair has low similarity (~0.1-0.3)
```

Key Learning Points:

Embeddings convert text into numerical vectors that can be mathematically compared
Cosine similarity measures how "aligned" two vectors are in meaning space (we'll explore this math in later lessons)
Similar meanings produce high similarity scores (close to 1.0)
Different meanings produce low similarity scores (close to 0.0)
This mathematical comparison enables semantic search in RAG systems

Try It: Replace the sentences with customer support queries. Try "cancel subscription" vs "terminate account" vs "weather update" to see how business-related queries cluster together.

Choosing Embedding Models for Your Project
An embedding model is a trained neural network that converts text into numerical vectors, capturing semantic meaning in the process. Different models are trained on different datasets and optimized for different tasks, affecting how well they understand and represent various types of content.

Selecting the right embedding model is crucial for RAG performance. The wrong choice can lead to poor retrieval accuracy, high costs, or slow response times.

Popular Models and Their Trade-offs
General Purpose Models:

all-MiniLM-L6-v2 (384 dimensions)
Speed: Fast inference (~2ms per query)
Quality: Good for most use cases
Best for: Prototyping, general Q&A, cost-sensitive applications
all-mpnet-base-v2 (768 dimensions)
Speed: Slower inference (~5ms per query)
Quality: Higher accuracy, better semantic understanding
Best for: Production systems where quality matters more than speed

Domain-Specific Models:

sentence-transformers/allenai-specter - Scientific papers and research
sentence-transformers/multi-qa-MiniLM-L6-cos-v1 - Optimized for Q&A tasks
Custom fine-tuned models - For highly specialized domains (legal, medical, finance)

Decision Framework

1. Start with your use case:
Customer support/FAQ: Use general models like all-MiniLM-L6-v2
Technical documentation: Consider all-mpnet-base-v2 for better accuracy
Scientific content: Use domain-specific models like allenai-specter
Multiple languages: Use multilingual models (sacrifice some quality for language coverage)

2. Consider your constraints:
Budget limited: Smaller models (384 dimensions) cost less in storage and compute
Quality critical: Larger models (768+ dimensions) provide better results
Latency sensitive: Choose faster models even if quality suffers slightly

3. Test with your actual data:
Different models perform differently on various content types
Always validate performance with your specific documents and queries

Critical Rules
Never mix embedding models: Each model creates its own "meaning space." Mixing embeddings from different models is like trying to use GPS coordinates from different planets - they're incompatible.

Re-embed everything when switching models: If you change models, you must re-process all documents in your knowledge base. This can be expensive but is absolutely necessary.

Common Pitfalls
Mixing Models: Each embedding model creates its own "meaning space" - do not mix embeddings from different models in the same system.

Wrong Similarity Metric: Use cosine similarity for text embeddings (most libraries default to this).

Too Long Text: Most models handle ~500 words max - longer documents need to be split into chunks.

Summary
Embeddings are the mathematical foundation that makes semantic search possible in RAG systems. By converting text into numerical vectors that capture meaning, embeddings enable computers to understand that "refund" and "money back" are related concepts, even when the exact words don't match.

The key insight is that similar meanings cluster together in vector space, allowing mathematical operations like cosine similarity to measure semantic relatedness. This transforms keyword-based search into meaning-based search.

Next, we'll explore vector databases - specialized systems designed to store billions of embedding vectors and perform lightning-fast similarity searches at scale.

Key concepts to remember
Embeddings convert text into numerical vectors that capture semantic meaning
Vector spaces act as "meaning maps" where similar concepts cluster together
Cosine similarity enables mathematical comparison of semantic relatedness
Choosing the right embedding model affects RAG system performance and accuracy