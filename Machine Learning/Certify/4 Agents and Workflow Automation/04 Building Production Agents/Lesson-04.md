## Why Agent Deployment Is Different

You have deployed web services many times. You write tests, run them in CI, deploy to staging, and if everything looks good, promote to production. If something breaks, you roll back. The feedback loop is fast—errors surface immediately as HTTP 500s or crashed processes.

Agent deployment breaks this model. Your tests pass. Staging looks fine. You deploy to production. A week later, users report that the agent has been approving PRs with security vulnerabilities. There was no crash, no error, no obvious signal that something was wrong.

Testing agent behavior requires different strategies than testing traditional software. You need evaluation datasets with known correct answers, shadow mode to compare agent decisions against humans, and progressive rollouts that catch quality problems before they affect everyone.

In this lesson, you will learn how to test what agents decide, not just whether they run, and how to deploy agent changes safely.

By the end, you will have a complete strategy for testing and deploying agents with confidence.

Building Evaluation Datasets
Evaluation datasets are collections of inputs with known correct outputs. For a code review agent, this means PRs where you know what the agent should say.

What makes a good evaluation dataset:

Known ground truth: Each example has a verified correct answer
Diverse coverage: Examples span different code types, vulnerability classes, and edge cases
Realistic difficulty: Examples reflect real PRs, not just easy cases
Labeled categories: Examples are tagged by difficulty, type, and expected behavior

```python
evaluation_dataset = [
    {
        "id": "eval-001",
        "pr_data": {"files": [{"path": "auth.py", "diff": "..."}]},
        "expected": {
            "verdict": "request_changes",
            "must_find": ["sql_injection"],
            "must_not_find": ["false_positive_xss"]
        },
        "category": "security",
        "difficulty": "medium"
    },
    {
        "id": "eval-002",
        "pr_data": {"files": [{"path": "api.py", "diff": "..."}]},
        "expected": {"verdict": "approve", "must_find": []},
        "category": "refactoring",
        "difficulty": "easy"
    }
]
```

Sources for evaluation examples:

Historical incidents: PRs where the agent made mistakes, corrected by humans
Security test cases: Known vulnerabilities from OWASP, CVE databases
Synthetic examples: Crafted examples targeting specific agent behaviors
Production samples: Random production PRs with human-verified verdicts
Aim for 50-100 examples minimum. Quality matters more than quantity.

Running Evaluations
Evaluations compare agent output against expected results. The goal is to measure decision quality, not just whether the agent runs successfully.

```python
class AgentEvaluator:
    async def evaluate_example(self, example: dict) -> dict:
        actual = await self.agent.review(example["pr_data"])
        expected = example["expected"]

        verdict_correct = actual["verdict"] == expected["verdict"]

        findings_found = set(f["type"] for f in actual.get("findings", []))
        must_find = set(expected.get("must_find", []))

        found_required = must_find.issubset(findings_found)

        return {
            "id": example["id"],
            "passed": verdict_correct and found_required,
            "verdict_correct": verdict_correct,
            "found_required": found_required
        }
```

Interpreting evaluation results:

Overall pass rate tells you general quality
Category breakdowns reveal specific weaknesses (e.g., security detection is 84%)
Difficulty breakdowns show where the agent struggles (hard examples at 60%)
Regression Testing
Before deploying any change, run the full evaluation suite and compare against the baseline. A change that improves one area might regress another.

```python
def compare_evaluations(baseline: EvaluationReport,
                       current: EvaluationReport) -> RegressionReport:
    regressions = []
    improvements = []

    for example_id in baseline.passed_examples:
        if example_id not in current.passed_examples:
            regressions.append({"id": example_id, "type": "regression"})

    for example_id in current.passed_examples:
        if example_id not in baseline.passed_examples:
            improvements.append({"id": example_id, "type": "improvement"})

    return RegressionReport(
        regressions=regressions,
        improvements=improvements,
        safe_to_deploy=len(regressions) == 0
    )
```

Deployment decision rules:

No regressions + improvements: Safe to deploy
Regressions + more improvements: Review regressions, may deploy if acceptable
Regressions + no improvements: Do not deploy, investigate

Now that you understand evaluation datasets, apply that knowledge to building effective test suites.

Shadow Mode Deployment
Shadow mode runs the new agent version alongside the current one without affecting production. The new version processes real requests, but its responses are logged rather than returned to users.

```python
class ShadowModeRouter:
    def __init__(self, production_agent, shadow_agent):
        self.production = production_agent
        self.shadow = shadow_agent

    async def review(self, pr_number: int) -> dict:
        production_result = await self.production.review(pr_number)

        # Run shadow in background (response is logged only)
        asyncio.create_task(self.run_shadow(pr_number, production_result))

        return production_result

    async def run_shadow(self, pr_number: int, production_result: dict):
        shadow_result = await self.shadow.review(pr_number)
        self.log_comparison(pr_number, production_result, shadow_result)
```

