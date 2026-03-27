# AI PowerShell Team with RAG

[![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/AIPSTeam)](https://www.powershellgallery.com/packages/AIPSTeam)
[![PowerShell Gallery Downloads](https://img.shields.io/powershellgallery/dt/AIPSTeam)](https://www.powershellgallery.com/packages/AIPSTeam)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/86de45135d5e4b3da515e5c7d56bc365)](https://app.codacy.com/gh/voytas75/AIPSTeam/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![Status: Beta](https://img.shields.io/badge/status-beta-orange.svg)](#known-limitations)

![AIPSTeam](https://github.com/voytas75/AIPSTeam/blob/master/images/AIPSTeam.png?raw=true "aipsteam")

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/A0A6KYBUS)

AIPSTeam is a PowerShell-first AI collaboration script that simulates a small delivery team around your project idea or existing script. Instead of giving you one raw answer, it helps produce a more structured first draft: requirements framing, implementation guidance, PowerShell output, documentation, and review-style feedback. It works with Azure OpenAI, Ollama, or LM Studio and is best approached through one clear first-run path before exploring the wider feature set.

## Table of Contents

- [Who this is for](#who-this-is-for)
- [Why use AIPSTeam](#why-use-aipsteam)
- [5-minute quickstart](#5-minute-quickstart)
- [What you get](#what-you-get)
- [Example first-run output](#example-first-run-output)
- [Representative example artifact](#representative-example-artifact)
- [Recommended parameters](#recommended-parameters)
- [Supported environment](#supported-environment)
- [Known limitations](#known-limitations)
- [Advanced parameters](#advanced-parameters)
- [Overview](#overview)
- [Retrieval-Augmented Generation (RAG)](#retrieval-augmented-generation-rag)
- [Installation notes](#installation-notes)
- [Additional usage examples](#additional-usage-examples)
- [Developer notes](#developer-notes)
- [Dependencies and prerequisites](#dependencies-and-prerequisites)
- [Troubleshooting](#troubleshooting)
- [FAQ](#faq)

## Who this is for

AIPSTeam is for:
- PowerShell builders who want more than a single one-shot prompt
- sysadmins and automation engineers who want AI-assisted project drafting
- people who want code, documentation, and review-style output in one workflow

AIPSTeam is **not** the best fit for:
- tiny one-line scripts
- users who do not have any LLM backend configured
- cases where fully production-ready output is expected from the first run without review

## Why use AIPSTeam

- **Multi-role workflow**: instead of one generic answer, the script simulates a team of specialists
- **PowerShell-first output**: focused on PowerShell project work rather than generic coding chatter
- **Documentation and review included**: useful when you want a first structured draft, not just raw code
- **Flexible backend choice**: Azure OpenAI, Ollama, or LM Studio
- **Better first-pass thinking**: useful when you want something closer to a draft delivery workflow than a single prompt completion

## 5-minute quickstart

### 1) Install required modules

```powershell
Install-Module -Name PSAOAI
Install-Module -Name PSScriptAnalyzer
Install-Module -Name powerHTML
```

### 2) Install the script

```powershell
Install-Script AIPSTeam
```

### 3) Configure one LLM backend

For the smoothest first run, use the backend you already have working.

Supported providers:
- [Azure OpenAI](https://azure.microsoft.com/en-us/services/cognitive-services/openai-service/)
- [LM Studio](https://lmstudio.ai/)
- [Ollama](https://ollama.com/)

PSAOAI module repo:
- [PSAOAI](https://github.com/voytas75/PSAOAI)

> [!IMPORTANT]
> You need Azure OpenAI, Ollama, or LM Studio to use this script.

### 4) Run the recommended first demo

This is the canonical first-run path for understanding what AIPSTeam does.
It keeps the workflow non-interactive and disables RAG so you do not need search-provider setup for the first pass.

```powershell
$prompt = @"
Create a PowerShell tool that checks local administrator membership,
exports results to CSV, and generates basic documentation.
"@

$prompt | AIPSTeam.ps1 -LLMProvider "AzureOpenAI" -NOInteraction -NORAG -Stream $false
```

If you want the most completion-friendly path on heavier models, use the reduced workflow mode:

```powershell
$prompt | AIPSTeam.ps1 -LLMProvider "AzureOpenAI" -NOInteraction -NORAG -ReducedWorkflow -Stream $false
```

If you are using another backend, switch only the provider value:
- `-LLMProvider "ollama"`
- `-LLMProvider "LMStudio"`

## What you get

After a successful first run, you should expect output such as:
- a clarified project goal or requirements summary
- implementation ideas or proposed PowerShell structure
- generated PowerShell code or code fragments
- documentation draft content
- review-style or QA-style feedback

The exact result depends on the model quality, available context window, and the prompt you provide.

> [!IMPORTANT]
> The quality of the generated project depends significantly on the model used and the context window available. Better models and better context generally produce better drafts.

## Example first-run output

A realistic first run will not usually give you a polished production-ready module. What it should give you is a strong working draft, for example:

```text
Requirements summary
- Check local administrator membership
- Export results to CSV
- Produce basic usage documentation

Proposed implementation
- Collect local group membership
- Normalize account names and types
- Export results with timestamp
- Add basic error handling and documentation

Draft deliverables
- PowerShell code skeleton
- suggested function layout
- documentation outline
- reviewer notes / next improvements
```

That is the value of AIPSTeam: a more structured project draft than a single one-shot reply.

## Representative example artifact

For a fuller walkthrough, see:
- [`docs/first-run-example.md`](docs/first-run-example.md)

That file shows a representative first-run scenario, the command used, the shape of the output, and what still needs human review.

## Recommended parameters

These are the most useful parameters for a realistic first run:

- `userInput` — project outline as a string; can also be piped
- `-NOInteraction` — run without prompts or menus during the session
- `-ReducedWorkflow` — run a smaller Manager + Developer flow that skips the heavier later stages
- `-LLMProvider` — choose the backend: `AzureOpenAI`, `ollama`, or `LMStudio`
- `-NORAG` — disable retrieval for a simpler first run
- `-Stream $false` — disable streaming for a cleaner, easier-to-review result
- `-TheCodePath` — work directly on an existing PowerShell script

## Supported environment

**Best-supported path**
- Windows PowerShell / PowerShell-focused workflow
- one configured LLM backend only for the first run
- non-interactive first pass with `-NOInteraction -NORAG -Stream $false`

**Supported providers**
- Azure OpenAI
- Ollama
- LM Studio

**Practical guidance**
- Start with the provider you already have working.
- Start without RAG for the first run.
- Treat Windows as the safest default path for now.
- If you are on WSL/Linux or a mixed environment, expect more setup friction and verify the PSAOAI/runtime path first.

## Known limitations

- First-run output is a **working draft**, not a production-ready deliverable.
- Result quality depends heavily on the selected model and available context window.
- The smoothest path is to configure exactly one backend first and leave RAG off until the base flow works.
- PSAOAI/runtime environment issues can be the main source of friction, especially outside the most typical Windows-oriented setup.
- Advanced parameters are useful, but they are not the right starting point for understanding the tool.

## Advanced parameters

Use these after the basic flow is already clear:

- `-Stream` — enable or disable live streaming (`$true` by default)
- `-NOPM` — disable Project Manager functions
- `-ReducedWorkflow` — keep only the initial Manager → Developer pass and skip the later multi-review stages
- `-NODocumentator` — disable Documentator functions
- `-NOLog` — disable logging
- `-LogFolder` — specify where logs should be stored
- `-DeploymentChat` — override the Azure OpenAI deployment setting
- `-MaxTokens` — control the length of generated responses
- `-NOTips` — disable tips
- `-VerbosePrompt` — show prompts
- `-LoadProjectStatus` — resume from a saved project state
- `-NOUserInputCheck` — disable the input check step

## Overview

This PowerShell script simulates a team of AI agents working together on a PowerShell project. Each specialist has a role and contributes to the project in sequence. The script processes user input, performs different project tasks, and can generate outputs such as code, documentation, and analysis reports.

The main value of AIPSTeam is not just “generate some code,” but to move through a more structured multi-role flow that resembles requirements thinking, implementation, review, and documentation.

## Retrieval-Augmented Generation (RAG)

RAG combines retrieval and generation to produce more accurate and contextually relevant outputs.

How it works:
1. **Retrieval**: the system fetches relevant external information.
2. **Generation**: the LLM uses that information to produce better output.

By integrating these two phases, AIPSTeam can produce more informed responses than a prompt-only flow.

### Data source for RAG

AIPSTeam uses web search providers as a source for retrieval.
Supported services include:
- [SerpApi](https://serpapi.com/) — 100 free searches per month
- [EXA](https://exa.ai/) — 1000 free searches per month
- [Serper](https://serper.com/) — 1000 free searches per month
- ~~[Bing Web Search API](https://www.microsoft.com/en-us/bing/apis/bing-web-search-api)~~ — retired ([retirement notice](https://azure.microsoft.com/en-us/updates?id=483570))

Current behavior:
1. the script tries SerpApi first
2. if that fails, it tries EXA
3. if that fails, it tries Serper
4. if all fail, the script continues without successful retrieval

For a simpler first experience, use `-NORAG` and come back to RAG later.

## Installation notes

### Environment variables

To configure external providers, set the needed environment variables before running the script.

### Azure OpenAI

- `PSAOAI_API_AZURE_OPENAI_KEY`
- `PSAOAI_API_AZURE_OPENAI_ENDPOINT`
- `PSAOAI_API_AZURE_OPENAI_APIVERSION`
- `PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT`
- `PSAOAI_BANNER`

Example:

```powershell
[Environment]::SetEnvironmentVariable('PSAOAI_API_AZURE_OPENAI_ENDPOINT','https://<your-endpoint>.openai.azure.com','user')
[Environment]::SetEnvironmentVariable('PSAOAI_API_AZURE_OPENAI_APIVERSION','2024-05-01-preview','user')
[Environment]::SetEnvironmentVariable('PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT','your-deployment-name','user')
```

> [!IMPORTANT]
> The `PSAOAI_API_AZURE_OPENAI_KEY` environment variable cannot be provided manually because the PSAOAI module encrypts it for security purposes. Ensure that the key is set and managed through PSAOAI's secure mechanisms.

### Ollama

- `OLLAMA_ENDPOINT`
- `OLLAMA_MODEL`

The script sets `OLLAMA_ENDPOINT` to `http://localhost:11434/` by default.

Example:

```powershell
[Environment]::SetEnvironmentVariable('OLLAMA_MODEL','ollama model, example: phi3:latest','user')
```

> [!IMPORTANT]
> For the **Ollama** provider, you do not need to manually define the `OLLAMA_MODEL` environment variable before the first run. The script can check the status of Ollama and guide model selection interactively when needed.

### LM Studio

- `OPENAI_API_KEY`
- `OPENAI_API_BASE`

Example:

```powershell
[Environment]::SetEnvironmentVariable('OPENAI_API_KEY','lm-studio','user')
[Environment]::SetEnvironmentVariable('OPENAI_API_BASE','http://localhost:1234/v1','user')
```

### RAG configuration

- `SERPAPI_API_KEY`
- `EXA_API_KEY`
- `SERPER_API_KEY`
- ~~`AZURE_BING_API_KEY`~~
- ~~`AZURE_BING_ENDPOINT`~~

Example:

```powershell
[Environment]::SetEnvironmentVariable('SERPAPI_API_KEY','your-serpapi-api-key','user')
```

## Additional usage examples

If you are new to the project, treat the examples below as **after-first-run** patterns. The recommended demo above remains the canonical starting point.

- **Basic usage**

  ```powershell
  "Monitor RAM usage and show a single color block based on the load." | AIPSTeam.ps1
  ```

  or

  ```powershell
  AIPSTeam -userInput "Monitor RAM usage and show a single color block based on the load."
  ```

- **Disable live streaming**

  ```powershell
  "Monitor RAM usage" | AIPSTeam.ps1 -Stream $false
  ```

- **Work on an existing script**

  ```powershell
  AIPSTeam.ps1 -TheCodePath "C:\UserScripts\script.ps1"
  ```

  This mode is useful when you want the AI team to improve, debug, or extend an existing PowerShell script instead of starting from a plain-language description.

- **Run without interaction**

  ```powershell
  "Generate a daily system health report." | AIPSTeam.ps1 -NOInteraction
  ```

- **Use Ollama**

  ```powershell
  "Recent software activities on Windows 11." | AIPSTeam -LLMProvider "ollama" -Stream $false
  ```

- **Load a saved project status**

  ```powershell
  AIPSTeam.ps1 -LoadProjectStatus "path\to\your\Project.xml"
  ```

## Developer Notes

### Code Structure

- **Main Script**: `AIPSTeam.ps1`
- **Classes**: `ProjectTeam`
- **Functions**: various utility functions for processing input, logging, and analysis

### Key Functions and Logic

- **ProjectTeam Class**: represents a team member with specific expertise
  - `ProcessInput`
  - `Feedback`
  - `AddLogEntry`
  - `Notify`
  - `SummarizeMemory`
- **Utility Functions**:
  - `SendFeedbackRequest`
  - `Invoke-CodeWithPSScriptAnalyzer`
  - `Export-AndWritePowerShellCodeBlocks`

## Dependencies and Prerequisites

- **PowerShell Version**: PowerShell 5.1 or later
- **Modules**:
  - `PSAOAI`
  - `PSScriptAnalyzer`
  - `powerHTML`

## Troubleshooting

- **Module not found**: install the required modules with `Install-Module`
- **Permission issues**: run PowerShell as Administrator if your environment requires it
- **Script errors**: check the generated log files for details
- **Provider setup confusion**: start with one backend only and use `-NORAG` for the first pass
- **Too much output noise**: use `-NOInteraction -Stream $false` for a calmer first run
- **WSL/Linux friction**: if the runtime path behaves oddly outside the most typical Windows setup, verify PSAOAI and backend configuration before assuming the script logic is broken

## FAQ

### How do I install the required modules?

```powershell
Install-Module -Name PSAOAI
Install-Module -Name PSScriptAnalyzer
Install-Module -Name powerHTML
```

### How do I disable live streaming?

```powershell
AIPSTeam.ps1 -Stream $false
```

### Where are the log files stored?

Log files are stored in the specified log folder or in the default folder under `MyDocuments`.

### How do I load a saved project status?

```powershell
AIPSTeam.ps1 -LoadProjectStatus "path\to\your\Project.xml"
```

### How do I disable the Project Manager functions?

```powershell
AIPSTeam.ps1 -NOPM
```

### How do I specify a custom LLM model for Ollama?

```powershell
$env:OLLAMA_MODEL = "your_custom_model"
AIPSTeam.ps1 -LLMProvider "ollama"
```

For deeper setup and first-run guidance, prefer the sections above before treating this FAQ as the main entry point.
