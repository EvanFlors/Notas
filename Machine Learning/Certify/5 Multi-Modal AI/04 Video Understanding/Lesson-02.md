SkillUp
Home
Learn
Certify

EF
Lesson: Processing Video Content
AI Tutor
Hi ESTEBAN!

Welcome to the "Processing Video Content" concept. Take a look at the lesson on the right, and feel free to ask me any questions as you explore.

Ask me any question

Processing Video Content
You understand video understanding concepts, but you need to implement video processing in your application. How do you extract frames efficiently? How do you process frames with vision APIs? How do you combine frame analyses into video understanding?

Processing video content requires efficient frame extraction, vision API integration, and temporal analysis. By the end of this lesson, you will understand practical techniques for processing videos, integrating with vision APIs, and building production video understanding applications.

Frame Extraction Implementation
Extract frames efficiently for processing:

python
import cv2
import numpy as np
from pathlib import Path

class VideoProcessor:
  """Process video files for AI analysis."""

  def extract_frames(self, video_path, output_dir, interval=1.0):
      """Extract frames at regular intervals."""
      cap = cv2.VideoCapture(video_path)
      fps = cap.get(cv2.CAP_PROP_FPS)
      frame_interval = int(fps * interval)

      Path(output_dir).mkdir(parents=True, exist_ok=True)

      frames = []
      frame_count = 0

      while True:
          ret, frame = cap.read()
          if not ret:
              break

          if frame_count % frame_interval == 0:
              timestamp = frame_count / fps
              frame_path = Path(output_dir) / f"frame_{timestamp:.2f}.jpg"
              cv2.imwrite(str(frame_path), frame)
              frames.append({
                  'path': frame_path,
                  'timestamp': timestamp,
                  'frame_number': frame_count
              })

          frame_count += 1

      cap.release()
      return frames
Key Frame Detection:

Extract frames at important moments:

python
def extract_key_frames(self, video_path, output_dir, threshold=0.3):
      """Extract frames at scene changes."""
      cap = cv2.VideoCapture(video_path)
      fps = cap.get(cv2.CAP_PROP_FPS)

      Path(output_dir).mkdir(parents=True, exist_ok=True)

      frames = []
      prev_frame = None
      frame_count = 0

      while True:
          ret, frame = cap.read()
          if not ret:
              break

          timestamp = frame_count / fps

          if prev_frame is not None:
              # Calculate difference
              gray_prev = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)
              gray_curr = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
              diff = cv2.absdiff(gray_prev, gray_curr)
              diff_score = diff.mean() / 255.0

              if diff_score > threshold:
                  frame_path = Path(output_dir) / f"keyframe_{timestamp:.2f}.jpg"
                  cv2.imwrite(str(frame_path), frame)
                  frames.append({
                      'path': frame_path,
                      'timestamp': timestamp,
                      'frame_number': frame_count,
                      'change_score': diff_score
                  })

          prev_frame = frame
          frame_count += 1

      cap.release()
      return frames
Processing Frames with Vision API
Process extracted frames using vision APIs:

python
from openai import OpenAI
import base64

class VideoAnalyzer:
  """Analyze video frames using vision API."""

  def __init__(self):
      self.client = OpenAI(
          api_key="API_KEY",
          base_url="BASE_URL",
      )

  def analyze_frame(self, frame_path, prompt):
      """Analyze single frame."""
      # Encode frame
      with open(frame_path, "rb") as f:
          base64_image = base64.b64encode(f.read()).decode('utf-8')

      # Analyze with vision API
      response = self.client.chat.completions.create(
          model="gpt-4.1-mini",
          messages=[
              {
                  "role": "user",
                  "content": [
                      {"type": "text", "text": prompt},
                      {
                          "type": "image_url",
                          "image_url": {
                              "url": f"data:image/jpeg;base64,{base64_image}"
                          }
                      }
                  ]
              }
          ],
          max_tokens=300
      )

      return response.choices[0].message.content

  def analyze_frames_batch(self, frames, prompt):
      """Analyze multiple frames."""
      analyses = []
      for frame in frames:
          analysis = self.analyze_frame(frame['path'], prompt)
          analyses.append({
              'frame': frame,
              'analysis': analysis
          })
      return analyses
Temporal Analysis
Combine frame analyses to understand temporal relationships:

Timeline view showing frame analyses grouped over time into scenes and detected events

