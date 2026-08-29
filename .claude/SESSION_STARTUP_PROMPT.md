This is the start of a new coding session.

Before making any changes, rebuild your understanding of the project and get me oriented for the next step.

Review the relevant project context, including:

* `DEVLOG.md`
* `LEARNING.md`
* `DECISIONS.md`
* `CLAUDE.md`
* `GAME_DESIGN.md`
* `LEARNING_ROADMAP.md`
* any game/design documentation
* the current git status and recent git history
* the current structure of the relevant code and scenes
* unfinished work, TODOs, warnings, or known issues from the previous session

Do not assume the documentation is perfectly current. Compare it against the actual codebase and git state, and call out any meaningful discrepancies.

Then give me a concise session startup briefing covering:

1. **Where the project currently stands**

   * What systems/features are currently working?
   * What was most recently implemented?
   * What parts are still rough, temporary, or incomplete?

2. **What I already understand**

   * Use `LEARNING.md` and the existing code to estimate my current understanding.
   * Avoid re-teaching concepts I have already demonstrated that I understand.
   * Point out any concepts that seem worth reinforcing because they are relevant to today's work.

3. **Important constraints and decisions**

   * Summarize any architectural or design decisions from `DECISIONS.md` that should influence the next work.
   * Distinguish durable decisions from temporary implementation choices.

4. **Loose ends**

   * Identify unfinished tasks, known bugs, technical debt, or questionable architecture that may affect the next step.
   * Do not turn minor imperfections into unnecessary refactoring work.

5. **Recommended next step**

   * Recommend the single best next task for this session based on the current state of the project.
   * Explain briefly why it is the right next step.
   * If there are 2–3 genuinely reasonable directions, mention them, but still recommend one default.

6. **Learning goal**

   * Identify the main Godot/GDScript/game-development concept I am likely to learn or practice by doing that task.
   * Structure your guidance so I remain involved in implementing and understanding it rather than simply having you generate the entire solution.

Do not modify code yet unless I explicitly ask you to after the briefing.

When we begin implementation:

* guide me incrementally
* explain new concepts when they first become relevant
* let me write or reason through meaningful parts myself when practical
* review what I produce and correct misunderstandings
* avoid unnecessary abstraction or premature architecture
* prefer getting the game working cleanly over building systems we do not yet need
* respect existing project conventions and documented decisions unless there is a strong reason to change them

The goal is to continue from the previous session with minimal context loss while keeping this an interactive learning process rather than turning the project into an AI-generated codebase.
