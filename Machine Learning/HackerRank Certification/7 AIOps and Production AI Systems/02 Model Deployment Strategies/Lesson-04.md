## Blue-Green Deployments for Zero-Downtime Updates

Blue-green deployment showing two identical environments with atomic traffic switching

![Blue-green deployment with instant traffic switching](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson04-blue-green-deployment.svg)

Blue-green deployment is a pattern where you maintain two identical production environments and switch traffic between them. This enables zero-downtime deployments and instant rollback when problems occur.

The concept is straightforward: Blue is your current production environment serving all user traffic. Green is an identical environment running the new model version with no traffic. You thoroughly test Green, then switch all traffic from Blue to Green atomically. If problems arise, you switch traffic back to Blue instantly.

Consider deploying a new recommendation model. Your blue environment runs model v1.2 serving 100 percent of traffic. You deploy v1.3 to the green environment, which has identical infrastructure but receives no user traffic. You run automated tests against green, manually verify predictions look good, and check for any errors or anomalies. Once confident, you update the load balancer to send all traffic to green. Blue becomes idle and can be decommissioned or kept as a rollback target.

The key advantage is atomic cutover. Traffic switches from old to new all at once, not gradually. This works well when you want clean separation between versions and have high confidence in the new version. The switch can be done in seconds with no user-visible disruption.

Implementation requires infrastructure that supports traffic switching. In Kubernetes, you might have two Deployments: blue and green. A Service selector determines which Deployment receives traffic. To switch, you update the Service selector from blue to green. In AWS, you might use two Auto Scaling Groups and switch an Elastic Load Balancer target group. In any environment, the core concept is the same: two environments, one traffic switch.

Resource cost is the main disadvantage. Running two full production environments doubles infrastructure costs during deployment. A deployment might take 2 hours from starting green to decommissioning blue, costing 2 hours of double infrastructure. For large deployments, this is significant. However, the safety and speed of rollback often justify the cost.

Testing green before cutover is critical. You can run automated tests, manual verification, or even send internal traffic to green for testing. Some teams route employee traffic to green for a final check before directing customer traffic. This pre-cutover validation catches issues before customers are affected.

Blue-green works best when your model and infrastructure are stateless. If state is shared between blue and green (like a database), switching traffic is more complex. You need to ensure both versions work with the shared state, or carefully manage state migration. For stateless model serving, this is rarely a problem.

Database schema changes require careful coordination with blue-green deployments. If the new model version expects different data schemas, you need a migration strategy. Typically, you make the schema backward-compatible, deploy the green version, then clean up old schema elements after blue is decommissioned.


Canary Releases and Traffic Splitting
Canary deployment showing gradual traffic increase from 5% to 100% with monitoring feedback

![Canary deployment with gradual traffic shifting and monitoring](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson04-canary-deployment.svg)

Canary releases gradually roll out new model versions by sending a small percentage of traffic to the new version while monitoring closely for problems. This reduces risk compared to all-at-once switches while providing real production validation.

The name comes from "canary in a coal mine" - the canary detects danger before humans are harmed. In deployment, a small percentage of users (the canary) test the new version first. If problems arise, only they are affected, and you can roll back before broader impact.

A typical canary rollout looks like this: Deploy model v1.3 alongside v1.2. Route 5 percent of traffic to v1.3 and 95 percent to v1.2. Monitor error rates, latency, and model metrics for both versions. If v1.3 metrics look good after 1 hour, increase to 25 percent. After another hour, increase to 50 percent. Continue until 100 percent of traffic uses v1.3, then decommission v1.2.

Traffic splitting can be implemented in multiple ways. A load balancer can route requests randomly: 95 percent to v1.2, 5 percent to v1.3. An API gateway might use consistent hashing: specific users always go to the same version, making their experience consistent. A feature flag system might control which users see which version based on user attributes.

Monitoring is crucial during canary rollouts. You need to compare metrics between versions. Is v1.3 latency higher than v1.2? Is error rate higher? Are prediction distributions similar? Automated monitoring with alerts enables quick detection of problems. If v1.3 error rate exceeds v1.2 by more than 2 percent, automatically roll back.

Statistical significance matters when comparing versions. With only 5 percent traffic on v1.3, you have less data, making comparisons noisier. A small number of bad requests can make v1.3 appear worse purely by chance. Wait for enough requests to make meaningful comparisons, or use statistical tests to determine if differences are real versus noise.

Gradual rollout duration depends on your traffic volume and confidence. With high traffic, 1 hour at each step might provide enough data for confident decisions. With low traffic, you might need days at each step to accumulate sufficient data. Balance speed of deployment with confidence in metrics.

