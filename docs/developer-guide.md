# Developer and release guide

[User guide](../README.md) · [Release notes](ReleaseNotes.md) · [Release packaging](release-packaging.md)

## Implementation map

- `AIPSTeam.ps1`: script metadata, parameters, startup, team workflow and state handling.
- `ProjectTeam` class: team member roles, response memory, logging and sequential processing; methods include `ProcessInput`, `AddLogEntry`, `Notify` and `SummarizeMemory`.
- `SendFeedbackRequest`: review feedback requests.
- `Export-AndWritePowerShellCodeBlocks`: extraction/export of draft PowerShell blocks.
- `Invoke-CodeWithPSScriptAnalyzer`: static analysis, not generated-script execution.
- `tools/tests/`: parser, core contracts, startup, draft/validation, legacy Azure and harness checks.
- `tools/diagnostics/`: focused developer prompt isolation/comparison tools. Treat raw output as private until sanitized.
- `.github/workflows/ci.yml`: CI entrypoint and dependency source guards.

## Provider-free checks

Inspect each script's parameters before running it. The release entrypoint is `tools/tests/Invoke-ReleaseCI.ps1`; it coordinates the offline checks. External PSAOAI source in CI is pinned with commit and normalized-file hash guards, without installing or bootstrapping provider modules. Do not remove those guards merely to make a test run.

The 3.10.4 candidate's earlier offline qualification covered Windows PowerShell 5.1 and native PowerShell 7 parser checks, core contracts (37 cases), startup (8), draft/validation (7) and legacy Azure integration (13). These are revision-bound prior results, not a fresh test run performed by the documentation rewrite. Refer to the exact revision's CI before making current release-readiness claims.

## Qualification boundaries

Offline function/section tests do not qualify full production startup, every provider, RAG, streaming, full multi-review workflows or generated-code execution. No fresh full analyzer qualification is implied.

A historical native PowerShell 7 canonical live run used real modules and two provider calls with clean final analysis. It covered earlier implementation bytes, not the later metadata/help-updated candidate. Windows PowerShell 5.1 acceptance was offline only. Keep historical live and candidate offline evidence separate.

Synthetic complete Process configuration was checked with the active PSAOAI resolvers; missing configuration may still prompt/persist in PSAOAI. Banner suppression is process-only, not persisted to User configuration. Culture/process banner residues and temporary dynamic-module lifecycle were not redesigned.

Draft and validation outcomes describe extraction and static analysis, not production readiness. State-save callers check success, but writes remain non-atomic. See [usage](usage.md) for user-visible recovery semantics.

## Release ownership

The checkout contains 3.10.4 as an unpublished candidate; Gallery installation and repository delivery are separate. Publication is a manual maintainer action. Do not record “published” merely because offline checks or CI pass, and do not publish private evidence or local planning files.
