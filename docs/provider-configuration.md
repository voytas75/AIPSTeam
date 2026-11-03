# Provider configuration

[Start here](../README.md) · [Usage](usage.md) · [Troubleshooting](troubleshooting.md)

Configure one backend before the first run. `-NOInteraction` controls AIPSTeam questions and menus; it does not guarantee that PSAOAI or provider setup will never prompt or persist settings. All providers still require the three modules listed in the README.

## Azure OpenAI

AzureOpenAI now defaults to `-AzureAPIProtocol Responses`. It sends a direct REST request to `<resource>/openai/v1/responses` with `api-key`, without a dated `api-version`. `AzureEndpoint` accepts the resource root, `/openai/v1/`, or `/openai/v1/responses`; dated deployment paths, queries and userinfo are rejected, not silently rewritten. The deployment name is the request's `model`. `MaxTokens` maps to `max_output_tokens`, including reasoning tokens.

Responses reads the existing `PSAOAI_API_AZURE_OPENAI_ENDPOINT`, `PSAOAI_API_AZURE_OPENAI_KEY`, and `PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT` names, Process → User → Machine. It never prompts for or writes configuration. Windows DPAPI keys created by PSAOAI are decoded in memory; decode failure stops the request. For a temporary key, enter it in your own console with `Read-Host -AsSecureString`, convert only to a Process environment value inside `try`, and restore the old value in `finally`; never paste keys into examples, logs or chat.

`Stream` remains true by default: SSE text deltas are rendered progressively, but only a validated terminal completed response is accepted/logged. Incomplete, failed, refusal, tool-only, malformed, empty and missing-terminal responses fail closed. All assistant `output_text` parts are concatenated in order; reasoning is excluded. Safe usage/status metadata goes to `azure-responses-meta.json`. Transient HTTP 408/429/500/502/503/504 can use the existing outer maximum of five attempts; other Responses failures stop immediately. No automatic Chat fallback is used. Partial streamed text is provisional, not a successful draft.

Responses sends `store=false` and deliberately omits temperature, top_p and reasoning effort because deployment aliases do not prove model support. This is a request setting, not a guarantee of comprehensive data sanitization. `AzureReasoningModel` and `AzureAPIVersion` affect **ChatCompletions only**; they do not alter Responses requests. Existing project-state XML does not persist the protocol: both ordinary and resumed runs use the current invocation's selector (Responses if omitted). Pass `-AzureAPIProtocol ChatCompletions` explicitly to resume using the legacy route.

