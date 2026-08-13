## Production RAG Application Development

In previous lessons, you learned how to build RAG pipelines and apply them to different use cases. However, basic similarity search often retrieves too broad a set of documents. Users frequently need more specific results based on criteria like document type, creation date, department, or access permissions.

Metadata-based filtering solves this challenge by adding structured information to documents that enables contextual retrieval. Instead of searching all documents, you can limit results to specific sources, time periods, or categories that match user needs.

This lesson explores how to implement effective metadata strategies, apply various filtering approaches, and build sophisticated query routing systems that combine semantic search with structured constraints.

Understanding Metadata in RAG Systems
What is Metadata?
Metadata is structured information about your documents that enables filtering and organization beyond semantic content. While embeddings capture what a document means, metadata captures contextual information about the document itself.

Content vs. Metadata Example:

```python
Document Content: "Our quarterly revenue increased by 15% compared to last year..."
Document Metadata: {
  "document_type": "financial_report",
  "quarter": "Q3_2024",
  "department": "finance",
  "access_level": "internal",
  "created_date": "2024-10-15",
  "author": "finance_team",
  "file_type": "pdf"
}
```

Types of Metadata
Temporal Metadata:

Creation date, modification date
Validity periods, expiration dates
Version numbers and update timestamps
Source Metadata:

Author, department, team
Document type, category
Original file format, location
Access Metadata:

Permission levels, user groups
Confidentiality classifications
Geographic restrictions
Content Metadata:

Language, length, complexity
Topic categories, tags
Quality scores, review status

Benefits of Metadata Filtering
Improved Precision: Filter out irrelevant documents before similarity matching occurs.

User Context: Provide results appropriate to the user's role, location, or current task.

Performance: Reduce the search space for faster query processing.

Compliance: Ensure users only access documents they are authorized to see.

Relevance: Return documents from appropriate time periods or sources.

When adding documents to your vector database, include both content embeddings and structured metadata. This function demonstrates how to structure document metadata consistently for effective filtering.

```python
def add_document_with_metadata(vector_store, content, metadata):
  """
  Add document with both semantic content and filterable metadata
  """
  embedding = embedding_model.encode(content)

  document = {
      'id': str(uuid.uuid4()),
      'content': content,
      'embedding': embedding,
      'metadata': {
          'document_type': metadata.get('type', 'unknown'),
          'created_date': metadata.get('date', datetime.now().isoformat()),
          'department': metadata.get('dept', 'general'),
          'access_level': metadata.get('access', 'public'),
          'author': metadata.get('author', 'unknown')
      }
  }

  vector_store.add(document)
  return document

# Example usage
financial_doc = {
  'type': 'financial_report',
  'date': '2024-10-15',
  'dept': 'finance',
  'access': 'internal'
}

add_document_with_metadata(vector_store, "Q3 revenue grew 15%...", financial_doc)
```

Basic Query-Time Filtering
Apply metadata filters during retrieval to constrain search results. This function combines semantic similarity search with metadata-based filtering to return only relevant documents that match specific criteria.

```python
def filtered_search(vector_store, query, filters=None, top_k=5):
  query_embedding = embedding_model.encode(query)

  filter_conditions = {}
  if filters:
      if 'department' in filters:
          filter_conditions['metadata.department'] = filters['department']
      if 'date_after' in filters:
          filter_conditions['metadata.created_date'] = {'$gte': filters['date_after']}

  return vector_store.search(
      query_vector=query_embedding,
      filter=filter_conditions,
      limit=top_k
  )

# Example usage
results = filtered_search(
  vector_store,
  query="revenue growth analysis",
  filters={'department': 'finance', 'date_after': '2024-07-01'}
)
```

Time-Based and Source-Based Retrieval Constraints
Time-Based Filtering
Time-based filtering ensures users receive current, relevant information rather than outdated content. This approach combines semantic similarity with document recency by calculating a time-decay score and blending it with similarity scores.

```python
def time_based_search(vector_store, query, recency_weight=0.3, days_back=90):
  base_results = vector_store.search(query, top_k=20)
  current_time = datetime.now()
  scored_results = []

  for result in base_results:
      doc_date = datetime.fromisoformat(result['metadata']['created_date'])
      days_old = (current_time - doc_date).days

      if days_back and days_old > days_back:
          continue

      recency_score = max(0, 1 - (days_old / 365))
      combined_score = (
          (1 - recency_weight) * result['similarity'] +
          recency_weight * recency_score
      )

      scored_results.append({**result, 'combined_score': combined_score})

  return sorted(scored_results, key=lambda x: x['combined_score'], reverse=True)[:5]
```