![Temporal analysis turns per-frame insights into a timeline of scenes and events](https://hrcdn.net/ai-engineering/module-5/light/video-lesson02-temporal-analysis-timeline.svg)

python
class TemporalAnalyzer:
  """Analyze temporal relationships in video."""

  def analyze_temporal(self, frame_analyses):
      """Analyze how content changes over time."""
      # Group analyses by timestamp
      sorted_analyses = sorted(
          frame_analyses,
          key=lambda x: x['frame']['timestamp']
      )

      # Identify patterns
      patterns = self.identify_patterns(sorted_analyses)

      # Detect scene changes
      scene_changes = self.detect_scene_changes(sorted_analyses)

      # Recognize actions
      actions = self.recognize_actions(sorted_analyses)

      return {
          'patterns': patterns,
          'scene_changes': scene_changes,
          'actions': actions,
          'timeline': sorted_analyses
      }

  def identify_patterns(self, analyses):
      """Identify repeating patterns."""
      # Simplified - actual implementation would use more sophisticated analysis
      patterns = []
      # Analyze for repeating visual elements or actions
      return patterns

  def detect_scene_changes(self, analyses):
      """Detect scene boundaries."""
      scene_changes = []
      prev_analysis = None

      for analysis in analyses:
          if prev_analysis:
              # Compare analyses to detect changes
              similarity = self.compare_analyses(prev_analysis, analysis)
              if similarity < 0.5:  # Threshold for scene change
                  scene_changes.append(analysis['frame']['timestamp'])
          prev_analysis = analysis

      return scene_changes

  def recognize_actions(self, analyses):
      """Recognize actions across frames."""
      # Simplified - actual implementation would use action recognition models
      actions = []
      # Analyze sequences of frames for actions
      return actions
SkillUp | Hackerrank

SkillUp
Home
Learn
Certify

EF
Lesson: Processing Video Content
AI Tutor
Hi ESTEBAN!

Welcome to the "Processing Video Content" concept. Take a look at the lesson on the right, and feel free to ask me any questions as you explore.

Ask me any question

Video Summarization
Generate summaries of video content:

python
class VideoSummarizer:
  """Generate summaries of video content."""

  def summarize_video(self, video_path, num_key_frames=10):
      """Generate video summary."""
      # Extract key frames
      processor = VideoProcessor()
      frames = processor.extract_key_frames(video_path, "temp_frames")

      # Analyze frames
      analyzer = VideoAnalyzer()
      frame_analyses = analyzer.analyze_frames_batch(
          frames[:num_key_frames],
          "Describe what is happening in this frame."
      )

      # Generate summary using language model
      summary = self.generate_summary(frame_analyses)

      return summary

  def generate_summary(self, frame_analyses):
      """Generate text summary from frame analyses."""
      from openai import OpenAI
      client = OpenAI(
          api_key="API_KEY",
          base_url="BASE_URL",
      )

      # Combine frame analyses
      analyses_text = "\n".join([
          f"At {a['frame']['timestamp']:.2f}s: {a['analysis']}"
          for a in frame_analyses
      ])

      # Generate summary
      response = client.chat.completions.create(
          model="gpt-4.1-mini",
          messages=[
              {
                  "role": "system",
                  "content": "You are a video summarizer. Generate concise summaries of video content."
              },
              {
                  "role": "user",
                  "content": f"Summarize this video based on frame analyses:\n\n{analyses_text}"
              }
          ],
          max_tokens=500
      )

      return response.choices[0].message.content
SkillUp | Hackerrank

SkillUp
Home
Learn
Certify

EF
Lesson: Processing Video Content
AI Tutor
Hi ESTEBAN!

Welcome to the "Processing Video Content" concept. Take a look at the lesson on the right, and feel free to ask me any questions as you explore.

Ask me any question

Production Implementation
Build production video processing applications:

python
class ProductionVideoProcessor:
  """Production video processing system."""

  def __init__(self):
      self.processor = VideoProcessor()
      self.analyzer = VideoAnalyzer()
      self.temporal_analyzer = TemporalAnalyzer()
      self.cache = {}

  def process_video(self, video_path, analysis_type="summary"):
      """Process video with caching and error handling."""
      # Check cache
      video_hash = self.get_video_hash(video_path)
      if video_hash in self.cache:
          return self.cache[video_hash]

      try:
          # Extract frames
          frames = self.processor.extract_frames(video_path, "temp_frames")

          # Analyze frames
          frame_analyses = self.analyzer.analyze_frames_batch(
              frames,
              "Describe what is happening in this frame."
          )

          # Temporal analysis
          temporal = self.temporal_analyzer.analyze_temporal(frame_analyses)

          # Generate result based on analysis type
          if analysis_type == "summary":
              result = self.generate_summary(frame_analyses)
          elif analysis_type == "timeline":
              result = temporal['timeline']
          else:
              result = temporal

          # Cache result
          self.cache[video_hash] = result

          return result

      except Exception as e:
          logger.error(f"Video processing failed: {e}")
          raise

  def get_video_hash(self, video_path):
      """Generate hash for caching."""
      import hashlib
      with open(video_path, "rb") as f:
          return hashlib.sha256(f.read()).hexdigest()
Summary
Processing video content requires efficient frame extraction, vision API integration, and temporal analysis. Understanding these techniques enables you to build production video understanding applications.

Key techniques include uniform and key frame extraction, batch frame analysis, temporal pattern recognition, and video summarization.

Key concepts to remember
Extract frames efficiently - Use uniform sampling or key frame detection
Process frames with vision APIs - Analyze frames using vision-language models
Analyze temporal relationships - Understand how content changes over time
Generate summaries - Combine frame analyses into video summaries
Implement caching - Cache results to avoid redundant processing
Further learning resources
Book icon
OpenAI Vision API Reference - Complete API documentation for vision-enabled chat completions used in frame analysis.

OpenAI Audio Transcription API - For extracting and transcribing audio tracks from videos.

In the next submodule, you will learn about building comprehensive multi-modal applications that combine vision, audio, text, and video capabilities.

Rate this lesson





SkillUp | Hackerrank