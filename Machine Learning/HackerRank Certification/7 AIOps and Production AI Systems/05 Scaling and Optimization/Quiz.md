## Quiz: Scaling and Optimization

Scaling and Optimization
Your AI-powered recommendation system serves 10,000 requests per second during peak hours. Current infrastructure uses 20 GPU instances at $3/hour each ($1,440/day). P99 latency is 180ms, which meets the 200ms SLA. The team wants to reduce costs while maintaining performance.


You need to scale your model serving system to handle 10x more traffic. You can either use 10x larger instances (vertical scaling) or 10x more instances of the same size (horizontal scaling). What is the main advantage of horizontal scaling?

Horizontal scaling is simpler—no code changes needed

Horizontal scaling provides unlimited capacity and better fault tolerance—if one instance fails, others continue

Horizontal scaling is always cheaper

Vertical scaling has no limits
Correct Answer!
Horizontal scaling provides unlimited capacity and fault tolerance—multiple instances provide redundancy.

Profiling shows 40% of predictions are for the same 100 popular items. Each prediction costs 5ms of GPU time. You serve 10,000 req/s (864M req/day). What is the daily GPU time saved by caching these popular items?

172,800 seconds (48 hours) of GPU time saved daily.

4,320 seconds (1.2 hours) of GPU time saved daily.

Caching provides no benefit since latency is already within SLA.

86,400 seconds (24 hours) of GPU time saved daily.
Correct Answer!
864M requests × 40% cached × 5ms = 1.728B ms = 1.728M seconds = 172,800 seconds (48 GPU-hours) saved daily. This justifies caching implementation.

Your model uses FP32 (100ms inference). Testing shows FP16 quantization reduces to 50ms with 0.5% accuracy loss. INT8 reduces to 30ms with 2% accuracy loss. Current accuracy is 94%. Which should you choose?

Stay with FP32 to maintain 94% accuracy.

Use INT8 for maximum speedup regardless of accuracy loss.

Use INT8 for non-critical requests and FP32 for critical ones.

Use FP16 for 2x speedup with minimal accuracy impact.
Correct Answer!
FP16 provides 2x speedup (100ms to 50ms) with only 0.5% accuracy loss (94% to 93.5%), a favorable tradeoff for most applications.

Training jobs run nightly for 6 hours at $50/hour ($300/night). Spot instances offer 70% discount but can be interrupted. How should you use spot instances?

Never use spot instances; training interruptions are unacceptable.

Use spot instances only if training can complete in under 1 hour.

Use spot instances with checkpointing to save $210 per night.

Use spot instances for 50% of instances, on-demand for the rest.
Correct Answer!
Training with checkpointing can resume after interruptions. 70% savings ($300 to $90) is substantial. Occasional interruptions are acceptable for batch training.

You can reduce latency from 180ms to 90ms by doubling GPU instances (from $1,440/day to $2,880/day). A/B tests show 90ms latency increases conversion by 2%, adding $5,000/day revenue. What should you do?

Keep current infrastructure since latency meets 200ms SLA.

Upgrade to double GPU instances for $1,440/day cost, gaining $5,000/day revenue.

Test with 25% capacity increase first to validate the conversion impact.

Optimize code instead of adding capacity to avoid cost increase.
Correct Answer!
The ROI is clear: spend $1,440/day more for $5,000/day more revenue (net +$3,560/day). This is a 347% ROI.