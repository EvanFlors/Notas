## Communication Between Agents
Your security agent finds a potential SQL injection. It needs to tell the testing agent to verify with specific test cases. But how? If it just outputs natural language, the testing agent might misunderstand, miss the context, or not even receive the message.

Multi-agent coordination requires structured communication. Agents need protocols for passing information, mechanisms for sharing context, and strategies for handling disagreements. Without these, collaboration breaks down into chaos.

In this lesson, you will learn how to design message protocols, implement shared context systems, and build coordination mechanisms that enable effective multi-agent collaboration.

By the end, you will have patterns for building systems where multiple agents work together smoothly.

Structured Message Protocols
Agents that work together need structured ways to communicate. Raw LLM outputs are ambiguous and hard for other agents to parse reliably. Effective multi-agent systems define clear message formats.

```python
from dataclasses import dataclass, field
from typing import Optional, Dict, Any
from datetime import datetime
from enum import Enum

class MessageType(Enum):
  REQUEST = "request"
  RESPONSE = "response"
  BROADCAST = "broadcast"
  FINDING = "finding"

@dataclass
class AgentMessage:
  message_id: str
  message_type: MessageType
  sender: str
  recipient: Optional[str]  # None for broadcasts
  content: Dict[str, Any]
  timestamp: datetime = field(default_factory=datetime.utcnow)
  priority: int = 0
```

The message bus pattern decouples agents from direct dependencies. Agents publish messages without knowing who will receive them, and subscribe to messages they care about. This makes adding new agents straightforward.

Shared Context Systems
Agents often need access to common information: the PR being reviewed, findings discovered so far, decisions already made. Shared context provides this common ground.

```python
@dataclass
class SharedContext:
  pr_number: int
  repo: str
  files: List[dict]
  findings: List[dict] = field(default_factory=list)
  decisions: Dict[str, Any] = field(default_factory=dict)
  analyzed_files: Dict[str, List[str]] = field(default_factory=dict)

  def add_finding(self, finding: dict):
      self.findings.append(finding)

  def mark_analyzed(self, file_path: str, agent_id: str):
      if file_path not in self.analyzed_files:
          self.analyzed_files[file_path] = []
      self.analyzed_files[file_path].append(agent_id)

  def get_unanalyzed_files(self, agent_id: str) -> List[str]:
      """Get files this agent has not yet analyzed"""
      return [
          f["path"] for f in self.files
          if agent_id not in self.analyzed_files.get(f["path"], [])
      ]
```

Shared context must handle concurrent access safely. When multiple agents read and write simultaneously, you need synchronization to prevent race conditions.

```python
class ContextManager:
  def __init__(self):
      self.contexts: Dict[str, SharedContext] = {}
      self.locks: Dict[str, asyncio.Lock] = {}

  async def update_context(self, review_id: str, updater: callable):
      """Safely update shared context with locking"""
      if review_id not in self.locks:
          self.locks[review_id] = asyncio.Lock()

      async with self.locks[review_id]:
          context = self.contexts[review_id]
          updater(context)
          return context
```

Understanding how to manage shared context safely prevents race conditions and data inconsistencies.

Task Distribution Strategies
Distributing work across agents efficiently requires strategies based on workload characteristics.

Capability-based routing sends tasks to agents with relevant expertise. A task involving Python security analysis goes to an agent that specializes in Python and security.

```python
@dataclass
class AgentCapabilities:
  agent_id: str
  can_analyze: List[str]      # File types: ["python", "javascript"]
  specializations: List[str]  # ["security", "performance"]
  max_concurrent: int = 3
  current_load: int = 0

class CapabilityRouter:
  def __init__(self):
      self.agents: Dict[str, AgentCapabilities] = {}

  def route_task(self, task: dict) -> Optional[str]:
      """Find best agent for a task based on capabilities"""
      file_types = task.get("file_types", [])
      specialization = task.get("specialization")

      candidates = []
      for agent_id, caps in self.agents.items():
          # Check capacity
          if caps.current_load >= caps.max_concurrent:
              continue

          # Check file type support
          if file_types and not any(ft in caps.can_analyze for ft in file_types):
              continue

          # Score by specialization match
          score = 10 if specialization in caps.specializations else 0
          score -= caps.current_load  # Prefer less loaded agents

          candidates.append((score, agent_id))

      if candidates:
          candidates.sort(reverse=True)
          return candidates[0][1]
      return None
```

