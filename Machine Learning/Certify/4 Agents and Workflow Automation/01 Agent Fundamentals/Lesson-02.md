## The ReAct Pattern
Imagine deploying an agent that performs code reviews. On Monday, it catches a critical SQL injection vulnerability and saves your team hours of debugging. On Tuesday, it approves a PR that introduces the same vulnerability pattern. When you investigate, you cannot understand why—the agent made a decision, but you have no visibility into its reasoning.

This opacity problem plagued early agent systems. The ReAct pattern—Reasoning and Acting—emerged to solve it. By making agents think out loud before each action, ReAct improves decision quality and provides the transparency you need for debugging, auditing, and building trust.

In this lesson, you will learn how the ReAct pattern structures agent reasoning, how to implement it in production systems, and how to handle common reasoning failures.

By the end, you will have the knowledge to build agents that explain their decisions, making them debuggable, auditable, and trustworthy.

How ReAct Works
When you ask an agent to complete a task, how does it decide what steps to take? The ReAct pattern provides the answer: the agent alternates between thinking about what to do and actually doing it. Think of it like a chess player who says their reasoning aloud—"If I move here, my opponent will likely respond with this, so I should instead..."—before making each move.

Before each action, the agent generates a thought that explains its reasoning. After each action, it observes the result and reasons about what to do next. This explicit reasoning improves decision quality and makes the agent's behavior more interpretable.

Here is what ReAct looks like in practice. You ask an agent: "Review the pull request for our authentication module." The agent's internal process looks like this:

Thought: "I need to analyze this pull request. I should first get the PR details and changed files to understand the scope."

Action: ```get_pr_details(pr_number=1247)```

Observation: "PR #1247: 'Add password reset feature'. Changes: 3 files modified, +127 lines, -12 lines. Files: auth_service.py, password_reset.py, tests/test_auth.py"

Thought: "This is a security-sensitive change. I should check for common authentication vulnerabilities and verify test coverage exists."

Action: ```analyze_code_security(files=["auth_service.py", "password_reset.py"])```

Observation: "Warning: password_reset.py line 45 uses predictable token generation. Recommendation: Use secrets.token_urlsafe() instead of random.randint()."

Thought: "I found a security issue. I should also check if the test coverage is adequate for this critical feature."

Action: ```check_test_coverage(files=["auth_service.py", "password_reset.py"])```

Observation: "Test coverage: auth_service.py 87%, password_reset.py 34%. Missing tests: token expiration, rate limiting."

Thought: "I have identified a security vulnerability and coverage gaps. I can now provide a comprehensive review."

Action: ```respond_to_user```

Response: "Review complete for PR #1247. Found 1 critical security issue: predictable token generation in password_reset.py (line 45). Test coverage is insufficient at 34% for password_reset.py—missing tests for token expiration and rate limiting. Recommend blocking merge until these issues are addressed."

Notice how the agent thinks before acting, and each thought informs the next action. Without explicit reasoning, the agent might check the server status and immediately respond without considering whether those metrics are normal. The reasoning steps ensure the agent gathers sufficient context before drawing conclusions.

