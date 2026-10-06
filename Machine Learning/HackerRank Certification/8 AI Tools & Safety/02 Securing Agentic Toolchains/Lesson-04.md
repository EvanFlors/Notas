## When One Mistake Can Delete Everything

Imagine you ask an AI assistant to clean up temporary files in your project. It generates a script that deletes files older than 30 days. The script looks correct, but it runs in the wrong directory—your home folder instead of the project folder. Without sandboxing, that mistake deletes your personal files, SSH keys, and configuration. With sandboxing, the mistake is contained to a disposable environment that gets destroyed when the task completes.

This is why sandboxing is essential for tool-using agents. When an AI tool can run commands or execute code, you have created a new execution environment. If that environment is not sandboxed, a single misstep can access sensitive files, modify production data, or reach external networks.

In this lesson, you will learn how to build sandboxed execution environments for AI tools, how to control filesystem and network access, and how to limit resource usage. You will understand why sandboxing is a reliability practice as much as a security practice, and how to balance safety with usability.

By the end, you will have a practical containment framework that limits the blast radius of mistakes while still allowing AI tools to be useful.

Why Sandboxing Is Essential for Tool-Using Agents
Sandboxing is not just a security best practice. It is a reliability practice. It limits the blast radius of mistakes, which are inevitable in AI-assisted workflows. Even if your prompts are perfect and your permissions are tight, mistakes happen. Sandboxing ensures that mistakes do not become disasters.

Consider a simple mistake: the assistant runs a cleanup script in the wrong directory. Without a sandbox, that mistake can delete production artifacts or modify repository state in ways that are hard to trace. With a sandbox, the impact is contained to a disposable environment. When the task completes, the sandbox is destroyed, and the mistake disappears with it.

This is especially important for AI tools because they make mistakes differently than humans. Humans might accidentally delete a file. AI tools might generate code that deletes files based on a misunderstanding. Sandboxing protects you when intent and execution diverge.

What a Good Sandbox Protects
A well-designed sandbox should protect:

Filesystem: limit which directories are readable or writable. This prevents accidental access to sensitive files.

Network: restrict outbound access and prevent data exfiltration. This prevents secrets from leaving your environment.

Process execution: control which commands can run and with what arguments. This prevents dangerous commands from executing.

Resource usage: prevent runaway processes from consuming CPU or memory. This protects shared infrastructure.

These controls are the same ones you would apply to a CI runner or a multi-tenant environment. AI tools should be treated with the same discipline. They are executing code in your environment, and that code needs boundaries.

The Difference Between Safe Execution and Safe Intent
Even if your prompt is safe, the tool might still run dangerous commands because of a misunderstanding. The assistant might think "clean up old files" means deleting everything older than a day, not 30 days. It might think "update configuration" means rewriting the entire config file, not just one value.

Sandboxing protects you when intent and execution diverge. It is your last line of defense. When prompts fail, permissions fail, and validation fails, sandboxing still prevents damage. This is why it is essential—it works even when other controls fail.

Practical Sandbox Architectures
Most teams use one of three approaches:

Container sandbox: run tools in an isolated container with limited filesystem mounts and network controls. This provides good isolation with low overhead.

VM sandbox: stronger isolation, higher overhead, used for high-risk tasks. This provides the strongest isolation but is slower and more expensive.

Policy sandbox: no isolation, but strict policy enforcement on tool calls and filesystem access. This provides fast execution but weaker isolation.

For AI-assisted development, a container sandbox is usually the right baseline. It is strong enough to limit damage and light enough to be used frequently. When tasks are low-risk, containers work well. When tasks are high-risk, you can escalate to VMs.

Ephemeral Environments Reduce Persistent Risk
Run tool tasks in short-lived environments. When the task ends, destroy the environment. This limits the persistence of any misconfiguration or malicious state and ensures each run starts clean. It also makes it harder for hidden state to influence future actions.

Consider what happens with persistent environments. A task might leave behind configuration or state that affects future tasks. This creates hidden dependencies that are hard to debug. With ephemeral environments, each task starts fresh, making behavior predictable and debuggable.


Before diving into filesystem and network controls, consider how sandboxing limits blast radius and makes tool execution safer, even when the model makes mistakes.

