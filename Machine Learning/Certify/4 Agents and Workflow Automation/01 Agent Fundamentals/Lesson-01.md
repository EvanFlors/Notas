## From Chatbots to Agents

Imagine you have built an LLM-powered code assistant that answers developer questions beautifully. It explains design patterns, suggests refactoring strategies, and provides helpful code snippets. Then a developer asks: "Review my pull request for security issues." Your assistant describes what a good security review looks like—but it cannot actually check the code. It talks about work but cannot do work.

This is the fundamental limitation of chatbots. They generate text about actions but cannot take actions. This limitation led to the development of AI agents—systems that do not just respond but actively accomplish goals.

In this lesson, you will understand what makes an AI system an agent rather than a chatbot, learn the core agent loop that powers autonomous decision-making, and explore the components that production agents require.

By the end, you will have a clear mental model for agent architecture that guides your decisions when building systems that do not just answer questions but actively solve problems.

What Makes an Agent Different
You have built LLM applications before. A user sends a prompt, your code calls an API, and the model returns a response. This works well for question answering, content generation, and conversational interfaces. But what happens when you need your application to actually do something—to check a database, update a ticket, send an email, or make decisions over multiple steps?

This is where agents come in. An agent is not just a model that responds to prompts. It is a system that can perceive its environment, make decisions, and take actions to achieve specific goals. Think of the difference like asking someone for directions versus hiring a driver. The chatbot tells you where to go; the agent takes you there.

Consider a code review scenario. A chatbot might answer "What should I look for in a code review?" with a list of best practices. An agent, however, can analyze your pull request, identify potential bugs and security vulnerabilities, check for style guide violations, verify test coverage, suggest specific improvements with code snippets, and even run the test suite to confirm nothing breaks—all from a single request like "Review my pull request."

The distinction matters in production. Chatbots excel at single-turn interactions where the model generates text and you are done. Agents excel at multi-step workflows where decisions depend on external data and actions produce real-world effects. The architecture you choose determines what your application can accomplish.