Source-Based Filtering
Source-based filtering ensures users receive information appropriate to their role and organizational access level. This implementation defines department-based access rules and applies them during search to respect organizational boundaries.

```python
def department_search(vector_store, query, user_department, include_public=True):
  allowed_departments = [user_department]
  if include_public:
      allowed_departments.append('public')

  # Role-based access rules
  if user_department == 'executive':
      allowed_departments.extend(['finance', 'hr', 'legal'])
  elif user_department == 'finance':
      allowed_departments.extend(['executive'])
  elif user_department == 'hr':
      allowed_departments.extend(['legal'])

  filters = {'department': allowed_departments}
  return filtered_search(vector_store, query, filters)
```

Advanced Query Routing and Filtering Strategies
Intent-Based Query Routing
Advanced RAG systems can analyze query intent and automatically apply the right filtering strategies. This approach detects keywords in user queries and maps them to appropriate metadata filters.

```python
def analyze_query_intent(query):
  """
  Detect intent patterns and suggest appropriate filters
  """
  query_lower = query.lower()
  filters = {}

  # Time-based intent detection
  if any(word in query_lower for word in ['latest', 'recent', 'current', 'new']):
      filters['date_after'] = (datetime.now() - timedelta(days=30)).isoformat()

  # Document type detection
  if any(word in query_lower for word in ['policy', 'procedure', 'guideline']):
      filters['document_type'] = 'policy'

  # Department detection
  if any(word in query_lower for word in ['employee', 'hiring', 'benefits']):
      filters['department'] = 'hr'
  elif any(word in query_lower for word in ['budget', 'revenue', 'financial']):
      filters['department'] = 'finance'

  return filters

# Example usage
query = "Show me the latest HR policies for employee benefits"
auto_filters = analyze_query_intent(query)
results = filtered_search(vector_store, query, auto_filters)
```

Multi-Stage Filtering
When strict filters return too few results, multi-stage filtering applies progressively relaxed constraints until sufficient results are found. This ensures users always get helpful results while maintaining the highest possible relevance.

```python
def multi_stage_search(vector_store, query, user_context, max_results=5):
  search_stages = [
      # Stage 1: Strict filtering
      {
          'department': user_context['department'],
          'access_level': user_context['access_level'],
          'date_after': (datetime.now() - timedelta(days=90)).isoformat()
      },
      # Stage 2: Relaxed time constraint
      {
          'department': user_context['department'],
          'access_level': user_context['access_level']
      },
      # Stage 3: Public documents only
      {
          'access_level': 'public'
      }
  ]

  for stage_num, filters in enumerate(search_stages, 1):
      results = filtered_search(vector_store, query, filters, top_k=max_results)

      if len(results) >= max_results:
          for result in results:
              result['search_stage'] = stage_num
          return results

  # Fallback: search without filters
  return filtered_search(vector_store, query, {}, top_k=max_results)
```

Common Pitfalls and Solutions
Over-Filtering Leading to Empty Results: Aggressive filtering can eliminate all relevant documents. Implement fallback strategies that progressively relax constraints if initial filters return no results.

Inconsistent Metadata Quality: Production systems often have inconsistent metadata. Build validation and normalization layers that standardize metadata formats and handle missing fields gracefully.

Performance Impact of Complex Filters: Multiple metadata filters can slow retrieval. Pre-index common filter combinations and use database query optimization techniques.

Metadata Schema Evolution: As business requirements change, metadata schemas evolve. Design systems that handle schema migrations and backward compatibility with existing document metadata.

Summary
Metadata-based filtering transforms basic RAG systems into sophisticated, context-aware retrieval systems. By adding structured information alongside semantic embeddings, you can provide users with precisely relevant results while respecting access controls and organizational boundaries.

Effective metadata strategies require thoughtful design and consistent implementation. The investment pays off through improved user satisfaction, better compliance, and more efficient knowledge discovery.
In the next lesson, we'll explore quality assurance and output validation techniques to ensure your RAG system consistently delivers accurate, relevant results.

Key concepts to remember
Metadata enables precise filtering beyond semantic similarity search
Time-based and source-based constraints significantly improve result relevance
Multi-stage filtering strategies ensure users get results even when strict filters find nothing
User context should automatically influence filtering to provide personalized, appropriate results