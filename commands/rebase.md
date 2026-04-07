---
name: rebase
description: Safely rebase the current feature branch onto main (or another target branch), always prioritizing the target branch's structural/architectural changes while carefully preserving feature branch logic. Has two modes: standard rebase with conflict guidance, and semantic rebase (fallback for complex cases) which snapshots intent, resets to main, re-reads the codebase, and re-implements changes from scratch with file-by-file validation.
allowed-tools: Bash
---

Safely rebase the current feature branch onto a target branch. Starts with standard rebase and automatically escalates to **semantic rebase** when conflicts are too structural to resolve mechanically.

Arguments: $ARGUMENTS

---

## Argument Parsing

- No arguments → target is `main`, no fetch
- `"origin"` → fetch `origin`, target is `origin/main`
- `"origin/branch-name"` → fetch `origin`, target is `origin/branch-name`
- `"branch-name"` → target is that local branch, no fetch
- `"--semantic"` anywhere in arguments → skip standard rebase, go straight to semantic rebase

---

## Phase 0: Pre-flight

```bash
git status --porcelain
git branch --show-current
```

- If dirty: `git stash push -m "rebase-skill-temp"` — remember to pop at the end.
- If on `main`/`master`: stop and ask the user which feature branch to rebase.
- If `--semantic` flag present: skip to **Phase S**.

---

## Phase 1: Safety Backup

Always create a timestamped backup before touching history:

```bash
git branch backup/$(git branch --show-current)-$(date +%Y%m%d-%H%M%S)
```

Tell the user the backup branch name. They can restore at any time with:
```bash
git reset --hard <backup-branch>
```

---

## Phase 2: Fetch (if needed)

If the target includes a remote: `git fetch <remote>`

---

## Phase 3: Pre-rebase Survey

Study what the target branch changed before touching anything:

```bash
git log --oneline HEAD..<target>
git diff HEAD...<target> --name-only
```

Also read git notes for both sides to understand intent:

```bash
# Fetch notes from remote if available
git fetch origin refs/notes/commits:refs/notes/commits 2>/dev/null || true

# Show feature branch commits with their intent notes
git log --oneline --notes <target>..HEAD

# Show target branch commits with their intent notes
git log --oneline --notes HEAD..<target>
```

Use these notes to understand the **why** behind each change before resolving any conflicts.

Summarize: "Main is N commits ahead. Files likely to conflict: [list]."

Detect **complexity signals** that suggest semantic rebase may be needed:
- More than 5 files overlapping between branches
- Any overlapping files appear in commits with messages containing: refactor, restructure, rename, reorganize, move, extract, split, redesign
- Overlapping files are core modules (not just config or docs)

If 2 or more complexity signals are present, note: *"This rebase may be complex. I'll attempt standard rebase first, but semantic rebase is available as a fallback."*

---

## Phase 4: Standard Rebase

```bash
git rebase <target>
```

### Conflict Resolution Loop

For EACH conflict:

**a.** Study the target branch's changes to that file, including intent notes:
```bash
git log -p -n 5 --notes <target> -- <conflicting-file>
```

**b.** Study the feature branch's intent for that file, including intent notes:
```bash
git log -p -n 5 --notes HEAD -- <conflicting-file>
```

Use the git notes to understand the reasoning behind each side's changes. Notes that mention dependencies or assumptions are especially valuable for determining resolution priority.

**c.** Resolution priority:
- **Target branch wins** → structural changes, refactors, renames, new abstractions, deleted code, interface/API changes
- **Feature branch wins** → new feature logic, new functions/classes that don't conflict structurally, new tests
- **Merge both** → feature adds logic inside a function that main refactored: adapt the feature code to use the new structure

**d.** NEVER silently drop changes from either side.

**e.** After each file: `git add <file>`, then `git rebase --continue`.

### Escalation Trigger

Escalate to **semantic rebase** if ANY of these occur:
- A conflict spans more than ~40 lines and both sides have substantial logic
- A file was heavily reorganized in main (functions moved, classes split/merged) making line-by-line resolution unreliable
- The same file conflicts across multiple commits in the rebase
- You are not confident the resolution preserves the full intent of the feature

