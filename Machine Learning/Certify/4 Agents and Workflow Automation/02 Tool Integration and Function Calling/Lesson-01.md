## What is Function Calling?
Your code review agent understands pull requests perfectly. When you ask it to check for security issues, it describes exactly what vulnerabilities to look for. But description is not action. You want the agent to actually call your security scanner, fetch the PR diff, and post comments—not just talk about doing so.

Function calling is what makes this possible. It transforms a language model from a text generator into an action taker, outputting structured requests that your code can execute against real systems.

In this lesson, you will learn how function calling works, how to implement it with major LLM providers, and when to use it versus simpler approaches.

By the end, you will understand the mechanism that connects agent reasoning to real-world actions—the foundation for building agents that do not just think but act.

The Bridge from Thought to Action
Function calling is the mechanism that transforms a language model from a text generator into an action taker. Instead of just producing natural language responses, the model can output structured requests to execute specific functions with precise parameters. This capability bridges the gap between understanding what needs to be done and actually doing it.

When you ask a traditional LLM "Review this pull request for security issues," it generates text describing what a review might look like. When you ask an LLM with function calling the same question, it can output a structured call like ```analyze_code_security(pr_number=1247, focus=["injection", "auth"])``` that your system executes against real code.

The key insight is that function calling separates intent from execution. The model determines what function to call and with what parameters. Your code handles the actual execution. This separation provides control, safety, and flexibility that direct LLM actions cannot achieve.

Consider a code review agent. Without function calling, you might try to parse natural language output: "I would check the authentication module for SQL injection." With function calling, you get structured output: ```{"function": "analyze_code_security", "arguments": {"files": ["auth.py"], "vulnerability_types": ["sql_injection"]}}```. The structured format is unambiguous, parseable, and directly executable.

Function calling is not a single feature but a protocol between your application and the LLM. You describe available functions, the model selects and parameterizes them, and you execute the results. This protocol enables reliable tool use in production systems.

How Function Calling Works
The function calling workflow has four distinct phases: definition, selection, execution, and response integration.

Definition is where you describe available functions to the model. Each function needs a name, description, and parameter schema. For a code review agent, you might define:

```json
{
"name": "get_pr_diff",
"description": "Retrieves the code diff for a pull request, showing all changed lines",
"parameters": {
  "type": "object",
  "properties": {
    "pr_number": {
      "type": "integer",
      "description": "The pull request number to fetch"
    },
    "file_filter": {
      "type": "string",
      "description": "Optional glob pattern to filter files (e.g., '*.py')"
    }
  },
  "required": ["pr_number"]
}
}
```

This schema tells the model exactly what the function does, what parameters it accepts, and which are required. The quality of these definitions directly affects how well the model uses the tools.

Selection is where the model decides which function to call based on the user's request and available functions. Given "Check PR 1247 for Python security issues," the model reasons that it needs the code diff first, selects ```get_pr_diff```, and provides appropriate arguments: ```{"pr_number": 1247, "file_filter": "*.py"}```.

The model might also decide that no function call is needed. If the user asks "What security issues should I look for in authentication code?", the model can respond directly with information rather than calling a function.

Execution is your responsibility. The model outputs a function call request; you parse it, validate the parameters, execute the actual function, and capture the result. This is where your code interacts with real systems—GitHub APIs, security scanners, databases.

Response integration feeds the function result back to the model. The model receives the execution output and uses it to continue reasoning or formulate a final response. After receiving the diff, the model might call ```analyze_code_security``` with the relevant code, then synthesize findings into a coherent review.

This workflow can repeat multiple times. Complex tasks require multiple function calls, each building on previous results. The model orchestrates these calls to achieve the user's goal.

