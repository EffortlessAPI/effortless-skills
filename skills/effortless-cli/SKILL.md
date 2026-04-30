---
name: effortless-cli
description: >
  Use when running effortless CLI commands, understanding CLI flags, logging in,
  installing transpilers, setting API keys, initializing projects, or troubleshooting
  the CLI. The CLI is also known as `ssotme` or `aicapture` but all documentation
  should use the canonical name `effortless`.
audience: customer
---

# Effortless CLI Reference

The `effortless` CLI (also invocable as `ssotme` or `aicapture` — but always use `effortless` in documentation and scripts) is the command-line interface for the EffortlessAPI / SSoT.me platform.

Current version format: `SSoTme CLI version YYYY.M.DD.NNN`

## Authentication — MUST happen first

Before any CLI operation, the user must be logged in:

```bash
effortless -login
```

This launches an interactive flow:
1. Prompts for an email address
2. Sends a 6-digit verification code to that email
3. User enters the code within 5 minutes
4. On success, a JWT is issued and stored locally, associating that email with the CLI account

**Check login status:**
```bash
effortless -info
```

**Logout:**
```bash
effortless -logout
```

**Project-specific login** (overrides global user for this project only):
```bash
effortless -projectLogin
```

## Initializing a Project

```bash
effortless -init
```

Creates the current folder as the root of an effortless project. Generates an `effortless.json` project file.

**With a project name:**
```bash
effortless -init -projectName "My Project"
```

**Force sub-project** (creates a nested project inside an existing one):
```bash
effortless -init force
```

## API Key Management

### Setting an Account API Key

```bash
effortless -setAccountAPIKey airtable=patXXXXXXXX.XXXXXXXX
```

This stores the key in `~/.ssotme/ssotme.key`, a JSON file structured as:

```json
{
  "EmailAddress": "user@example.com",
  "Secret": "...",
  "APIKeys": {
    "airtable": "patXXXXXXXX.XXXXXXXX"
  }
}
```

### Reading the API Key

Priority order for Airtable API key resolution:
1. `AIRTABLE_API_KEY` environment variable
2. `~/.ssotme/ssotme.key` -> parse JSON -> `APIKeys.airtable`
3. `effortless.json` -> `ProjectSettings` -> `_apikey_`

### The `-account` flag

When a transpiler needs an API key (e.g., Airtable tools), pass `-account airtable` so the CLI sends the key configured in `~/.ssotme/ssotme.key`:

```bash
effortless airtable-to-rulebook -o effortless-rulebook.json -account airtable
```

**Every airtable-facing tool MUST include `-account airtable`.**

### effortless.env

An `effortless.env` file in the project root can also store keys as environment variables. This is an alternative to `~/.ssotme/ssotme.key` for project-scoped secrets. Format is standard dotenv:

```
AIRTABLE_API_KEY=patXXXXXXXX.XXXXXXXX
```

## Installing Transpilers

Transpilers are installed from the directory where the output is expected. The exact syntax is:

```bash
effortless -install <transpiler-name> -p param1=value1 -i input-file.txt -o output-file.json
```

**The `-install` flag saves the command into the project's `effortless.json` under `ProjectTranspilers`.**

The installed entry records:
- `RelativePath` — the folder from which the install was run (relative to project root)
- `CommandLine` — the full command with all flags

### Standard Tool Installation Paths

Each tool MUST be installed from its designated directory:

| Directory | Command | Notes |
|-----------|---------|-------|
| `/bootstrap/` | `effortless -install raw-text-to-rulebook -i requirements.txt -o bootstrap-rulebook.json` | Rough starting-point rulebook |
| `/effortless-rulebook/` | `effortless -install airtable-to-rulebook -o effortless-rulebook.json -account airtable` | Main rulebook sync |
| `/effortless-rulebook/push-to-airtable/` | `effortless -install rulebook-to-airtable -i ../effortless-rulebook.json -account airtable` | **MUST BE DISABLED** — not run by default |
| `/postgres/` | `effortless -install rulebook-to-postgres -i ../effortless-rulebook/effortless-rulebook.json` | SQL generation |
| `/docs/` | `effortless -install rulebook-to-docs` | Documentation generation |