![Chatbot vs Agent](https://hrcdn.net/ai-engineering/module-4/light/agent-fundamentals-lesson01-chatbot-vs-agent.svg)

The Agent Loop
Every agent operates through a decision-making loop that repeats until it achieves its goal or determines it cannot proceed. This loop has four key phases: perception, reasoning, action, and observation.

Perception is how the agent understands its current situation. This includes the user's request, the conversation history, available tools, and any context from previous actions. In a deployment automation agent, perception might include the current deployment status, server health metrics, and recent error logs.

Reasoning is where the agent decides what to do next. Given what it perceives, what action brings it closer to the goal? Should it gather more information, execute a tool, or provide a final response? This is where the language model's capabilities shine—it can analyze complex situations and plan multi-step solutions.

Action is the agent executing its decision. This might be calling an API, querying a database, running a script, or generating a response for the user. Actions change the state of the system or gather new information.

Observation is receiving feedback from the action. What did the API return? Did the database query succeed? What error occurred? This observation becomes part of the agent's perception in the next loop iteration.

Here is what this looks like in practice. A deployment agent receives the goal "Deploy version 2.1.0 to production." It perceives that deployment requires checking prerequisites, backing up the current version, and executing deployment scripts. It reasons that it should first verify prerequisites. It acts by checking server capacity and dependencies. It observes that one dependency is outdated. This observation feeds back into perception, and the reasoning phase now knows it must update dependencies before proceeding with deployment.

![Agent Loop](https://hrcdn.net/ai-engineering/module-4/light/agent-fundamentals-lesson01-agent-loop.svg)

The loop continues until the agent either completes the goal successfully or determines it cannot proceed (perhaps due to insufficient permissions or an unrecoverable error). This iterative approach allows agents to handle complex, dynamic situations that would require extensive hardcoded logic in traditional systems.

Agent Components and Architecture
Building an agent requires more than just prompting a language model in a loop. Production agents need several interconnected components working together.

The reasoning engine is typically a large language model that drives decision-making. You prompt it with the current state, available actions, and the goal. It returns structured decisions about what to do next. GPT-5.1, Claude, or open-source models like Llama can serve this role. The key is prompt engineering: you must clearly describe available tools, the current situation, and the decision format you expect.

The tool registry defines what actions the agent can take. Each tool has a name, description, and parameters. When you give an agent a "send_email" tool, you specify what parameters it requires (recipient, subject, body) and what it returns (success confirmation or error). The reasoning engine selects tools based on these descriptions, so clarity is critical.

The execution layer actually runs the tools. When the reasoning engine decides to call "query_database," the execution layer handles the actual database connection, query execution, error handling, and result formatting. This layer isolates the agent's logic from implementation details. You can change how you query the database without modifying the agent's reasoning process.

State management tracks what has happened across loop iterations. The agent needs to remember what tools it has called, what results it received, and what decisions it made. Without state management, the agent might repeat failed actions or forget crucial context. In production, state management also enables resumability—if an agent crashes mid-task, you can restore its state and continue from where it left off.

Safety controls prevent the agent from taking harmful or unintended actions. This includes permission systems (can this agent delete data?), rate limiting (prevent infinite loops), cost controls (stop if LLM API costs exceed thresholds), and validation (check that tool parameters are sensible before execution). Safety controls are not optional in production systems.

![Production agent architecture components](https://hrcdn.net/ai-engineering/module-4/dark/agent-fundamentals-lesson01-architecture.svg)

Consider a code review agent. The reasoning engine analyzes pull requests and decides what checks to run. The tool registry includes "run_linter," "check_tests," "analyze_complexity," and "post_comment." The execution layer runs these tools against the actual codebase. State management tracks which checks have completed and their results. Safety controls ensure the agent cannot merge code without human approval or post abusive comments.

The architecture looks like this: the user provides a goal → the reasoning engine perceives the current state and available tools → it decides on an action → the execution layer runs that action → the result updates the state → the loop repeats. Each component has a clear responsibility, making the system testable and maintainable.

Agent vs Traditional Automation
You might wonder: how is this different from a script or workflow automation tool? Both can check databases, send emails, and make decisions. The difference lies in adaptability and decision-making flexibility.

Traditional automation follows predetermined paths. An automation script might say: "If order status is 'shipped' and delivery date passed, send refund email and update database." This works perfectly for predictable scenarios. But what if the customer asks "My package says delivered but I did not receive it—can I get a refund?" The script has no path for this situation. You must anticipate every scenario and code explicit rules.

Agents use general reasoning to handle novel situations. The agent has tools like "check_order_status," "verify_delivery," "process_refund," and "send_email." When faced with the delivery issue, it reasons through the problem: check the order status, see that it shows delivered, recognize this conflicts with the customer's claim, decide to offer a refund due to delivery problems, execute the refund, and send confirmation. You did not hard-code this specific sequence—the agent figured it out.

This adaptability comes with trade-offs. Agents are slower than scripts because LLM inference takes time. Agents are less predictable because the reasoning engine might make different decisions in similar situations. Agents are more expensive due to API costs for each reasoning step. And agents can make mistakes because language models are not perfect reasoners.

Use agents when you need flexibility: customer support handling diverse requests, deployment systems dealing with varying infrastructure states, or data processing pipelines that adapt to different data formats. Use traditional automation when the workflow is fixed: nightly backup scripts, scheduled report generation, or form validation. Many production systems use both—agents for adaptive decision-making, scripts for reliable execution of known processes.

Building Your First Agent
Let us walk through a minimal agent implementation to see how these concepts come together. We will build an agent that helps developers debug failed CI/CD builds.

The user's goal: "Why did build #1247 fail?" The agent has three tools: get_build_logs, search_error_patterns, and suggest_fix. Here is how the loop works:

Iteration 1: The reasoning engine perceives the user's question and available tools. It reasons that it needs the build logs first. It acts by calling get_build_logs(build_id="1247"). It observes the logs, which show a Python import error.

Iteration 2: Now the agent perceives it has logs with an import error. It reasons that searching for similar errors might provide context. It acts by calling search_error_patterns(error="ImportError: cannot import name 'deprecated'"). It observes that this error commonly occurs when dependency versions are mismatched.

Iteration 3: The agent perceives it has identified the issue. It reasons that it should provide a fix suggestion. It acts by calling suggest_fix(issue="dependency_mismatch"). It observes the suggestion: "Update requirements.txt to pin 'library-name==2.1.0'."

Iteration 4: The agent perceives it has gathered all necessary information. It reasons that it can now respond to the user. It acts by generating a final response: "Build #1247 failed due to a dependency version mismatch. The ImportError occurs because the CI environment has an incompatible version of 'library-name'. Update your requirements.txt to pin version 2.1.0."

The agent stops because it has achieved the goal of explaining the failure and suggesting a fix.

In code, this might look like:

```python
def agent_loop(goal, max_iterations=10):
  state = {"goal": goal, "history": [], "completed": False}

  for i in range(max_iterations):
      # Reasoning: decide what to do next
      decision = reasoning_engine.decide(state)

      if decision["action"] == "respond":
          return decision["response"]

      # Action: execute the tool
      tool_result = execute_tool(
          decision["tool_name"],
          decision["tool_params"]
      )

      # Observation: update state
      state["history"].append({
          "tool": decision["tool_name"],
          "result": tool_result
      })

  return "Agent reached max iterations without completing goal"
```

This is simplified, but it captures the essence. The reasoning engine looks at the current state and decides what to do. The execution layer runs the tool. The state updates with the result. The loop continues until the agent generates a final response.

Common Pitfalls
Agents introduce failure modes that do not exist in traditional applications. The reasoning engine might select the wrong tool, call a tool with invalid parameters, or get stuck in loops where it repeats the same failed action. These are not bugs in your code—they are limitations of language model reasoning.

Infinite loops happen when the agent does not recognize that an action failed or is not making progress. You tried to read a file that does not exist, the agent observes "file not found," but then tries to read it again. Mitigation: implement loop detection (if the same action fails three times, stop and ask for help) and maximum iteration limits.

Tool selection errors occur when the agent chooses the wrong tool for the situation. You want to update a database record, but the agent calls a read-only query tool instead. Mitigation: write clear tool descriptions, include examples of when to use each tool, and implement validation that checks tool calls make sense given the current state.

State explosion happens when the conversation history grows too large to fit in the model's context window. After 50 tool calls, you have megabytes of state data. Mitigation: summarize old history, keep only recent actions in full detail, and design agents to complete tasks in fewer steps.

Non-deterministic behavior frustrates debugging. You test the agent with a scenario, it works perfectly. You test again with the same inputs, and it makes different decisions. This is inherent to LLM-based agents. Mitigation: use lower temperature settings for more consistent behavior, log all reasoning decisions for debugging, and implement comprehensive testing that covers edge cases.

Understanding these pitfalls helps you design more robust agents. You build in safeguards from the start rather than discovering problems in production.

Summary
AI agents are systems that autonomously decide what actions to take to achieve goals. They differ from chatbots in their ability to execute multi-step workflows, interact with external tools, and adapt to dynamic situations without hardcoded logic.

The agent loop—perception, reasoning, action, observation—is the core pattern that enables this autonomy. The reasoning engine (typically an LLM) analyzes the current state and decides what to do next. Tools provide the agent's capabilities. State management tracks progress across iterations. Safety controls prevent harmful actions.

Agents excel at adaptive workflows where you cannot predict every scenario in advance. They introduce trade-offs: slower execution, higher costs, and potential for reasoning errors. Production systems often combine agents for flexible decision-making with traditional automation for reliable execution.

Key Takeaways:

Agents autonomously decide and execute actions to achieve goals, unlike chatbots that only respond to prompts
The agent loop (perceive → reason → act → observe) is the fundamental pattern for agent decision-making
Production agents require a reasoning engine, tool registry, execution layer, state management, and safety controls
Use agents for adaptive workflows and traditional automation for fixed, predictable processes
Common pitfalls include infinite loops, tool selection errors, state explosion, and non-deterministic behavior



```python
```

```python
```