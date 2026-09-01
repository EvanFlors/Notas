## Quiz: Vision-Language Models

Vision-Language Models
You are building an automated document processing system for an insurance company. The system needs to extract information from claim forms (PDFs with handwritten fields), supporting documents (photos of damaged items), and ID verification (driver's license photos). Your team has access to gpt-4.1-mini Vision API and needs to design a robust, cost-effective solution that processes 10,000 documents daily.


For processing driver's license photos where you need to extract the exact license number and expiration date, which detail level should you use and why?

Low detail - it's faster and cheaper, and text extraction works at any resolution

High detail - small text requires higher resolution for accurate character recognition

Auto detail - let the API decide based on image complexity

It doesn't matter - gpt-4.1-mini performs equally well at all detail levels
Correct Answer!
High detail preserves fine text. License numbers and dates are small - low resolution causes OCR errors.

Your system needs to extract claim amount, date, and policy number from forms into a database. What is the most reliable approach?

Ask the model to describe the form and parse the response with regex

Use response_format with JSON mode and explicit field definitions in the prompt

Fine-tune a custom model specifically for your form types

Use multiple API calls with different prompts and average the results
Correct Answer!
JSON mode with explicit schema ensures consistent, parseable output for database insertion.

A single insurance claim includes: a damaged car photo, a repair estimate document, and the claimant's driver's license. How should you process these for a comprehensive claim summary?

Three separate API calls, then combine the text outputs

Single API call with all three images in the content array

Concatenate images into one large image before sending

Process images sequentially in a multi-turn conversation
Correct Answer!
Single call with multiple images allows the model to correlate information across documents.

Your system extracts a claim amount from a handwritten form, but the model reports low confidence because the handwriting is unclear. What is the best production approach?

Accept the extraction anyway - some data is better than none

Retry the same request multiple times and use majority voting

Flag for human review when confidence is below threshold

Use a higher temperature setting to get more creative interpretations
Correct Answer!
Human review for uncertain cases prevents errors while maintaining automation for clear cases.

Processing 10,000 documents daily with high detail costs $500/day. Your manager asks you to reduce costs without sacrificing accuracy on critical fields. What is the best strategy?

Switch all processing to low detail mode

Use low detail for damage photos, high detail only for documents with text

Process only 50% of documents and extrapolate the results

Cache all responses and reuse them for similar-looking documents
Correct Answer!
Damage photos need visual understanding, not text extraction. Save high detail for documents.