Content Management and Optimization
This quiz evaluates your understanding of token limits, pricing optimization, chunking strategies, prompt chaining, and context management. You'll need to solve cost-optimization problems, design effective chunking strategies, and architect multi-step prompt chains for complex tasks.


Your document analysis application processes research papers averaging 15,000 tokens each. Initial implementation uses GPT-5 ($0.025 input/$0.05 output per 1M tokens) for all processing. After analyzing usage patterns, you find 70% of tasks involve simple section extraction that could use GPT-5 mini ($0.0008 input/$0.0012 per 1M tokens), while only 30% require complex reasoning. What optimization strategy provides the best cost-quality balance?

Switch entirely to GPT-5 mini to maximize cost savings across all tasks

Implement dynamic model selection routing simple tasks to GPT-5 mini and complex tasks to GPT-5

Use Claude Sonnet 4 for all tasks since larger context windows eliminate chunking needs

Implement aggressive chunking to reduce all papers below 2,000 tokens for cheaper processing
Correct Answer!
Routes simple tasks (70%) to GPT-5 mini and complex tasks to GPT-5, optimizing both quality and cost.

You built a customer support chatbot that references a 50-page product manual. Users report the bot cannot answer questions about troubleshooting steps that appear in later sections of the manual. Your current implementation truncates the manual at the token limit. Which chunking strategy best solves this problem?

Increase context window size to fit the entire manual in one prompt

Use simple truncation but start from the end of the document instead

Implement keyword density analysis to prioritize chunks most relevant to the user query

Split the manual into equal-sized chunks and process all chunks for every query
Correct Answer!
Keyword density prioritizes sections relevant to user queries, retrieving specific content within token limits regardless of document position.

Your legal document analysis chain has three steps: extract key clauses, analyze risk factors, generate recommendations. The third step sometimes produces generic recommendations that do not align with specific risks identified in step two. What is the most likely cause and solution?

Step three needs more examples in few-shot prompting to show proper recommendation patterns

Inadequate context management between steps—step three is not receiving sufficient detail from step two

The chain should use conditional branching based on risk severity rather than sequential processing

Token limits are causing truncation of step two output before it reaches step three
Correct Answer!
Misaligned outputs indicate inadequate context passing. Step three needs detailed risk findings from step two for specific recommendations.

Your financial reporting system processes 10,000 transaction records daily, generating analysis reports. Current implementation sends all records to Claude Sonnet 4 in a single call at $3 input/$15 output per million tokens. Each report costs approximately $8.50. Your manager wants to reduce costs by 60% while maintaining report quality. Which approach is most viable?

Switch to GPT-5 mini for all processing to minimize per-token costs

Reduce the number of transactions analyzed per report from 10,000 to 4,000

Use aggressive chunking to process transactions in smaller batches with GPT-5 mini

Implement caching for common transaction patterns and use GPT-5 mini for initial categorization, Claude Sonnet 4 for complex analysis only
Correct Answer!
Caching common patterns, GPT-5 mini for categorization, and Claude Sonnet 4 for complex analysis only achieves 60% cost reduction while preserving quality.

Your research paper analysis system chunks documents by splitting every 2,000 tokens without regard to document structure. Users complain that analysis misses connections between related findings spread across multiple sections. Which document-aware strategy would most improve analysis quality?

Reduce chunk size to 1,000 tokens to create more granular processing

Add 20% overlap between chunks to prevent boundary information loss

Chunk by semantic sections (Introduction, Methods, Results) while preserving complete section content

Implement priority-based selection to include only the most important sections
Correct Answer!
Semantic section chunking keeps related findings together, preserving relationships that token-based splitting destroys.

You are designing a prompt chain for competitor analysis. The chain should: identify competitors, analyze their features, assess pricing, evaluate marketing, then synthesize findings. During testing, the synthesis step takes too long and sometimes times out. What architectural change best addresses this issue?

Convert the sequential chain into a branching chain where feature, pricing, and marketing analysis happen in parallel after competitor identification

Reduce the number of competitors analyzed in the first step to speed up subsequent analysis

Combine all analysis steps into a single comprehensive prompt to eliminate chain overhead

Add conditional logic to skip marketing analysis when feature and pricing analysis are sufficient
Correct Answer!
Parallel processing of independent tracks (features, pricing, marketing) significantly reduces execution time while maintaining information completeness.

SkillUp | Hackerrank