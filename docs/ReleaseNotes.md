# AI PowerShell Team with RAG - release notes

> **Unreleased next-version work:** this GitHub source includes offline-qualified backlog delivered to the repository, not a PowerShell Gallery release. Script version remains **3.10.4**; the next version is not selected. Current bytes are not freshly live-qualified.

Changes in the current release source. [Archived release history](archive/release-history.md) preserves earlier entries.

The format is based on [Keep a Changelog](http://keepachangelog.com/) and this project adheres to [Semantic Versioning](http://semver.org/).

## Unreleased — next stabilization release (version provisional)

- Accept paired Markdown emphasis (`**`, `__`, `*`, `_`) around numbered PowerShell Code/Usage Example titles, case-insensitively, without changing prompts or section/fence admission. Native Windows 5.1/7 captured-response offline replay and 20-case export matrices pass; original-filepath reduced workflow with installed analyzer persists Complete/Clean. No fresh inference. Earlier live source binding is superseded by source SHA256 `E325D1EB5A373F0E00DA3DF25AD1C926CF688549FF2ADFE92F4A752FB2B481C5`; the historical live failure remains a failure. Incomplete-state recovery retains its original exception/outcome, not retroactive completion.

- Append optional validated public Ollama `TimeoutSec`, conditionally inherited only when dispatcher timeout is omitted. Preserve omitted defaults, positional API, other providers and model persistence. Native 5.1/7 original-filepath RED rejects explicit timeout before repair; GREEN explicit 512-token/120-second and omitted-timeout controls all pass. Final source SHA256 `A3E385EB9E3E6A38580490428E9081525AB1CCCCB35D2D25FF32CA0521ACC1CE`.
- Guarded unchanged installed PSAOAI/PowerHTML/PSScriptAnalyzer imports and real analyzer known-draft execution pass on both native runtimes. Approved full live gate is BLOCKED: bounded read-only `/api/ps` returned no running models. Zero completion POSTs, no warmup/load; live workflow/artifact/recovery remain untested. See the owning tracker for evidence and remaining runner qualification.

- Fix Ollama endpoint selection: nonblank `OLLAMA_ENDPOINT` → `OLLAMA_HOST` → `http://localhost:11434/`, retaining existing Process/User/Machine resolution per name. Trim and normalize the trailing slash after selection; remove endpoint default environment writes.
- Focused source-bound offline tests cover fallback, precedence, scopes and whitespace on Linux PowerShell 7 and native Windows 5.1/7. This is not full Ollama startup/model/inference acceptance; other existing model helpers can still persist settings. Version literals remain 3.10.4; final next version is not selected.

- Forward optional positive Ollama output limits to `options.num_predict` and explicit nonstreaming `TimeoutSec`, preserving omitted defaults, positional API, other providers and automatic model retention. Native 5.1/7 bounds contracts pass 6/6 each; final relevant regressions pass. Source SHA256 `68BA2FEBB5183D9E0BD19AEC0DF1C4FF11428473711DF8E8F048FCEBC8A8BC46`.
- Single native 5.1 original-adapter live smoke on smallest installed `qwen2.5:7b-instruct` (4,683,087,332 bytes), `num_predict=64`, `stream=false`, HTTP 60 s/supervisor 75 s, zero retry/redirect: timeout after 60.1806145 s; HTTP status/usage unknown. No warmup/download or repeat. Exact native Process/User model-setter readback and finally-restoration pass, full User hash preserved. This is not full Ollama workflow or successful live inference qualification; see [checkpoint](next-release-plan.md#bounded-adapter-limit-and-live-supplement).

## [3.10.4]

[3.10.4 is published on PowerShell Gallery](https://www.powershellgallery.com/packages/AIPSTeam/3.10.4); this section describes its release source without asserting a publication date. Script metadata, help and runtime version are 3.10.4. PSAOAI >= 0.7.0 is now required both at startup and by #Requires; older installations are intentionally excluded. External dependency names remain in supported PSScriptInfo metadata; the versioned requirement is declared through #Requires, not invented metadata syntax.

- Add dedicated `llama.cpp` provider with Process-only `LLAMACPP_ENDPOINT`/`LLAMACPP_API_KEY`, authenticated model discovery, ordinary JSON/SSE chat parsing and caller `max_tokens`. This change left version 3.10.4 unchanged. Earlier handoff-refresh requirements were historical pre-publication gates; publication does not establish fresh native Windows or live inference qualification. No CI wiring was changed for the new suite.
- Export only the bounded `2. PowerShell Code` section of structured Developer replies, retaining all its PowerShell blocks and excluding `3. Usage Example`. A single unsectioned PowerShell block remains supported; ambiguous, unknown-sectioned or unparseable replies retain the prior draft/version. Exact captured-response replay is offline qualification, not a new live inference; earlier handoff-obsolete notices describe historical pre-publication gates.
- Add UTF-8 BOM for native Windows PowerShell 5.1 parsing compatibility.
- Remove unsupported diagnostic JSON parsing options on Windows PowerShell 5.1.
- Reject whitespace-only Developer responses at the terminal response guard.
- Normalize legacy project states missing `LLMProvider` or `ReducedWorkflow` to `AzureOpenAI` or `$false` while preserving existing fields.
- Return an explicit save result and check it in both menu callers and final save before reporting success. This does not provide atomic saves or a data-loss protection guarantee.
- Clarify that `ReducedWorkflow` skips intermediate review/analysis/documentation/report stages but retains final PSScriptAnalyzer analysis; PSAOAI, PSScriptAnalyzer and PowerHTML remain globally mandatory.
- Extend provider-free native function/section contracts to cover save callers. Parser and contract checks do not qualify full startup, all providers, RAG, streaming, generated scripts or fresh full analyzer results. Beta output remains a draft requiring human review.

- Add optional AzureReasoningModel, AzureEndpoint and AzureAPIVersion caller overrides, forwarded equally to primary and existing fallback calls without changing omitted-option resolution or fallback policy.
- Remove User banner persistence; retain process suppression. Offline synthetic configuration/body tests are not live dated Azure API qualification or missing-config fail-closed guarantees.
- Reject missing NOInteraction input before prompting unless supplied by code/state. Track Complete/Incomplete draft and Clean/Findings/Failed validation outcomes, retain prior code on incomplete extraction, and fail terminally on incomplete draft or analyzer failure after attempted recovery save.
- Wire all four offline suites (37 core, 8 startup, 7 draft/validation, 13 legacy Azure) on native Windows 5.1 and 7 with required reports and always-upload receipts. PSAOAI source is separately checked out at an immutable commit and hash-guarded without module bootstrap or fixture vendoring; [remote CI run 41229909283](https://github.com/voytas75/AIPSTeam/actions/runs/41229909283) succeeded on commit `d88f1f5d632cc9246551f111880ff7843a77e579` in both native Windows PowerShell 5.1 and PowerShell 7 jobs (whole-source parsing and the four provider-free suites; no installation, live provider calls or publication).
- Historical native PowerShell 7 live canonical acceptance used two calls and real final analysis on earlier implementation bytes, not the current release source. Windows 5.1 is offline-qualified only. Culture/process banner and temporary-module lifecycle residues remain; private raw diagnostics may echo provider content. Beta, provider/RAG/streaming/full-workflow and generated-code limits remain.
