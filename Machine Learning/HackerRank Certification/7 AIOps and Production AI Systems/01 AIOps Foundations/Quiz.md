## Quiz: AIOps Foundations

AIOps Foundations
Your company is deploying its first machine learning model to production: a recommendation system that suggests products to users. The model has been trained and validated with good offline metrics (92% accuracy). You are responsible for the operational aspects of this deployment.


The recommendation model has been running for two weeks. Infrastructure metrics show 100% uptime, no errors, and normal latency. However, users report that recommendations are becoming less relevant. Which monitoring approach would have detected this issue?

Traditional DevOps monitoring of CPU, memory, and error rates.

MLOps monitoring of training pipeline execution.

AIOps monitoring of prediction distributions and business metrics.

Database query performance monitoring.
Correct Answer!
AIOps monitoring tracks prediction quality and business impact, catching silent failures where infrastructure appears healthy but model output degrades.

During training, your model processes 1 million user interactions in 2 hours using 4 GPUs. In production, the model needs to serve individual recommendations in under 100ms. What is the most critical infrastructure difference?

Serving needs low latency per request while training needs high throughput.

Training needs more storage than serving.

Training requires CPUs while serving requires GPUs.

Training needs faster networking than serving.
Correct Answer!
Training environments optimize for batch throughput over hours; serving environments optimize for individual request latency in milliseconds. This fundamental difference drives infrastructure and optimization choices.

Your model's accuracy suddenly drops from 92% to 78%. You have the model file but not the training data version, hyperparameters, or exact code version used for training. Why is this a problem?

You cannot retrain the model without the exact GPU specifications.

The model file is unusable without storage metadata.

Model versioning only matters for compliance requirements.

You cannot debug or reproduce the model without complete artifact lineage.
Correct Answer!
Without training data version, hyperparameters, and code, you cannot determine what changed or reproduce the original model. Complete artifact tracking is essential for debugging and iteration.

Testing shows your model takes 200ms per prediction on CPUs and 10ms on GPUs. CPU instances cost $0.50/hour, GPU instances cost $3/hour. At 1,000 predictions per second, which infrastructure choice is most cost-effective?

Always use GPUs because they are 20x faster.

Calculate how many instances of each type you need and compare total cost.

Use CPUs because they cost less per instance.

Use specialized accelerators like TPUs to minimize cost.
Correct Answer!
At 200ms per prediction, each CPU serves 5 req/s (200 instances needed, $100/hr). At 10ms, each GPU serves 100 req/s (10 instances needed, $30/hr). GPUs are more cost-effective.

Your model is ready to deploy. You have limited time to implement additional safeguards. Which production readiness item should you prioritize?

Monitoring, alerting, and a tested rollback procedure.

Comprehensive API documentation for all endpoints.

Performance optimization to reduce latency by 50%.

A/B testing framework for gradual rollout.
Correct Answer!
These are critical for detecting problems quickly and recovering from failures. Without them, you are deploying blind and have no escape route when issues arise.