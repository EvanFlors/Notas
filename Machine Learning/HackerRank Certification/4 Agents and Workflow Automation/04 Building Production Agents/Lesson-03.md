## Where Agent Costs Come From

Your code review agent has been running for a month. You check the bill: $3,400. For a single agent reviewing pull requests. Your manager asks why it costs more than the engineering team's coffee budget.

Agent costs are not intuitive. A typical web service has predictable costs: CPU time, memory, network bandwidth. Agents add LLM inference costs that scale with context size and iteration count—and can spike unpredictably when the agent encounters difficult cases or gets stuck.

In this lesson, you will learn where agent costs originate, how to control them through budgets and optimization, and how to balance cost against quality.

By the end, you will have strategies to make agent costs predictable and sustainable.

Understanding Token Economics
Agent costs come primarily from LLM API calls. You pay for tokens—both the tokens you send (input/prompt tokens) and the tokens the model generates (output/completion tokens).

A typical review might cost $0.35. But costs can explode in problematic cases—a stuck agent iterating 47 times can cost $7 or more. One review consumed 18x the typical cost and did not even produce a useful result.

What drives high-cost reviews:

Large PRs: More files mean more tool calls and larger context
Complex code: Security-sensitive code triggers deeper analysis
Agent loops: Stuck agents iterate until timeout or budget exhaustion
Unclear requirements: Ambiguous PRs cause more reasoning iterations
Missing information: Agent keeps requesting data it cannot find
You cannot prevent all high-cost reviews, but you can bound them. Token budgets ensure that even the worst case is limited to a predictable maximum.

Token Budgets
A token budget is a hard limit on how many tokens a single review can consume. When the budget is exhausted, the agent must stop—either completing with partial results or acknowledging it could not finish.

```python
class TokenBudget:
  def __init__(self, max_input: int, max_output: int):
      self.max_input = max_input
      self.max_output = max_output
      self.used_input = 0
      self.used_output = 0

  def record_usage(self, input_tokens: int, output_tokens: int):
      self.used_input += input_tokens
      self.used_output += output_tokens

  def can_afford(self, estimated_input: int, estimated_output: int) -> bool:
      return (self.remaining_input() >= estimated_input and
              self.remaining_output() >= estimated_output)

  def remaining_input(self) -> int:
      return max(0, self.max_input - self.used_input)
```

Using budgets in the agent loop:

```python
async def review_with_budget(self, pr_number: int) -> ReviewResult:
  budget = TokenBudget(max_input=50000, max_output=10000)

  for iteration in range(self.max_iterations):
      if not budget.can_afford(estimated_input=5000, estimated_output=500):
          return self.create_partial_result(reason="Token budget exhausted")

      response = await self.llm.chat(messages=self.messages, tools=self.tools)
      budget.record_usage(response.usage.prompt_tokens, response.usage.completion_tokens)

      # Process response...

  return self.create_result()
```

Reviews that exhaust their budget should be flagged for human review. The agent could not complete its job—a human needs to finish it.

Understanding token economics helps you anticipate where costs come from and why budgets are essential.

Context Optimization
The largest driver of token costs is input context. Every token of context you provide is charged on every iteration. A 10,000-token context that appears in 5 iterations costs 50,000 input tokens.

Use diffs, not full files:

```python
# Expensive: loading full file contents
content = await self.github.get_file_content(file_path)  # 5,000+ tokens

# Efficient: loading only the diff
diff = await self.github.get_file_diff(pr_number, file_path)  # 200-500 tokens
For code review, you rarely need the full file—you need the changes. Diffs are typically 10-20x smaller than full files.
```

Summarize old context:

As the agent iterates, conversation history grows. Each new iteration pays for all previous context. Summarizing old context keeps costs linear rather than quadratic.

```python
def manage_context(self, messages: list, budget: TokenBudget) -> list:
  total_tokens = sum(len(m["content"]) // 4 for m in messages)

  if total_tokens > budget.remaining_input() * 0.5:
      system_prompt = messages[0]
      recent_messages = messages[-4:]  # Last 2 turns

      middle = messages[1:-4]
      if middle:
          summary = self.summarize_messages(middle)
          summary_message = {"role": "assistant",
                           "content": f"[Summary: {summary}]"}
          return [system_prompt, summary_message] + recent_messages

  return messages
```

Progressive context loading:

Start with minimal context and expand only if needed:

