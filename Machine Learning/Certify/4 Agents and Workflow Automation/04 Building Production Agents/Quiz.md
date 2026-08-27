## Quiz: Building Production Agents
Building Production Agents
Your code review agent works perfectly in development but fails in production. It approved a PR with a SQL injection vulnerability, consumed $200 in API costs on a single review, and got stuck in infinite loops. You need to implement resilience patterns, observability, cost controls, and deployment strategies to make it production-ready.


Your code review agent completes successfully but approves a PR containing a SQL injection vulnerability. What type of agent failure is this?

Infrastructure failure, because the agent crashed during execution

Reasoning failure, where the agent makes a bad decision without throwing errors or crashing

Token explosion, because the agent consumed too many tokens

Goal drift, because the agent changed its objective mid-review
Correct Answer!
Reasoning failures occur when agents complete successfully but make incorrect decisions. No exceptions are thrown, making them hard to detect.

Your agent keeps calling get_file_content('auth.py') repeatedly without making progress. What strategies help detect and prevent this infinite loop?

Only set maximum time limits; agents will naturally stop when they complete their task

Track action history to flag repeated identical calls, set maximum iterations per task, and require progress indicators

Increase the context window so the agent can see all previous actions

Use faster language models that process requests more quickly
Correct Answer!
Loop detection requires tracking actions, limiting iterations, and monitoring for progress. Repeated identical calls indicate a loop.

Why are token budgets essential for production agents?

Token budgets make agents execute faster by limiting context size

Token budgets provide hard limits on API costs per task, preventing catastrophic spending when agents get stuck or encounter difficult cases

Token budgets improve agent accuracy by forcing concise reasoning

Token budgets are only needed for development, not production
Correct Answer!
Token budgets bound costs even in worst-case scenarios, ensuring predictable spending when agents loop or process complex cases.

When debugging why an agent approved a vulnerable PR, what type of observability reveals the agent's thought process?

Infrastructure observability, which shows uptime, error rates, and latency

Behavior observability, which tracks which tools were called and what results were returned

Reasoning observability, which captures the agent's thought process, what it considered, and how it connected observations to decisions

Cost observability, which tracks token usage and API spending
Correct Answer!
Reasoning observability captures the agent's internal reasoning, revealing why it made specific decisions.

To reduce token costs, which strategy is most effective for code review agents?

Always load full file contents to ensure the agent has complete context

Use diffs instead of full files, summarize old conversation history, and only include relevant context from previous iterations

Use the largest available context window to avoid summarization overhead

Cache all tool results indefinitely to avoid repeated API calls
Correct Answer!
Diffs show changes efficiently, summarization compresses history, and selective context inclusion reduces token usage significantly.

Your agent was asked to review a PR for security issues but ended up focusing entirely on code style. What pattern helps prevent this goal drift?

Use faster language models that process requests more quickly

Include the goal in every prompt iteration, structure tasks as explicit phases, and validate final output against the original goal

Reduce the number of tools available to the agent

Increase the context window so the agent remembers the original goal better
Correct Answer!
Repeating goals, using structured phases, and validating outputs help agents maintain focus on original objectives throughout execution.

When should you implement circuit breakers for agent systems?

Circuit breakers are only needed for traditional software, not agent systems

Circuit breakers help prevent cascading failures when external services fail repeatedly, stopping the agent from making more calls until the service recovers

Circuit breakers make agents faster by skipping validation steps

Circuit breakers are only useful for preventing infinite loops in agents
Correct Answer!
Circuit breakers detect repeated failures and stop making calls, preventing wasted resources and allowing services to recover.