**Critical:** The `rulebook-to-airtable` tool in `push-to-airtable/` must be disabled (`"IsDisabled": true`) so it is NOT run during a normal `effortless build`. It is only run explicitly with `effortless build -id`.

## Building

```bash
effortless build              # Run all ENABLED transpilers from project root
effortless build -id          # Run ALL transpilers INCLUDING disabled ones
effortless buildLocal         # Build only transpilers in the current folder
effortless buildAll           # Build all transpilers in the project
```

### Build Flags
- `-skipClean` / `-sc` — Don't clean output before building
- `-dryRun` / `-dr` — Dry run (no actual execution)
- `-debug` — Show debug output
- `-ignoreErrors` — Continue build if a transpiler fails
- `-waitTimeout N` / `-w N` — Timeout in milliseconds for a command

## Project Inspection

```bash
effortless -describe          # Describe current project and transpilers
effortless -describeAll       # Describe all transpilers
effortless -listSettings      # List project settings
effortless -addSetting key=value   # Add a setting
effortless -removeSetting key      # Remove a setting
effortless -info              # Show configured settings
```

## Managing Transpilers

```bash
effortless -uninstall         # Remove current command from project file
effortless -listVersions      # List available versions of a tool
effortless -upgrade           # Update pinned version to current head
effortless -latest            # Run with current head AND update pinned version
effortless -refreshTools      # Purge and re-fetch the remote tools index
```

## Cleaning

```bash
effortless -clean             # Clean transpilers in and downstream of this folder
effortless -cleanAll          # Clean all project transpilers
effortless -cleanLocal        # Clean only transpilers in the current folder
```

## Seeds (Project Templates)

```bash
effortless -listSeeds         # List available seed repositories
effortless -cloneSeed <name>  # Clone a seed repository
effortless -skipBuild         # Skip the build part of cloning
```

## Tool URL Management

```bash
effortless -listUrls          # List custom tool URLs for this user
effortless -setUrl <name>=<url>    # Set a custom tool endpoint
effortless -removeUrl <name>       # Reset to default URL
effortless -updateUrls        # Check for URL updates
effortless -viewUrl <name>    # View the URL for a specific tool
```

## Other Commands

```bash
effortless -version           # Show CLI version
effortless -subscription      # View account subscription plan
effortless -discuss           # Discuss the project with AI
effortless -checkResults      # Check build results, create SPXML
effortless -createDocs        # Create documentation from SPXML
effortless -buildOnTrigger    # Build on trigger invocation
effortless -copilotConnect    # Connect baseId to SSoTme Copilot Agent
```

## Project File Structure (`effortless.json`)

```json
{
  "Name": "Project Name",
  "Description": "Optional description",
  "ProjectSettings": [
    { "Name": "baseId", "Value": "appXXXXXXXXXXXX" },
    { "Name": "project-name", "Value": "my-project" }
  ],
  "ProjectTranspilers": [
    {
      "Name": "airtabletorulebook",
      "RelativePath": "/effortless-rulebook",
      "CommandLine": "effortless airtable-to-rulebook -o effortless-rulebook.json -account airtable",
      "IsDisabled": false
    }
  ]
}
```

**The `baseId` setting** stores the Airtable base ID for the project. This is shared across all airtable-facing tools and should always be set here so any tool can read it.

---

## See also

- `effortless-install-cli` — for installing or updating the CLI binary itself (clones the repo and registers `effortless` as a global npm package).
- `effortless-pipeline` — for the build pipeline / `ProjectTranspilers` schema this skill references.
- `effortless-setup-postgres` — for the canonical first-run sequence that uses these CLI commands in order.
- `effortless-airtable` — for the airtable-facing API key conventions (`-account airtable`, `~/.ssotme/ssotme.key`).
