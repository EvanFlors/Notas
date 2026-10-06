## Video Content Moderation

Video platforms need to identify problematic content before it reaches users. Video moderation combines visual analysis with temporal understanding to detect policy violations that may be subtle or context-dependent.

```python
from dataclasses import dataclass
from enum import Enum
from typing import Optional

class ModerationCategory(Enum):
  SAFE = "safe"
  VIOLENCE = "violence"
  ADULT_CONTENT = "adult_content"
  HATE_SPEECH = "hate_speech"
  DANGEROUS_ACTIVITY = "dangerous_activity"
  SPAM = "spam"
  NEEDS_REVIEW = "needs_review"

@dataclass
class ModerationResult:
  decision: ModerationCategory
  confidence: float
  flagged_frames: list[int]
  reasoning: str
  requires_human_review: bool

class VideoModerationService:
  """
  Video content moderation service.

  Analyzes videos for policy violations using frame sampling
  and AI analysis.
  """

  def __init__(self, client, policy_config: dict = None):
      self.client = client
      self.policy = policy_config or self._default_policy()

  def _default_policy(self) -> dict:
      return {
          "categories": ["violence", "adult_content", "dangerous_activity", "hate_symbols"],
          "confidence_threshold": 0.7,
          "frames_to_analyze": 10
      }

  def moderate_video(self, video_path: str) -> ModerationResult:
      """
      Moderate a video for content policy compliance.
      """
      frames = extract_frames_by_count(
          video_path,
          self.policy["frames_to_analyze"]
      )

      # First pass: quick classification
      quick_result = self._quick_classification(frames)

      if quick_result["likely_safe"]:
          return ModerationResult(
              decision=ModerationCategory.SAFE,
              confidence=quick_result["confidence"],
              flagged_frames=[],
              reasoning="No concerning content detected",
              requires_human_review=False
          )

      # Second pass: detailed analysis of concerning frames
      detailed_result = self._detailed_analysis(
          frames,
          quick_result["concerning_frames"]
      )

      return detailed_result

  def _quick_classification(self, frames: list) -> dict:
      """Quick pass to identify potentially problematic content."""
      content = [
          {
              "type": "text",
              "text": """
                    Quickly scan these video frames for any concerning content.

                    Categories to check:
                    - Violence or gore
                    - Adult/sexual content
                    - Dangerous activities
                    - Hate symbols or offensive imagery

                    For each frame, mark as:
                    - "safe": No concerns
                    - "concerning": Needs closer look
                    - "violation": Clear policy violation

                    Return JSON:
                    {
                    "frame_assessments": [{"frame": 1, "status": "safe/concerning/violation"}],
                    "likely_safe": true/false,
                    "confidence": 0.0-1.0,
                    "concerning_frames": [frame_numbers]
                    }
                """
          }
      ]

      for i, (timestamp, frame) in enumerate(frames, 1):
          content.append({
              "type": "image_url",
              "image_url": {
                  "url": f"data:image/jpeg;base64,{frame_to_base64(frame)}",
                  "detail": "low"  # Low detail for quick scan
              }
          })

      response = self.client.chat.completions.create(
          model="gpt-4.1-mini",
          messages=[{"role": "user", "content": content}],
          response_format={"type": "json_object"},
          max_tokens=500
      )

      import json
      return json.loads(response.choices[0].message.content)

  def _detailed_analysis(self, frames: list, concerning_indices: list) -> ModerationResult:
      """Detailed analysis of flagged frames."""
      if not concerning_indices:
          return ModerationResult(
              decision=ModerationCategory.SAFE,
              confidence=0.9,
              flagged_frames=[],
              reasoning="No concerning content found",
              requires_human_review=False
          )

      # Analyze concerning frames in high detail
      concerning_frames = [frames[i-1] for i in concerning_indices if i <= len(frames)]

      content = [
          {
              "type": "text",
              "text": """
                Analyze these flagged frames in detail for content policy violations.

                    For each frame, determine:
                    1. Specific policy violation (if any)
                    2. Severity (minor/moderate/severe)
                    3. Context consideration (could this be educational, news, artistic?)
                    4. Confidence in assessment

                    Return JSON:
                    {
                    "violations_found": true/false,
                    "category": "safe/violence/adult_content/hate_speech/dangerous_activity",
                    "severity": "none/minor/moderate/severe",
                    "confidence": 0.0-1.0,
                    "reasoning": "explanation",
                    "requires_human_review": true/false
                    }
                """
          }
      ]

      for i, (timestamp, frame) in enumerate(concerning_frames, 1):
          content.append({
              "type": "image_url",
              "image_url": {
                  "url": f"data:image/jpeg;base64,{frame_to_base64(frame)}",
                  "detail": "high"
              }
          })

      response = self.client.chat.completions.create(
          model="gpt-4.1-mini",
          messages=[{"role": "user", "content": content}],
          response_format={"type": "json_object"},
          max_tokens=500
      )

      import json
      result = json.loads(response.choices[0].message.content)

      category_map = {
          "safe": ModerationCategory.SAFE,
          "violence": ModerationCategory.VIOLENCE,
          "adult_content": ModerationCategory.ADULT_CONTENT,
          "hate_speech": ModerationCategory.HATE_SPEECH,
          "dangerous_activity": ModerationCategory.DANGEROUS_ACTIVITY
      }

      return ModerationResult(
          decision=category_map.get(result.get("category", "safe"), ModerationCategory.NEEDS_REVIEW),
          confidence=result.get("confidence", 0.5),
          flagged_frames=concerning_indices,
          reasoning=result.get("reasoning", ""),
          requires_human_review=result.get("requires_human_review", True)
      )
```

