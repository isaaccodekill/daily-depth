# Existing regression checks

These Swift check programs were preserved from the original development workspace. They are standalone `@main` executables, not an XCTest target; compile each separately alongside the relevant app sources. Several accept a temporary output directory or SQLite path as their first argument. Do not point them at live app data.

The reader checks are portable within this repository:

```sh
cd Tests/Reader
npm ci
node check.cjs
```

For previous validation results and remaining live API checks, see `../LEARNING_DESIGN.md`.
