SkillUp
Home
Learn
Certify

EF
Lesson: Temporal Understanding
AI Tutor
Hi ESTEBAN!

Welcome to the "Temporal Understanding" concept. Take a look at the lesson on the right, and feel free to ask me any questions as you explore.

Ask me any question

Understanding Events Over Time
Video captures events as they unfold. True video understanding requires reasoning about temporal relationships: what happened before, what comes after, and how events relate causally. This temporal understanding enables applications from security monitoring to sports analysis.

Temporal Concepts in Video:

Sequence: Events occur in order. A person enters, picks up an object, and exits. The order matters for understanding the narrative.

Duration: Events have length. A quick gesture differs from a sustained action. Understanding duration helps distinguish meaningful actions from transitions.

Causation: Some events cause others. A ball hitting pins causes them to fall. Recognizing causal relationships enables prediction and anomaly detection.

Simultaneity: Multiple events can occur at once. One person talks while another gestures. Understanding concurrent events is essential for complex scenes.

Analyzing these temporal aspects requires strategies that go beyond single-frame analysis to reason about relationships across time.

Four types of temporal relationships: sequence showing ordered events, duration showing event length, causation showing cause-effect links, and simultaneity showing concurrent events

![Temporal relationships in video: sequence, duration, causation, and simultaneity](https://hrcdn.net/ai-engineering/module-5/light/video-lesson03-temporal-relationships.svg)

temporal_concepts.py
python
from dataclasses import dataclass
from typing import Optional

@dataclass
class VideoEvent:
  """Represents an event detected in video."""
  event_type: str
  description: str
  start_time: float
  end_time: float
  confidence: float
  subjects: list[str]
  location_in_frame: Optional[str] = None

@dataclass
class TemporalRelation:
  """Relationship between two events."""
  event_a: VideoEvent
  event_b: VideoEvent
  relation_type: str  # before, after, during, causes, caused_by
  description: str

def analyze_temporal_sequence(
  video_path: str,
  client,
  focus_query: str = None
) -> dict:
  """
  Analyze temporal relationships in a video.

  Args:
      video_path: Path to video
      client: OpenAI client
      focus_query: Optional query to focus analysis (e.g., "person entering")
  """
  frames = extract_frames_by_count(video_path, 12)  # More frames for temporal

  prompt = """Analyze the temporal sequence in these video frames.

For each significant event you observe:
1. What is the event?
2. When does it start and end (by frame number)?
3. What causes it or what does it cause?
4. Who or what is involved?

Then describe the overall temporal structure:
- What happens first, then, finally?
- Are there any cause-effect relationships?
- Do any events happen simultaneously?

"""
  if focus_query:
      prompt += f"\nFocus especially on: {focus_query}"

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

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[{"role": "user", "content": content}],
      max_tokens=1500
  )

  return {
      "temporal_analysis": response.choices[0].message.content,
      "frame_count": len(frames),
      "duration": frames[-1][0] if frames else 0
  }
Entity Tracking Across Frames
Understanding video often requires tracking specific entities (people, objects, vehicles) as they move through scenes. While full object tracking requires specialized models, vision-language models can track entities conceptually across sampled frames.

entity_tracking.py
python
def track_entity_through_video(
  video_path: str,
  entity_description: str,
  client,
  num_frames: int = 10
) -> dict:
  """
  Track a specific entity through video frames.

  Args:
      video_path: Path to video
      entity_description: Description of entity to track (e.g., "person in red shirt")
      client: OpenAI client

  Returns:
      Tracking information including presence and location per frame
  """
  frames = extract_frames_by_count(video_path, num_frames)

  prompt = f"""Track this entity through the video frames: "{entity_description}"

For each frame, report:
1. Is the entity visible? (yes/no/partial)
2. Where in the frame? (left/center/right, near/middle/far)
3. What is the entity doing?
4. Any notable changes from previous frame?

Then summarize the entity's journey through the video:
- When does it appear and disappear?
- How does it move through the scene?
- What actions does it take?

Return as JSON:
{{
  "entity": "{entity_description}",
  "frame_observations": [
      {{"frame": 1, "visible": "yes/no/partial", "location": "description", "action": "description", "changes": "description"}}
  ],
  "journey_summary": "overall description of entity's movement and actions"
}}"""

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

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[{"role": "user", "content": content}],
      response_format={"type": "json_object"},
      max_tokens=1500
  )

  import json
  return json.loads(response.choices[0].message.content)

