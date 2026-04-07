# Git & PR Workflow

## Commits
- Write concise commit messages focused on "why", not "what"
- One logical change per commit
- Don't amend published commits

## Branches
- Use descriptive branch names: `feat/`, `fix/`, `refactor/` prefixes
- Keep branches short-lived and focused

## Pull Requests
- PR title under 70 characters
- Include a Summary section with 1-3 bullet points
- Include a Test Plan section
- Prefer small, reviewable PRs over large ones

## Git Notes for Commit Intent

After every commit, add a git note that captures the **intent** behind the change. This serves as a semantic summary that aids conflict resolution during rebases and merges.

### When to add notes

Add a git note immediately after creating a commit:

```bash
git notes add -m "<intent summary>" HEAD
```

### What to include in a note

Write 2-5 sentences covering:
- **Why** this change was made (the motivation, not the mechanics)
- **What behavior** changed from the user/system perspective
- **Key decisions** — any non-obvious choices, trade-offs, or alternatives rejected
- **Dependencies** — if this commit assumes or builds on specific prior state

### Example

```
Commit message: "Extract auth middleware into shared module"

Git note:
"Auth logic was duplicated across 3 route handlers with slight variations.
Consolidated into a single middleware to ensure consistent token validation.
Chose middleware over decorator pattern because Express routes already chain handlers.
This must be merged before the rate-limiting PR which depends on the shared auth context."
```

### Pushing and fetching notes

Git notes live in `refs/notes/commits` and must be pushed/fetched explicitly:

```bash
# Push notes to remote
git push origin refs/notes/commits

# Fetch notes from remote
git fetch origin refs/notes/commits:refs/notes/commits
```

### Reading notes

```bash
# Show note for a specific commit
git notes show <commit>

# Show log with notes inline
git log --notes
```

### Updating notes

If a commit's intent becomes clearer after discussion or review:

```bash
git notes append -m "<additional context>" <commit>
```

## Code Review
- Address all review comments before merging
- Don't force-push to shared branches without coordination
