Review everything we worked on during this coding session, including the current codebase, git diff/history, and any relevant discussion from this session.

Create or update concise hindsight documentation for the project.

Focus on four things:

1. **What was implemented**

   * Summarize meaningful features, systems, refactors, or fixes completed this session.
   * Do not document trivial edits that are obvious from the code.

2. **What I learned**

   * Capture Godot, GDScript, programming, architecture, or game-development concepts that I appeared to learn or understand better during this session.
   * Focus especially on things I was confused about, asked questions about, or corrected during implementation.
   * Explain them briefly in a way that will be useful to me later.
   * Do not repeat concepts already documented unless today's work meaningfully changed my understanding.

3. **Important decisions**

   * Record architectural or game-design decisions we made that future work should respect.
   * Include the reasoning behind the decision when that reasoning is not obvious.
   * Do not elevate temporary implementation details or speculative ideas into permanent decisions.

4. **Where to continue**

   * Record unfinished work, known problems, technical debt that is actually worth remembering, and the most logical next steps.
   * Distinguish between things that genuinely need attention and optional improvements.

Review and maintain the following project documentation. Each file has a different purpose; keep information in the file where it belongs rather than duplicating it across files.

* `DEVLOG.md`

  * Maintain a chronological record of meaningful development progress.
  * Add a concise entry for this session describing what was accomplished, major problems solved, and notable unfinished work.
  * This is a development history, not exhaustive release notes.

* `LEARNING.md`

  * Maintain a consolidated reference of concepts I have learned.
  * Add or revise entries based on concepts I meaningfully learned or clarified this session.
  * Prefer improving, consolidating, or replacing existing entries over endlessly appending duplicate notes.
  * Do not add concepts merely because they appeared in the code; there should be evidence that I actually learned or discussed them.

* `LEARNING_ROADMAP.md`

  * Maintain a loose, evolving roadmap for what I should learn next while building this project.
  * Update it based on what I demonstrated that I now understand, what I practiced this session, and what upcoming project work will require.
  * Mark concepts as learned/in progress when appropriate and adjust future priorities accordingly.
  * Remove or deprioritize roadmap items that are no longer useful.
  * Prefer learning concepts when the project naturally creates a reason to use them rather than following an arbitrary curriculum.
  * Keep the roadmap focused on the next useful layer of knowledge rather than planning my entire Godot education in advance.

* `DECISIONS.md`

  * Maintain durable architectural and game-development decisions along with their rationale.
  * Add decisions made this session when they are likely to constrain or guide future work.
  * Revise existing entries if a previous decision was changed or superseded.
  * Do not record tentative ideas as settled decisions.

* `GAME_DESIGN.md`

  * Treat this as the current source of truth for the game's intended mechanics and design.
  * Update it when this session established, changed, clarified, or removed meaningful game-design behavior.
  * Incorporate confirmed design decisions into the appropriate existing sections rather than simply adding a session log.
  * Remove or revise outdated descriptions when the design has changed.
  * Preserve useful distinction between what is currently implemented and what is merely intended when that distinction matters.
  * Do not add implementation details, programming notes, bugs, or learning notes unless they directly affect the intended game design.
  * Do not treat brainstorming or possibilities discussed during the session as confirmed design unless we actually settled on them.

* `CLAUDE.md`

  * Keep this useful as persistent operational context for future Claude coding sessions.
  * Update it when this session revealed information that would materially help a future Claude work effectively in this repository.
  * Appropriate additions or revisions may include:

    * important project structure or architectural conventions
    * established coding patterns
    * responsibilities of important systems/files
    * project-specific Godot conventions
    * important development workflow instructions
    * known pitfalls that future sessions should avoid
    * durable preferences about how I want Claude to teach, guide, or modify the project
  * Remove or revise obsolete guidance when the project has changed.
  * Do not turn `CLAUDE.md` into a devlog, design document, or encyclopedia of the codebase.
  * Only include information that is likely to remain useful across multiple future sessions.

Keep all documentation concise and high-signal. The goal is to preserve useful context for future development and teaching, not to produce exhaustive documentation.

Avoid:

* narrating every code change
* documenting information obvious from reading the code
* copying the same information into several files
* repeating existing documentation unnecessarily
* lengthy explanations of simple concepts
* inventing lessons or decisions that were not actually established
* presenting tentative ideas as settled decisions
* preserving obsolete information merely because it was previously documented
* bloating `CLAUDE.md` with information that belongs elsewhere

Before modifying any documentation:

1. Inspect the existing versions of all relevant files.
2. Compare them with the actual current codebase, git diff/history, and what happened during this session.
3. Determine which documents genuinely need changes.
4. Merge, revise, consolidate, or remove obsolete information instead of blindly appending.
5. Leave a file unchanged when this session produced nothing meaningful for it.

Documentation should reflect the project as it exists at the end of the session, not merely describe the sequence of things we tried along the way.

At the end, give me a short session-closeout summary containing:

* the most important thing implemented
* the most important thing I learned
* the main architectural or game-design decision, if any
* how the learning roadmap changed, if relevant
* which persistent documentation files were meaningfully updated
* the best starting point for the next coding session

Treat these documents collectively as persistent project memory intended to help a future AI coding session quickly understand:

* the current state of the project
* the intended game design
* the architectural decisions and conventions already established
* how this repository should be worked on
* what I currently understand
* what I should learn next
* where development should resume
