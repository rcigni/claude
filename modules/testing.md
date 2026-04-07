# Testing & Quality

## Test Strategy
- Write tests for new functionality and bug fixes
- Prefer integration tests over unit tests for IO-heavy code
- Use real dependencies over mocks when practical

## Test Structure
- One assertion per test when possible
- Use descriptive test names that explain the scenario
- Arrange-Act-Assert pattern

## Quality Gates
- All tests must pass before committing
- Don't skip or disable tests without a tracking issue
- Run the project's linter before committing