![The function calling workflow: from definition to response integration](https://hrcdn.net/ai-engineering/module-4/light/tool-integration-lesson01-workflow.svg)

Function Calling vs Traditional Approaches
Before function calling became a native LLM capability, developers used various workarounds to enable tool use. Understanding these alternatives clarifies why function calling is preferred.

Prompt-based parsing instructs the model to output in a specific format that you parse. You might prompt: "When you need to call a function, output JSON like: ```{function: name, args: \{...\}}```". This works but is fragile. The model might not follow the format perfectly, might include extra text, or might format JSON incorrectly. You need robust parsing and error handling.

ReAct-style text parsing uses the Thought/Action/Observation format from the previous submodule. The model outputs "Action: ```get_pr_diff(1247)```" and you parse that text. This is more readable but still requires text parsing with all its ambiguity.

Native function calling is built into the model's API. You pass function definitions as structured data, and the model returns function calls as structured data. No parsing of natural language output required. The model is trained to produce valid function calls that match your schemas.

The advantages of native function calling are significant:

Reliability: The model produces properly formatted output because it is trained to do so. You do not need to handle malformed JSON or unexpected text.

Validation: The API can validate that function calls match defined schemas before returning them. Invalid parameter types or missing required fields get caught automatically.

Clarity: Function definitions are separate from prompts. You can modify available tools without changing prompt text. The model clearly distinguishes between when it is responding with text versus requesting a function call.

Parallel calling: Some APIs support the model requesting multiple function calls simultaneously. "Check security and test coverage" can become two parallel calls rather than sequential.

Most production agent systems use native function calling when available. The reliability and structure justify any additional complexity in setup.

![Function calling approaches: from fragile parsing to native structured output](https://hrcdn.net/ai-engineering/module-4/light/tool-integration-lesson01-comparison.svg)

Provider-Specific Implementations
Different LLM providers implement function calling with varying syntax and capabilities. Understanding these differences helps you build portable agent systems.

OpenAI uses a ```tools``` parameter with function definitions and returns ```tool_calls``` in the response. Functions are defined with JSON Schema for parameters. The model can request multiple tool calls in a single response.

```python
response = client.chat.completions.create(
  model="gpt-4",
  messages=[{"role": "user", "content": "Review PR 1247 for security issues"}],
  tools=[{
      "type": "function",
      "function": {
          "name": "analyze_code_security",
          "description": "Scan code files for security vulnerabilities",
          "parameters": {
              "type": "object",
              "properties": {
                  "pr_number": {"type": "integer"},
                  "severity_threshold": {"type": "string", "enum": ["low", "medium", "high"]}
              },
              "required": ["pr_number"]
          }
      }
  }]
)

# Check if model requested a function call
if response.choices[0].message.tool_calls:
  tool_call = response.choices[0].message.tool_calls[0]
  function_name = tool_call.function.name
  arguments = json.loads(tool_call.function.arguments)
```

Anthropic uses a similar ```tools``` parameter with XML-style tool definitions. Claude returns tool use in a ```tool_use``` content block with structured arguments.

Open-source models vary widely. Some support function calling natively through their APIs (like Llama via certain providers), while others require prompt-based approaches. Libraries like LangChain and LlamaIndex abstract these differences.

The core concepts remain consistent across providers: you define functions, the model selects and parameterizes them, you execute and return results. Build abstraction layers in your code to handle provider-specific syntax while keeping your business logic portable.

When to Use Function Calling
Function calling is powerful but not always necessary. Understanding when it adds value helps you make appropriate architectural decisions.

Use function calling when you need structured actions. If the agent must interact with external systems—APIs, databases, file systems—function calling provides the structure for reliable interaction. A code review agent that needs to fetch PR details, run security scans, and post comments requires function calling to interact with GitHub and security tools.

Use function calling when outputs must be precise. If you need specific data formats, exact parameter values, or unambiguous action requests, function calling enforces structure. Asking the model to "output the PR number" might get "PR #1247" or "pull request 1247" or "1247". Function calling with a typed parameter guarantees you get the integer 1247.

Use function calling when you need auditability. Function calls create clear records of what actions were requested. For compliance, debugging, or monitoring, having structured logs of every tool invocation is valuable. You know exactly what the model tried to do, not just what text it generated.

Skip function calling for pure conversation. If the agent only needs to discuss, explain, or generate text, function calling adds unnecessary complexity. An agent answering "What security issues should I look for?" does not need tools—it needs knowledge.

Skip function calling for simple transformations. If you just need the model to reformat data or extract information from text, direct prompting is simpler. Extracting key points from a code review discussion does not require function calling.

Consider hybrid approaches. Many agents use function calling for actions but direct generation for explanations. The code review agent calls functions to analyze code, then generates natural language summaries of findings. Both capabilities work together.

Common Pitfalls
Function calling introduces failure modes that differ from traditional LLM applications. Being aware of these helps you build more robust systems.

Over-eager function calling happens when the model calls functions unnecessarily. Asked "What does the ```get_pr_diff``` function do?", the model might call the function instead of explaining it. Mitigation: include instructions about when to call functions versus when to respond directly.

Parameter hallucination occurs when the model invents parameter values. Asked to review "the latest PR," the model might guess a PR number rather than asking for clarification. Mitigation: make the model acknowledge when it lacks required information, and validate parameters against known values when possible.

Function selection errors happen when the model picks the wrong function for the task. With many similar functions, the model might confuse ```analyze_code_security``` with ```analyze_code_quality```. Mitigation: write distinct, clear descriptions; consider reducing the number of available functions for specific tasks.

Infinite loops can occur if the model keeps calling functions without making progress. It might repeatedly call ```get_pr_diff``` with the same parameters expecting different results. Mitigation: track function call history, implement maximum iteration limits, and detect repeated identical calls.

Context overflow happens when function results are too large. A PR diff with thousands of lines might exceed context limits. Mitigation: design functions to return summarized or paginated results; implement truncation strategies.

Understanding these pitfalls prepares you for robust implementation. Function calling is reliable but not foolproof—your system design must account for edge cases.

Summary
Function calling enables LLMs to interact with external systems through structured requests rather than natural language parsing. The workflow involves defining available functions with schemas, letting the model select and parameterize calls, executing those calls in your code, and feeding results back to the model.

Native function calling from LLM providers is more reliable than prompt-based parsing approaches. Different providers have varying syntax, but the core concepts are consistent. Function calling is most valuable when you need structured actions, precise outputs, or auditability.

Common pitfalls include over-eager calling, parameter hallucination, selection errors, infinite loops, and context overflow. Awareness of these failure modes guides robust system design.

Key Takeaways:

Function calling separates intent (what to do) from execution (how to do it), giving you control over actual system interactions
The workflow is: define functions → model selects and parameterizes → you execute → feed results back
Native function calling is more reliable than parsing natural language output
Use function calling for structured actions and precise outputs; skip it for pure conversation
Design for common pitfalls: hallucinated parameters, wrong function selection, and infinite loops