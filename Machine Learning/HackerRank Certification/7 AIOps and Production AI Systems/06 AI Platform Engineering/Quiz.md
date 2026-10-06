## Quiz: AI Platform Engineering

AI Platform Engineering
Your organization has 15 data scientists across 3 teams deploying 30 models. Each team built custom infrastructure for training and serving. Deployment takes 2 weeks per model due to manual processes. Models have inconsistent monitoring. Leadership wants to improve velocity and standardization.


Teams are spending 40% of their time on infrastructure instead of models. What platform approach should you take?

Use a commercial platform like SageMaker or Vertex AI for faster time-to-value.

Build a custom platform from scratch tailored to exact needs.

Continue with custom per-team infrastructure to maintain flexibility.

Hire 10 platform engineers to build and maintain custom infrastructure.
Correct Answer!
Commercial platforms provide immediate capabilities for teams of this size. 15 data scientists cannot justify building custom platforms when proven solutions exist.

Models are sometimes deployed to production without proper validation, causing incidents. What governance mechanism addresses this?

Faster deployment automation to reduce manual errors.

More comprehensive training for data scientists on deployment.

Longer deployment timelines to allow more manual review.

Model registry with approval workflows requiring validation before production.
Correct Answer!
Approval workflows enforce validation and review before production deployment, preventing unvalidated models from reaching users.

Your platform will process EU customer data including names and emails. GDPR requires deletion of specific users' data on request. How should the platform handle this?

Store all data without PII detection since data scientists need full access.

Block all EU customer data from the platform to avoid GDPR compliance.

Implement PII detection, anonymization options, and deletion request procedures.

Delete all training data weekly to minimize PII retention.
Correct Answer!
GDPR compliance requires detecting PII, providing anonymization, supporting deletion requests, and maintaining audit trails of data handling.

Your organization has shared model serving infrastructure but teams still build custom training pipelines and deployment processes manually. What maturity stage are you at?

Stage 1: Ad-hoc (no shared infrastructure).

Stage 2: Basic shared services (some centralization, much manual work).

Stage 3: Managed platform (comprehensive automation and self-service).

Stage 4: Advanced platform (enterprise-scale with advanced features).
Correct Answer!
Shared serving with custom training and manual deployment is classic Stage 2. Core capabilities are centralized but automation and self-service are limited.

Your organization grew from 15 to 60 data scientists across 10 teams. The original 2 platform engineers are overwhelmed. How should you adjust platform team structure?

Keep 2 platform engineers but improve their productivity with better tools.

Disband the platform team and distribute engineers across product teams.

Hire 20 platform engineers to ensure comprehensive coverage.

Grow to 5-6 platform engineers and establish specialized roles.
Correct Answer!
60 data scientists need 4-6 platform engineers (1:10-15 ratio). Specialization (infrastructure, dev experience, security) improves effectiveness at this scale.