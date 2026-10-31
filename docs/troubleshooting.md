# Troubleshooting

[Start here](../README.md) · [Provider setup](provider-configuration.md) · [Usage and recovery](usage.md)

## Script or module not found

Install all three required modules in the PowerShell edition you will use. PSAOAI must be at least 0.7.0. `-NORAG` and `-ReducedWorkflow` do not bypass `#Requires`. Use `Get-InstalledScript -Name AIPSTeam` to find a Gallery installation; for a checkout, run `./AIPSTeam.ps1` from its directory.

Do not start with administrator privileges as a generic fix. Install with `-Scope CurrentUser`; review your organization's execution policy and permissions if execution is blocked.

## Missing configuration or unexpected prompts

Choose one backend and verify it first. Azure credentials are managed by PSAOAI; the endpoint, deployment and API version must match your deployment. Ollama needs a running service and available model; LM Studio needs a loaded model and running server.

`-NOInteraction` suppresses AIPSTeam prompts and menus, not every dependency/provider setup prompt. Missing input is rejected before AIPSTeam asks for it unless an existing script or saved state supplies it. Use `-NORAG` to avoid first-run search configuration.

## Incomplete code or analyzer failure

Check `DraftOutcome` and `ValidationOutcome`, the generated files and logs. Increase `-MaxTokens` if a response was truncated, and ask the model for a complete fenced PowerShell code block. Do not treat `Complete` or `Clean` as functional correctness. Analyzer failure leaves the draft available for inspection; retain backups before retrying or resuming saved state.

## Too much output

Use `-Stream $false` and, after configuration, `-NOInteraction`. `-ReducedWorkflow` skips intermediate stages; it is not a full documentation/review run. `-NOTips` hides tips. Avoid `-VerbosePrompt` when sharing console output.

## Logs and bug reports

Logs live under the chosen `-LogFolder` or the default root described in [usage](usage.md). Raw diagnostics may echo provider content. Masking is not comprehensive sanitization: redact credentials, endpoints, personal data, prompts and private code before sharing. Report the script version, PowerShell edition, provider, flags and minimal reproducible error; do not upload entire raw run directories.

## WSL/Linux or mixed runtimes

Windows is the recommended starting point. Native PowerShell 7 offline checks do not prove all Linux startup/provider paths. Ollama helpers include Windows launching and User-scoped persistence. Check module availability and provider configuration in the actual shell before attributing a failure to model output or changing system configuration.
