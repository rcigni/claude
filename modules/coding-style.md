# Coding Style & Conventions

## General Principles
- Prefer clarity over cleverness
- Follow the existing conventions of whatever codebase you're working in
- Don't add abstractions until they're needed at least twice

## Naming
- Use descriptive names that convey intent
- Prefer full words over abbreviations (except universally known ones like `id`, `url`, `config`)

## Formatting
- Respect the project's formatter/linter configuration (Prettier, Black, rustfmt, etc.)
- Don't reformat code you didn't change

## Language-Specific Notes
- **TypeScript**: Prefer `interface` over `type` for object shapes. Use strict mode.
- **Python**: Follow PEP 8. Use type hints for function signatures.
- **Rust**: Follow clippy suggestions. Prefer `impl` blocks.