The rollback decision is critical. What metric thresholds trigger automatic rollback? How do you decide manually whether to proceed or roll back? Document these criteria before deployment. During an incident, clear criteria enable faster decisions. For example: if p99 latency increases more than 50ms, roll back automatically; if prediction distributions shift more than 10 percent, investigate and decide manually.

Canary releases work well for most model deployments. The gradual rollout limits blast radius of problems while providing real production validation that staging environments cannot match. The cost is slower deployment: what takes minutes with blue-green might take hours or days with canary releases.

Automated canary analysis tools like Kayenta or Flagger continuously compare metrics between versions and make promotion decisions automatically. These tools implement best practices: statistical comparison, automated rollback on degradation, and gradual traffic increases. They reduce manual monitoring burden and enable teams to deploy confidently.


Shadow Deployments and Safe Rollback
Shadow deployment is the safest deployment pattern: the new model runs in production but its predictions are not served to users. You send all traffic to both old and new models, serve predictions from the old model, and log predictions from both for comparison. This validates the new model with real production data without any user impact.

Consider deploying a fraud detection model. You deploy v2 alongside v1. Every transaction is scored by both models. You use v1 scores for actual fraud decisions. You log both scores for comparison. After a week, you analyze the logs and find v2 catches 3 percent more fraud with the same false positive rate. This gives high confidence that v2 is better, so you promote it to primary.

Shadow deployment catches issues that staging environments miss. Production data distributions, rare edge cases, and real user behaviors differ from test environments. Shadow deployment validates with actual production data while maintaining zero risk of user impact.

Implementation requires duplicating traffic. Every request sent to the primary model is also sent to the shadow model. This can be done at the load balancer, API gateway, or application layer. The response from the primary model is returned immediately. The shadow model response is logged but discarded. This doubles compute cost temporarily but provides maximum safety.

Comparing predictions between models requires thought. For classification, you might compare predicted labels and confidence scores. For regression, you might compare predicted values and prediction distributions. For recommendations, you might compare overlap in top-N items. Define comparison metrics that matter for your use case.

Statistical analysis of shadow results guides promotion decisions. If 95 percent of predictions match between v1 and v2, are the differences improvements or problems? Examine the disagreements: is v2 fixing mistakes v1 made, or making new mistakes? This analysis requires domain expertise and careful evaluation.

Shadow deployment works best for model changes where predictions can be compared objectively. Changing model architecture, training data, or algorithms while maintaining the same task enables clear comparison. Changing the task itself makes comparison harder.

The cost of shadow deployment is doubling compute resources during the shadow period. You are running two models instead of one. For expensive models or long shadow periods, this adds up. However, for critical models where failure has severe consequences, the cost is often justified.

Shadow deployment does not test everything. It tests model predictions but not integration, API contracts, or deployment procedures. You still need other testing and validation. Shadow deployment is one layer in a comprehensive deployment strategy.

Rollback strategies are essential for any deployment pattern. How do you quickly revert to the previous model version when problems occur? The fastest rollback is keeping the old version running and simply routing traffic back to it. This requires no deployment, just traffic switching. It works for blue-green and canary patterns.

For deployments where the old version is decommissioned, rollback requires redeployment. Keep old model artifacts readily available. Test the rollback procedure regularly. Document the exact steps. During an incident, you need to execute rollback quickly and confidently.

Automated rollback based on metrics provides fast response to problems. If error rates spike or latency degrades, automatically revert to the previous version. This catches obvious problems within minutes instead of hours. However, automated rollback needs well-chosen triggers to avoid false positives that cause unnecessary rollbacks.

Manual rollback procedures should be straightforward. Document the commands to run, the expected outputs, and how to verify success. Practice rollback in staging environments. When an incident occurs, clear procedures enable any team member to execute rollback, not just the expert who did the deployment.

Summary
Progressive deployment strategies including blue-green deployments, canary releases, and shadow deployments enable safe model updates with controlled risk. Blue-green provides instant rollback and zero-downtime deployment at the cost of doubled infrastructure. Canary releases gradually increase traffic to new versions while monitoring for problems. Shadow deployments validate with production data without user impact.

Effective rollback strategies are essential for all deployment patterns. Keeping previous versions readily available, automating rollback based on metrics, and documenting manual procedures enable fast recovery from problems.

Key concepts to remember
Blue-Green Safety - Blue-green deployments enable instant atomic traffic switching and rollback at the cost of doubled infrastructure during deployment
Gradual Canary Rollout - Canary releases gradually increase traffic to new models while monitoring metrics, limiting blast radius to small user percentages
Risk-Free Validation - Shadow deployments validate new models with real production traffic without serving predictions to users
Statistical Rigor - Statistical significance is critical when comparing model versions to distinguish real differences from noise
Fast Recovery - Automated and well-documented rollback procedures enable fast recovery from deployment issues