Filesystem Allowlists and Working Directories
The simplest filesystem control is a working directory allowlist. The tool can read and write only within a specified directory. This prevents accidental edits to sensitive files and prevents leakage of secrets outside the intended scope.

For example:

Allow ```src/``` and ```tests/```: the tool can read and write code files.

Deny ```.env```, deployment keys, and credential stores: the tool cannot access secrets.

Mount read-only documentation separately: the tool can read docs but cannot modify them.

This pattern also improves reviewability. You can see which files the tool could have touched. When a reviewer sees a change, they know it came from an allowed directory, making review faster and more confident.

For large repositories, consider a "path budget" per task. The tool gets access only to the directories that were listed in the acceptance criteria. This keeps the action surface narrow and encourages developers to define scope clearly. When scope is explicit, sandboxing is easier.

You can also separate read and write access. For example, allow read-only access to documentation and configuration, but write access only to src/ and tests/. This prevents accidental edits to sensitive configuration while still allowing code changes. The tool can read what it needs but can only modify what it should.

Here is an example of a sandbox configuration:

sandbox-config.yml
```yaml
# Sandbox Configuration for AI Tool Execution

sandbox:
type: "container"  # container, vm, or policy

filesystem:
  working_directory: "/workspace"

  read_access:
    allow:
      - "/workspace/src/**"
      - "/workspace/tests/**"
      - "/workspace/docs/**"
    deny:
      - "/workspace/.env*"
      - "/workspace/**/secrets/**"
      - "/workspace/**/credentials/**"
      - "/workspace/deployment/**"
      - "/workspace/infrastructure/**"

  write_access:
    allow:
      - "/workspace/src/**"
      - "/workspace/tests/**"
    deny:
      - "*"  # Deny all other writes

  read_only_mounts:
    - source: "/repo/docs"
      target: "/workspace/docs"
      read_only: true

network:
  egress:
    default: "deny"
    allowlist:
      - "internal-api.example.com:443"
      - "ci.example.com:443"
    blocklist:
      - "*"  # Block all other outbound access

  ingress:
    default: "deny"
    allowlist: []  # No inbound access needed

execution:
  max_cpu_time: "5m"
  max_memory: "2GB"
  max_disk: "1GB"

  allowed_commands:
    - "python"
    - "pytest"
    - "git"
    - "npm"
    - "make"

  denied_commands:
    - "rm"
    - "rmdir"
    - "chmod"
    - "chown"
    - "sudo"
    - "docker"
    - "kubectl"

environment:
  ephemeral: true  # Destroy after task completes
  timeout: "30m"   # Maximum execution time
  cleanup: true    # Clean up all files on exit
```

Here is an example of a sandbox implementation:

