---
name: split-pr
description: Analyze the current branch's uncommitted changes or commits ahead of main and propose a split into multiple focused, reviewable PRs. Use when the user asks to split changes, break up a large PR, or wants help organizing work before opening a pull request.
allowed-tools: Bash
---

Analyze all changes in the current branch relative to main (or a specified base), then propose a logical split into multiple smaller, focused PRs — each independently mergeable and reviewable.

Arguments: $ARGUMENTS

## Argument Parsing

- No arguments → compare against `main`
- `"origin"` or `"origin/main"` → compare against `origin/main`
- `"branch-name"` → compare against that branch

## Steps

### 1. Understand the current state

```bash
git status --porcelain
git branch --show-current
```

Check for both:
- **Uncommitted changes** (staged + unstaged)
- **Commits ahead of base** that are not yet in a PR

```bash
git log --oneline <base>..HEAD
git diff <base>...HEAD --stat
```

Show a brief summary: total files changed, insertions, deletions, number of commits.

### 2. Deep diff analysis

Get the full diff to understand what changed:

```bash
git diff <base>...HEAD
```

Also inspect commit messages for intent:

```bash
git log <base>..HEAD --format="%H %s" 
```

### 3. Cluster changes into logical groups

Analyze the diff and group files/changes into clusters based on:

**Cluster criteria (in priority order):**
1. **Layer / concern**: e.g., database migrations, API layer, business logic, UI, tests, config, docs
2. **Feature area**: e.g., authentication, notifications, billing — if changes span multiple features
3. **Type of change**: refactor vs. new feature vs. bug fix vs. dependency update vs. infrastructure
4. **Dependencies**: if change B depends on change A being merged first, they must be separate PRs in order
5. **Review audience**: infra changes reviewed by ops, UI changes by designers — separate if different reviewers

**Rules for a good PR split:**
- Each PR must be independently compilable/testable (no broken imports between PRs)
- Each PR should have a single clear purpose expressible in one sentence
- Tests for a feature should be in the SAME PR as the feature, not a separate one
- Config/env changes should be in their own PR or bundled with the first PR that needs them
- Refactors that unblock a feature: refactor PR first, feature PR second

### 4. Produce the split proposal

Output a structured proposal like this:

---

## Proposed PR Split

**Base branch:** `main`  
**Total changes:** X files, +Y -Z lines  
**Proposed split:** N PRs

---

### PR 1: `<suggested-branch-name>` — `<one-line title>`

**Purpose:** [What this PR does and why it's standalone]  
**Files:**
- `path/to/file.ext` — [why it belongs here]
- `path/to/other.ext` — [why it belongs here]

**Depends on:** none  
**Can be merged independently:** yes  
**Suggested reviewers / review focus:** [optional]

---

### PR 2: `<suggested-branch-name>` — `<one-line title>`

**Purpose:** [...]  
**Files:** [...]  
**Depends on:** PR 1 (must be merged first because: [reason])  
**Can be merged independently:** only after PR 1

---

[repeat for each PR]

---

### Risks / Notes
- [Any file that was hard to assign to one PR]
- [Any circular dependency concern]
- [Any suggestion to further simplify before splitting]

---

### 5. Ask before executing

After presenting the proposal, ask:

> "Does this split look good? I can:
> 1. **Create the branches and cherry-pick/stash the changes** into separate branches ready to push
> 2. **Just show the plan** so you can execute it manually
> 3. **Adjust the split** — tell me what to move between PRs"

Do NOT create branches or move files until the user confirms the plan.

### 6. Execution (if user confirms)

For each PR in dependency order:

**Option A — Cherry-pick approach** (when changes are already in clean commits):
```bash
git checkout <base>
git checkout -b <pr-branch-name>
git cherry-pick <commit-hash> [<commit-hash> ...]
```

**Option B — Stash/patch approach** (when changes are uncommitted or mixed in commits):
```bash
git checkout <base>
git checkout -b <pr-branch-name>
# Apply only the relevant files from the diff
git checkout <original-branch> -- <file1> <file2> ...
git add <files>
git commit -m "<conventional commit message>"
```

After creating each branch:
```bash
git log --oneline <base>..<pr-branch-name>  # verify commits
git diff <base>...<pr-branch-name> --stat   # verify files
```

### 7. Final summary

After all branches are created, output:

```
✅ Created N branches:

  pr/1-<name>  →  X commits, Y files
  pr/2-<name>  →  X commits, Y files
  ...

Suggested merge order: pr/1-<name> → pr/2-<name> → ...

Original branch '<name>' is untouched. Push each branch and open PRs when ready.
```

## Split Philosophy

> A good PR split is not just about size — it's about **reviewability** and **safety**. Each PR should tell a clear story, be mergeable without breaking main, and give reviewers a focused surface to evaluate. When in doubt, keep things together rather than create a split that leaves either PR in a broken state.
