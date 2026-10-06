## Quiz: Monitoring, Observability, and User Feedback

Monitoring, Observability, and User Feedback
Your recommendation model has been running in production for 3 months. Infrastructure metrics look healthy (low latency, no errors), but the product team reports a 15% decline in click-through rates over the past 2 weeks. You need to investigate and respond.


Infrastructure monitoring shows everything is healthy, but click-through rates are declining. What type of monitoring would have detected this issue earlier?

CPU and memory utilization monitoring.

Prediction distribution and data drift monitoring.

Network bandwidth and latency monitoring.

Log volume and storage capacity monitoring.
Correct Answer!
Silent failures where models degrade without infrastructure issues require monitoring prediction distributions and data drift to detect before business impact.

A request takes 500ms total: 50ms API gateway, 400ms model serving, 50ms response formatting. Using distributed tracing, you discover 350ms of the model serving time is feature retrieval from a database. What should you optimize?

The model inference code to reduce GPU compute time.

API gateway routing logic to reduce overhead.

All components equally since they all contribute to latency.

Feature retrieval by adding caching or optimizing database queries.
Correct Answer!
Feature retrieval consumes 70% of total request time. Optimizing this bottleneck provides the largest latency improvement.

Your drift monitoring shows PSI (Population Stability Index) of 0.32 for a key feature, indicating significant drift. Model accuracy on recent labeled data dropped from 92% to 85%. What should you do?

Retrain the model with recent data to adapt to the distribution shift.

Ignore the drift since infrastructure metrics are healthy.

Scale up infrastructure to handle the changed data distribution.

Wait for more data to confirm the drift is not temporary.
Correct Answer!
Significant drift (PSI 0.32) with confirmed performance degradation (85% vs 92%) requires retraining with recent data to restore performance.

Your fraud detection model makes predictions immediately, but ground truth labels arrive 2-3 weeks later after investigations complete. How should you monitor model performance?

Use only infrastructure metrics since ground truth is unavailable.

Stop monitoring until ground truth labels are available.

Use proxy metrics (confidence scores, manual review rates) with delayed ground truth validation.

Generate synthetic ground truth from model predictions.
Correct Answer!
Delayed ground truth requires proxy metrics for early signals, supplemented by ground truth validation when labels arrive weeks later.

You run an A/B test with 10,000 users in each group. Control has 5.0% conversion, treatment has 5.5% conversion (p-value = 0.03). Should you deploy the new model?

Yes, because p-value < 0.05 indicates statistical significance.

No, because the sample size is too small for reliable results.

Extend the test to 100,000 users to increase confidence.

Evaluate if 0.5% absolute improvement justifies deployment costs and risks.
Correct Answer!
Statistical significance confirms a real difference, but you must assess if the improvement justifies deployment effort, infrastructure costs, and risks.

Your monitoring shows: GPU utilization at 95%, p99 latency at 450ms (SLA is 500ms), prediction distribution shifted 20%, but revenue increased 5%. Which metric should concern you most?

GPU utilization at 95% because it leaves no headroom for traffic spikes.

Prediction distribution shift because it indicates potential drift.

Nothing, because revenue increased so the system is working well.

P99 latency because it means some users have poor experience.
Correct Answer!
95% GPU utilization with p99 latency near SLA limits means you cannot handle traffic spikes. Business metrics are good now, but capacity issues will cause future problems.