Video Search and Retrieval
Finding specific content within videos or across video libraries requires understanding what each video contains. Video search combines content analysis with efficient indexing.

```python
from dataclasses import dataclass
import json

@dataclass
class VideoIndexEntry:
  video_id: str
  video_path: str
  duration: float
  summary: str
  topics: list[str]
  entities: list[str]
  scenes: list[dict]
  transcript_available: bool

class VideoSearchService:
  """
  Index and search video content.
  """

  def __init__(self, client, index_store):
      self.client = client
      self.index = index_store

  def index_video(self, video_id: str, video_path: str) -> VideoIndexEntry:
      """
      Analyze and index a video for search.
      """
      video_info = get_video_info(video_path)
      frames = extract_frames_by_count(video_path, 10)

      # Generate comprehensive index
      content = [
          {
              "type": "text",
              "text": """
                Analyze this video to create a searchable index.

                Extract:
                1. A one-paragraph summary
                2. Main topics/themes (list)
                3. Key entities (people, products, places mentioned or shown)
                4. Scene descriptions with approximate timestamps

                Return JSON:
                {
                    "summary": "paragraph summary",
                    "topics": ["topic1", "topic2"],
                    "entities": ["entity1", "entity2"],
                    "scenes": [
                        {"timestamp": 0, "description": "scene description"},
                        ...
                    ]
                }
                """
          }
      ]

      for i, (timestamp, frame) in enumerate(frames, 1):
          content.append({
              "type": "text",
              "text": f"Frame {i} ({timestamp:.1f}s):"
          })
          content.append({
              "type": "image_url",
              "image_url": {"url": f"data:image/jpeg;base64,{frame_to_base64(frame)}"}
          })

      response = self.client.chat.completions.create(
          model="gpt-4.1-mini",
          messages=[{"role": "user", "content": content}],
          response_format={"type": "json_object"},
          max_tokens=1000
      )

      data = json.loads(response.choices[0].message.content)

      entry = VideoIndexEntry(
          video_id=video_id,
          video_path=video_path,
          duration=video_info['duration_seconds'],
          summary=data.get("summary", ""),
          topics=data.get("topics", []),
          entities=data.get("entities", []),
          scenes=data.get("scenes", []),
          transcript_available=False
      )

      self.index.store(entry)
      return entry

  def search(self, query: str, limit: int = 10) -> list[dict]:
      """
      Search indexed videos for matching content.
      """
      # Get all entries (in production, use vector search or full-text search)
      all_entries = self.index.get_all()

      # Use LLM to rank relevance
      entries_text = "\n".join([
          f"ID: {e.video_id}\nSummary: {e.summary}\nTopics: {', '.join(e.topics)}\nEntities: {', '.join(e.entities)}\n---"
          for e in all_entries
      ])

      response = self.client.chat.completions.create(
          model="gpt-4.1-mini",
          messages=[
              {
                  "role": "user",
                  "content": f"""
                    Search query: "{query}"

                    Available videos:
                    {entries_text}

                    Return the IDs of the most relevant videos for this query, ranked by relevance.
                    Return JSON: {{"results": ["id1", "id2", ...]}}
                    """
              }
          ],
          response_format={"type": "json_object"},
          max_tokens=200
      )

      result = json.loads(response.choices[0].message.content)
      relevant_ids = result.get("results", [])[:limit]

      return [
          {"video_id": vid, "entry": self.index.get(vid)}
          for vid in relevant_ids
          if self.index.get(vid)
      ]
```