Priority-based scheduling ensures important work happens first. Security tasks take precedence over style checks. Large changes get reviewed before small ones.

```python
class PriorityScheduler:
  def calculate_priority(self, task: dict) -> int:
      """Calculate priority (lower = higher priority)"""
      priority = 5  # Default medium

      if task.get("type") == "security":
          priority = 0  # Highest
      elif task.get("lines_changed", 0) > 500:
          priority = 2
      elif task.get("is_documentation_only"):
          priority = 8  # Lowest

      return priority
```

Work stealing lets idle agents take work from busy ones. When an agent finishes its queue, it checks if other agents have pending work and takes some, balancing load dynamically.

Synchronization and Consensus
When multiple agents contribute to a decision, synchronization ensures consistency.

Barrier synchronization waits for all agents to complete a phase before proceeding. After parallel analysis, a barrier ensures all results are in before synthesis begins.

```python
class ReviewBarrier:
  def __init__(self, agent_count: int):
      self.agent_count = agent_count
      self.waiting = 0
      self.condition = asyncio.Condition()

  async def wait(self, agent_id: str):
      """Wait for all agents to reach this point"""
      async with self.condition:
          self.waiting += 1

          if self.waiting == self.agent_count:
              self.waiting = 0
              self.condition.notify_all()
          else:
              await self.condition.wait()
```
Voting and consensus resolves disagreements through agreement. Agents vote on contentious issues, and a threshold determines the outcome. When consensus is not reached, an arbiter makes the final call.

```python
class ConsensusManager:
  def __init__(self, agents: List[str], threshold: float = 0.6):
      self.agents = agents
      self.threshold = threshold

  async def reach_consensus(self, topic: str, context: dict) -> dict:
      """Have agents vote and reach consensus"""
      votes = await asyncio.gather(*[
          self.get_agent_vote(agent, topic, context)
          for agent in self.agents
      ])

      # Tally votes
      vote_counts: Dict[str, int] = {}
      for vote in votes:
          position = vote["position"]
          vote_counts[position] = vote_counts.get(position, 0) + 1

      # Check for consensus
      for position, count in vote_counts.items():
          if count / len(votes) >= self.threshold:
              return {"consensus_reached": True, "position": position}

      return {"consensus_reached": False, "needs_arbitration": True}
```

Understanding how to manage shared context safely prevents race conditions and data inconsistencies.

Task Distribution Strategies
Distributing work across agents efficiently requires strategies based on workload characteristics.

Capability-based routing sends tasks to agents with relevant expertise. A task involving Python security analysis goes to an agent that specializes in Python and security.

```python
@dataclass
class AgentCapabilities:
  agent_id: str
  can_analyze: List[str]      # File types: ["python", "javascript"]
  specializations: List[str]  # ["security", "performance"]
  max_concurrent: int = 3
  current_load: int = 0

class CapabilityRouter:
  def __init__(self):
      self.agents: Dict[str, AgentCapabilities] = {}

  def route_task(self, task: dict) -> Optional[str]:
      """Find best agent for a task based on capabilities"""
      file_types = task.get("file_types", [])
      specialization = task.get("specialization")

      candidates = []
      for agent_id, caps in self.agents.items():
          # Check capacity
          if caps.current_load >= caps.max_concurrent:
              continue

          # Check file type support
          if file_types and not any(ft in caps.can_analyze for ft in file_types):
              continue

          # Score by specialization match
          score = 10 if specialization in caps.specializations else 0
          score -= caps.current_load  # Prefer less loaded agents

          candidates.append((score, agent_id))

      if candidates:
          candidates.sort(reverse=True)
          return candidates[0][1]
      return None
````

Priority-based scheduling ensures important work happens first. Security tasks take precedence over style checks. Large changes get reviewed before small ones.

```python
class PriorityScheduler:
  def calculate_priority(self, task: dict) -> int:
      """Calculate priority (lower = higher priority)"""
      priority = 5  # Default medium

      if task.get("type") == "security":
          priority = 0  # Highest
      elif task.get("lines_changed", 0) > 500:
          priority = 2
      elif task.get("is_documentation_only"):
          priority = 8  # Lowest

      return priority
