## The Challenge of Testing Agents
Your multi-agent code review system works beautifully in demos. You deploy it, and users report that sometimes the security agent and testing agent give conflicting recommendations. Other times, findings get duplicated. Occasionally, the system misses obvious vulnerabilities. You want to add tests, but how do you test systems that produce different outputs each run?

Agent testing is fundamentally different from traditional software testing. You cannot assert exact outputs because LLM responses vary. You cannot test all paths because agents make dynamic decisions. Multi-agent systems add interaction complexity that multiplies the testing challenge.

In this lesson, you will learn testing strategies that work for non-deterministic agents: capability testing, interaction testing, and evaluation suites that measure quality without requiring exact matches.

By the end, you will have patterns for testing agent systems with confidence despite their inherent variability.

Testing Non-Deterministic Systems
Traditional unit tests verify that given specific inputs, functions produce specific outputs. Agents produce varied outputs—the same PR might receive slightly different review comments on different runs. Both outputs can be correct, but they are not identical.

Testing agents requires a shift in approach: test for properties and capabilities, not exact matches. Does the agent detect the vulnerability? Does it provide actionable suggestions? Does it avoid false positives on safe code?

Multi-agent systems add another dimension: interactions between agents. Even if each agent works correctly in isolation, the system might fail when agents coordinate. Testing must cover both individual agents and their interactions.

Testing Individual Agents
Start with focused tests on individual agent capabilities:

```python
import pytest

class TestSecurityAgent:
  @pytest.mark.asyncio
  async def test_detects_sql_injection(self, security_agent, sql_injection_code):
      """Agent should detect SQL injection vulnerability"""
      result = await security_agent.analyze(sql_injection_code)

      assert len(result["findings"]) > 0

      sql_findings = [
          f for f in result["findings"]
          if "sql" in f["type"].lower() or "injection" in f["type"].lower()
      ]
      assert len(sql_findings) > 0
      assert sql_findings[0]["severity"] in ["critical", "high"]
```

Behavioral testing verifies agent reasoning, not just outputs:

```python
@pytest.mark.asyncio
async def test_provides_actionable_suggestions(self, security_agent, vuln_code):
  """Findings should include actionable fix suggestions"""
  result = await security_agent.analyze(vuln_code)

  for finding in result["findings"]:
      suggestion = finding.get("suggestion", "")

      # Suggestion should be specific, not generic
      assert len(suggestion) > 20
      # Should mention the actual fix
      assert "parameterized" in suggestion.lower() or "prepared" in suggestion.lower()
```

Understanding how to test non-deterministic systems helps you build reliable test suites for agents.

Testing Multi-Agent Interactions
Multi-agent systems require tests that verify coordination:

```python
@pytest.mark.asyncio
async def test_agents_dont_duplicate_findings(self, review_system):
  """Multiple agents should not report the same issue"""
  result = await review_system.review_pr(pr_context)

  locations = [(f["file"], f.get("line")) for f in result["findings"]]
  unique_locations = set(locations)

  assert len(locations) == len(unique_locations), "Duplicate findings"

@pytest.mark.asyncio
async def test_partial_failure_handling(self, review_system):
  """System should complete review even if one agent fails"""
  with patch.object(review_system.agents["security"], 'analyze',
                   side_effect=Exception("Agent crashed")):
      result = await review_system.review_pr(pr_context)

  assert result is not None
  assert "recommendation" in result
```

Integration tests verify end-to-end behavior:

