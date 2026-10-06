## Quiz: Agent Fundamentals
Agent Fundamentals
Your team has built a chatbot that answers developer questions about code, but developers are frustrated because it cannot actually check their code or run tests. You need to upgrade it to an agent that can analyze pull requests, run security scans, check test coverage, and provide actionable feedback. The system must handle multi-step workflows, remember what it has already checked, and explain its reasoning for debugging.


What is the fundamental difference between a chatbot and an agent that makes agents better suited for code review tasks?

Agents use more advanced language models than chatbots

Agents can execute multi-step workflows with tools and maintain state across actions, while chatbots only generate text responses

Agents are faster at processing requests than chatbots

Agents provide more detailed explanations than chatbots
Correct Answer!
Agents can take actions (run tools, check code) and remember previous steps, enabling complex workflows that chatbots cannot handle.

In the agent loop, what happens during the 'observation' phase?

The agent decides what action to take next based on available tools

The agent receives feedback from executed actions, which becomes part of its perception for the next iteration

The agent executes a tool or generates a response to the user

The agent understands its current situation including user request and conversation history
Correct Answer!
Observation captures results from actions (API responses, tool outputs) and feeds them back into the agent's understanding.

Why does the ReAct pattern improve agent decision quality compared to agents that don't think out loud?

ReAct makes agents faster by reducing the number of tool calls needed

ReAct forces agents to explicitly reason about what to do next before acting, improving decision quality and providing debuggability

ReAct eliminates the need for state management in agent systems

ReAct allows agents to skip the perception phase in the agent loop
Correct Answer!
Explicit reasoning (thoughts) before actions helps agents make better decisions and provides transparency for debugging.

When designing tools for a code review agent, why is a mid-level abstraction (like `get_pr_details(pr_number)`) better than either very low-level (`github_api_call(endpoint, method)`) or very high-level (`merge_pr_if_approved(pr_number)`) tools?

Mid-level tools are faster to execute than low-level or high-level tools

Mid-level tools provide the right balance: they map to meaningful domain operations while remaining composable for diverse scenarios

Mid-level tools require less validation than low-level or high-level tools

Mid-level tools are the only type that agents can reliably use
Correct Answer!
Mid-level tools match common operations without being too complex (low-level) or too rigid (high-level), enabling flexible composition.

Your code review agent needs to remember that it already checked the authentication module for security issues. What type of memory is most appropriate for tracking this current task state?

Episodic memory, which stores specific past interactions as discrete episodes

Working memory, which tracks the current conversation, recent actions, and immediate observations

Semantic memory, which stores general knowledge and learned patterns

Procedural memory, which stores learned procedures and workflows
Correct Answer!
Working memory maintains short-term context about the current task, including what has been checked and what remains.

After 50 tool calls, your agent's conversation history has grown too large for the context window. According to agent fundamentals, which approach best mitigates this state explosion problem?

Increase the context window size to accommodate all history

Summarize old history, keep only recent actions in full detail, and design agents to complete tasks in fewer steps

Delete all history after each tool call to keep state minimal

Use a faster language model that can process larger contexts
Correct Answer!
Compression strategies (summarization, selective retention) and efficient task design prevent state explosion while maintaining necessary context.

Your code review agent needs to decide which security checks to run, execute those checks, track which checks have completed, and prevent unauthorized code merges. Which component handles tracking which checks have completed?

The reasoning engine, which analyzes pull requests and decides what checks to run

State management, which tracks what has happened across loop iterations including completed actions

The execution layer, which runs the security check tools

Safety controls, which prevent harmful actions like unauthorized merges
Correct Answer!
State management maintains context about what has been done, what results were received, and what remains to be done.