Official contracts: [Responses guide](https://learn.microsoft.com/azure/foundry/openai/how-to/responses), [REST reference](https://learn.microsoft.com/rest/api/microsoft-foundry/azureopenai/responses), [migration guide](https://learn.microsoft.com/azure/developer/ai/how-to/azure-openai-to-responses). Offline tests do not establish deployment/region/model support or live inference.

### Explicit ChatCompletions compatibility

Use `-AzureAPIProtocol ChatCompletions` for the unchanged PSAOAI caller and its dated endpoint/version, reasoning and existing gpt-5 Developer fallback semantics. Example for an already securely configured backend (not executed):

```powershell
'Draft a RAM summary script.' | ./AIPSTeam.ps1 -AzureAPIProtocol ChatCompletions -NORAG -ReducedWorkflow -NOInteraction -Stream $false
```

Use [PSAOAI's current setup instructions](https://github.com/voytas75/PSAOAI) to configure credentials securely. PSAOAI manages the encrypted `PSAOAI_API_AZURE_OPENAI_KEY`; do not manually assign a plaintext key to that variable or commit credentials.

Non-secret configuration names used by PSAOAI/AIPSTeam:

- `PSAOAI_API_AZURE_OPENAI_ENDPOINT`
- `PSAOAI_API_AZURE_OPENAI_APIVERSION`
- `PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT`
- `PSAOAI_BANNER` (presentation only, not provider configuration)

For session configuration, use `$env:NAME` assignments for non-secret values. User-scoped settings persist for later processes; do not assume changing them updates the current process. AIPSTeam's `Get-EnvValue` checks Process, User, then Machine values. Azure dependency resolution remains owned by PSAOAI.

The current release source accepts `-DeploymentChat`, `-AzureEndpoint` and `-AzureAPIVersion` overrides. Use the endpoint and dated API version your deployment supports, rather than copying an old preview version. Omitted endpoint/version options preserve PSAOAI resolution.

`-AzureReasoningModel` explicitly enables PSAOAI reasoning requests, including its medium reasoning effort. It is optional; deployment-name inference and the existing gpt-5-only Developer fallback policy remain unchanged. Options are forwarded to both primary Azure calls and that fallback. Offline coverage does not establish compatibility with every live dated Azure route.

## Ollama

Install [Ollama](https://ollama.com/), download a suitable model and start the local service. Relevant settings are `OLLAMA_ENDPOINT`, `OLLAMA_HOST` and `OLLAMA_MODEL`. In the local next-release source, a nonblank `OLLAMA_ENDPOINT` takes precedence over nonblank `OLLAMA_HOST`, then `http://localhost:11434/`. Each name retains Process → User → Machine resolution through `Get-EnvValue`; even a User endpoint takes precedence over a Process host. Whitespace-only values are skipped; surrounding whitespace is trimmed and a trailing slash added only after fallback selection. Endpoint resolution does not persist defaults or change environment values. This fix is unpublished; the published 3.10.4 startup has the earlier fallback defect.

```powershell
$env:OLLAMA_ENDPOINT = 'http://localhost:11434/'
$env:OLLAMA_MODEL = 'your-installed-model'
"Draft a script that summarizes RAM usage." | ./AIPSTeam.ps1 `
    -LLMProvider ollama -NORAG -ReducedWorkflow -Stream $false
```

Replace the model name with one installed locally and ensure a model is already running: the current startup path checks for a running model and returns if none is found. It can select that running model rather than the requested environment value. AIPSTeam also has interactive status/model-selection helpers, but setting `OLLAMA_MODEL` alone does not guarantee model startup. For unattended use, configure and verify the service/model first. Fresh startup automatically retains the first running model in both Process `OLLAMA_MODEL` and persistent Windows User `OLLAMA_MODEL`; this existing behavior is deliberately preserved (it is not process-only configuration). Some interactive helpers also use Windows process launching. Recovery keeps the saved provider and resolves the endpoint from current environment settings, but does not discover or initialize an Ollama model under `-LoadProjectStatus -NOInteraction`; that path makes no generation request. Native offline fixtures verify synthetic in-memory model retention, not actual Windows User persistence or live service compatibility; do not assume equivalent WSL/Linux behavior.

The local unreleased Ollama dispatcher forwards positive explicit `MaxTokens` as `options.num_predict`; the adapter also accepts optional `TimeoutSec` for nonstreaming requests. Omitted options retain historical defaults and positional callers remain compatible. The local unreleased script now appends optional validated public `-TimeoutSec` (positive integer). For Ollama only, it supplies an omitted dispatcher timeout; an explicit dispatcher timeout wins. Omission preserves historical transport defaults, other providers remain unchanged, and streaming timeout is not qualified. This flag does not disable outer product retries. The separately owned live gate caps actual completion dispatches at two and latches after failure/empty/truncated response, denying later HTTP even if product retry callers continue. Native 5.1/7 original-filepath synthetic controls verify two `num_predict=512` payloads with explicit `TimeoutSec=120`, and omitted timeout behavior. The approved full live gate stopped after one read-only `/api/ps` returned no running models: zero completion POSTs, no warmup/load. Full real workflow remains unqualified. A native Windows 5.1 original-adapter one-shot used the smallest installed model (`qwen2.5:7b-instruct`, 4,683,087,332 bytes), `num_predict=64`, `stream=false`, HTTP 60 s and supervisor 75 s, with zero redirects/retries. Its single POST timed out after 60.1806145 s (`WebException.Status=Timeout`); HTTP status and usage are unknown. No inference retry or warmup was performed. Native original-setter testing confirmed chosen-model Process/User readback and exact restoration, with the complete User environment hash unchanged afterward; automatic product retention remains intact. See the [owning checkpoint](next-release-plan.md#bounded-adapter-limit-and-live-supplement) for exact hashes, offline gates and limitations. This does not qualify full startup or resumed inference.

## LM Studio

The `LMStudio` adapter retains `OPENAI_API_BASE` and `OPENAI_API_KEY` resolution (Process, User, Machine), default `http://localhost:1234/v1/`, first-model discovery, and its existing chat behavior. It does not persist keys or defaults in User settings. For llama.cpp, use the dedicated provider below instead of sharing LM Studio settings.

## llama.cpp

Select `-LLMProvider 'llama.cpp'`. This distinct adapter reads only Process-scoped `LLAMACPP_ENDPOINT` and `LLAMACPP_API_KEY`; it does not inherit `OPENAI_*` settings or write User configuration. The default OpenAI-compatible base is `http://127.0.0.1:8081/v1/` on Windows. Trailing slashes are normalized. Set the base including `/v1/`, not `/models` or `/chat/completions`. WSL localhost may not reach a Windows listener; configure a reachable address yourself without changing server binding or firewall automatically.

Startup requests `<base>models` with a 30-second timeout, never the base/root route. It selects the first nonblank string model ID. An explicit `-DeploymentChat` selects an exactly advertised model ID; do not use an Azure deployment alias. Empty/malformed catalogues, transport/authentication failures or an unadvertised override stop startup without reporting readiness. Saved llama.cpp states re-run discovery after loading; credentials are not saved in project state.

A nonblank key other than the literal placeholder `***` is sent as Bearer Authorization on discovery and both chat paths. Omit the key for an unauthenticated server; no fake credential is generated. Chat uses `chat/completions`, `max_tokens` from the caller's token budget, and a 240-second timeout. Both ordinary JSON and SSE responses are validated; empty content, incomplete streams, malformed data and HTTP failures fail without a success message. SSE is buffered until the bounded HTTP transfer completes, then parsed (not progressive console rendering). Existing class prompt/response logging remains; credentials and raw transport errors are not logged by this adapter.

Windows example for an already configured authenticated server. Enter the key only in your own console:

```powershell
$oldEndpoint = [Environment]::GetEnvironmentVariable('LLAMACPP_ENDPOINT', 'Process')
$oldKey = [Environment]::GetEnvironmentVariable('LLAMACPP_API_KEY', 'Process')
$secureKey = Read-Host 'llama.cpp API key' -AsSecureString
try {
    [Environment]::SetEnvironmentVariable('LLAMACPP_ENDPOINT', 'http://127.0.0.1:8081/v1/', 'Process')
    [Environment]::SetEnvironmentVariable('LLAMACPP_API_KEY', ([pscredential]::new('local', $secureKey)).GetNetworkCredential().Password, 'Process')
    "Draft a script that summarizes RAM usage." | & ./AIPSTeam.ps1 `
        -LLMProvider 'llama.cpp' -MaxTokens 2048 -NORAG -ReducedWorkflow -NOInteraction -Stream $false
} finally {
    [Environment]::SetEnvironmentVariable('LLAMACPP_API_KEY', $oldKey, 'Process')
    [Environment]::SetEnvironmentVariable('LLAMACPP_ENDPOINT', $oldEndpoint, 'Process')
    $secureKey.Dispose()
    Remove-Variable secureKey, oldKey, oldEndpoint
}
```

For an unauthenticated server, omit hidden-key input and clear only the Process `LLAMACPP_API_KEY` during the run, restoring its prior value in `finally`. PowerShell does not automatically read `.env`. Hidden input avoids command-history disclosure, not process-environment access or managed plaintext copies; close the console afterward. Mandatory modules still apply. Offline fake-HTTP qualification is not live inference acceptance. Earlier handoff-obsolete notices were historical pre-publication gates: [3.10.4 is published on PowerShell Gallery](https://www.powershellgallery.com/packages/AIPSTeam/3.10.4). Publication does not establish fresh live inference or Windows checkout activation.

## OpenAI parameter value

The parser accepts `OpenAI`, but its dispatch branch is unimplemented and throws `-- Unsupported LLM provider: OpenAI. This provider is not implemented yet.` Use one of the implemented providers above; parser acceptance is not provider support.