sandbox-implementation.py
```python
#!/usr/bin/env python3
"""
Sandbox implementation for AI tool execution.
Provides filesystem, network, and execution controls.
"""

import subprocess
import tempfile
import shutil
from pathlib import Path
from typing import List, Optional, Dict
from dataclasses import dataclass

@dataclass
class SandboxConfig:
  """Configuration for sandbox environment."""
  working_dir: Path
  read_allowed: List[str]
  write_allowed: List[str]
  read_denied: List[str]
  network_allowed: List[str]
  max_memory_mb: int = 2048
  max_cpu_time_seconds: int = 300

class Sandbox:
  """Sandboxed execution environment for AI tools."""

  def __init__(self, config: SandboxConfig):
      self.config = config
      self.work_dir = Path(tempfile.mkdtemp(prefix="ai-sandbox-"))
      self._setup_environment()

  def _setup_environment(self):
      """Set up sandboxed environment."""
      # Create working directory structure
      (self.work_dir / "src").mkdir()
      (self.work_dir / "tests").mkdir()
      (self.work_dir / "docs").mkdir()

  def check_file_access(self, file_path: Path, operation: str) -> bool:
      """Check if file access is allowed."""
      path_str = str(file_path)

      # Check read access
      if operation == "read":
          # Check deny list first
          for denied_pattern in self.config.read_denied:
              if denied_pattern in path_str:
                  return False

          # Check allow list
          for allowed_pattern in self.config.read_allowed:
              if allowed_pattern in path_str:
                  return True

          return False

      # Check write access
      elif operation == "write":
          for allowed_pattern in self.config.write_allowed:
              if allowed_pattern in path_str:
                  return True
          return False

      return False

  def execute_command(
      self,
      command: List[str],
      timeout: Optional[int] = None
  ) -> subprocess.CompletedProcess:
      """Execute command in sandboxed environment."""
      # Check if command is allowed
      if command[0] in ["rm", "rmdir", "chmod", "chown", "sudo"]:
          raise PermissionError(f"Command '{command[0]}' is not allowed")

      # Set resource limits
      timeout = timeout or self.config.max_cpu_time_seconds

      # Execute in working directory
      result = subprocess.run(
          command,
          cwd=self.work_dir,
          timeout=timeout,
          capture_output=True,
          text=True
      )

      return result

  def cleanup(self):
      """Clean up sandbox environment."""
      if self.work_dir.exists():
          shutil.rmtree(self.work_dir)

# Example usage
def create_sandbox_for_task(acceptance_criteria: Dict) -> Sandbox:
  """Create sandbox based on task acceptance criteria."""
  # Extract allowed paths from acceptance criteria
  allowed_files = acceptance_criteria.get("files", [])

  config = SandboxConfig(
      working_dir=Path("/workspace"),
      read_allowed=["src/", "tests/", "docs/"] + allowed_files,
      write_allowed=["src/", "tests/"],
      read_denied=[".env", "secrets/", "credentials/"],
      network_allowed=["internal-api.example.com"]
  )

  return Sandbox(config)
```

Network Egress Controls
Egress controls prevent data from leaving the environment. Common policies include:

Allow outbound access only to internal APIs: the tool can call internal services but cannot reach the internet.

Block access to public internet by default: prevent data exfiltration through external services.

Require explicit approval to access external domains: when external access is needed, require approval and time-box it.

This matters because prompt injection often tries to exfiltrate secrets through network calls. If egress is blocked, the attack fails even if the model is compromised. The attacker cannot send data anywhere, so the attack fails.

Egress controls should be specific, not generic. Instead of "allow all HTTPS," define the exact domains or services the tool can reach. This turns network access into a deliberate design decision rather than a default capability. When access is specific, it is easier to audit and control.

If a tool needs temporary access to an external domain, require an approval and time-box the allowlist. This keeps exceptions visible and reduces long-term exposure. When exceptions are temporary and approved, they are manageable.

Audit Logs and Traceability
Every tool call should produce an audit record: what was called, with what arguments, and what the result was. Audit logs make incident response possible and enable post-incident improvements.

If you cannot answer "what command was run" and "why it was run," you do not have a safe toolchain. When an incident happens, you need to understand what happened. Audit logs provide that understanding.

Audit logs should include:

Command executed: what command was run.

Arguments: what arguments were passed.

Result: what the command returned or what error occurred.

Context: what task triggered the command and what user requested it.

This information enables debugging and learning. When you see patterns in commands or failures, you can improve the system. When you need to investigate an incident, you have the data you need.

Resource Limits and Runaway Processes
AI-generated commands sometimes trigger long-running or expensive tasks. Resource limits prevent these mistakes from taking down shared infrastructure. Basic safeguards include:

CPU and memory limits per task: prevent a single task from consuming all resources.

Timeouts for command execution: prevent commands from running forever.

Disk usage caps: prevent tasks from filling up disk space.

These limits are not only about security. They protect reliability and cost. When tasks are limited, they cannot break shared infrastructure. When tasks are limited, costs are predictable.

Consider what happens without limits. An AI assistant might generate a command that runs forever, consuming CPU and memory. This slows down other tasks and increases costs. With limits, the command is killed after a timeout, preventing damage.

Secrets Handling Inside the Sandbox
Avoid placing secrets directly in the sandbox environment. Use short-lived tokens with narrow scopes and prefer proxy services that perform sensitive operations on behalf of the tool. This reduces the risk of leakage and limits the blast radius if the sandbox is compromised.