def find_entity_interactions(
  video_path: str,
  entity_a: str,
  entity_b: str,
  client
) -> dict:
  """
  Find interactions between two entities in a video.

  Useful for understanding relationships and events involving multiple subjects.
  """
  frames = extract_frames_by_count(video_path, 12)

  prompt = f"""Analyze interactions between these two entities in the video:

Entity A: "{entity_a}"
Entity B: "{entity_b}"

For each frame, note:
1. Are both entities visible?
2. What is their spatial relationship (near, far, touching, etc.)?
3. Are they interacting? How?

Then summarize:
- When do they interact?
- What types of interactions occur?
- How does their relationship change through the video?"""

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

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[{"role": "user", "content": content}],
      max_tokens=1000
  )

  return {
      "entity_a": entity_a,
      "entity_b": entity_b,
      "interactions": response.choices[0].message.content
  }
Apply temporal analysis concepts to distinguish between different behavior patterns in a security monitoring scenario.

A security system needs to detect 'person entering then immediately leaving' (suspicious behavior) vs 'person entering and staying' (normal behavior). What analysis approach is required?

Analyze each frame independently to detect person presence

Count the total number of frames containing a person

Temporal sequence analysis comparing person positions across ordered frames

Use motion detection to identify any movement in the scene
SkillUp | Hackerrank

SkillUp
Home
Learn
Certify

EF
Lesson: Temporal Understanding
AI Tutor
Hi ESTEBAN!

Welcome to the "Temporal Understanding" concept. Take a look at the lesson on the right, and feel free to ask me any questions as you explore.

Ask me any question

Temporal Queries
Applications often need to answer specific questions about when things happen in videos. Temporal queries enable finding specific moments, understanding sequences, and extracting time-bound information.

temporal_queries.py
python
def answer_temporal_query(
  video_path: str,
  query: str,
  client,
  num_frames: int = 12
) -> dict:
  """
  Answer a temporal question about a video.

  Examples:
      "When does the speaker start talking about pricing?"
      "How long does the demonstration take?"
      "What happens after the car enters the frame?"
  """
  frames = extract_frames_by_count(video_path, num_frames)
  video_info = get_video_info(video_path)

  prompt = f"""Video duration: {video_info['duration_seconds']:.1f} seconds

Answer this question about the video: {query}

Based on the frames shown, provide:
1. Direct answer to the question
2. Timestamp estimate (if applicable)
3. Confidence level (high/medium/low)
4. Supporting observations from the frames

If the question cannot be answered from the frames, explain what information is missing."""

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

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[{"role": "user", "content": content}],
      max_tokens=500
  )

  return {
      "query": query,
      "answer": response.choices[0].message.content,
      "video_duration": video_info['duration_seconds'],
      "frames_analyzed": num_frames
  }

def find_moment(
  video_path: str,
  moment_description: str,
  client,
  precision: str = "coarse"
) -> dict:
  """
  Find a specific moment in a video.

  Args:
      video_path: Path to video
      moment_description: What moment to find (e.g., "when product is shown")
      precision: "coarse" (fewer frames, faster) or "fine" (more frames, slower)
  """
  num_frames = 8 if precision == "coarse" else 20
  frames = extract_frames_by_count(video_path, num_frames)

  prompt = f"""Find this moment in the video: "{moment_description}"

Analyze the frames and identify:
1. In which frame(s) does this moment occur?
2. Estimated timestamp (in seconds)
3. Confidence that this is the correct moment (high/medium/low)
4. Description of what you see at that moment

If the moment is not found, indicate that and describe what the video does show."""

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

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[{"role": "user", "content": content}],
      max_tokens=500
  )

  return {
      "searching_for": moment_description,
      "result": response.choices[0].message.content,
      "precision": precision,
      "frames_searched": num_frames
  }
Event Detection and Classification
Detecting specific types of events enables automation and alerting. From security incidents to quality control, event detection monitors video for predetermined conditions.

event_detection.py
python
from enum import Enum

class EventType(Enum):
  PERSON_ENTERS = "person_enters"
  PERSON_EXITS = "person_exits"
  OBJECT_MOVED = "object_moved"
  ACTIVITY_STARTED = "activity_started"
  ACTIVITY_ENDED = "activity_ended"
  ANOMALY = "anomaly"

