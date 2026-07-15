## Production Monitoring & Reliability
AI applications break differently than normal web apps. Instead of simple server crashes, you get model overloads, token limits, quality drops, and cost explosions. This lesson covers how to build AI systems that stay reliable when things go wrong.

Why AI Systems Fail Differently
New Types of Failures
Model overload: Too many users cause the AI provider to reject requests
Token limits: Conversations get too long and hit context windows
Quality drops: API works but responses become nonsensical
Cost limits: You hit spending caps and service stops
Streaming breaks: Network issues corrupt responses mid-generation

The Challenge
Traditional monitoring misses these problems because they're not typical "server down" failures. You need AI-specific approaches.

Smart Retry Strategies
Do not Retry Everything

```python
# Bad: Blind retries make problems worse
def bad_retry(request):
    for i in range(5):
        try:
            return api_call(request)
        except:
            time.sleep(2 ** i)  # Makes overload worse

# Good: Check error type first
def smart_retry(request):
    try:
        return api_call(request)
    except RateLimitError as e:
        # Wait the exact time the API tells you
        time.sleep(e.retry_after)
        return api_call(request)
    except ContextLengthError:
        # Don't retry - fix the request instead
        shorter_request = truncate_context(request)
        return api_call(shorter_request)
    except ModelOverloadError:
        # Stop hitting the overloaded model
        return try_fallback_model(request)
```

Key Retry Rules
Rate limits: Wait the exact time the API specifies
Context errors: Shorten the request, don't retry
Model overload: Try a different model or wait longer
Invalid requests: Don't retry at all

Essential Metrics to Track

Time to First Token (TTFT)
How long before users see the response start. This matters more than total time for streaming.

```python
import time

start_time = time.time()
response = openai.chat.completions.create(
    model="gpt-4",
    messages=[{"role": "user", "content": "Hello"}],
    stream=True
)

first_token_time = None
for chunk in response:
    if first_token_time is None:
        first_token_time = time.time() - start_time
        log_metric("ttft", first_token_time)
```

Tokens Per Second
How fast the AI generates text during streaming.

Error Rates by Type
Track different error types separately:

Rate limits
Context overflows
Model failures
Quality issues

Simple Logging Approach
What to Log

```python
def log_ai_request(request, response, error=None):
    log_data = {
        "timestamp": datetime.now(),
        "model": request.model,
        "prompt_tokens": request.token_count,
        "response_tokens": response.token_count if response else 0,
        "cost": calculate_cost(request, response),
        "ttft": response.time_to_first_token if response else None,
        "error_type": type(error).__name__ if error else None,
        "user_id": request.user_id  # Hash or anonymize for privacy
    }
    logger.info(json.dumps(log_data))
```

Privacy Rules
Never log full conversation content in production
Hash user IDs
Log token counts and costs, not actual text
Set automatic deletion after 30-90 days

Rate Limit Management
Read the Headers

```python
def check_rate_limits(response):
    remaining = response.headers.get('x-ratelimit-remaining-tokens')
    reset_time = response.headers.get('x-ratelimit-reset-tokens')

    if int(remaining) < 1000:  # Low on tokens
        log_warning(f"Rate limit low: {remaining} tokens left")

    return int(remaining), reset_time
```

Graceful Degradation
When you hit limits:

Queue non-urgent requests for later
Switch to faster, cheaper models temporarily
Show users estimated wait times
Use cached responses when possible

Health Checks for AI
Test with Known Prompts

```python
def ai_health_check():
    test_prompt = "What is 2+2?"
    expected_keywords = ["4", "four"]

    try:
        response = call_ai_api(test_prompt)
        if any(keyword in response.lower() for keyword in expected_keywords):
            return "healthy"
        else:
            return "degraded_quality"
    except Exception as e:
        return f"failed: {e}"
```

Monitor Multiple Models
Test your fallback models regularly so they work when you need them.

Common Pitfalls and Solutions
Retry Storms
Problem: Your retry logic makes overloaded systems worse

Fix: Use circuit breakers that stop retries when error rates are high

Alert Fatigue
Problem: Too many false alarms when AI metrics naturally vary

Fix: Use percentile-based alerts (95th percentile response time) instead of absolute thresholds

Context Explosions
Problem: Conversations grow until they suddenly hit token limits

Fix: Track context length and trim conversations before they break

Cost Surprises
Problem: Unexpected bills from AI usage spikes

Fix: Set spending alerts at 50%, 80%, and 95% of your budget

Quick Implementation Guide
Step 1: Basic Monitoring

```python
# Track these metrics immediately
metrics = {
    "requests_per_minute": counter,
    "error_rate_by_type": counter_by_type,
    "average_ttft": histogram,
    "tokens_per_second": histogram,
    "cost_per_request": histogram
}
```

Step 2: Smart Retries

```python
def handle_ai_error(error, request):
    if isinstance(error, RateLimitError):
        return wait_and_retry(error.retry_after, request)
    elif isinstance(error, ContextLengthError):
        return retry_with_shorter_context(request)
    elif isinstance(error, ModelOverloadError):
        return try_fallback_model(request)
    else:
        raise error  # Don't retry unknown errors
```

Step 3: Health Monitoring

```python
# Run every 5 minutes
def monitor_ai_health():
    for model in ["gpt-4", "gpt-3.5-turbo"]:
        health = test_model_health(model)
        if health != "healthy":
            alert(f"{model} health: {health}")
```

Summary
The goal is building systems that gracefully handle AI provider issues while keeping users happy and costs under control.

Key concepts to remember
AI systems fail differently you need AI-specific monitoring.
Smart retries beat aggressive retries; understand the error before retrying.
Track AI metrics like TTFT and tokens/second, not just HTTP response codes.
Monitor costs in real-time to avoid budget surprises.
Test fallback models regularly so they work when needed.
Log strategically capture metrics without storing sensitive content.