Video Summarization
Long videos benefit from automated summaries that capture key content without requiring full viewing. Summaries can be textual, visual (highlight reels), or both.

```python
def generate_video_summary(
  video_path: str,
  client,
  summary_type: str = "text",
  length: str = "medium"
) -> dict:
  """
  Generate a summary of a video.

  Args:
      video_path: Path to video
      summary_type: "text", "chapters", or "highlights"
      length: "brief", "medium", or "detailed"
  """
  frames = extract_frames_by_count(video_path, 12)
  video_info = get_video_info(video_path)

  # Try to get transcript
  transcript = None
  try:
      audio_path = extract_audio(video_path)
      with open(audio_path, "rb") as f:
          result = client.audio.transcriptions.create(
              model="whisper-1",
              file=f,
              response_format="verbose_json",
              timestamp_granularities=["segment"]
          )
      transcript = result.text
      import os
      os.unlink(audio_path)
  except Exception:
      pass

  length_instructions = {
      "brief": "2-3 sentences maximum",
      "medium": "One paragraph (4-6 sentences)",
      "detailed": "Multiple paragraphs covering all major points"
  }

  if summary_type == "text":
      prompt = f"""
        Summarize this video in {length_instructions[length]}.

        Video duration: {video_info['duration_seconds']:.0f} seconds
      """

      if transcript:
          prompt += f"\nTranscript: {transcript[:2000]}..."

      prompt += "\n\nProvide a clear, informative summary."

  elif summary_type == "chapters":
      prompt = f"""
        Create chapter markers for this video.
        Video duration: {video_info['duration_seconds']:.0f} seconds

        Based on the frames, identify major sections/topics and create chapter markers.

        Return JSON:
        {{
            "chapters": [
                {{"timestamp": seconds, "title": "Chapter title", "description": "brief description"}}
            ]
        }}
      """

  elif summary_type == "highlights":
      prompt = f"""
        Identify the most important moments in this video for a highlight summary.

        Video duration: {video_info['duration_seconds']:.0f} seconds

        Select 3-5 key moments that capture the essential content.

        Return JSON:
        {{
            "highlights": [
                {{"timestamp": seconds, "description": "what happens", "importance": "why it matters"}}
            ]
        }}
      """

  content = [{"type": "text", "text": prompt}]

  for i, (timestamp, frame) in enumerate(frames, 1):
      content.append({
          "type": "text",
          "text": f"Frame {i} ({timestamp:.1f}s):"
      })
      content.append({
          "type": "image_url",
          "image_url": {"url": f"data:image/jpeg;base64,{frame_to_base64(frame)}"}
      })

  response_format = (
      {"type": "json_object"}
      if summary_type in ["chapters", "highlights"]
      else None
  )

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[{"role": "user", "content": content}],
      response_format=response_format,
      max_tokens=1000
  )

  result_text = response.choices[0].message.content

  if summary_type == "text":
      return {"summary": result_text}
  else:
      return json.loads(result_text)
```

Production Considerations
Video analysis at scale requires attention to performance, cost, and reliability.