```python
async def analyze_with_progressive_context(self, pr_number: int) -> dict:
  # Phase 1: Just PR metadata (~200 tokens)
  pr_summary = await self.get_pr_summary(pr_number)
  initial = await self.quick_assessment(pr_summary)

  if initial["needs_deeper_review"]:
      # Phase 2: Load relevant diffs only (~1000 tokens)
      diffs = await self.get_diffs(pr_number, initial["high_risk_files"])
      detailed = await self.detailed_review(diffs)

  return self.compile_findings()
```

This approach loads 200 tokens for simple PRs, 1,200 tokens for moderate PRs, and more only when necessary.

Model Routing for Cost Efficiency
Not all tasks need the most powerful (and expensive) model. Model routing uses cheaper models for simple tasks and reserves expensive models for complex reasoning.

```python
class ModelRouter:
  def __init__(self):
      self.models = {
          "fast": "gpt-3.5-turbo",      # $0.0015/1K input
          "balanced": "gpt-4-turbo",     # $0.01/1K input
          "powerful": "gpt-4",           # $0.03/1K input
      }

  def select_model(self, task_type: str, complexity: str) -> str:
      if task_type == "style_check":
          return self.models["fast"]
      elif task_type == "security_scan" and complexity == "high":
          return self.models["powerful"]
      return self.models["balanced"]
Two-pass review strategy:

python
async def two_pass_review(self, pr_number: int) -> dict:
  # Pass 1: Fast initial scan with cheap model (~$0.02)
  self.model = self.router.select_model("initial_scan", "low")
  quick_scan = await self.quick_security_scan(pr_number)

  if not quick_scan["potential_issues"]:
      return {"verdict": "approve", "cost": "$0.02"}

  # Pass 2: Deep analysis with powerful model (~$0.30)
  self.model = self.router.select_model("security_scan", "high")
  detailed = await self.detailed_analysis(pr_number, quick_scan["potential_issues"])

  return {"verdict": detailed["verdict"], "cost": "$0.32"}
```

The two-pass approach costs $0.02 for clean PRs (majority) and $0.32 for PRs needing investigation.

Now that you understand context optimization techniques, consider how to enforce token budgets when limits are reached.

Caching for Cost Reduction
Caching LLM responses can dramatically reduce costs for repeated or similar inputs.

```python
class ResponseCache:
  def __init__(self, storage, ttl_seconds: int = 3600):
      self.storage = storage
      self.ttl = ttl_seconds

  def cache_key(self, messages: list, tools: list = None) -> str:
      content = json.dumps({"messages": messages, "tools": tools}, sort_keys=True)
      return hashlib.sha256(content.encode()).hexdigest()

  async def get(self, messages: list, tools: list = None):
      key = self.cache_key(messages, tools)
      cached = await self.storage.get(key)
      if cached and not self.is_expired(cached):
          return cached["response"]
      return None
```

What to cache:

Tool results: PR metadata, file contents, scan results rarely change during a review
Common prompts: System prompts and boilerplate reasoning
Repeated analysis: If the same file appears in multiple PRs, cache the analysis
What not to cache:

Final verdicts: Reviews should consider current PR state
Time-sensitive data: CI status, approval counts change frequently
Cost Monitoring and Budgets
Even with optimization, you need visibility into costs and the ability to enforce limits.

```python
class BudgetEnforcer:
  def __init__(self, daily_limit: float, monthly_limit: float):
      self.daily_limit = daily_limit
      self.monthly_limit = monthly_limit

  async def check_budget(self) -> tuple[bool, str]:
      daily = await self.get_daily_spend()
      monthly = await self.get_monthly_spend()

      if daily >= self.daily_limit:
          return False, f"Daily budget exhausted (\${daily:.2f})"
      if monthly >= self.monthly_limit:
          return False, f"Monthly budget exhausted (\${monthly:.2f})"

      return True, "OK"
```

Summary
Agent costs come primarily from LLM token usage, with input tokens typically dominating. Cost variance is high—outlier reviews can cost 100x the median. Without controls, a few problematic reviews can consume your entire budget.

Token budgets set hard limits on individual review costs. Context optimization reduces input tokens through diffs, summarization, and progressive loading. Model routing uses cheaper models for simple tasks.

Caching reduces costs for repeated queries. Cost monitoring and budget enforcement provide visibility and control.

Key Takeaways:

Input tokens dominate agent costs—optimize context size first
Token budgets prevent runaway reviews—set per-review limits and handle exhaustion gracefully
Use diffs instead of full files—10-20x token savings
Summarize old context—prevent quadratic cost growth over iterations
Route to cheaper models for simple tasks—GPT-3.5 for style, GPT-4 for security
Two-pass strategies save money—cheap initial scan, expensive deep dive only when needed
Cache tool results and common prompts—but not final verdicts
Monitor costs and alert on anomalies—catch runaway spending early