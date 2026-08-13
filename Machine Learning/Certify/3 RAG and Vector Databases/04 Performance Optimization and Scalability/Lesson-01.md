## Advanced Indexing Techniques

In the previous lesson, you learned advanced ranking and response validation techniques that improve result quality. However, these sophisticated ranking methods are only effective if your vector search can scale to handle large document collections efficiently.

As your RAG system grows from thousands to millions of vectors, basic similarity search becomes a performance bottleneck. Users expect sub-second responses, but exhaustive search through large databases can take several seconds. Advanced indexing techniques solve this scalability challenge by organizing vectors in specialized data structures that enable fast approximate similarity search.

This lesson covers the most important indexing algorithms for production vector databases: HNSW (Hierarchical Navigable Small World) and IVF-PQ (Inverted File with Product Quantization). You'll learn when to use each approach and how to optimize the critical trade-off between search speed and result accuracy.

Vector Index Fundamentals
The Speed vs. Accuracy Trade-off
Advanced indexing involves trading perfect accuracy for faster search speed. Instead of comparing your query to every vector (exact search), these methods use smart data structures to quickly identify approximate nearest neighbors.

Performance Comparison:

| Search Type | Accuracy | Time Complexity | Best For |
|--------------|----------|------------------|----------|
| Exact Search (Brute Force) | 100% | O(n) | Less than 10K vectors |
| Approximate Search (Advanced Indexes) | 95-99% | O(log n) | Millions+ vectors |

Key Metrics:

Recall@K: Percentage of true top-K results found
Latency: Single query response time
Memory: RAM required for index storage
Build Time: Time to construct the index

HNSW (Hierarchical Navigable Small World)
How HNSW Works
HNSW creates a multi-layer graph where vectors are nodes connected to their nearest neighbors. Search starts at the top layer (sparse, long-range connections) and moves down to the bottom layer (dense, local connections), efficiently navigating through vector space like using highways and local roads to reach a destination.

Understanding HNSW Structure

Below example shows how HNSW creates a hierarchical graph structure and navigates through it during search.

```python
import numpy as np
import random

# Simple demonstration of HNSW key concepts
class SimpleHNSWDemo:
  def __init__(self):
      self.layers = {}  # layer_number -> {node_id: [connections]}
      self.vectors = {}  # node_id -> vector
      self.entry_point = None

  def add_vector(self, vector_id, vector):
      """Add vector to HNSW structure"""
      self.vectors[vector_id] = vector

      # Randomly assign layer (higher layers are less likely)
      layer = 0
      while random.random() < 0.5 and layer < 3:  # Max 4 layers for demo
          layer += 1

      print(f"Adding vector {vector_id} to layers 0-{layer}")

      # Add to all layers from 0 to assigned layer
      for l in range(layer + 1):
          if l not in self.layers:
              self.layers[l] = {}
          self.layers[l][vector_id] = []

      # Set as entry point if highest layer
      if self.entry_point is None or layer > max(self.get_node_layers(self.entry_point)):
          self.entry_point = vector_id
          print(f"  New entry point: {vector_id}")

  def get_node_layers(self, node_id):
      """Get all layers containing this node"""
      return [layer for layer, nodes in self.layers.items() if node_id in nodes]

  def distance(self, vec1, vec2):
      """Simple Euclidean distance"""
      return np.linalg.norm(np.array(vec1) - np.array(vec2))

  def search_demo(self, query_vector):
      """Demonstrate HNSW search process"""
      print(f"\n=== Searching with query {query_vector} ===")

      if not self.layers:
          return []

      current_best = self.entry_point
      current_best_dist = self.distance(query_vector, self.vectors[current_best])

      # Search from top layer down
      max_layer = max(self.layers.keys())

      for layer in range(max_layer, -1, -1):
          print(f"\nSearching layer {layer}:")
          print(f"  Nodes in layer: {list(self.layers[layer].keys())}")
          print(f"  Starting from node {current_best} (distance: {current_best_dist:.3f})")

          # Simple greedy search in this layer
          improved = True
          while improved:
              improved = False
              for node_id in self.layers[layer]:
                  if node_id != current_best:
                      dist = self.distance(query_vector, self.vectors[node_id])
                      if dist < current_best_dist:
                          print(f"    Found better node {node_id} (distance: {dist:.3f})")
                          current_best = node_id
                          current_best_dist = dist
                          improved = True

          print(f"  Best in layer {layer}: node {current_best}")

      return current_best, current_best_dist

# Demonstrate HNSW concepts
def demonstrate_hnsw():
  hnsw = SimpleHNSWDemo()

  # Add some 2D vectors for easy visualization
  vectors = {
      1: [0.1, 0.1],   # Bottom-left cluster
      2: [0.2, 0.15],
      3: [0.8, 0.1],   # Bottom-right cluster
      4: [0.85, 0.15],
      5: [0.1, 0.8],   # Top-left cluster
      6: [0.15, 0.85],
      7: [0.5, 0.5],   # Center point
  }

  print("Building HNSW index...")
  for vec_id, vector in vectors.items():
      hnsw.add_vector(vec_id, vector)

  # Show layer structure
  print("\n=== Final HNSW Structure ===")
  for layer in sorted(hnsw.layers.keys(), reverse=True):
      print(f"Layer {layer}: nodes {list(hnsw.layers[layer].keys())}")

  print(f"Entry point: {hnsw.entry_point}")

  # Demonstrate search
  query = [0.9, 0.2]  # Should find bottom-right cluster
  best_node, distance = hnsw.search_demo(query)

  print(f"\n=== Search Result ===")
  print(f"Query: {query}")
  print(f"Best match: node {best_node} at {hnsw.vectors[best_node]} (distance: {distance:.3f})")

  # Show why hierarchical search is efficient
  print(f"\n=== Why HNSW is Efficient ===")
  print("• Higher layers have fewer nodes → fast navigation to right region")
  print("• Lower layers have more nodes → precise local search")
  print("• No need to check every vector, just follow the graph structure")

demonstrate_hnsw()
```

