# dbt Commands Cheatsheet

## Quick Reference

Copy-paste ready commands for common operations.

---

## Project Setup

```powershell
# Initialize new project
dbt init my_project

# Install packages (from packages.yml)
dbt deps

# Check connection and config
dbt debug

# Verbose debug
dbt debug -v
```

---

## Running Models

```powershell
# Run all models
dbt run

# Run specific model
dbt run --select my_model

# Run models in a folder
dbt run --select staging.*

# Run model and all upstream dependencies
dbt run --select +my_model

# Run model and all downstream dependents
dbt run --select my_model+

# Run model with upstream AND downstream
dbt run --select +my_model+

# Run multiple specific models
dbt run --select model_a model_b model_c

# Run models with a tag
dbt run --select tag:daily

# Exclude models
dbt run --exclude my_model

# Full refresh (rebuild from scratch)
dbt run --full-refresh

# Run with different target
dbt run --target prod
```

---

## Seeds

```powershell
# Load all seeds
dbt seed

# Load specific seed
dbt seed --select my_seed

# Full refresh seed (drop and recreate)
dbt seed --full-refresh
```

---

## Testing

```powershell
# Run all tests
dbt test

# Test specific model
dbt test --select my_model

# Test specific test
dbt test --select test_name

# Run tests and store failures
dbt test --store-failures

# Show first failure only
dbt test --limit 1

# Run tests with warnings
dbt test --warn-error
```

---

## Build (Run + Test)

```powershell
# Run and test everything
dbt build

# Build specific model
dbt build --select my_model

# Build with dependencies
dbt build --select +my_model+
```

---

## Documentation

```powershell
# Generate docs
dbt docs generate

# Serve docs locally (opens browser)
dbt docs serve

# Serve on specific port
dbt docs serve --port 8001
```

---

## Compilation

```powershell
# Compile all models (no run)
dbt compile

# Compile specific model
dbt compile --select my_model

# See compiled SQL in target/compiled/
```

---

## Sources

```powershell
# Check source freshness
dbt source freshness

# Check specific source
dbt source freshness --select source:my_source
```

---

## Snapshots

```powershell
# Run all snapshots
dbt snapshot

# Run specific snapshot
dbt snapshot --select my_snapshot
```

---

## Cleaning

```powershell
# Remove target/ and dbt_packages/
dbt clean
```

---

## Selection Syntax

| Syntax | Meaning |
|--------|---------|
| `my_model` | Just this model |
| `+my_model` | This model + all upstream |
| `my_model+` | This model + all downstream |
| `+my_model+` | All upstream + model + all downstream |
| `staging.*` | All models in staging folder |
| `staging.stg_*` | Models matching pattern |
| `tag:daily` | Models with tag "daily" |
| `source:raw.customers` | Specific source |
| `@my_model` | Model + all in same file |

### Complex Selection

```powershell
# Intersection (both conditions)
dbt run --select "staging,tag:daily"

# Union (either condition)
dbt run --select staging --select marts

# Exclude from selection
dbt run --select staging --exclude stg_legacy
```

---

## Environment Variables

```powershell
# Set target
$env:DBT_TARGET = "prod"

# Set profiles directory
$env:DBT_PROFILES_DIR = "C:\custom\path"

# Use in dbt
dbt run --target $env:DBT_TARGET
```

---

## Common Flags

| Flag | Purpose |
|------|---------|
| `--select` / `-s` | Choose what to run |
| `--exclude` | Skip specific models |
| `--target` / `-t` | Use different target |
| `--full-refresh` | Rebuild incrementals |
| `--vars` | Pass variables |
| `--profiles-dir` | Custom profiles location |
| `--project-dir` | Custom project location |

---

## Variables

```powershell
# Pass variables via command line
dbt run --vars '{"start_date": "2023-01-01", "limit_rows": 1000}'

# Use in SQL
# {{ var('start_date') }}
```

---

## Debug and Troubleshooting

```powershell
# Check config
dbt debug

# See what would run (dry run)
dbt ls --select my_model

# List all models
dbt ls

# List tests
dbt ls --resource-type test

# View compiled SQL
cat target/compiled/my_project/models/my_model.sql
```

---

## Typical Workflows

### Daily Development

```powershell
# 1. Make changes to SQL
# 2. Run your model
dbt run --select my_model

# 3. Test your model
dbt test --select my_model

# 4. Or do both
dbt build --select my_model
```

### Before Merging PR

```powershell
# Run everything you changed + downstream
dbt build --select +my_model+

# Generate and check docs
dbt docs generate
dbt docs serve
```

### Production Deploy

```powershell
# Full build with prod target
dbt build --target prod

# Or just run (tests separately)
dbt run --target prod
dbt test --target prod
```

---

**Back to:** [../00_START_HERE.md](../00_START_HERE.md)
