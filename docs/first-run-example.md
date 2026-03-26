# AIPSTeam first-run example

This document shows a **representative first-run example** for AIPSTeam.
It is meant to help a new user understand what a good first pass looks like before they run the script in their own environment.

> [!NOTE]
> This is a curated example artifact, not a verbatim captured run log.
> The exact output depends on the provider, model quality, context window, enabled options, and prompt quality.

## Scenario

Goal: start with one realistic non-interactive example that shows the kind of structured draft AIPSTeam is good at producing.

We want AIPSTeam to help draft a PowerShell tool that:
- checks local administrator membership
- exports results to CSV
- produces basic documentation

## Prompt

```text
Create a PowerShell tool that checks local administrator membership,
exports results to CSV, and generates basic documentation.
```

## Command

```powershell
$prompt = @"
Create a PowerShell tool that checks local administrator membership,
exports results to CSV, and generates basic documentation.
"@

$prompt | AIPSTeam.ps1 -LLMProvider "AzureOpenAI" -NOInteraction -NORAG -Stream $false
```

This command is a good first-run path because it:
- keeps the session non-interactive
- avoids RAG setup for the first pass
- avoids noisy streaming output
- focuses on one clear draft request

## Representative output shape

A useful first run may produce content like this:

### 1) Requirements summary

- Identify members of the local Administrators group
- Normalize account names where possible
- Export the collected results to CSV
- Generate a short usage and output description
- Add basic error handling for common local lookup failures

### 2) Proposed implementation outline

- Create a main function to collect local administrator membership
- Resolve local and domain principals where possible
- Build structured output objects
- Export results with timestamped CSV naming
- Generate a documentation section with usage notes and limitations

### 3) Draft PowerShell structure

```powershell
function Get-LocalAdministratorMembership {
    [CmdletBinding()]
    param()

    # collect local Administrators group membership
}

function Export-AdministratorMembershipReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [array]$InputObject,

        [Parameter(Mandatory)]
        [string]$Path
    )

    # export results to csv
}
```

### 4) Documentation draft

Example documentation content might include:
- what the script does
- expected CSV columns
- basic usage example
- permissions caveats
- known edge cases (for example unresolved principals)

### 5) Review-style feedback

AIPSTeam may also include notes such as:
- add parameter validation before production use
- handle inaccessible machines or missing groups explicitly
- separate data collection from export logic
- add tests or validation examples for CSV output

## How to read this output

The value of AIPSTeam is not that it magically finishes the whole project in one run.
The value is that it gives you a **better first structured draft** than a single generic prompt response.

A good result should help you:
- clarify the task
- see a sensible PowerShell structure
- get a starting implementation shape
- identify obvious next improvements

## What still needs human review

Even after a good first run, a human should still review:
- correctness of generated PowerShell code
- environment-specific assumptions
- security and permission handling
- error handling depth
- naming, style, and production readiness

## Why this example exists

This file is here to make README claims more concrete.
It gives a new visitor one clear answer to the question:

> "What does a useful AIPSTeam first run actually look like?"
