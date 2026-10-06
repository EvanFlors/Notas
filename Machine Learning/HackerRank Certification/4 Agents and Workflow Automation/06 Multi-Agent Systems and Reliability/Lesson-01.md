## When Single Agents Are Not Enough
Your code review agent reviews a PR touching authentication, database queries, and frontend components. It finds a minor style issue but misses a SQL injection vulnerability, overlooks a performance regression, and ignores missing test coverage. The agent knows a little about everything but not enough about anything.

This is the single-agent problem. As scope expands, single agents become jacks-of-all-trades that master none. Multi-agent systems solve this through specialization: dedicated agents that go deep in their domains and collaborate to cover the full scope.

In this lesson, you will learn when multi-agent architectures make sense, the fundamental patterns for organizing agent collaboration, and the trade-offs between different approaches.

By the end, you will understand how to design systems where specialized agents work together to accomplish tasks beyond any single agent's capability.

The Limits of Single Agents
A single code review agent can analyze pull requests, identify issues, and suggest improvements. But as requirements grow, single agents hit limitations. You want security-focused analysis, performance optimization suggestions, documentation quality checks, and test coverage validation—all with deep expertise in each area.

One approach is to make the single agent handle everything. This leads to massive prompts, confused reasoning, and mediocre performance across all dimensions. The agent becomes a generalist that excels at nothing.

Multi-agent systems take a different approach: specialized agents that collaborate. A security agent focuses solely on vulnerabilities. A performance agent optimizes for speed. A documentation agent ensures clarity. Each agent masters its domain while coordinating with others to produce a comprehensive review.

This mirrors how effective engineering teams work. No single person reviews for security, performance, style, and correctness simultaneously. Different specialists contribute their expertise, and the team synthesizes their input into a coherent whole.

Comparison of single agent generalist approach versus multi-agent specialist collaboration