When escalating: `git rebase --abort`, inform the user, then proceed to **Phase S**.

---

## Phase 5: Post-rebase Verification (standard path)

```bash
git log --oneline <target>..HEAD
git diff <target>...HEAD --stat
```

Ask the user if they want the test suite run. Check `CLAUDE.md`, `package.json`, `Makefile`, `pyproject.toml` for the test command.

Pop stash if applicable: `git stash pop`

Produce a summary report:
- Backup branch name
- Target rebased onto
- Commits replayed
- Files that conflicted and how resolved
- Any items to manually review

---

---

# SEMANTIC REBASE (Phase S)

Triggered automatically on escalation, or manually with `--semantic`.

> **Core idea:** Instead of fighting git's mechanical conflict resolution, snapshot the *intent* of the feature changes, reset to clean main, re-read the full updated codebase, then re-implement the changes from scratch using the snapshot as a specification — not a diff to apply.

---

## S1: Generate Intent Summary (Mitigation 1 — intent over patch)

Before generating any patch, produce a **human-readable intent document** for each commit in the feature branch.

```bash
git log <target>..HEAD --format="%H %s"
```

For each commit, run:
```bash
git show <hash> --stat
git show <hash> -p
git notes show <hash> 2>/dev/null   # read existing intent note if present
```

If a git note exists for the commit, use it as the **primary source of intent** — it was written at commit time and reflects the author's reasoning. Supplement with diff analysis, but prefer the note's description of why the change was made.

For each commit, write:

```
## Commit: <short hash> — "<message>"

### What this commit does (plain language)
[2-4 sentences describing the purpose and behavior being added/changed]

### Files touched
- `path/to/file.ext`: [what changed and why]
- `path/to/other.ext`: [what changed and why]

### Key logic to preserve
[Bullet list of the specific functions, classes, behaviors, or invariants
that MUST be present after re-implementation. Be explicit — this is the
spec Claude will use when re-implementing on top of main.]

### What NOT to preserve
[Anything that was a workaround for old main structure, or that main has
now superseded with a better approach]
```

Save this document to: `.git/semantic-rebase-intent.md`

Show it to the user and ask: *"Does this intent summary correctly capture what your feature does? Add any corrections before I proceed."*

**Wait for user confirmation before continuing.**

---

## S2: Generate the Raw Patch

```bash
git diff <target>...HEAD > .git/semantic-rebase-feature.patch
```

This is kept as a **reference artifact only** — it will NOT be applied with `git apply`. It is used in S5 for file-by-file validation only.

---

## S3: Reset to Clean Main

```bash
git checkout <target-branch-name>   # e.g. main
git checkout -b semantic-rebase/$(date +%Y%m%d-%H%M%S)
```

This new branch starts at the exact tip of main.

---

## S4: Re-read the Codebase

Before writing a single line, systematically understand the current state of main:

**a.** Read the project structure:
```bash
find . -type f | grep -v '.git' | grep -v 'node_modules' | grep -v '__pycache__' | sort
```

**b.** For every file mentioned in the intent summary (S1), read its current version in main:
```bash
cat <file>
```

**c.** For files adjacent to touched areas (same module/package), scan their interfaces:
```bash
cat <adjacent-file>
```

**d.** Check for any new abstractions, base classes, utilities, or patterns introduced in main that the feature should use:
```bash
git log <original-feature-base>..<target> --oneline --diff-filter=A
```

Build a clear mental model: *"Here is how main currently works in the areas the feature needs to touch."* Write a brief summary of any new patterns, renamed symbols, or structural changes discovered.

---

## S5: Re-implement Changes — File by File with Validation (Mitigation 2)

Work through each file from the intent summary **one at a time**.

For each file:

**a. Re-implement** the change using:
- The intent summary (S1) as the **specification** — what must be achieved
- The current main codebase (S4) as the **structural context** — how to express it
- The raw patch (S2) as a **logic reference** — exact algorithms, values, signatures — but adapted to new structure