```python
import asyncio
from typing import Optional
import tempfile
import os

class ProductionVideoService:
  """
  Production-ready video analysis service.
  """

  def __init__(
      self,
      client,
      max_concurrent: int = 3,
      max_video_duration: float = 3600,  # 1 hour
      max_frames_per_video: int = 20
  ):
      self.client = client
      self.semaphore = asyncio.Semaphore(max_concurrent)
      self.max_duration = max_video_duration
      self.max_frames = max_frames_per_video

  async def analyze_video(
      self,
      video_path: str,
      analysis_type: str = "summary"
  ) -> dict:
      """
      Analyze video with production safeguards.
      """
      # Validate video
      video_info = get_video_info(video_path)

      if video_info['duration_seconds'] > self.max_duration:
          return {
              "success": False,
              "error": f"Video exceeds maximum duration of {self.max_duration}s"
          }

      # Calculate appropriate frame count
      duration = video_info['duration_seconds']
      frame_count = min(
          self.max_frames,
          max(5, int(duration / 10))  # ~1 frame per 10 seconds, min 5
      )

      async with self.semaphore:
          try:
              frames = extract_frames_by_count(video_path, frame_count)

              result = await self._analyze_frames(
                  frames,
                  analysis_type,
                  video_info
              )

              return {
                  "success": True,
                  "result": result,
                  "metadata": {
                      "frames_analyzed": frame_count,
                      "video_duration": duration
                  }
              }

          except Exception as e:
              return {
                  "success": False,
                  "error": str(e)
              }

  async def _analyze_frames(
      self,
      frames: list,
      analysis_type: str,
      video_info: dict
  ) -> dict:
      """Internal frame analysis."""
      # Implementation varies by analysis_type
      pass

  def estimate_cost(self, video_duration: float) -> dict:
      """
      Estimate API cost for analyzing a video.
      """
      frame_count = min(
          self.max_frames,
          max(5, int(video_duration / 10))
      )

      # Rough estimates (check current pricing)
      tokens_per_frame = 1000  # Low detail image
      tokens_for_prompt = 500
      tokens_for_response = 1000

      total_input_tokens = (frame_count * tokens_per_frame) + tokens_for_prompt
      total_output_tokens = tokens_for_response

      # gpt-4.1-mini pricing: $0.40/1M input, $1.60/1M output
      input_cost = total_input_tokens * 0.0000004  # $0.40 per 1M tokens
      output_cost = total_output_tokens * 0.0000016  # $1.60 per 1M tokens

      return {
          "estimated_frames": frame_count,
          "estimated_input_tokens": total_input_tokens,
          "estimated_output_tokens": total_output_tokens,
          "estimated_cost_usd": input_cost + output_cost
      }
```

Common Pitfalls
Processing Videos Synchronously: Video analysis is slow. Always use async patterns to avoid blocking.

No Duration Limits: Long videos create high costs. Set maximum durations and frame counts.

Missing Error Handling: Videos may be corrupt, unsupported formats, or too large. Handle failures gracefully.

Ignoring Privacy: Videos may contain faces, license plates, or other sensitive information. Consider privacy in your pipeline.

Over-Analysis: Not every video needs 20 frames analyzed. Adjust frame count to task requirements.

Summary
Video understanding enables practical applications including content moderation, search, and summarization. Content moderation uses multi-pass analysis for efficient policy enforcement. Video search requires indexing content with summaries, topics, and entities for retrieval.

Summarization produces textual summaries, chapter markers, or highlight identification depending on use case. Production systems need concurrency control, duration limits, cost estimation, and robust error handling. Privacy considerations are especially important for video content that may contain identifiable information.

Key concepts to remember
Content moderation benefits from two-pass analysis: quick scan then detailed review
Video search requires comprehensive indexing of summaries, topics, and entities
Summarization can produce text, chapters, or highlight selections
Production systems need duration limits, concurrency control, and cost management
Privacy considerations are critical for video content with identifiable information
This completes the Video Understanding submodule. You have learned how to analyze video content, understand temporal relationships, and apply these techniques to practical applications. The next submodule covers Multi-Modal Applications, where you will learn to combine vision, audio, and language capabilities for comprehensive AI solutions.