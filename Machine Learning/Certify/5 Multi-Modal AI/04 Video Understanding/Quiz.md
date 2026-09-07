## Quiz: Video Understanding

Video Understanding
You are building a video content analysis system for a media company. The system needs to analyze uploaded videos (ranging from 30-second clips to 2-hour documentaries) for content moderation, automatic chapter generation, and searchable video archives. You process 1,000 videos daily using gpt-4.1-mini Vision API by extracting and analyzing frames.


A 10-minute product review video needs chapter markers. The video has talking-head segments, product demos, and screen recordings. What frame sampling strategy should you use?

Extract 1 frame per second (600 frames total) for maximum coverage

Extract exactly 10 frames evenly spaced throughout the video

Use scene detection to extract frames at visual transitions, supplemented by regular intervals

Extract frames only when audio transcript indicates a topic change
Correct Answer!
Scene detection captures transitions (chapters), intervals ensure coverage of static segments.

You need to detect when a product is first shown in a review video. The product appears at different times in different videos. What approach works best?

Analyze each frame independently and find the first frame containing the product

Send all frames in one request asking the model to identify when the product is first prominently featured

Use binary search: check middle frame, then search earlier or later half

Train a custom object detection model for each product type
Correct Answer!
Multi-frame analysis with temporal prompt lets the model reason about sequence and prominence.

Your moderation system checks videos for policy violations. Most videos (95%) are safe, but you need to catch violations quickly. What is the most cost-effective approach?

Full analysis with high-detail frames for every video

Quick scan with low-detail frames first, detailed analysis only for flagged content

Random sampling of 10% of videos with thorough analysis

Analyze only the first and last frames of each video
Correct Answer!
Two-pass approach: cheap quick scan for most videos, expensive detailed analysis only when needed.

You want to make videos searchable by content (e.g., 'show me videos where someone demonstrates a cooking technique'). What should you index?

Only the video title and description provided by uploaders

Frame-by-frame descriptions of every extracted frame

Video summary, topics, entities, and scene descriptions with timestamps

Raw frame embeddings for vector similarity search
Correct Answer!
Comprehensive index enables semantic search while keeping storage manageable.

A 2-hour documentary needs full analysis. Processing all frames at once exceeds API context limits. What is the best approach?

Sample only 20 frames evenly distributed across 2 hours

Process in 10-minute segments, then use another call to synthesize segment summaries

Extract audio transcript and skip visual analysis entirely

Increase API timeout and send all frames in one very large request
Correct Answer!
Hierarchical analysis: detailed segment analysis, then synthesis preserves detail and stays within limits.