**b. Validate immediately** after implementing each file.

Cross-check against the raw patch for that file:
```bash
grep -A 200 "diff --git a/<file>" .git/semantic-rebase-feature.patch | head -200
```

Run through this checklist for every file:
- [ ] Every item from "Key logic to preserve" in S1 is present
- [ ] No logic from the original patch was silently dropped
- [ ] Implementation uses main's new structure (new class names, utilities, patterns) — not the old one
- [ ] No references to renamed symbols, deleted abstractions, or old APIs
- [ ] If a function signature changed in main, the feature uses the new signature

If any check fails: fix before moving to the next file. Do not batch fixes.

**c.** After each file passes validation, commit it:
```bash
git add <file>
git commit -m "<original commit message> (semantic rebase)"
```

Committing file-by-file creates a clean rollback point if anything goes wrong mid-rebase.

---

## S6: Final Cross-validation

After all files are re-implemented:

**a.** Check no files were missed. Extract all files from the original patch:
```bash
grep "^diff --git" .git/semantic-rebase-feature.patch | sed 's/diff --git a\///' | sed 's/ b.*//'
```
Compare against files committed in S5. Every file must be either re-implemented or explicitly skipped with a documented reason.

**b.** Compare overall diff scope:
```bash
git diff <target>...HEAD --stat
```
A drastically smaller diff than the original patch is a warning sign that logic was dropped. Investigate any large discrepancy.

**c.** Run the test suite if available. Check `CLAUDE.md`, `package.json`, `Makefile`, `pyproject.toml` for the test command.

**d.** Show the user the final diff for review:
```bash
git diff <target>...HEAD
```

---

## S7: Cleanup

```bash
rm -f .git/semantic-rebase-intent.md
rm -f .git/semantic-rebase-feature.patch
git stash pop   # only if stashed in Phase 0
```

---

## S8: Summary Report

```
✅ Semantic Rebase Complete

Original branch:        <feature-branch>  (preserved as backup/<n>-<ts>)
Rebased onto:           <target>
New branch:             semantic-rebase/<ts>

Commits re-implemented: N
Files re-implemented:   M

Validation:
  ✅ Intent checklist passed for all files
  ✅ All patch files accounted for
  ⚠️  <any warnings or items needing manual review>

Next steps:
  1. Review: git diff <target>...semantic-rebase/<ts>
  2. Run your full test suite
  3. If happy: git checkout <feature-branch> && git reset --hard semantic-rebase/<ts>
  4. Force-push your feature branch
```

---

## Decision Flow

```
/rebase [args]
    │
    ├── --semantic flag? ──────────────────────────────────► Phase S
    │
    ├── Phase 0: Pre-flight (stash, guard against main)
    ├── Phase 1: Safety backup (timestamped branch)
    ├── Phase 2: Fetch if needed
    ├── Phase 3: Pre-rebase survey → complexity signals?
    │               └── 2+ signals: warn user, continue anyway
    │
    ├── Phase 4: Standard rebase + conflict resolution
    │               └── Escalation trigger hit? ───────────► git rebase --abort → Phase S
    │
    └── Phase 5: Verify + report (standard path)


Phase S: Semantic Rebase
    ├── S1: Intent summary per commit        ← Mitigation 1: spec over patch
    │        └── User confirms before proceeding
    ├── S2: Save raw patch (reference only)
    ├── S3: Checkout clean main → new branch
    ├── S4: Re-read full codebase
    ├── S5: Re-implement + validate per file  ← Mitigation 2: file-by-file checks
    ├── S6: Final cross-validation
    ├── S7: Cleanup
    └── S8: Summary report
```

---

## Philosophy

> **Standard rebase** resolves *what lines conflict*.
> **Semantic rebase** answers *how should this feature be expressed, given how main works today*.
>
> The raw patch is a memory aid and validation tool — not a script to execute.
> The intent summary is the real specification.
> The current codebase is the real context.
> Re-implementation is always guided by all three.
