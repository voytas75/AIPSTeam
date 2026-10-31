# AI PowerShell Team (AIPSTeam)

AIPSTeam helps PowerShell builders and automation engineers turn a project description or existing script into a draft. It simulates a team that can propose requirements, code, documentation and review feedback using Azure OpenAI, Ollama or LM Studio.

**Beta:** generated code requires human review and testing. AIPSTeam does not execute the generated script. Model quality and context size affect the result. Prompts, script contents and retrieved context may be sent to your selected providers; do not include secrets or sensitive data without authorization.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7; Windows is the recommended starting environment.
- `PSAOAI` >= 0.7.0, `PSScriptAnalyzer` and `PowerHTML`. All three modules are required, even when RAG or the full workflow is disabled.
- One working LLM backend. Configure it before running AIPSTeam; see [provider setup](docs/provider-configuration.md).

## Install

```powershell
Install-Module -Name PSAOAI -MinimumVersion 0.7.0 -Scope CurrentUser
Install-Module -Name PSScriptAnalyzer -Scope CurrentUser
Install-Module -Name PowerHTML -Scope CurrentUser
Install-Script -Name AIPSTeam -Scope CurrentUser
```

The Gallery release is currently **3.10.3**; this checkout contains the **3.10.4 candidate, not yet published**. `Install-Script` installs the published release, not this candidate. To use the candidate, download or clone this checkout and run `./AIPSTeam.ps1` from its directory after installing the modules above.

If the installed script is not on `PATH`, locate it with `Get-InstalledScript -Name AIPSTeam` and run the file from its `InstalledLocation`.

## First run: a small code draft

Configure Azure credentials securely through [PSAOAI](https://github.com/voytas75/PSAOAI). Replace the deployment, endpoint and dated API version below with values supported by your Azure deployment. Do not put an API key in the command.

Run this from the checkout directory (for the published script, use its installed path instead):

```powershell
$prompt = "Create a PowerShell tool that checks local administrator membership and exports results to CSV."
$prompt | ./AIPSTeam.ps1 -LLMProvider AzureOpenAI `
    -DeploymentChat 'your-deployment-name' `
    -AzureEndpoint 'https://your-resource.openai.azure.com' `
    -AzureAPIVersion 'YYYY-MM-DD' `
    -MaxTokens 2048 -NORAG -ReducedWorkflow -NOInteraction -Stream $false
```

This candidate example uses explicit Azure options introduced in 3.10.4. For Gallery 3.10.3, configure the endpoint/API version through PSAOAI and omit `-AzureEndpoint` and `-AzureAPIVersion`.

`-ReducedWorkflow` runs Manager → Developer and final PSScriptAnalyzer analysis; it skips intermediate reviews, documentation and reports. Remove it when you want the fuller team workflow. `-NORAG` disables web retrieval, not model calls. Add `-AzureReasoningModel` only if your Azure model needs PSAOAI reasoning-mode handling.

`-NOInteraction` disables AIPSTeam questions and menus, but missing provider configuration can still trigger dependency setup prompts. Configure and test the backend first. For Ollama or LM Studio, use the [backend-specific setup](docs/provider-configuration.md), not just a different provider name.

## Results and recovery

Look for console messages and a timestamped run directory containing generated `TheCode_v*.ps1` files and logs. The default root is `MyDocuments/AIPSTeam` (home/current-directory fallback); choose your own with `-LogFolder`.

- `DraftOutcome=Complete` means nonempty, parseable code was extracted, not that it is correct. `Incomplete` retains prior code/version and ends unsuccessfully.
- `ValidationOutcome=Clean`, `Findings` or `Failed` reports final static analysis. Findings require review; failure retains the draft and ends unsuccessfully. A clean result does not prove runtime safety.
- Resume a saved `Project.xml` using `-LoadProjectStatus`. Saves are not atomic: keep independent backups. See [usage and recovery](docs/usage.md).

Review the generated script, permissions and assumptions before testing it in a safe environment. Logs can contain prompts and provider responses; redact them before sharing.

## Documentation

- [Provider configuration](docs/provider-configuration.md): Azure, Ollama and LM Studio setup.
- [Usage and parameters](docs/usage.md): existing scripts, full workflow, logs and saved projects.
- [RAG setup](docs/rag.md): optional web search and data handling.
- [Troubleshooting](docs/troubleshooting.md): installation, provider and output issues.
- [Representative first-run example](docs/first-run-example.md): curated full-workflow output, not a captured run.
- [Developer and release guide](docs/developer-guide.md): implementation map and qualification limits.
- [Release notes](docs/ReleaseNotes.md) · [License](LICENSE)
