## Quiz: AI-Augmented Software Development

AI-Augmented Software Development
Your team is rolling out AI-assisted coding across multiple repositories. Productivity is up, but reviewers are seeing larger diffs, inconsistent conventions, and occasional regressions. You need workflows that keep changes reviewable, reproducible, and safe without slowing the team to a crawl.


What is the most accurate framing of AI tools in a production development workflow?

AI tools own correctness because they generate the implementation.

AI tools delegate responsibility away from humans if tests pass.

AI tools delegate labor while humans keep ownership of outcomes and safety.

AI tools are only safe to use for documentation, not for code.
Correct Answer!
The workflow should preserve human responsibility while accelerating execution.

Which acceptance criteria set is best suited for AI-assisted changes?

“Fix the bug and clean up the code while you are there.”

“Make it work” with no tests, because AI is fast.

“Match existing style” with no behavioral requirements.

Behavioral requirements + edge cases + explicit testing expectations.
Correct Answer!
Testable requirements and edge-case coverage are the most reliable interface.

What should repo-level rules primarily contain?

Stable invariants and safety boundaries that prevent recurring failure modes.

One-off instructions that change every week.

A full tutorial for every tool the team might use.

Only formatting rules, because correctness is handled by tests.
Correct Answer!
High-signal rules improve consistency and reduce risk when paired with enforcement.

What is the primary value of evaluation gates in AI-assisted development?

They make the assistant sound more confident.

They provide objective evidence that the change is safe enough to merge.

They eliminate the need for human code review.

They ensure the diff is small.
Correct Answer!
Evals convert plausible output into reviewable, test-backed evidence.

What is a regression pack in this context?

A random sample of tests run only when CI is slow.

A curated set of tests based on past incidents and high-risk flows.

A single LLM judge prompt that approves or rejects PRs.

A set of lint rules focused only on formatting.
Correct Answer!
Regression packs encode what has actually broken before and should not break again.

Why is treating context as a budget a good default?

More context always decreases hallucinations.

It reduces cost, lowers noise, and limits accidental data exposure.

It guarantees deterministic outputs.

It is only relevant for small models.
Correct Answer!
Context minimization improves safety and efficiency while keeping signal high.

Which practice most directly improves reproducibility for AI-assisted code changes?

Relying on whatever hidden context the tool retrieves automatically.

Pinning instruction templates and recording verification evidence in the PR.

Increasing temperature so the assistant explores more options.

Avoiding tests because they slow down iteration.
Correct Answer!
Versioned instructions and recorded evidence make outputs repeatable and reviewable.