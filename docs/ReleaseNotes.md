# AI PowerShell Team with RAG - release notes

Changes in the current release source. [Archived release history](archive/release-history.md) preserves earlier entries.

The format is based on [Keep a Changelog](http://keepachangelog.com/) and this project adheres to [Semantic Versioning](http://semver.org/).

## [3.10.4]

This section describes the 3.10.4 release source; it does not record a Gallery publication date. Script metadata, help and runtime version are 3.10.4. PSAOAI >= 0.7.0 is now required both at startup and by #Requires; older installations are intentionally excluded. External dependency names remain in supported PSScriptInfo metadata; the versioned requirement is declared through #Requires, not invented metadata syntax.

- Add dedicated `llama.cpp` provider with Process-only `LLAMACPP_ENDPOINT`/`LLAMACPP_API_KEY`, authenticated model discovery, ordinary JSON/SSE chat parsing and caller `max_tokens`. This local source change leaves version 3.10.4 unchanged; native Windows and live inference qualification and refreshed publication handoff remain separate gates. The previous handoff is obsolete. No CI wiring was changed for the new suite.
- Export only the bounded `2. PowerShell Code` section of structured Developer replies, retaining all its PowerShell blocks and excluding `3. Usage Example`. A single unsectioned PowerShell block remains supported; ambiguous, unknown-sectioned or unparseable replies retain the prior draft/version. Exact captured-response replay is offline qualification, not a new live inference; previous publication handoffs remain obsolete.
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