Interpreting shadow results:

High agreement (>95%): Shadow version behaves similarly, safe to promote
Shadow stricter: New version catches more issues—verify they are real, not false positives
Shadow lenient: New version approves more—dangerous, investigate if missing real issues
Frequent disagreements (<90% agreement): Significant behavior change, review carefully
Progressive Rollout
After shadow mode validation, deploy to production gradually. Start with a small percentage of traffic and increase as you gain confidence.

```python
class ProgressiveRollout:
    def __init__(self, old_agent, new_agent):
        self.old = old_agent
        self.new = new_agent
        self.new_percentage = 0

    def select_agent(self, pr_number: int):
        bucket = hash(str(pr_number)) % 100
        if bucket < self.new_percentage:
            return self.new, "new"
        return self.old, "old"

    def increase_rollout(self, new_percentage: int):
        self.new_percentage = min(new_percentage, 100)
```

Rollout schedule:

Day 1: 5% traffic → Monitor metrics, no alerts
Day 2: 10% traffic → Agreement rate stable
Day 3: 25% traffic → Quality metrics unchanged
Day 4: 50% traffic → Continue monitoring
Day 5: 100% traffic → Full rollout complete
Rollout gates: At each stage, check quality metrics before proceeding. If error rate exceeds 1%, quality score drops below 0.8, or cost spikes beyond 150% of baseline—halt the rollout.

Rollback Strategies
When problems are detected, you need to roll back quickly.

```python
class AgentDeployment:
    async def rollback(self, reason: str):
        logger.warning(f"Rolling back: {reason}")

        # Swap versions
        self.current_version, self.previous_version = (
            self.previous_version, self.current_version
        )

        # Reset rollout percentage
        self.rollout_percentage = 0

        # Invalidate caches with bad decisions
        await self.invalidate_caches()

        await self.send_alert(severity="high",
                             message=f"Agent rollback: {reason}")
```

Reviews that started before rollback should complete with the old version—switching mid-review could cause inconsistent behavior.

That covers the core deployment and rollout strategies! Do you have any questions about shadow mode, progressive rollouts, or rollback procedures?

Testing Agent Prompts
Prompt changes are code changes. A single word difference in a prompt can dramatically alter agent behavior. Treat prompt changes with the same rigor as code changes.

```python
SECURITY_REVIEW_PROMPT_V1 = """
You are a security reviewer. Analyze the code for vulnerabilities.
"""

SECURITY_REVIEW_PROMPT_V2 = """
You are a security engineer reviewing code for a production system.

Focus areas:
1. SQL injection - especially string interpolation in queries
2. XSS - unescaped user input in HTML/JavaScript
3. Authentication - password handling, session management

Do not flag issues based on variable names alone.
"""
```

Prompt change checklist:

Run full evaluation suite with new prompt
Compare against baseline—identify regressions
Review specific examples where behavior changed
Shadow test on live traffic for 24-48 hours
Progressive rollout with quality gates
Testing Tool Changes
Tool changes affect what information the agent receives. A change to tool output format can break agent reasoning even if the tool itself works correctly.

```python
def test_tool_output_compatibility():
    output = get_file_diff(pr_number=1247, file="auth.py")

    # Verify expected fields exist
    assert "additions" in output
    assert "deletions" in output
    assert "content" in output

    # Verify format the agent expects
    assert isinstance(output["additions"], int)
    assert isinstance(output["content"], str)
```

Tool change testing workflow:

Unit test the tool in isolation
Integration test with agent—does the agent interpret output correctly?
Evaluation suite—do tool changes affect decision quality?
Shadow test—compare behavior with old vs. new tool
Summary
Agent deployment requires testing what agents decide, not just whether they run. Evaluation datasets with known correct answers measure decision quality. Shadow mode reveals how new versions would behave on real traffic. Progressive rollouts catch problems before they affect all users.

Prompt changes are code changes—they need the same testing rigor. Tool changes can break agent reasoning even when tools work correctly. Rollback must be fast and handle in-flight reviews correctly.

Key Takeaways:

Evaluation datasets test decision quality, not just execution success
Build datasets from incidents, security test cases, and production samples
Regression testing compares new versions against baseline—no regressions means safe to deploy
Shadow mode runs new versions without affecting users—analyze disagreements carefully
Progressive rollout increases traffic gradually with quality gates at each stage
Prompt changes need full evaluation and shadow testing—a single word can change behavior
Tool output changes can break agent reasoning—test integration, not just tools
Rollback quickly when problems are detected—lock in-flight reviews to their starting version