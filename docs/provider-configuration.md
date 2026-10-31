# Provider configuration

[Start here](../README.md) · [Usage](usage.md) · [Troubleshooting](troubleshooting.md)

Configure one backend before the first run. `-NOInteraction` controls AIPSTeam questions and menus; it does not guarantee that PSAOAI or provider setup will never prompt or persist settings. All providers still require the three modules listed in the README.

## Azure OpenAI

Use [PSAOAI's current setup instructions](https://github.com/voytas75/PSAOAI) to configure credentials securely. PSAOAI manages the encrypted `PSAOAI_API_AZURE_OPENAI_KEY`; do not manually assign a plaintext key to that variable or commit credentials.

Non-secret configuration names used by PSAOAI/AIPSTeam:

- `PSAOAI_API_AZURE_OPENAI_ENDPOINT`
- `PSAOAI_API_AZURE_OPENAI_APIVERSION`
- `PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT`
- `PSAOAI_BANNER` (presentation only, not provider configuration)

For session configuration, use `$env:NAME` assignments for non-secret values. User-scoped settings persist for later processes; do not assume changing them updates the current process. AIPSTeam's `Get-EnvValue` checks Process, User, then Machine values. Azure dependency resolution remains owned by PSAOAI.

The 3.10.4 candidate accepts `-DeploymentChat`, `-AzureEndpoint` and `-AzureAPIVersion` overrides. Use the endpoint and dated API version your deployment supports, rather than copying an old preview version. Omitted endpoint/version options preserve PSAOAI resolution. These options are not available in the published 3.10.3 script.

`-AzureReasoningModel` explicitly enables PSAOAI reasoning requests, including its medium reasoning effort. It is optional; deployment-name inference and the existing gpt-5-only Developer fallback policy remain unchanged. Options are forwarded to both primary Azure calls and that fallback. Offline coverage does not establish compatibility with every live dated Azure route.

## Ollama

Install [Ollama](https://ollama.com/), download a suitable model and start the local service. Relevant settings are `OLLAMA_ENDPOINT` and `OLLAMA_MODEL`; the default endpoint is `http://localhost:11434/`.

```powershell
$env:OLLAMA_ENDPOINT = 'http://localhost:11434/'
$env:OLLAMA_MODEL = 'your-installed-model'
"Draft a script that summarizes RAM usage." | ./AIPSTeam.ps1 `
    -LLMProvider ollama -NORAG -ReducedWorkflow -Stream $false
```

Replace the model name with one installed locally and ensure a model is already running: the current startup path checks for a running model and returns if none is found. It can select that running model rather than the requested environment value. AIPSTeam also has interactive status/model-selection helpers, but setting `OLLAMA_MODEL` alone does not guarantee model startup. For unattended use, configure and verify the service/model first. Some startup helpers use Windows process launching and User-scoped persistence; do not assume equivalent WSL/Linux behavior.

## LM Studio

Install [LM Studio](https://lmstudio.ai/), load a model and start its OpenAI-compatible server. AIPSTeam reads `OPENAI_API_BASE` and `OPENAI_API_KEY`.

For a local server without authentication, this example uses a dummy key, not a secret:

```powershell
$env:OPENAI_API_BASE = 'http://localhost:1234/v1'
$env:OPENAI_API_KEY = 'lm-studio'
"Draft a script that summarizes RAM usage." | ./AIPSTeam.ps1 `
    -LLMProvider LMStudio -NORAG -ReducedWorkflow -Stream $false
```

Use your actual server address. If authentication is enabled, follow the server's secure credential setup rather than placing real credentials in shared examples.

## OpenAI parameter value

The parser also accepts `OpenAI`. The onboarding paths here cover Azure OpenAI, Ollama and LM Studio; accepting a parameter value is not evidence of fully qualified provider behavior. Consult the implementation and PSAOAI documentation before relying on this additional route.