![Single agent limitations vs multi-agent specialization](https://hrcdn.net/ai-engineering/module-4/light/multi-agent-systems-lesson01-single-vs-multi.svg)

Benefits of Multi-Agent Systems
Multi-agent architectures offer several advantages over monolithic agents:

Specialization enables deeper expertise. An agent focused entirely on security can include detailed vulnerability patterns, security-specific examples, and nuanced reasoning about attack vectors. A generalist agent cannot afford this depth across all domains.

Modularity simplifies development and maintenance. You can update the security agent without touching the performance agent. New capabilities add as new agents rather than expanding an already complex prompt.

Parallelism reduces latency. Multiple specialized agents can analyze a PR simultaneously. A monolithic agent must process sequentially.

Resilience contains failures. If the documentation agent fails, the security and performance agents still contribute. A monolithic agent failure loses everything.

```python
class MultiAgentReviewSystem:
  def __init__(self):
      self.agents = {
          "security": SecurityReviewAgent(),
          "performance": PerformanceReviewAgent(),
          "testing": TestingReviewAgent()
      }
      self.orchestrator = OrchestratorAgent()

  async def review_pr(self, pr_context: dict) -> dict:
      # Select relevant agents and run in parallel
      relevant = self.orchestrator.select_agents(pr_context)
      reviews = await asyncio.gather(*[
          self.agents[role].review(pr_context) for role in relevant
      ])
      return await self.orchestrator.synthesize(reviews, pr_context)
```

Understanding the limits of single agents helps you decide when multi-agent architectures provide value.

Multi-Agent Patterns
Several patterns organize how agents work together. The right pattern depends on your specific requirements.

Overview of three multi-agent patterns: parallel specialists, pipeline, and hierarchical delegation

![Multi-agent coordination patterns: Parallel, Pipeline, and Hierarchical](https://hrcdn.net/ai-engineering/module-4/light/multi-agent-systems-lesson01-patterns-overview.svg)

Parallel specialists run independent agents simultaneously, then merge results. This pattern works well when agents analyze different aspects that do not depend on each other. Security analysis does not need performance results to proceed, so both can run in parallel.

```python
class ParallelSpecialistsPattern:
  async def review(self, pr_context: dict) -> dict:
      # All specialists run in parallel
      results = await asyncio.gather(
          self.security_agent.analyze(pr_context),
          self.performance_agent.analyze(pr_context),
          self.documentation_agent.analyze(pr_context)
      )

      # Merge and deduplicate findings
      all_issues = []
      for result in results:
          all_issues.extend(result.get("issues", []))

      return {"issues": self._deduplicate(all_issues)}
```

Pipeline processing passes work through agents sequentially, each adding to the analysis. This pattern suits scenarios where later agents benefit from earlier analysis. A context agent might summarize the PR first, then security and performance agents analyze with that context.

```python
class PipelinePattern:
  def __init__(self):
      self.pipeline = [
          ("context", self.context_agent),
          ("security", self.security_agent),
          ("synthesis", self.synthesis_agent)
      ]

  async def review(self, pr_context: dict) -> dict:
      state = {"pr_context": pr_context, "analyses": {}}

      for stage_name, agent in self.pipeline:
          result = await agent.process(state)
          state["analyses"][stage_name] = result

      return state["analyses"]["synthesis"]
```

Hierarchical delegation uses a manager agent that delegates to specialists based on assessed needs. The manager examines the PR, decides which specialists are relevant, and dispatches targeted requests.

```python
class HierarchicalPattern:
  async def review(self, pr_context: dict) -> dict:
      # Manager assesses what expertise is needed
      assessment = await self.manager_agent.assess(pr_context)

      delegations = []
      if assessment["needs_security_review"]:
          delegations.append(self.security_agent.review(pr_context))
      if assessment["needs_performance_review"]:
          delegations.append(self.performance_agent.review(pr_context))

      results = await asyncio.gather(*delegations)

      # Manager synthesizes specialist input
      return await self.manager_agent.synthesize(results)
```

Debate and consensus has agents discuss and refine conclusions. When agents disagree, they present arguments, and an arbiter resolves the conflict. This pattern produces higher-quality decisions but adds latency.

Now that you understand different multi-agent patterns, apply that knowledge to selecting the right approach for your scenario.

Challenges in Multi-Agent Systems
Multi-agent systems introduce complexity that single agents avoid.

Communication overhead requires careful design. Agents need to understand each other's outputs. If the security agent flags a vulnerability, the orchestrator must parse that format to include it in the final review. Standardizing message formats prevents misunderstandings.

```python
@dataclass
class StandardizedFinding:
  """Common format for all agent findings"""
  finding_id: str
  source_agent: str
  severity: str  # critical, high, medium, low, info
  category: str
  file_path: str
  line_number: int
  description: str
  suggestion: str
  confidence: float
````

Conflict resolution handles when agents disagree. The security agent might flag a pattern as vulnerable while the performance agent recommends it for speed. You need policies that determine which perspective wins—typically security concerns take precedence over performance.

Coordination failures occur when agents work on outdated or inconsistent information. If one agent modifies shared context while another reads it, results become unpredictable. Locks, barriers, or event-driven updates maintain consistency.

Common Pitfalls and Solutions
Overlapping responsibilities: When two agents both think they should handle something, you get duplicates or conflicts. Define clear boundaries for each agent's domain and enforce them in prompts.

Missing handoffs: Complex issues span multiple domains. A performance optimization might introduce a security vulnerability. Build cross-referencing so agents can flag implications in other domains.

Orchestrator bottleneck: If the orchestrator does too much work, you lose the parallelism benefits. Keep orchestration lightweight—route and merge, do not analyze.

Over-specialization: Agents that are too narrow miss important context. Balance specialization with enough context to make informed decisions.

Summary
Multi-agent systems enable specialization, modularity, parallelism, and resilience. Different patterns—parallel specialists, pipelines, hierarchical delegation, and debate—organize agent collaboration for different needs.

These benefits come with challenges: communication overhead, conflict resolution, and coordination complexity. Standardized formats, priority-based resolution, and clear role boundaries address these challenges.

Key Takeaways:

Use multi-agent systems when single agents cannot achieve necessary depth across multiple domains
Parallel specialists work independently and merge results—simple but may miss cross-domain insights
Pipelines build sequential understanding—better for complex reasoning chains
Hierarchical patterns let managers delegate based on need—efficient resource use
Standardize communication formats between agents for reliable interoperability
Define clear conflict resolution policies when agents disagree
Balance specialization with enough context for informed decisions