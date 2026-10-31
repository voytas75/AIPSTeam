# Usage and parameters

[Start here](../README.md) · [Provider setup](provider-configuration.md)

Examples below use a checkout, installed mandatory modules and an already configured backend. They do not imply a provider-free run.

## Workflow choices

The full workflow simulates specialists handling requirements, implementation, review and documentation. Output varies with the model and prompt. `-ReducedWorkflow` retains Manager → Developer and final PSScriptAnalyzer analysis, skipping intermediate review, analysis, documentation and report stages. It is useful for a smaller first pass, not for demonstrating every deliverable.

```powershell
"Monitor RAM usage and show a color block based on load." | ./AIPSTeam.ps1 -NORAG -Stream $false
# Equivalent direct input:
./AIPSTeam.ps1 -userInput "Monitor RAM usage and show a color block based on load." -NORAG -Stream $false
```

For a full-workflow output illustration, see the [curated first-run example](first-run-example.md).

## Existing scripts

```powershell
./AIPSTeam.ps1 -TheCodePath 'C:\UserScripts\script.ps1' -NORAG -Stream $false
```

Use an absolute path. This mode loads script contents for analysis, enhancement or debugging; those contents may be sent to your provider. It does not execute the generated draft.

## Parameter reference

| Parameter | Meaning |
| --- | --- |
| `userInput` | Project outline; string or pipeline input. |
| `TheCodePath` | Absolute path to an existing PowerShell script. |
| `LLMProvider` | `AzureOpenAI` (default), `ollama`, `LMStudio`, or parser-accepted `OpenAI`; see provider guide. |
| `Stream` | Boolean; `$true` by default. Use `-Stream $false` for non-streaming output. |
| `NORAG` | Disable web retrieval, not LLM calls. |
| `ReducedWorkflow` | Smaller Manager/Developer workflow; final static analysis remains. |
| `NOInteraction` | Disable AIPSTeam questions/menus; does not make dependency configuration fail-closed. |
| `NOPM` | Disable Project Manager functions. |
| `NODocumentator` | Disable Documentator functions. |
| `NOLog` | Disable logging functions; do not treat this as comprehensive data sanitization. |
| `LogFolder` | Custom log/output root. |
| `DeploymentChat` | Azure deployment override; otherwise resolved from `PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT`. |
| `AzureAPIProtocol` | Azure-only: `Responses` (default v1 REST/SSE) or explicit `ChatCompletions` (PSAOAI legacy). Local providers unchanged. Not persisted in project state; repeat the compatibility selector on resume. |
| `MaxTokens` | Response token limit; default `20480`. Responses uses `max_output_tokens`, covering visible and reasoning tokens. The first-run example uses `2048`; too small a limit can truncate code. |
| `NOTips` | Disable tips. |
| `VerbosePrompt` | Show prompts; may expose sensitive content. |
| `LoadProjectStatus` | Load saved state; belongs to the `LoadStatus` parameter set. |
| `NOUserInputCheck` | Disable input checking. |
| `AzureReasoningModel` | explicit PSAOAI Azure reasoning mode. |
| `AzureEndpoint` | optional Azure endpoint override. |
| `AzureAPIVersion` | optional dated Azure API version override. |

## Output and saved projects

The default root is the AIPSTeam directory under `MyDocuments`, falling back to home or the current directory when necessary. Each run uses a timestamped directory. Generated code is written as `TheCode_v*.ps1`; logs contain team/provider activity. Set `-LogFolder` when you need a predictable root.

```powershell
"Generate a daily system health report." | ./AIPSTeam.ps1 `
    -NOInteraction -NORAG -ReducedWorkflow -Stream $false -LogFolder 'C:\AIPSTeamRuns'
./AIPSTeam.ps1 -LoadProjectStatus 'C:\AIPSTeamRuns\saved-run\Project.xml'
```

Resume only from a state file you trust. Save callers check the boolean save result before announcing success. Saves are non-atomic and provide no data-loss guarantee: keep independent backups. Legacy states missing `LLMProvider` or `ReducedWorkflow` receive `AzureOpenAI` or `$false` defaults while retaining existing fields.

`DraftOutcome=Complete` means extracted code is nonempty and parseable. Empty, missing or unparseable extraction sets `Incomplete`, retains prior code/version and ends unsuccessfully. Final analysis sets `ValidationOutcome=Clean`, `Findings` or `Failed`. Analysis failure retains the draft and ends unsuccessfully; findings do not establish clean analysis. None of these states proves the generated script works or is safe to execute.
