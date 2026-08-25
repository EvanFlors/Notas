## Putting It All Together
You have learned the multi-agent patterns individually: when to use multiple agents, how they communicate, how to organize them, and how to test them. Now it is time to see a complete system where specialized agents collaborate to produce reviews that would be impossible for any single agent.

This synthesis lesson demonstrates the power of multi-agent systems. You will see security, performance, and testing agents working together—each contributing unique expertise while an orchestrator coordinates their collaboration.

By the end, you will have a blueprint for building multi-agent systems that harness the power of specialization and collaboration.

System Architecture
The multi-agent code review system consists of specialized reviewer agents, an orchestrator, and supporting infrastructure.

The workflow: compose a team of specialists based on PR needs, run parallel analysis where each agent contributes expertise, cross-reference findings so agents can build on each other's work, resolve conflicts through priority rules, and synthesize a unified review that combines all perspectives.

Multi-agent code review system architecture showing PR input flowing through orchestrator to specialized agents then conflict resolution and synthesis

![Complete multi-agent code review system architecture](https://hrcdn.net/ai-engineering/module-4//multi-agent-systems-lesson04-system-architecture.svg)

The Complete System

```python
class MultiAgentCodeReviewSystem:
  def __init__(self, config):
      self.agents = {
          "security": SecurityReviewAgent(config),
          "performance": PerformanceReviewAgent(config),
          "testing": TestingReviewAgent(config)
      }
      self.orchestrator = ReviewOrchestrator(self.agents)
      self.synthesizer = ReviewSynthesizer()

  async def review_pr(self, pr_number: int, repo: str) -> dict:
      pr_context = await self.fetch_pr_context(pr_number, repo)
      team = self.orchestrator.compose_team(pr_context)
      analyses = await self.orchestrator.run_parallel_analysis(team, pr_context)
      resolved = self.orchestrator.resolve_conflicts(analyses)
      return await self.synthesizer.synthesize(resolved, pr_context)
```

Understanding how the orchestrator composes teams helps you design efficient multi-agent workflows.

The Orchestrator
The orchestrator manages the multi-agent workflow. It selects which agents participate, coordinates their execution, and handles conflicts.

```python
class ReviewOrchestrator:
  def __init__(self, agents: dict):
      self.agents = agents
      self.priority_order = ["security", "testing", "performance"]

  def compose_team(self, pr_context: dict) -> List[str]:
      """Select agents based on PR characteristics"""
      team = []
      if self._has_security_sensitive_files(pr_context):
          team.append("security")
      if self._has_backend_code(pr_context):
          team.append("performance")
      if self._has_tests_or_source(pr_context):
          team.append("testing")
      return team if team else ["security"]

  async def run_parallel_analysis(self, team: List[str], pr_context: dict):
      """Run agents in parallel with error handling"""
      async def safe_analyze(name: str):
          try:
              return await self.agents[name].analyze(pr_context)
          except Exception as e:
              return {"error": str(e), "findings": []}

      results = await asyncio.gather(*[safe_analyze(n) for n in team])
      return {name: result for name, result in zip(team, results)}
```

The orchestrator ensures agents work together effectively: parallel execution for speed, shared context for coordination, and priority-based conflict resolution for coherent output.

Specialized Agents
Each specialized agent focuses on its domain with a tailored system prompt:

```python
class SecurityReviewAgent:
  def get_system_prompt(self) -> str:
      return """
        You are a security-focused code reviewer.
        Look for:
        - Injection vulnerabilities (SQL, XSS, command injection)
        - Authentication and authorization flaws
        - Insecure data handling (hardcoded secrets, weak encryption)
        - Input validation issues

        For each issue, provide:
        - Severity (critical/high/medium/low)
        - Clear description of the vulnerability
        - Specific fix recommendation

        Do NOT comment on code style, performance, or documentation.
        Stay in your lane. Only report security issues.
       """

class PerformanceReviewAgent:
  def get_system_prompt(self) -> str:
      return """
        You are a performance-focused code reviewer.

        Look for:
        - Algorithmic inefficiencies (O(n²) when O(n) is possible)
        - N+1 query patterns
        - Missing caching opportunities
        - Blocking operations in async code

        For each issue, provide:
        - Severity (critical/high/medium/low)
        - Clear description of the performance impact
        - Specific optimization recommendation

        Do NOT comment on security, style, or documentation.
        Stay in your lane. Only report performance issues.
      """
```

The "stay in your lane" instruction prevents agents from overlapping. Each agent produces focused, expert-level analysis in its domain.

Now that you understand orchestration, apply conflict resolution knowledge to handle agent disagreements.

The security agent flags a code pattern as vulnerable. The performance agent recommends the same pattern for speed optimization. How should the system resolve this conflict?

Use the performance recommendation since it was generated first

Apply priority rules where security concerns take precedence over performance

Report both recommendations without resolution

Average the severity scores and report a moderate issue
The Synthesizer
The synthesizer creates a unified review from multiple agent contributions:

```python
class ReviewSynthesizer:
  async def synthesize(self, resolved: dict, pr_context: dict) -> dict:
      """Create unified review from agent findings"""

      findings = resolved["findings"]

      # Determine overall recommendation
      severities = [f.get("severity", "info") for f in findings]

      if "critical" in severities:
          recommendation = "request_changes"
      elif "high" in severities and severities.count("high") >= 2:
          recommendation = "request_changes"
      elif any(s in ["medium", "high"] for s in severities):
          recommendation = "comment"
      else:
          recommendation = "approve"

      # Group findings by type for organized output
      by_type = {}
      for finding in findings:
          agent = finding.get("source_agent", "general")
          by_type.setdefault(agent, []).append(finding)

      # Format review body
      body = self._format_review_body(by_type, recommendation)

      return {
          "recommendation": recommendation,
          "findings": findings,
          "formatted_review": {"body": body},
          "agent_contributions": list(by_type.keys())
      }

  def _format_review_body(self, by_type: dict, recommendation: str) -> str:
      sections = []

      for agent, findings in by_type.items():
          section = f"## {agent.title()} Review\n\n"
          for finding in findings:
              section += f"- **{finding['severity'].upper()}**: {finding['description']}\n"
              if finding.get("suggestion"):
                  section += f"  - *Fix*: {finding['suggestion']}\n"
          sections.append(section)

      return "\n".join(sections)
```

Common Pitfalls and Solutions
Agents stepping on each other: Without clear boundaries, agents report the same issues differently. Use strict system prompts that define what each agent should and should not comment on.

Orchestrator becoming a bottleneck: If the orchestrator does too much analysis, you lose parallelism benefits. Keep it focused on coordination—routing, merging, and conflict resolution.

Inconsistent output formats: When agents return different structures, merging becomes fragile. Define and enforce a standard finding format across all agents.

Ignoring partial failures: When one agent fails, the system should still produce useful output from successful agents. Always handle exceptions and continue with partial results.

Summary
A multi-agent code review system combines specialized agents with effective orchestration. Each agent focuses on its domain: security, performance, or testing. The orchestrator composes teams, coordinates parallel analysis, and resolves conflicts.

This architecture enables deeper expertise than a single generalist agent while maintaining coherent output. The system handles partial failures gracefully and produces reviews that reflect insights from multiple perspectives.

Key Takeaways:

Specialized agents focus deeply on their domains with tailored prompts
Team composition selects agents based on PR characteristics
Parallel analysis maximizes throughput while shared context enables collaboration
Conflict resolution uses priority rules—security typically wins over performance
The synthesizer creates unified reviews respecting all agent contributions
Graceful failure handling ensures partial results rather than complete failure
Clear boundaries prevent agents from duplicating or conflicting work