![The ReAct pattern: thought → action → observation loop](https://hrcdn.net/ai-engineering/module-4/light/agent-fundamentals-lesson02-react-flow.svg)

The ReAct pattern also provides debuggability. When an agent makes a poor decision, you can examine its thought process. Did it misunderstand the situation? Did it have the wrong information? Did it choose an inappropriate tool? The thought traces reveal where reasoning went wrong, which is essential for improving agent behavior.

Implementing ReAct in Production
Implementing ReAct requires structuring your prompts to encourage explicit reasoning. You provide the model with a format that separates thoughts from actions, and you enforce this format during execution.

A typical ReAct prompt structure looks like this:

```code
You are an agent helping with code review. You have access to these tools:

- get_pr_details(pr_number): Returns PR title, description, changed files, and diff stats
- analyze_code_security(files): Scans files for security vulnerabilities
- check_test_coverage(files): Returns test coverage percentages and missing test cases
- run_linter(files): Checks code style and returns violations
- respond_to_user: Provide final review to user

You must follow this format:

Thought: [Your reasoning about what to do next]
Action: [The tool to call with parameters]
Observation: [Result from the tool - this will be provided by the system]

Continue this loop until you can respond to the user's question.

User question: {user_question}

Begin!
```

The agent then generates text in this format. Your execution loop parses the generated text, extracts the action, runs it, and feeds the observation back to the agent for the next iteration. This requires careful parsing and error handling.

Here is a simplified implementation:

```python
def react_loop(user_question, tools, max_iterations=10):
  prompt = build_react_prompt(user_question, tools)
  conversation_history = []

  for i in range(max_iterations):
      # Generate the next thought and action
      response = llm.generate(prompt + format_history(conversation_history))

      # Parse the response
      thought, action = parse_react_response(response)
      conversation_history.append({"thought": thought, "action": action})

      # Check if agent wants to respond
      if action["type"] == "respond_to_user":
          return action["content"]

      # Execute the action
      observation = execute_tool(action["tool"], action["params"])
      conversation_history.append({"observation": observation})

      # Check for stopping conditions
      if should_stop(conversation_history):
          break

  return "Agent could not complete task within iteration limit"
```

The key challenges are parsing (the model might not perfectly follow the format) and knowing when to stop (the agent might not explicitly signal completion). Production implementations need robust parsing that handles format deviations and multiple stopping conditions: reaching max iterations, detecting loops, encountering errors, or explicit completion signals.

Reasoning Quality and Failure Modes
The quality of an agent's reasoning directly affects its performance, and ReAct makes reasoning quality visible. But explicit reasoning also introduces new failure modes.

Reasoning errors happen when the agent's logic is flawed. It might think "This SQL query looks fine" when it actually contains a SQL injection vulnerability. These errors occur because language models do not have perfect world knowledge or domain expertise. Mitigation: provide domain context in the prompt ("Always check user input sanitization in database queries"), include relevant information in tool descriptions, and validate the agent's reasoning in the execution layer (if code constructs SQL from user input without parameterization, flag it regardless of what the agent thinks).

Premature termination occurs when the agent decides it has enough information but actually needs more. It checks the code diff, sees no obvious syntax errors, and approves the PR without checking for security issues, test coverage, or performance implications. This happens because the model does not realize certain observations require follow-up. Mitigation: include examples in prompts showing thorough investigation, explicitly list what checks must pass before approving, and implement heuristics that prevent responding with incomplete analysis.

Overthinking is when the agent takes unnecessary actions. It checks code style, security, test coverage, performance benchmarks, documentation, commit history, and contributor guidelines—just to answer "Does this one-line typo fix look okay?" This wastes time and API calls. Mitigation: prompt the agent to aim for efficiency, set iteration limits, and penalize unnecessarily complex solutions during evaluation.

Reasoning-action misalignment happens when the thought says one thing but the action does another. The agent thinks "I should check the database" but calls the server health check tool. This usually indicates the model did not properly understand available tools or struggled to map its reasoning to concrete actions. Mitigation: provide clear examples of thoughts matched with appropriate actions, use structured output formats for actions (JSON schemas), and validate that actions make sense given the stated reasoning.

![Common ReAct failure modes and their characteristics](https://hrcdn.net/ai-engineering/module-4/light/agent-fundamentals-lesson02-failure-modes.svg)

One subtle issue is that forcing explicit reasoning can actually hurt performance on simple tasks. If you ask "What is 2+2?" the agent does not need to think—it just needs to answer. The ReAct overhead adds complexity without benefit. Use ReAct for multi-step tasks where reasoning genuinely helps. For simple tasks, direct prompting is more efficient.

Advanced Reasoning Patterns
While basic ReAct alternates between single thoughts and single actions, production agents often need more sophisticated reasoning patterns. Several extensions to ReAct address different types of tasks.

Planning involves generating a complete action sequence upfront before executing any steps. Instead of reasoning step-by-step, the agent creates a plan: "First check server status, then get historical metrics, then analyze logs, then respond." This works well for tasks with clear, predictable steps. Planning reduces LLM calls (you generate the whole plan at once) and provides an overview of the approach before executing anything. The downside is rigidity: if step 2 reveals unexpected information, the plan might be invalid but the agent already committed to it.

You can combine planning with ReAct: the agent generates an initial plan but reconsiders it after each observation. If something unexpected happens, it revises the plan. This provides structure while maintaining adaptability.

Reflection means the agent evaluates its own actions and decisions. After attempting a solution, it asks itself: "Did this work? What could I have done better?" If the first approach failed, reflection helps the agent try a different strategy rather than repeating the same mistake.

A reflection-augmented agent loop looks like:

Thought: "I will search the codebase for security vulnerabilities."

Action: search_code(query="password")

Observation: "Found 847 results across 124 files, too many to analyze."

Reflection: "My search was too broad. I should focus on the files changed in this PR."

Thought: "I will search only the modified files for password handling."

Action: analyze_code_security(files=["auth_service.py", "user_handler.py"])

Observation: "Found 2 issues: hardcoded credentials on line 23, missing password hashing on line 67."

Without reflection, the agent might get stuck after the first failed search. Reflection enables course correction.

Decomposition breaks complex tasks into smaller sub-tasks. If you ask "Deploy the new feature and notify the team," the agent decomposes this into: (1) Deploy the feature, (2) Verify deployment succeeded, (3) Send notification. Each sub-task becomes its own ReAct loop. This prevents the agent from getting overwhelmed by complex multi-part goals.

Decomposition also enables parallelization. If sub-tasks are independent, you can execute them concurrently. "Check API server and database server" decomposes into two independent checks that can run simultaneously.

Chain-of-thought prompting is related to ReAct but focuses on intermediate reasoning steps for answering questions rather than taking actions. If you ask "If deployment A takes 5 minutes and deployment B takes 8 minutes, and they start simultaneously, when can we start deployment C that requires both?" a chain-of-thought response walks through the logic: "A finishes at 5 min, B finishes at 8 min, both are done at 8 min, so C can start at 8 min." This reasoning style improves accuracy on questions requiring multi-step logic.

![Advanced reasoning patterns](https://hrcdn.net/ai-engineering/module-4/light/agent-fundamentals-lesson02-advanced-patterns.svg)

Choosing the right reasoning pattern depends on your task. Multi-step workflows benefit from ReAct. Tasks with clear sequences benefit from planning. Agents that need error recovery benefit from reflection. Complex goals benefit from decomposition. Many production agents combine multiple patterns: plan the overall approach, use ReAct for execution with reflection for error recovery, and decompose sub-tasks when needed.

Reasoning with Constraints and Preferences
Real-world agents operate under constraints: time limits, cost budgets, rate limits, permissions, and user preferences. Effective reasoning must account for these constraints when deciding what actions to take.

Cost-aware reasoning considers the expense of each action. Calling an LLM API costs more than querying a local cache. Processing a large dataset takes longer than sampling. An agent debugging a production issue might think: "I could analyze all logs from the past week, but that will take 10 minutes. Instead I will check recent high-severity errors first, which takes 30 seconds and likely contains the relevant information."

Implementing cost awareness means providing cost information in tool descriptions ("search_all_logs: comprehensive but slow, search_recent_logs: faster but limited") and prompting the agent to prefer efficient approaches. You can also set hard limits: if a tool call would exceed the remaining budget, refuse execution and force the agent to find an alternative.

Permission-aware reasoning respects what the agent is allowed to do. An agent helping with deployments can read configurations but cannot write to production without approval. When the agent thinks "I should update the production database," it must recognize this requires human authorization and request it rather than attempting direct execution.

This requires the agent to understand its own capabilities and limitations. Tool descriptions should indicate permission levels: "restart_service: requires approval," "read_logs: always allowed." The agent's reasoning should account for this: "I need to restart the service but cannot do so directly. I will request approval from the user."

User preference reasoning customizes behavior based on user preferences. Some users want detailed explanations, others want concise answers. Some prefer conservative approaches, others accept higher risk for faster resolution. An agent that understands preferences tailors its actions accordingly.

You can provide preferences in the prompt: "The user prefers detailed explanations with evidence" or "The user values speed over thoroughness." The agent incorporates this into reasoning: "The user wants a quick answer, so I will check the most likely cause first rather than investigating all possibilities."

Advanced systems learn preferences over time. After multiple interactions, the agent recognizes patterns: "This user always asks follow-up questions about methodology, so I should proactively explain my reasoning" or "This user approves restart requests immediately, so I should default to suggesting restarts for performance issues."

Constraint-aware reasoning makes agents more practical for production use. An agent that ignores costs, permissions, or preferences creates problems even when it technically solves the task.

Measuring and Improving Reasoning Quality
How do you know if your agent's reasoning is good? Unlike traditional software where you test input-output pairs, agent evaluation requires assessing decision quality across multiple steps. Several approaches help measure and improve reasoning.

Process-based evaluation examines the reasoning steps rather than just the final outcome. Did the agent gather relevant information before deciding? Did it consider alternatives? Did it respond appropriately to unexpected observations? You can create rubrics that score each step: "Agent correctly identified the problem: 1 point," "Agent chose an appropriate tool: 1 point," "Agent recognized when it needed more information: 1 point."

This reveals whether success was luck or good reasoning. An agent might accidentally solve a problem by trying random actions. Process evaluation catches this, while outcome-only evaluation would rate it as successful.

Adversarial testing introduces scenarios designed to challenge reasoning. Give the agent misleading information and see if it questions it. Create situations where the obvious action is wrong and the correct action requires careful thought. Provide tools with similar descriptions to see if the agent distinguishes their appropriate use cases.

For example, test an agent with: "The server reports 'healthy' status but users are experiencing errors." A poorly reasoning agent accepts the status at face value. A good agent recognizes the contradiction and investigates further. Adversarial tests expose brittleness in reasoning that normal cases miss.

Reasoning chain analysis involves reviewing the thought traces from real agent interactions. Look for patterns: Does the agent frequently make the same reasoning error? Does it overthink simple cases? Does it take unnecessary actions? This qualitative analysis identifies where to improve prompts, add tool descriptions, or restructure the workflow.

You can automate some of this analysis by using another LLM to evaluate reasoning quality. Provide the trace and ask: "Was the reasoning logical? Did the agent miss any important considerations? Were actions appropriate given the situation?" This scales reasoning evaluation beyond what human review can handle.

A/B testing reasoning patterns compares different approaches. Run one version of your agent with basic ReAct, another with planning, and another with reflection. Measure task success rate, number of steps to completion, cost, and user satisfaction. This data-driven approach reveals which reasoning patterns work best for your specific use case.

Improving reasoning often comes down to better prompts. Adding examples of good reasoning helps the model understand what you expect. Providing domain knowledge helps it make informed decisions. Clarifying tool descriptions helps it choose appropriate actions. Iteration is key: test, analyze failures, adjust prompts, repeat.

Reasoning Transparency and Explainability
One major advantage of ReAct is transparency. The agent's thought process is visible, making its behavior explainable. This matters enormously in production systems where you need to understand why the agent made certain decisions.

Audit trails built from reasoning traces provide accountability. If an agent makes a costly mistake, you review the trace to understand what went wrong. Did it have the right information? Did it misinterpret something? Did it fail to consider relevant factors? This forensic analysis is impossible with black-box systems.

User trust increases when users can see the agent's reasoning. If an agent recommends blocking a PR merge, showing the thought process ("Found SQL query on line 45 constructed from user input without parameterization, this pattern commonly leads to SQL injection attacks, blocking until sanitization is added") builds confidence in the recommendation. Users can evaluate whether the reasoning is sound rather than blindly trusting the output.

Debugging and refinement rely on understanding reasoning failures. When you can see exactly where reasoning went wrong, you can fix it. Maybe the agent lacked a crucial piece of information, or misunderstood a tool's purpose, or made an invalid assumption. Each failure teaches you how to improve the system.

However, transparency has limits. Just because you can see the reasoning does not mean it is correct or complete. The agent might confidently state flawed logic. It might omit important considerations without realizing it. And it might generate plausible-sounding reasoning that does not reflect its actual decision process (language models do not have introspective access to their own computations; the "reasoning" is generated text that rationalizes decisions, not a true internal thought process).

Treat reasoning traces as explanations, not guarantees. They help you understand agent behavior, but they require validation. Cross-check reasoning against ground truth, test edge cases, and implement safeguards that catch reasoning errors.

Summary
The ReAct pattern improves agent decision-making by making reasoning explicit. Agents alternate between thinking about what to do and taking actions, with each thought informing the next step. This approach improves decision quality, provides debuggability, and makes agent behavior more interpretable.

Implementing ReAct requires careful prompt engineering to encourage explicit reasoning, robust parsing to handle format variations, and stopping conditions to prevent infinite loops. Production systems must handle reasoning errors, premature termination, overthinking, and reasoning-action misalignment.

Advanced reasoning patterns extend ReAct: planning generates action sequences upfront, reflection enables error recovery, decomposition breaks complex tasks into manageable pieces, and chain-of-thought improves multi-step logical reasoning. Constraint-aware reasoning accounts for costs, permissions, and user preferences.

Measuring reasoning quality requires process-based evaluation, adversarial testing, reasoning chain analysis, and A/B testing of different patterns. Reasoning transparency provides audit trails, builds user trust, and enables debugging, though it should be validated rather than blindly trusted.

Key Takeaways:

ReAct alternates between explicit reasoning (thoughts) and actions, improving decision quality and interpretability
Implementation requires structured prompts, robust parsing, and clear stopping conditions
Common failures include reasoning errors, premature termination, overthinking, and reasoning-action misalignment
Advanced patterns like planning, reflection, and decomposition extend ReAct for different task types
Constraint-aware reasoning accounts for costs, permissions, and user preferences in production systems
Measure reasoning quality through process evaluation, adversarial testing, and trace analysis
Reasoning transparency enables auditing and debugging but requires validation