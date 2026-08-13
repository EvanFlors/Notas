Production RAG Application Development
Your company deploys a RAG-powered legal document search system for multiple departments. Finance users need only financial documents, HR needs personnel policies, and legal teams need access to all documents. The system serves 500 concurrent users across different time zones.


Users in the finance department see legal compliance documents in their search results. How should metadata filtering address this?

Increase the similarity threshold to retrieve only highly relevant documents.

Filter documents at query time using department metadata.

Create separate vector databases for each department.

Train the embedding model to recognize department-specific content.
A user query 'show me the latest HR policies' should prioritize recent documents. What metadata strategy achieves this?

Analyze the query for temporal keywords and apply date-based filtering.

Use a specialized embedding model trained on temporal relationships.

Sort results by document creation date after retrieval.

Increase the number of retrieved documents to find recent ones.
Correct Answer!
Intent detection identifies 'latest' and applies date filters or recency scoring automatically.

The system filters by department and date, but returns zero results. What fallback strategy prevents empty responses?

Return an error message asking the user to rephrase.

Use multi-stage filtering that progressively relaxes constraints.

Disable all filters and search the entire database.

Use the LLM to generate a response without retrieval.
Correct Answer!
Try strict filters first, then relax (remove date, then department) until finding sufficient results.

The team stores document metadata as: created_date (string), dept (string), access (string). A query filters by 'department: Finance' but documents use 'dept: finance'. What issue exists?

The vector database needs to be reindexed.

Inconsistent metadata schema and case sensitivity cause missed results.

The embedding model cannot understand metadata fields.

The similarity threshold is set too high.
Correct Answer!
Schema inconsistencies (department vs dept, Finance vs finance) cause filters to fail. Validation and normalization prevent this.

Legal documents need to be accessible only to users with 'legal' or 'executive' access levels. How should metadata filtering enforce this?

Store access_level as metadata and filter by user's permission during queries.

Create separate vector databases for different access levels.

Have the LLM filter responses based on user permissions.

Encrypt documents and only provide decryption keys to authorized users.
Correct Answer!
Access control metadata enables permission-based filtering at query time, ensuring users see only authorized documents.

SkillUp | Hackerrank