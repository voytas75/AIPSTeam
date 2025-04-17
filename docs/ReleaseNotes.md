# AI PowerShell Team with RAG - release notes

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/) and this project adheres to [Semantic Versioning](http://semver.org/).

## [3.10.2] - 2025.04.16 unpublished

- move check for script update to the beginning of the script.
- add EXA web search to RAG (https://exa.ai/). 

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
