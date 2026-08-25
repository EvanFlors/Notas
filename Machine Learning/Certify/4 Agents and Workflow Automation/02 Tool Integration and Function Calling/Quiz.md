Quiz: Tool Integration and Function Calling
Tool Integration and Function Calling
Your code review agent needs to interact with GitHub APIs, security scanners, and CI systems. The agent understands what needs to be done but cannot execute actions. You must implement function calling so the agent can actually fetch PR details, run security scans, check test coverage, and post comments. The system must handle API rate limits, validate parameters, and provide clear error messages when tools fail.


In the function calling workflow, what happens during the 'selection' phase?

The model outputs a function call request that you parse and execute

The model decides which function to call based on the user's request and available function definitions

You describe available functions to the model with names, descriptions, and parameter schemas

The function result is fed back to the model to continue reasoning
Why is native function calling preferred over prompt-based parsing approaches?

Native function calling is faster than parsing text output

Native function calling provides structured, validated output that matches schemas, eliminating parsing ambiguity and errors

Native function calling requires less code to implement than parsing approaches

Native function calling only works with OpenAI models
Correct Answer!
Native function calling returns structured data that matches your schemas, avoiding JSON parsing errors and format inconsistencies.

Your agent keeps calling the wrong tools. When asked to check test coverage, it calls the security scanner. What is the most likely cause?

The tool implementations are buggy

The tool schema descriptions are vague or unclear, making it difficult for the model to distinguish between tools

The execution layer is not routing function calls correctly

The model's temperature setting is too high
Correct Answer!
The model selects tools based almost entirely on descriptions. Vague descriptions lead to incorrect tool selection.

When designing tool schema parameters, why should you use enums for values like severity levels instead of free-form strings?

Enums make the tool execute faster than string parameters

Enums provide validation, prevent invalid values, and make valid options explicit to the model

Enums reduce the number of tokens needed in function calls

Enums are required by all LLM function calling APIs
Correct Answer!
Enums constrain values to valid options, prevent typos, and clearly communicate acceptable values to the model.

What are the three core responsibilities of the execution layer in a function calling system?

Defining schemas, selecting tools, and executing functions

Routing function calls to implementations, executing those implementations safely, and formatting results for the model

Validating parameters, calling APIs, and storing results in a database

Parsing natural language, generating function calls, and handling errors
Correct Answer!
The execution layer routes calls to the right implementation, executes them safely, and formats results so the model can use them.

When a tool execution fails (e.g., API rate limit exceeded), how should the execution layer handle this for the agent?

Return null or empty result and let the agent continue without knowing about the failure

Return a structured error response that explains what failed and why, enabling the agent to retry or choose alternative actions

Automatically retry the failed call up to 3 times before returning an error

Throw an exception that stops the agent loop immediately
Correct Answer!
Clear error messages help the agent understand failures, retry with backoff, or choose alternative tools to accomplish the goal.

What makes a tool schema description effective for enabling reliable tool selection?

Short, concise descriptions that fit on one line

Descriptions that explain what the function does, when to use it, what it returns, and any important constraints or limitations

Descriptions that match the function name exactly

Descriptions written in technical jargon that matches the implementation code
Correct Answer!
Comprehensive descriptions covering purpose, usage context, return values, and constraints help the model make accurate tool selection decisions.