Key Learning Points:

HNSW builds a hierarchical graph where higher layers provide long-range navigation and lower layers ensure local accuracy
The max_connections parameter controls memory usage and search quality - higher values improve results but use more RAM
ef_construction affects index build quality - higher values create better structures but take longer to build
Search-time ef parameter allows dynamic trade-off between speed and accuracy per query
Try It: Experiment with different parameter combinations and observe how they affect build time, search speed, and result quality.

HNSW Parameter Guidelines

```python
# Fast Search (Low Latency)
hnsw_fast = {"max_connections": 8, "ef_construction": 100, "search_ef": 32}

# High Accuracy
hnsw_accurate = {"max_connections": 32, "ef_construction": 400, "search_ef": 100}

# Memory Efficient
hnsw_efficient = {"max_connections": 12, "ef_construction": 150, "search_ef": 50}
```

IVF-PQ (Inverted File with Product Quantization)
How IVF-PQ Works
IVF-PQ combines two techniques for memory-efficient search at massive scale:

Inverted File (IVF): Divides vector space into clusters and searches only the most relevant clusters, reducing search space from millions of vectors to thousands.

Product Quantization (PQ): Compresses vectors by splitting them into subvectors and quantizing each independently, achieving 8-32x compression while maintaining search quality.

IVF-PQ in Action

Below example demonstrates how IVF clustering and Product Quantization work together to enable memory-efficient vector search.

