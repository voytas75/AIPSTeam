# AI PowerShell Team with RAG - release notes

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/) and this project adheres to [Semantic Versioning](http://semver.org/).

## [3.10.4] - UNPUBLISHED candidate

This is the 3.10.4 stabilization release candidate, not a published release. Script metadata, help and runtime version are 3.10.4. PSAOAI >= 0.7.0 is now required both at startup and by #Requires; older installations are intentionally excluded. External dependency names remain in supported PSScriptInfo metadata; the versioned requirement is declared through #Requires, not invented metadata syntax.

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
- Historical native PowerShell 7 live canonical acceptance used two calls and real final analysis on earlier implementation bytes, not this final metadata/help candidate. Windows 5.1 is offline-qualified only. Culture/process banner and temporary-module lifecycle residues remain; private raw diagnostics may echo provider content. Beta, provider/RAG/streaming/full-workflow and generated-code limits remain.

## [3.10.3] - 2026.03.26

- improve WSL/Linux and Azure OpenAI compatibility, including safer environment-variable resolution and cross-platform log path handling.
- add developer-stage mitigation and debug artifacts for Azure/PSAOAI empty-response investigation.
- add `ReducedWorkflow` mode to keep the flow on Manager + Developer when heavier later stages are not reliable.
- improve the practical first-run path so the reduced workflow can complete and export generated PowerShell code artifacts.
- docs update.

## [3.10.2] - 2025.04.20 unpublished

- move check for script update to the beginning of the script.
- add EXA web search to RAG (https://exa.ai/). 
- minor fixes.
- added retry logic for web requests.
- serper API integration (https://serper.dev/).
- docs update.
- updated verbose logging to use a wrapper function for better message handling and truncation.
- changes to class `ProjectTeam`.

## [3.10.1] - 2025.04.16

- minor fixes.
- improved user input handling logic.
- remove unused logic.
- fix web search logic (retirement of Bing Search API - https://azure.microsoft.com/en-us/updates?id=483570, implementation of SERPAPI - https://serpapi.com/).
- adjusted temperature and top_p for agents.
- documentation output file changed to markdown (Documentation.md).

## [3.9.1] - 2024.07.29

- Implemented logic to return to the root menu ([#10](https://github.com/voytas75/AIPSTeam/issues/10)).
- Add non-interactive session ([#21](https://github.com/voytas75/AIPSTeam/issues/21)).
- Add feature to work on user's code instead of description of project ([#12](https://github.com/voytas75/AIPSTeam/issues/12)).
- Minor fixes and code formatting improvements.

## [3.8.1] - 2024.07.28

- Improved user prompts for input.
- Add parameter `NOUserInputCheck`.
- Documentation file info ([#11](https://github.com/voytas75/AIPSTeam/issues/11)).

## [3.7.1] - 2024.07.27

- Minor fixes and code formatting improvements.
- Added information message.
- Improve cleaning function.
- Fix passing of maxtokens value.
- Added new function `Test-NeedForMoreInfo` to assess if additional information is required for processing.
- Removed excess `[System.]` references. (thx <https://github.com/NathanWindisch>)
- Removed excess parameters in Mandatory flag. (thx <https://github.com/NathanWindisch>)
- Logo change.

## [3.6.1] - 2024.07.25

- Optimized queries and prompts for better performance.
- Added information message after cleaning RAG data.
- Included verbose messages for better debugging.
- Implemented logic for handling missing environment variables in Bing Web Search.
- Minor fixes and code formatting improvements.
- Deleted old unused functions to clean up the codebase.

## [3.5.2] - 2024.07.20

- add secret agent to clean RAG data.
- fixed load project logic ([#9](https://github.com/voytas75/AIPSTeam/issues/9)).
- minor fixes.

## [3.5.1] - 2024.07.15

- improved response prompt.
- minor fixes.

## [3.4.3] - 2024.07.15

- issue #7.
- minor fixes.

## [3.4.2] - 2024.07.14

- minor changes and bug fixes, fix userInput value from pipeline (issue #4), add lm studio support (issue #5).

## [3.3.2] - 2024.07.13

- minor changes and fixes, add streaming http response to ollama.

## [3.2.1]

- minor changes and fixes, issue #2 - add env for ollama endpoint.

## [3.1.1]

- moved PM exec, Test-ModuleMinVersion, add iconuri, minor fixes, optimize ollama manager logic, code cleanup.

## [3.0.3]

- Corrected log entry method usage.

## [3.0.2]

- check module version of PSAOAI, ollama checks, ollama auto manager.

## [3.0.1]

- implement RAG based on Bing Web search API, add new method to class, extend globalstate for all params.

## [2.1.2]

- minor fixes.

## [2.1.1]

- move to new repository, new projecturi, LoadProjectStatus searching for xml file if no fullName path, fix Documentation bug.

## [2.0.1]

- add abstract layer for LLM providers, fix update of lastPSDevCode, ann NOTips, Updated error handling, Added VerbosePrompt switch.

## [1.6.2]

- fix double feedback display.

## [1.6.1]

- fix stream in feedback.

## [1.6.0]

- minor fixes, enhanced error reporting, added error handling, new menu options, and refactored functions.

## [1.5.0]

- minor fixes, modularize PSScriptAnalyzer logic, load, save project status, State Management Object, refactoring.

## [1.4.0]

- modularize feedback.

## [1.3.0]

- add to menu Generate documentation, The code research, Requirement for PSAOAI version >= 0.2.1 , fix CyclomaticComplexity.

## [1.2.1]

- fix EXTERNALMODULEDEPENDENCIES.

## [1.2.0]

- add user interaction and use PSScriptAnalyzer.

## [1.1.0]

- default value for DeploymentChat.

## [1.0.7]

- Added 'DeploymentChat' parameter.

## [1.0.6]

- Updated function calls to Add-ToGlobalResponses $GlobalState.

## [1.0.5]

- code export fix.

## [1.0.3]

- fix requirements.

## [1.0.2]

- publishing, check version fix, dependience.

## [0.0.1]

- Initializing.