If secrets must be in the sandbox, use environment variables that are injected at runtime and cleared when the task completes. Never hardcode secrets in sandbox images or configuration. When secrets are injected, they can be rotated and revoked. When secrets are hardcoded, they persist.

A Step-by-Step Containment Checklist
A practical containment checklist for a new tool:

Define allowed directories and mount them read-only by default: start restrictive, then add access as needed.

Define a minimal writable workspace: limit write access to what is necessary.

Block outbound network access, then add explicit allowlisted destinations: start with no network access, then add what is needed.

Enforce CPU, memory, and time limits: prevent resource exhaustion.

Log every tool command and every denied action: enable debugging and learning.

This checklist is short enough to apply consistently and strong enough to reduce most accidental failures. When you follow it, you create a safe environment that still allows useful work.


Summary: Contain the Blast Radius
Sandboxing, filesystem allowlists, and egress controls are the physical safety boundaries for AI tools. They reduce the impact of mistakes and make security incidents manageable. When sandboxing is done well, mistakes are contained and damage is limited.

Sandboxing is not just about security. It is about reliability. When tools run in isolated environments, they cannot break shared infrastructure. When tools run in ephemeral environments, they cannot leave behind hidden state. This makes systems more predictable and debuggable.

Operational Trade-offs
Sandboxing adds friction. A tool might fail to access a file or a network resource it legitimately needs. The solution is not to remove the sandbox. The solution is to make the approval path easy and auditable.

If a tool legitimately needs external access, make it a deliberate action: a scoped allowlist for that task, or an approval gate for a temporary permission. This keeps the system safe while preserving productivity. When exceptions are deliberate and approved, they are manageable.

Sandbox Observability
Sandboxing should not be opaque. You should be able to see:

Which commands were attempted: what the tool tried to do.

Which ones were blocked: what was prevented and why.

Which resources were accessed: what files or networks were used.

This visibility turns sandboxing from a black box into a learning tool for improving rules and prompts. When you can see what happened, you can improve the system. When sandboxing is opaque, you cannot learn from it.

Performance and Developer Experience
Sandboxing adds overhead. The best systems amortize that overhead by:

Reusing container images instead of rebuilding for each task: reduce startup time.

Caching dependencies inside the sandbox image: reduce download time.

Using lightweight policies for low-risk tasks: reduce enforcement overhead.

This keeps the system safe without turning every AI-assisted task into a slow build. When sandboxing is fast, developers use it. When sandboxing is slow, developers bypass it.

Incident Drills for Sandbox Failures
You should practice what happens when sandboxing fails or when the tool attempts a blocked action. A basic drill includes:

Verifying that the blocked action is logged: ensure audit trails work.

Checking that no external network calls were made: ensure egress controls work.

Confirming that credentials were not exposed: ensure secrets handling works.

These drills make sure your containment controls are not theoretical. When you test controls, you find problems before incidents happen.

Common Pitfalls and Solutions
Pitfall: shared sandboxes for many tools. Shared environments increase blast radius. Solution: isolate sandboxes per task or per repository. When sandboxes are isolated, mistakes are contained.

Pitfall: no audit trail. Without logs, you cannot learn from mistakes. Solution: record every tool call and store it for incident review. When actions are logged, you can debug and learn.

Pitfall: bypassing the sandbox for convenience. This usually happens when the sandbox is too restrictive. Solution: add clear approval paths and document how to request exceptions. When exceptions are easy, developers use them instead of bypassing.

Pitfall: persistent sandboxes. Persistent environments accumulate state and risk. Solution: use ephemeral sandboxes that are destroyed after each task. When sandboxes are ephemeral, state does not persist.

Pitfall: no resource limits. Unlimited resources allow runaway processes. Solution: enforce CPU, memory, and time limits. When resources are limited, processes cannot run away.

Key concepts to remember
Sandboxing is a safety boundary—it limits the blast radius of mistakes
Egress controls prevent exfiltration—block outbound access by default
Audit logs enable accountability—every tool call should be traceable
Trade-offs are manageable—use scoped exceptions and approvals, not blanket access
Ephemeral environments reduce risk—destroy sandboxes after each task
Resource limits protect infrastructure—prevent runaway processes
Observability enables learning—make sandboxing transparent, not opaque