```python
import numpy as np
from sklearn.cluster import KMeans

class SimpleIVFPQ:
  def __init__(self, num_clusters=4, num_subquantizers=4):
      self.num_clusters = num_clusters
      self.num_subquantizers = num_subquantizers
      self.cluster_centers = None
      self.inverted_lists = {}  # cluster_id -> list of (vector_id, pq_codes)
      self.pq_codebooks = []    # quantization codebooks
      self.vectors = {}         # original vectors for comparison

  def train_and_add_vectors(self, vectors):
      """Train IVF-PQ and add vectors"""
      print(f"Training IVF-PQ on {len(vectors)} vectors...")
      vector_dim = vectors.shape[1]

      # Step 1: IVF - Cluster the vectors
      print(f"\n=== IVF: Clustering into {self.num_clusters} groups ===")
      kmeans = KMeans(n_clusters=self.num_clusters, random_state=42, n_init=10)
      cluster_assignments = kmeans.fit_predict(vectors)
      self.cluster_centers = kmeans.cluster_centers_

      for i, cluster_id in enumerate(cluster_assignments):
          print(f"Vector {i}: {vectors[i]} → Cluster {cluster_id}")

      # Step 2: PQ - Train quantization codebooks
      print(f"\n=== PQ: Creating {self.num_subquantizers} quantization codebooks ===")
      subvector_dim = vector_dim // self.num_subquantizers

      for subq_idx in range(self.num_subquantizers):
          start_dim = subq_idx * subvector_dim
          end_dim = (subq_idx + 1) * subvector_dim
          subvectors = vectors[:, start_dim:end_dim]

          # Create simple codebook (4 centroids for demo)
          codebook_kmeans = KMeans(n_clusters=4, random_state=42, n_init=5)
          codebook_kmeans.fit(subvectors)
          self.pq_codebooks.append(codebook_kmeans)

          print(f"Subquantizer {subq_idx} (dims {start_dim}-{end_dim-1}):")
          print(f"  Codebook centers: {codebook_kmeans.cluster_centers_.round(2).tolist()}")

      # Step 3: Encode vectors and build inverted lists
      print(f"\n=== Building Inverted Lists ===")
      for vector_id, (vector, cluster_id) in enumerate(zip(vectors, cluster_assignments)):
          # Quantize vector using PQ
          pq_codes = self._encode_vector_pq(vector)

          # Add to appropriate cluster's inverted list
          if cluster_id not in self.inverted_lists:
              self.inverted_lists[cluster_id] = []
          self.inverted_lists[cluster_id].append((vector_id, pq_codes))

          # Store original for comparison
          self.vectors[vector_id] = vector

          print(f"Vector {vector_id}: {vector} → Cluster {cluster_id}, PQ codes: {pq_codes}")

      # Show cluster contents
      print(f"\n=== Cluster Contents ===")
      for cluster_id, items in self.inverted_lists.items():
          vector_ids = [item[0] for item in items]
          print(f"Cluster {cluster_id}: vectors {vector_ids}")

  def _encode_vector_pq(self, vector):
      """Encode vector using Product Quantization"""
      pq_codes = []
      subvector_dim = len(vector) // self.num_subquantizers

      for subq_idx in range(self.num_subquantizers):
          start_dim = subq_idx * subvector_dim
          end_dim = (subq_idx + 1) * subvector_dim
          subvector = vector[start_dim:end_dim].reshape(1, -1)

          # Find nearest centroid in codebook
          code = self.pq_codebooks[subq_idx].predict(subvector)[0]
          pq_codes.append(code)

      return pq_codes

  def search(self, query_vector, clusters_to_search=2):
      """Search using IVF-PQ"""
      print(f"\n=== Searching for: {query_vector} ===")

      # Step 1: Find nearest clusters
      cluster_distances = []
      for cluster_id, center in enumerate(self.cluster_centers):
          distance = np.linalg.norm(query_vector - center)
          cluster_distances.append((distance, cluster_id))

      cluster_distances.sort()
      nearest_clusters = [cluster_id for _, cluster_id in cluster_distances[:clusters_to_search]]

      print(f"Searching clusters: {nearest_clusters}")
      print(f"(Skipping {self.num_clusters - clusters_to_search} clusters)")

      # Step 2: Search within selected clusters
      candidates = []
      for cluster_id in nearest_clusters:
          if cluster_id in self.inverted_lists:
              print(f"\nCluster {cluster_id}:")
              for vector_id, pq_codes in self.inverted_lists[cluster_id]:
                  # Calculate approximate distance using PQ codes
                  approx_dist = self._asymmetric_distance(query_vector, pq_codes)
                  candidates.append((approx_dist, vector_id))
                  print(f"  Vector {vector_id}: approx distance = {approx_dist:.3f}")

      # Return best match
      if candidates:
          candidates.sort()
          best_dist, best_id = candidates[0]
          exact_dist = np.linalg.norm(query_vector - self.vectors[best_id])
          print(f"\nBest match: Vector {best_id}")
          print(f"Approximate distance: {best_dist:.3f}")
          print(f"Exact distance: {exact_dist:.3f}")
          return best_id
      return None

  def _asymmetric_distance(self, query_vector, pq_codes):
      """Calculate distance between query and PQ-encoded vector"""
      distance = 0.0
      subvector_dim = len(query_vector) // self.num_subquantizers

      for subq_idx, code in enumerate(pq_codes):
          start_dim = subq_idx * subvector_dim
          end_dim = (subq_idx + 1) * subvector_dim

          query_subvector = query_vector[start_dim:end_dim]
          quantized_subvector = self.pq_codebooks[subq_idx].cluster_centers_[code]

          subvector_dist = np.linalg.norm(query_subvector - quantized_subvector) ** 2
          distance += subvector_dist

      return np.sqrt(distance)

# Demonstrate IVF-PQ with simple 2D vectors
def demonstrate_ivf_pq():
  # Create simple 4D vectors for easy understanding
  vectors = np.array([
      [1.0, 1.0, 0.1, 0.1],  # Cluster A
      [1.1, 0.9, 0.0, 0.2],  # Cluster A
      [5.0, 5.0, 0.8, 0.9],  # Cluster B
      [5.2, 4.8, 0.9, 0.8],  # Cluster B
      [1.0, 5.0, 5.0, 1.0],  # Cluster C
      [0.9, 5.1, 4.9, 1.1],  # Cluster C
  ])

  ivfpq = SimpleIVFPQ(num_clusters=3, num_subquantizers=2)
  ivfpq.train_and_add_vectors(vectors)

  # Test search
  query = np.array([1.05, 0.95, 0.05, 0.15])  # Should match Cluster A
  result = ivfpq.search(query, clusters_to_search=2)

  print(f"\n=== IVF-PQ Benefits ===")
  print("• IVF: Only searched 2/3 clusters instead of all vectors")
  print("• PQ: Used compressed codes for fast distance calculations")
  print("• Memory: Each vector uses ~2 bytes instead of 16 bytes (8x compression)")

demonstrate_ivf_pq()
```

