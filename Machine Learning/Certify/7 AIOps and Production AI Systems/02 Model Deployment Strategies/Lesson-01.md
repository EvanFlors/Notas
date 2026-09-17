## Batch Prediction versus Real-Time Serving
Comparison of batch, real-time, and streaming deployment patterns showing workflow and tradeoffs

![Batch, real-time, and streaming deployment pattern comparison](https://hrcdn.net/ai-engineering/module-7/light/aiops-lesson01-deployment-patterns-comparison.svg)

The choice between batch prediction and real-time serving fundamentally shapes your deployment architecture, infrastructure costs, and user experience. Understanding when to use each pattern prevents costly mistakes and enables better system design.

Batch prediction processes many inputs at once on a schedule. You might generate predictions for all users every night, every hour, or every few minutes. The predictions are stored and served from a database or cache when needed. Users receive pre-computed predictions rather than on-demand predictions. This pattern works well when predictions do not need immediate freshness and when you can predict what users will need before they ask.

Consider a movie recommendation system. You can generate recommendations for all users overnight, processing millions of users in a few hours using powerful batch processing infrastructure. When users log in the next day, they see pre-computed recommendations served from a cache. The recommendations are not based on their most recent viewing (from the last few hours), but they are fast to serve and cheap to generate at scale.

Here is how batch prediction works in practice:

Batch Prediction System

```python
from datetime import datetime

class BatchPredictionSystem:
  """Processes many inputs at once, stores results for later serving."""

  def __init__(self):
      self.prediction_store = {}  # Cache for pre-computed predictions

  def run_batch_prediction(self, user_ids: list, batch_size: int = 100):
      """Run batch predictions for all users on a schedule."""
      for i in range(0, len(user_ids), batch_size):
          batch = user_ids[i:i + batch_size]

          # Batch inference is more efficient than individual predictions
          predictions = self._predict_batch(batch)

          # Store predictions in database/cache for later serving
          for user_id, prediction in predictions.items():
              self.prediction_store[user_id] = {
                  'prediction': prediction,
                  'generated_at': datetime.now().isoformat(),
                  'ttl': 86400  # 24 hours
              }

  def _predict_batch(self, user_ids: list) -> dict:
      """Batch model inference - process many users efficiently."""
      return {
          user_id: {'recommended_items': [1001, 2001], 'scores': [0.85, 0.72]}
          for user_id in user_ids
      }

  def serve_prediction(self, user_id: int) -> dict:
      """Serve pre-computed prediction via fast cache lookup."""
      if user_id in self.prediction_store:
          return {'prediction': self.prediction_store[user_id], 'source': 'cached'}
      return {'prediction': None, 'source': 'miss'}


# Example: Nightly batch job for recommendations
system = BatchPredictionSystem()
system.run_batch_prediction(user_ids=list(range(1, 10001)), batch_size=500)

# Serving is ultra-fast (<1ms cache lookup)
result = system.serve_prediction(user_id=42)

# Benefits: spot instances (70% savings), 10-50x more efficient, complex models OK
# Tradeoffs: predictions become stale, need storage, not for real-time decisions
```

Batch prediction is ideal when you can pre-compute predictions for known users, trading freshness for dramatically lower costs and the ability to use more complex models.

Real-time serving computes predictions on-demand when requested. A user action triggers a request to your model server, which computes and returns a prediction immediately. The prediction reflects the most current information available. This pattern provides the freshest possible predictions but requires infrastructure that can handle request volume with acceptable latency.

Consider a fraud detection system. When a user attempts a transaction, you need to evaluate it for fraud immediately. You cannot batch fraud detection overnight because by then the fraudulent transaction would be complete. Real-time serving is essential because decisions cannot wait.

Here is how real-time serving works:

Real-Time Serving System

```python
class RealTimeServingSystem:
  """Computes predictions synchronously when requested."""

  def predict_fraud(self, transaction: dict) -> dict:
      """Real-time fraud prediction - must complete in <100ms."""
      # Step 1: Feature retrieval from fast cache/DB (~10ms)
      features = self._get_features_realtime(transaction)

      # Step 2: Model inference - optimized for low latency (~20ms)
      fraud_score = self._model_inference(features)

      # Step 3: Apply business rules
      decision = 'block' if fraud_score > 0.7 else 'allow'

      return {'fraud_score': fraud_score, 'decision': decision}

  def _get_features_realtime(self, transaction: dict) -> dict:
      """Retrieve features in real-time using cached/denormalized data."""
      return {
          'amount': transaction.get('amount', 0),
          'merchant_risk_score': 0.3,   # Pre-cached
          'user_velocity': 2,            # From real-time counter
          'device_fingerprint_risk': 0.2 # Pre-cached
      }

  def _model_inference(self, features: dict) -> float:
      """Run optimized model inference (quantized model or GPU)."""
      score = (
          features['amount'] / 10000 * 0.3 +
          features['merchant_risk_score'] * 0.3 +
          features['user_velocity'] / 10 * 0.2 +
          features['device_fingerprint_risk'] * 0.2
      )
      return min(1.0, score)


# Example: Real-time fraud detection on payment
system = RealTimeServingSystem()
result = system.predict_fraud({'amount': 5000.00, 'merchant': 'electronics'})
# Returns immediately with fraud_score and decision

# Characteristics: freshest data, strict latency (<100ms), always-available
# Tradeoffs: higher cost, model complexity constrained, need peak capacity
```

Real-time serving provides the freshest predictions but requires always-available infrastructure and careful optimization to meet strict latency requirements.

The latency requirements differ dramatically. Batch prediction can take seconds or minutes per prediction because users never wait for computation. You can use large, complex models that would be too slow for real-time serving. Real-time serving must complete within strict latency budgets, often under 100 milliseconds. This constrains model complexity and infrastructure choices.

Cost characteristics differ significantly. Batch prediction allows using spot instances or preemptible VMs that cost 70 percent less than regular instances. Since predictions happen on a schedule, temporary instance failures are acceptable. You can also use larger batches that maximize GPU utilization and reduce cost per prediction. Real-time serving requires always-available infrastructure with capacity to handle peak request rates plus a safety margin. You cannot use spot instances because failure means dropped requests and unhappy users.

Freshness is the key tradeoff. Batch predictions become stale as time passes. A recommendation based on yesterday's user behavior might not reflect today's interests. Real-time predictions use the most current data and provide the best user experience. The question is whether the freshness improvement justifies the additional cost and complexity.

Data availability affects pattern choice. Batch prediction can use data that takes time to process or compute. You might run complex feature engineering pipelines that aggregate historical data, train temporary models, or compute expensive features. Real-time serving needs features available immediately, limiting what data you can use.


Streaming Predictions for Continuous Processing
Streaming prediction is a third pattern that sits between batch and real-time. Instead of processing requests individually on-demand or all at once on a schedule, streaming processes a continuous flow of events as they occur. This pattern works well for event-driven systems where predictions are needed for every event but not necessarily synchronized with user actions.

Consider a content moderation system for social media. Users continuously post content. Each post needs to be checked for inappropriate content. You do not need results instantly (a few seconds delay is acceptable), but you need to process all posts continuously as they arrive. Streaming prediction handles this pattern naturally.

The architecture uses message queues or streaming platforms like Kafka or Kinesis. Events flow into a queue. Prediction workers consume events, compute predictions, and emit results. Multiple workers process events in parallel, providing high throughput without requiring immediate response to individual requests.

Streaming provides several advantages over pure real-time serving. You can batch multiple events together for more efficient processing. A worker might collect 32 events before sending them to the model together, improving GPU utilization. You can handle traffic spikes by letting events queue temporarily while workers process them. You cannot do this with synchronous real-time serving where every request waits for a response.

Backpressure handling is a key feature of streaming systems. If prediction workers cannot keep up with event volume, the queue grows. You can add more workers to increase capacity or temporarily slow down event ingestion. This flexibility helps handle unexpected traffic spikes without dropping requests or failing requests.

Streaming works well when predictions do not need to return to the original requester immediately. Content moderation predictions can be written to a database that other systems check. Recommendation scores can be written to a cache that serving systems read. Fraud scores can trigger alerts without blocking the original transaction. This decoupling provides flexibility and resilience.

However, streaming adds complexity. You need to manage message queues, handle failures and retries, monitor queue depths, and ensure event ordering when it matters. The infrastructure cost includes queue services in addition to prediction workers. For simple use cases, streaming might be over-engineering.

The choice between streaming and real-time serving depends on whether results must return to the original caller. If a user is waiting for a response, use real-time serving. If results can be processed asynchronously, streaming often provides better efficiency and scalability.


Now that you understand batch, real-time, and streaming patterns, apply that knowledge to selecting the right approach for your use case.


Choosing the Right Pattern for Your Use Case
Deciding which deployment pattern to use requires analyzing your specific requirements, constraints, and tradeoffs. Several factors guide this decision.

Latency requirements are the most critical factor. If users wait for predictions, you need real-time serving with latency under a few hundred milliseconds. If decisions can wait seconds or minutes, streaming works. If predictions can be hours or days old, batch processing suffices. A product recommendation system might use batch predictions served from cache with 100ms latency. A fraud detection system needs real-time predictions computed in 50ms. A customer churn prediction system can use batch predictions generated weekly.

Request volume and cost considerations affect the decision. High volume with strict latency requirements is expensive. Real-time serving 100,000 requests per second requires significant infrastructure. If you can batch those predictions, costs decrease dramatically. Calculate the cost difference: real-time serving at 100 requests per second per GPU costs $3/hour or $0.000008 per prediction. Batch processing at 10,000 predictions per second costs $0.0000003 per prediction, about 25x cheaper.

Data freshness needs determine whether batch predictions are acceptable. If user behavior changes rapidly and predictions must reflect recent actions, batch predictions quickly become stale. If user preferences are stable over days or weeks, batch predictions work fine. A news recommendation system needs freshness because interests change hourly. A movie recommendation system can use day-old predictions because taste changes slowly.

Prediction diversity matters. If most users need similar predictions, you can precompute popular predictions and serve them to many users. If every user needs unique predictions based on their specific context, precomputation becomes impractical. A trending products feature serves the same predictions to millions of users from cache. A personalized recommendation feature needs unique predictions per user.

Operational complexity is a practical consideration. Batch prediction is simpler to implement and operate than real-time serving. You run a scheduled job, store results, and serve from a database. Real-time serving requires model servers, load balancers, autoscaling, health checks, and more sophisticated monitoring. For early projects or small teams, simplicity might outweigh perfect freshness.

Hybrid approaches often provide the best balance. Use batch predictions as a default, served from cache with low latency. Use real-time predictions when context requires it. For example, a recommendation system might precompute homepage recommendations overnight but compute real-time recommendations on product detail pages based on the current product. This balances cost, latency, and freshness.

Another hybrid pattern is using batch predictions with real-time filtering. Generate candidate recommendations in batch for all users. At request time, filter candidates based on real-time context like current inventory, user location, or time-sensitive rules. This provides some freshness benefit without full real-time prediction costs.

Consider risk and failure modes. Batch systems fail gracefully. If a batch job fails, you serve slightly older predictions until the next successful run. Real-time systems fail visibly. If model servers fail, requests fail immediately. Batch systems are more forgiving operationally, which matters for teams learning to deploy AI systems.

Summary
Deployment patterns for AI models include batch prediction, real-time serving, and streaming processing. Batch prediction precomputes predictions on a schedule and serves from cache, optimizing for cost at the expense of freshness. Real-time serving computes predictions on-demand, optimizing for freshness at higher cost. Streaming processes continuous event flows, balancing throughput and latency.

Pattern choice depends on latency requirements, request volume, data freshness needs, prediction diversity, and operational complexity. Hybrid approaches combining batch and real-time patterns often provide the best balance of cost, performance, and user experience.

Key concepts to remember
Batch Cost-Effectiveness - Batch prediction is 10-50x more cost-effective than real-time serving but produces stale predictions
Real-Time Freshness - Real-time serving provides the freshest predictions but requires always-available infrastructure and strict latency management
Streaming for Events - Streaming patterns work well for event-driven systems where results do not need to return immediately to the caller
Hybrid Approaches - Combine batch predictions with real-time filtering or context-specific real-time prediction to balance cost and freshness
Data-Driven Decisions - Base pattern choice on actual latency requirements and data freshness needs, not assumptions about what users want