```python
@pytest.mark.asyncio
async def test_complete_review_workflow(self, full_system):
  """Test complete review from PR to posted comments"""
  pr_context = create_test_pr_with_issues([
      {"type": "security", "vulnerability": "sql_injection"},
      {"type": "performance", "issue": "n_plus_one"}
  ])

  result = await full_system.review_pr(pr_context)

  # Should have findings from multiple agents
  sources = set(f["source_agent"] for f in result["findings"])
  assert len(sources) >= 2

  # Should have appropriate recommendation
  assert result["recommendation"] in ["approve", "request_changes"]

@pytest.mark.asyncio
async def test_idempotent_review(self, full_system):
  """Same PR should get consistent review decisions"""
  pr_context = create_test_pr_with_issues([
      {"type": "security", "vulnerability": "xss"}
  ])

  # Run review multiple times
  results = [await full_system.review_pr(pr_context) for _ in range(3)]

  # Recommendation should be consistent
  recommendations = [r["recommendation"] for r in results]
  assert len(set(recommendations)) == 1, "Inconsistent decisions"
```

Evaluation and Benchmarking
Systematic evaluation measures agent quality over time. Build evaluation suites with known test cases and expected outcomes:

```python
@dataclass
class EvaluationCase:
  case_id: str
  pr_context: dict
  expected_findings: List[dict]  # Issues that should be found
  expected_recommendation: str

class AgentEvaluator:
  def __init__(self, test_cases: List[EvaluationCase]):
      self.test_cases = test_cases

  async def evaluate(self, agent) -> dict:
      """Evaluate agent against test suite"""
      true_positives = 0
      false_positives = 0
      false_negatives = 0

      for case in self.test_cases:
          result = await agent.analyze(case.pr_context)

          # Match findings to expected
          matched = self._match_findings(result["findings"], case.expected_findings)

          true_positives += matched["true_positives"]
          false_positives += matched["false_positives"]
          false_negatives += matched["false_negatives"]

      # Calculate metrics
      precision = true_positives / (true_positives + false_positives) if (true_positives + false_positives) > 0 else 0
      recall = true_positives / (true_positives + false_negatives) if (true_positives + false_negatives) > 0 else 0
      f1 = 2 * precision * recall / (precision + recall) if (precision + recall) > 0 else 0

      return {"precision": precision, "recall": recall, "f1": f1}
```

Regression testing catches quality degradation when you change prompts or models:

```python
class RegressionMonitor:
  def __init__(self, baseline_results: dict, threshold: float = 0.05):
      self.baseline = baseline_results
      self.threshold = threshold

  def check_regression(self, new_results: dict) -> dict:
      """Check for regression against baseline"""
      regressions = []

      if new_results["precision"] < self.baseline["precision"] - self.threshold:
          regressions.append({
              "metric": "precision",
              "baseline": self.baseline["precision"],
              "current": new_results["precision"]
          })

      if new_results["recall"] < self.baseline["recall"] - self.threshold:
          regressions.append({
              "metric": "recall",
              "baseline": self.baseline["recall"],
              "current": new_results["recall"]
          })

      return {"has_regression": len(regressions) > 0, "regressions": regressions}
```

Common Pitfalls and Solutions
Testing exact outputs: LLM responses vary. Test for properties (found a vulnerability, severity is high) rather than exact strings.

Ignoring edge cases: Agents fail on unusual inputs. Include empty files, massive files, non-English code, and adversarial inputs in test suites.

Not testing failures: Agent failures should be graceful. Test what happens when LLM calls timeout, return errors, or produce invalid JSON.

Static test suites: As agents improve, tests become too easy. Continuously add challenging cases that expose weaknesses.

Summary
Testing agents requires approaches beyond traditional unit testing. Individual agent tests verify capability to detect issues and avoid false positives. Multi-agent tests verify coordination, conflict resolution, and failure handling.

Evaluation suites measure precision (avoiding false positives), recall (finding real issues), and consistency. Regression monitoring catches quality degradation over time.

Key Takeaways:

Test agents for correct detection, not exact output matching
Verify agents provide actionable suggestions, not just issue detection
Test multi-agent coordination, deduplication, and conflict resolution
Include partial failure scenarios in integration tests
Build evaluation suites with precision and recall metrics
Monitor for regressions when changing prompts or models
Test idempotency—same input should yield consistent decisions