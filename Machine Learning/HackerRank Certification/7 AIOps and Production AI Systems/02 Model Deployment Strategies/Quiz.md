## Quiz: Model Deployment Strategies

Model Deployment Strategies
Your team is preparing to deploy a new computer vision model for product quality inspection in a manufacturing line. The model processes images and classifies products as pass/fail. The system handles 500 images per minute during peak hours. A false negative (accepting a defective product) costs $100. A false positive (rejecting a good product) costs $10. System downtime costs $1,000 per minute.


Your current model v1 runs in production. Model v2 shows 2% better accuracy in offline tests. Which deployment pattern is most appropriate for this high-stakes manufacturing scenario?

Batch prediction running v2 overnight to precompute all results.

Immediate blue-green deployment switching all traffic to v2.

Streaming deployment processing images through message queues.

Shadow deployment of v2 alongside v1 for validation before promotion.
Correct Answer!
Shadow deployment validates v2 with real production data without affecting actual decisions. Given high costs of errors, this safety is justified before full rollout.

You are building a model serving API that will be called by internal microservices (all written in Python and Go). The system needs to handle 10,000 requests per second with large image payloads (2-5MB each). Which protocol choice is most appropriate?

gRPC with Protocol Buffers for better performance with large payloads.

REST with JSON because it is universally compatible.

GraphQL for flexible query capabilities.

WebSockets for bidirectional communication.
Correct Answer!
gRPC provides 2-5x better performance with binary encoding and HTTP/2. For internal services with large payloads at high throughput, gRPC is optimal.

Your model requires 8GB GPU memory and uses 2 CPU cores during inference. Testing shows the model processes 50 requests per second per GPU. You need to handle 500 requests per second. How many GPU Pods should you request in Kubernetes?

5 Pods with 1 GPU each (exactly 500 req/s capacity).

10 Pods to handle twice the expected load.

7-8 Pods with 1 GPU each (40-60% over-provisioning for safety).

1 Pod with 10 GPUs for better resource utilization.
Correct Answer!
You need 10 GPUs for 500 req/s. Deploying 7-8 Pods provides 350-400 req/s baseline with autoscaling for peaks. This balances cost and reliability.

During a canary release with 10% traffic on v2, you observe: v1 has 0.5% error rate, v2 has 1.2% error rate. Both have seen 10,000 requests. What should you do?

Immediately roll back v2 because error rate is higher.

Investigate the errors, check statistical significance, and decide based on root cause.

Continue rollout because 1.2% is acceptably low.

Increase v2 traffic to 50% to gather more data faster.
Correct Answer!
The difference could be noise with limited data, or real issues. Examine the actual errors, verify statistical significance, and make an informed decision.

Your Docker image for model serving is 8GB (model is 5GB, base image and dependencies are 3GB). Image pulls take 5 minutes, slowing autoscaling. How should you optimize?

Store the model in S3 and download it when containers start.

Use a smaller base image like Alpine to reduce the 3GB overhead.

Compress the model file to reduce its size.

Use multi-stage builds to reduce image layers.
Correct Answer!
Downloading 5GB from S3 in a nearby region takes 30-60 seconds versus 5 minutes for full image pull. Keep image small (<1GB) and load models at startup.

Your API gateway uses a sliding window rate limit of 1,000 requests per minute per API key. A client makes 900 requests in the first 30 seconds, then 200 requests in the next 30 seconds. What should happen?

All 1,100 requests succeed because they average to 18 requests per second.

All requests succeed because each 1-minute window is under 1,000.

The gateway queues excess requests to process them later.

The first 1,000 requests succeed, the last 100 are rejected with 429.
Correct Answer!
Sliding window rate limiting tracks requests in any 60-second window. After 900 in 30s, only 100 more are allowed in the next 30s before hitting 1,000/minute.