Key Learning Points:

IVF clustering divides search space, allowing search within only the most relevant clusters
Product Quantization compresses vectors while maintaining approximate distance calculations
Asymmetric distance computation is key to IVF-PQ efficiency - query uses original precision, database vectors use quantized codes
Compression ratios of 8-32x are common while maintaining good search quality
Try It: Experiment with different numbers of clusters and subquantizers to see the speed vs. accuracy trade-off.

Choosing the Right Index Strategy
When to Use Each Approach
HNSW Best For:

High-dimensional vectors (greater than 100 dimensions)
Applications requiring consistent high recall (greater than 95%)
Real-time applications with sub-10ms latency requirements
When memory usage is not the primary constraint
IVF-PQ Best For:

Very large datasets (millions+ vectors)
Memory-constrained environments
Batch processing scenarios
When 85-90% recall is acceptable for significant memory savings

Quick Selection Guide

| Dataset | Size | Memory Constraint | Accuracy Need | Recommended Index |
|---------|------|-------------------|---------------|-------------------|
| Less than 100K | Any | Any | Exact search (brute force) | |
| 100K - 1M | Low memory | High recall (greater than 95%) | HNSW | |
| 100K - 1M | Low memory | Good recall (85-90%) | IVF-PQ | |
| Greater than 1M | Memory limited | Any | IVF-PQ with high compression | |
| Greater than 1M | Memory available | High recall needed | HNSW | |
| Greater than 10M | Any | Any | IVF-PQ (HNSW becomes memory intensive) | |

Common Scenarios:
Small knowledge base (50K documents): Use exact search for simplicity
Medium enterprise search (1M documents, need accuracy): Choose HNSW
Large-scale search (10M+ documents): Use IVF-PQ for memory efficiency
Memory-constrained deployment: Always prefer IVF-PQ over HNSW
Common Pitfalls and Best Practices
Wrong Index Choice: Using HNSW for massive datasets (greater than 10M vectors) wastes memory, while IVF-PQ for small datasets (less than 100K) adds unnecessary complexity. Match the index to your scale.

Ignoring Memory Growth: Indexes consume more memory than raw vectors. Plan for 2-4x memory overhead for HNSW and monitor usage in production.

Parameter Over-tuning: Start with default parameters and optimize incrementally based on real queries, not synthetic benchmarks.

Not Planning for Scale: Choose indexing strategies that can grow with your data. Consider future dataset size when making architectural decisions.

Summary
Advanced indexing techniques are essential for scaling RAG systems beyond basic similarity search. HNSW provides excellent accuracy and consistent performance for most applications, while IVF-PQ enables memory-efficient search at massive scale.

Your choice depends on dataset size, memory constraints, and accuracy requirements. Start simple with exact search for small datasets, move to HNSW for balanced performance, and consider IVF-PQ when memory becomes a constraint.

In the next lesson, you'll learn system performance tuning techniques that optimize the entire RAG pipeline beyond just vector indexing.

Key concepts to remember
HNSW excels for high-dimensional data with consistent high accuracy requirements
IVF-PQ enables massive scale through clustering and vector compression
Index choice should match dataset size, memory constraints, and accuracy needs
Parameter tuning has significant impact on the speed vs. accuracy trade-off