def detect_events(
  video_path: str,
  event_types: list[EventType],
  client,
  num_frames: int = 10
) -> list[dict]:
  """
  Detect specific event types in a video.

  Returns list of detected events with timestamps and descriptions.
  """
  frames = extract_frames_by_count(video_path, num_frames)
  video_info = get_video_info(video_path)

  event_descriptions = {
      EventType.PERSON_ENTERS: "A person entering the scene",
      EventType.PERSON_EXITS: "A person leaving the scene",
      EventType.OBJECT_MOVED: "An object being moved or changed position",
      EventType.ACTIVITY_STARTED: "A new activity beginning",
      EventType.ACTIVITY_ENDED: "An activity concluding",
      EventType.ANOMALY: "Something unusual or unexpected"
  }

  watching_for = [event_descriptions[et] for et in event_types]

  prompt = f"""Analyze this video for these specific events:
{chr(10).join(f'- {e}' for e in watching_for)}

For each event detected, report:
- Event type
- Approximate timestamp (based on frame number and total duration {video_info['duration_seconds']:.1f}s)
- Description of what happened
- Confidence (high/medium/low)

Return JSON array:
[
  {{"event_type": "type", "timestamp": seconds, "description": "what happened", "confidence": "level"}}
]

If no events of these types are detected, return an empty array."""

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

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[{"role": "user", "content": content}],
      response_format={"type": "json_object"},
      max_tokens=1000
  )

  import json
  result = json.loads(response.choices[0].message.content)

  # Handle both array and object with events key
  if isinstance(result, list):
      return result
  return result.get("events", [])
SkillUp | Hackerrank

SkillUp
Home
Learn
Certify

EF
Lesson: Temporal Understanding
AI Tutor
Hi ESTEBAN!

Welcome to the "Temporal Understanding" concept. Take a look at the lesson on the right, and feel free to ask me any questions as you explore.

Ask me any question

Cause-Effect Analysis
Understanding causal relationships helps explain why events occur and predict consequences. This analysis is valuable for incident investigation, process optimization, and training content.

causal_analysis.py
python
def analyze_cause_effect(
  video_path: str,
  client,
  focus_event: str = None
) -> dict:
  """
  Analyze cause-effect relationships in a video.

  Args:
      video_path: Path to video
      focus_event: Optional specific event to analyze causes/effects for
  """
  frames = extract_frames_by_count(video_path, 12)

  prompt = """Analyze the cause-effect relationships in this video sequence.

For each significant event:
1. What caused it? (preceding events or conditions)
2. What effects did it have? (subsequent events or changes)
3. How confident are you in this causal relationship?

Identify any chains of causation (A causes B, B causes C).

"""
  if focus_event:
      prompt += f"\nFocus especially on causes and effects of: {focus_event}"

  prompt += """

Return JSON:
{
  "causal_chains": [
      {
          "cause": "description",
          "effect": "description",
          "confidence": "high/medium/low",
          "evidence": "what in the video supports this"
      }
  ],
  "summary": "overall description of causal structure"
}"""

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

  response = client.chat.completions.create(
      model="gpt-4.1-mini",
      messages=[{"role": "user", "content": content}],
      response_format={"type": "json_object"},
      max_tokens=1000
  )

  import json
  return json.loads(response.choices[0].message.content)
Common Pitfalls
Assuming Causation from Sequence: Events happening in sequence are not necessarily causally related. Be cautious about inferring causation.

Missing Events Between Frames: Rapid events may occur entirely between sampled frames. Important causal links may be invisible.

Ignoring Off-Screen Events: Causes or effects may occur outside the frame. Audio can provide hints about off-screen events.

Overconfidence in Temporal Precision: Frame sampling limits timestamp precision. Do not claim more precision than the sampling rate allows.

Summary
Temporal understanding enables reasoning about how events unfold, relate, and cause each other over time. Entity tracking follows specific subjects through videos, revealing their journeys and interactions. Temporal queries answer time-based questions about video content.

Event detection identifies specific occurrences like entries, exits, or anomalies. Cause-effect analysis reveals why events happen and what consequences follow. These capabilities build on frame-based analysis but add the dimension of time, enabling applications that understand video as sequences of related events rather than collections of independent images.

Key concepts to remember
Temporal understanding reasons about sequence, duration, causation, and simultaneity
Entity tracking follows subjects through video, revealing journeys and interactions
Temporal queries answer time-based questions with estimated timestamps
Event detection identifies specific occurrences for monitoring and alerting
Cause-effect analysis reveals relationships between events for investigation and prediction
In the next lesson, you will learn practical applications of video understanding including content moderation, sports analysis, security monitoring, and video search.

Further learning resources
Book icon
Temporal Action Detection - Research on detecting and localizing actions in video.

Video Understanding Survey - Comprehensive overview of video understanding techniques.

Rate this lesson





SkillUp | Hackerrank