```

Work stealing lets idle agents take work from busy ones. When an agent finishes its queue, it checks if other agents have pending work and takes some, balancing load dynamically.

Synchronization and Consensus
When multiple agents contribute to a decision, synchronization ensures consistency.

Barrier synchronization waits for all agents to complete a phase before proceeding. After parallel analysis, a barrier ensures all results are in before synthesis begins.

```python
class ReviewBarrier:
  def __init__(self, agent_count: int):
      self.agent_count = agent_count
      self.waiting = 0
      self.condition = asyncio.Condition()

  async def wait(self, agent_id: str):
      """Wait for all agents to reach this point"""
      async with self.condition:
          self.waiting += 1

          if self.waiting == self.agent_count:
              self.waiting = 0
              self.condition.notify_all()
          else:
              await self.condition.wait()
```

Voting and consensus resolves disagreements through agreement. Agents vote on contentious issues, and a threshold determines the outcome. When consensus is not reached, an arbiter makes the final call.

```python
class ConsensusManager:
  def __init__(self, agents: List[str], threshold: float = 0.6):
      self.agents = agents
      self.threshold = threshold

  async def reach_consensus(self, topic: str, context: dict) -> dict:
      """Have agents vote and reach consensus"""
      votes = await asyncio.gather(*[
          self.get_agent_vote(agent, topic, context)
          for agent in self.agents
      ])

      # Tally votes
      vote_counts: Dict[str, int] = {}
      for vote in votes:
          position = vote["position"]
          vote_counts[position] = vote_counts.get(position, 0) + 1

      # Check for consensus
      for position, count in vote_counts.items():
          if count / len(votes) >= self.threshold:
              return {"consensus_reached": True, "position": position}

      return {"consensus_reached": False, "needs_arbitration": True}
```

Now that you understand task distribution strategies, apply synchronization knowledge to coordinate multi-agent phases.

Defining Agent Roles
Effective multi-agent systems define clear roles and responsibilities. Without boundaries, agents duplicate work or leave gaps.

```python
@dataclass
class AgentRole:
  name: str
  responsibilities: List[str]
  defers_to: List[str]  # Other agents to defer to on edge cases

  def get_system_prompt(self):
      return f"""You are a {self.name}. Your responsibilities:
{chr(10).join(f'- {r}' for r in self.responsibilities)}

Defer to appropriate specialists for: {', '.join(self.defers_to)}

Stay in your lane. Only report issues in your domain."""

# Example roles
security_role = AgentRole(
  name="Security Reviewer",
  responsibilities=[
      "Identify injection vulnerabilities",
      "Check authentication and authorization",
      "Find insecure data handling"
  ],
  defers_to=["Performance Reviewer", "Testing Reviewer"]
)

performance_role = AgentRole(
  name="Performance Reviewer",
  responsibilities=[
      "Identify algorithmic inefficiencies",
      "Find N+1 query patterns",
      "Suggest caching opportunities"
  ],
  defers_to=["Security Reviewer"]
)
````

Team composition selects which specialists participate based on PR characteristics. Security-focused changes get the security specialist. Performance-critical paths get the performance specialist. Small documentation changes may only need one generalist.

Common Pitfalls and Solutions
Message format mismatches: When agents expect different message structures, communication fails silently. Define schemas and validate messages before processing.

Deadlocks in synchronization: Circular waits between agents freeze the system. Use timeouts and design coordination to avoid circular dependencies.

Context staleness: Agents reading outdated shared context make decisions on wrong information. Use versioning or timestamps to detect stale reads.

Overcommunication: Too many messages overwhelm agents and slow the system. Be selective about what gets broadcast versus sent directly.

Summary
Agent coordination requires structured communication, efficient task distribution, and synchronization mechanisms. Message protocols define how agents exchange information. Shared context provides common ground for collaboration.

Task distribution strategies—capability routing and priority scheduling—ensure efficient resource utilization. Synchronization through barriers and consensus mechanisms maintains consistency when multiple agents contribute to decisions.

Key Takeaways:

Define clear message protocols for inter-agent communication
Use shared context with proper locking for concurrent access
Route tasks based on agent capabilities and current load
Prioritize security and high-impact tasks over routine work
Synchronize phases when agents need to build on each other's work
Use voting and arbitration to resolve disagreements systematically
Define clear roles with specific responsibilities for each agent
Handle failures gracefully with timeouts and fallbacks