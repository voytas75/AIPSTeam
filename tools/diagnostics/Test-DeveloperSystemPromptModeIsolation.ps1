[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path,
    [string]$AIPSTeamPath,
    [string]$UserInput,
    [string]$UserInputFile,
    [string]$ManagerGuidelinesPath,
    [string]$Deployment = $env:PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT,
    [string]$OutputRoot,
    [int]$MaxTokens = 1200,
    [double]$ManagerTemperature = 0.4,
    [double]$ManagerTopP = 0.8,
    [double]$DeveloperTemperature = 0.3,
    [double]$DeveloperTopP = 0.7,
    [switch]$IncludeTip,
    [switch]$SkipManager,
    [switch]$KeepBanner
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "== $Message" -ForegroundColor Cyan
}

function Save-TextArtifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [AllowNull()][AllowEmptyString()][string]$Content
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -Path $parent)) {
        [void](New-Item -ItemType Directory -Path $parent -Force)
    }

    if ($null -eq $Content) {
        $Content = ''
    }

    Set-Content -Path $Path -Value $Content -Encoding UTF8
}

function Save-JsonArtifact {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Data,
        [int]$Depth = 12
    )

    $json = $Data | ConvertTo-Json -Depth $Depth
    Save-TextArtifact -Path $Path -Content $json
}

function Get-HereStringBlock {
    param(
        [Parameter(Mandatory)][string]$Content,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Label
    )

    $match = [regex]::Match($Content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $match.Success) {
        throw "Could not locate prompt block for '$Label'."
    }

    return $match.Groups[1].Value.Trim("`r", "`n")
}

function Get-PromptBlocks {
    param([Parameter(Mandatory)][string]$ScriptPath)

    $content = Get-Content -Path $ScriptPath -Raw

    $managerSystemPromptRaw = Get-HereStringBlock -Content $content -Label 'Manager system prompt' -Pattern '\$projectManager\s*=\s*\[ProjectTeam\]::new\(\s*"Manager",\s*\$projectManagerRole,\s*@"(.*?)"@\s*-f'
    $developerSystemPromptRaw = Get-HereStringBlock -Content $content -Label 'Developer system prompt' -Pattern '\$powerShellDeveloper\s*=\s*\[ProjectTeam\]::new\(\s*"Developer",\s*\$powerShellDeveloperRole,\s*@"(.*?)"@\s*-f'

    [pscustomobject]@{
        ManagerRole           = 'Project Manager'
        DeveloperRole         = 'PowerShell Developer'
        ManagerName           = 'Manager'
        DeveloperName         = 'Developer'
        ManagerSystemPrompt   = [string]::Format($managerSystemPromptRaw, 'Project Manager')
        DeveloperSystemPrompt = [string]::Format($developerSystemPromptRaw, 'PowerShell Developer')
    }
}

function Resolve-UserInput {
    param(
        [string]$DirectInput,
        [string]$FilePath
    )

    if (-not [string]::IsNullOrWhiteSpace($DirectInput)) {
        return $DirectInput.Trim()
    }
    if (-not [string]::IsNullOrWhiteSpace($FilePath)) {
        return (Get-Content -Path $FilePath -Raw).Trim()
    }

    return @"
Create a PowerShell tool that checks local administrator membership,
exports results to CSV, and generates basic documentation.
"@.Trim()
}

function Build-ManagerUserPrompt {
    param([Parameter(Mandatory)][string]$UserInputText)

    @"
Write detailed and concise PowerShell project name, description, objectives, deliverables, additional considerations, and success criteria based on user input and RAG data.

###User input###

````````text
$UserInputText
````````
"@.Trim()
}

function Resolve-ManagerGuidelinesContent {
    param([Parameter(Mandatory)][string]$Path)

    $raw = Get-Content -Path $Path -Raw
    if ($Path -match '\.log$' -and $raw -match '(?s)Generated feedback response:\s*(.*)') {
        $extracted = $matches[1]
        $extracted = $extracted -replace '(?s)\r?\n\[\d{4}-\d{2}-\d{2} .*$', ''
        $extracted = $extracted -replace '(?s)\r?\n-+$', ''
        return $extracted.Trim()
    }

    return $raw.Trim()
}

function Build-DeveloperBaselineUserPrompt {
    param(
        [Parameter(Mandatory)][pscustomobject]$PromptBlocks,
        [Parameter(Mandatory)][string]$ManagerGuidelines,
        [switch]$IncludeTip
    )

    $prompt = @"
Your task is to write PowerShell code based on the following requirements and guidelines. Please follow these steps:
1. Analyze the $($PromptBlocks.ManagerName)'s guidelines provided below.
2. Plan the structure of your PowerShell script.
3. Write the PowerShell code that meets the requirements.
4. Add appropriate error handling and logging.
5. Include comments explaining complex parts of the code.
6. Add version notes to document the code changes.
7. Perform a self-review of your code for efficiency and adherence to best practices.

Please format your response as follows:
1. Script Purpose: (Brief description of what the script does)
2. Input Parameters: (List of input parameters, if any)
3. Output: (Description of what the script returns or produces)
4. PowerShell Code: (The actual code, properly formatted and commented)
5. Usage Example: (A brief example of how to use the script)
6. Self-Review Notes: (Any observations or potential improvements you've identified)

$($PromptBlocks.ManagerName) Guidelines:
````````text
$ManagerGuidelines
````````
"@

    if ($IncludeTip) {
        $prompt += "`n`nNote: There is `$50 tip for this task."
    }

    return $prompt
}

function Build-SystemPromptVariants {
    param([Parameter(Mandatory)][pscustomobject]$PromptBlocks)

    $minimalNeutral = @"
You are a PowerShell developer. Write clear, correct, maintainable PowerShell 5.1+ code.
Return the requested sections and include one PowerShell code block when code is needed.
"@.Trim()

    @(
        [pscustomobject]@{
            Name = 'current-developer-system'
            Description = 'Current Developer system prompt extracted from AIPSTeam.ps1.'
            SystemPrompt = $PromptBlocks.DeveloperSystemPrompt
            PromptKind = 'current'
        },
        [pscustomobject]@{
            Name = 'minimal-neutral-system'
            Description = 'Minimal neutral coding system prompt.'
            SystemPrompt = $minimalNeutral
            PromptKind = 'minimal-neutral'
        },
        [pscustomobject]@{
            Name = 'empty-system-prompt'
            Description = 'Empty system prompt string; PSAOAI should fall back to its default generic assistant system prompt.'
            SystemPrompt = ''
            PromptKind = 'empty-default-fallback'
        }
    )
}

function Build-CallModeVariants {
    @(
        [pscustomobject]@{
            Name = 'current-simpleresponse'
            Description = 'Matches current AIPSTeam call path: -simpleresponse -OneTimeUserPrompt -Stream:$false.'
            SimpleResponse = $true
            OneTimeUserPrompt = $true
            Stream = $false
        },
        [pscustomobject]@{
            Name = 'without-simpleresponse'
            Description = 'Same call path, but omits -simpleresponse to isolate formatter/return-path effects.'
            SimpleResponse = $false
            OneTimeUserPrompt = $true
            Stream = $false
        }
    )
}

function Find-LatestMatchingFile {
    param(
        [Parameter(Mandatory)][string]$Folder,
        [Parameter(Mandatory)][string]$Filter
    )

    $match = Get-ChildItem -Path $Folder -File -Filter $Filter -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    if ($null -eq $match) {
        return $null
    }

    return $match.FullName
}

function Update-ResultFromPsaArtifacts {
    param(
        [Parameter(Mandatory)]$Result,
        [Parameter(Mandatory)][string]$OutputFolder
    )

    $Result.requestBodyPath = Find-LatestMatchingFile -Folder $OutputFolder -Filter '*.request-*.body.json'
    $Result.requestMetaPath = Find-LatestMatchingFile -Folder $OutputFolder -Filter '*.request-*.meta.json'
    $Result.rawHttpResponsePath = Find-LatestMatchingFile -Folder $OutputFolder -Filter '*.http-success-response.json'
    $Result.rawHttpResponseMetaPath = Find-LatestMatchingFile -Folder $OutputFolder -Filter '*.http-success-meta.json'
    $Result.rawHttpErrorPath = Find-LatestMatchingFile -Folder $OutputFolder -Filter '*.http-error.txt'
    $Result.rawHttpErrorMetaPath = Find-LatestMatchingFile -Folder $OutputFolder -Filter '*.http-error-meta.json'

    if (-not [string]::IsNullOrWhiteSpace($Result.rawHttpResponsePath) -and (Test-Path -Path $Result.rawHttpResponsePath)) {
        try {
            $rawResponse = Get-Content -Path $Result.rawHttpResponsePath -Raw | ConvertFrom-Json
            if ($null -ne $rawResponse.choices -and $rawResponse.choices.Count -gt 0) {
                $firstChoice = $rawResponse.choices[0]
                $Result.rawFinishReason = $firstChoice.finish_reason
                $Result.rawChoiceMessagePropertyNames = @($firstChoice.message.PSObject.Properties.Name)

                $messageContent = $firstChoice.message.content
                if ($null -eq $messageContent) {
                    $Result.rawFirstMessageContentLength = 0
                    $Result.rawFirstMessageContentType = $null
                }
                elseif ($messageContent -is [string]) {
                    $Result.rawFirstMessageContentLength = $messageContent.Length
                    $Result.rawFirstMessageContentType = $messageContent.GetType().FullName
                }
                else {
                    $serialized = $messageContent | ConvertTo-Json -Depth 20 -Compress
                    $Result.rawFirstMessageContentLength = $serialized.Length
                    $Result.rawFirstMessageContentType = $messageContent.GetType().FullName
                }

                if ($null -ne $firstChoice.message.tool_calls) {
                    $Result.rawToolCallsCount = @($firstChoice.message.tool_calls).Count
                }
                else {
                    $Result.rawToolCallsCount = 0
                }
            }
        }
        catch {
            $Result.rawParseError = $_.Exception.Message
        }
    }
}

function Invoke-ChatVariant {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$SystemVariant,
        [Parameter(Mandatory)]$CallModeVariant,
        [Parameter(Mandatory)][string]$UserPrompt,
        [Parameter(Mandatory)][double]$Temperature,
        [Parameter(Mandatory)][double]$TopP,
        [Parameter(Mandatory)][int]$MaxTokens,
        [Parameter(Mandatory)][string]$Deployment,
        [Parameter(Mandatory)][string]$OutputFolder,
        [string]$User = 'AIPSTeamSystemModeIsolation'
    )

    if (-not (Test-Path -Path $OutputFolder)) {
        [void](New-Item -ItemType Directory -Path $OutputFolder -Force)
    }

    Save-TextArtifact -Path (Join-Path $OutputFolder 'system-prompt.txt') -Content $SystemVariant.SystemPrompt
    Save-TextArtifact -Path (Join-Path $OutputFolder 'user-prompt.txt') -Content $UserPrompt
    Save-JsonArtifact -Path (Join-Path $OutputFolder 'mode-flags.json') -Data ([ordered]@{
        callMode = $CallModeVariant.Name
        simpleresponse = [bool]$CallModeVariant.SimpleResponse
        oneTimeUserPrompt = [bool]$CallModeVariant.OneTimeUserPrompt
        stream = [bool]$CallModeVariant.Stream
    })

    $result = [ordered]@{
        variant                       = $Name
        timestamp                     = (Get-Date).ToString('o')
        deployment                    = $Deployment
        systemVariant                 = $SystemVariant.Name
        systemVariantDescription      = $SystemVariant.Description
        systemPromptKind              = $SystemVariant.PromptKind
        callModeVariant               = $CallModeVariant.Name
        callModeDescription           = $CallModeVariant.Description
        simpleresponse                = [bool]$CallModeVariant.SimpleResponse
        oneTimeUserPrompt             = [bool]$CallModeVariant.OneTimeUserPrompt
        stream                        = [bool]$CallModeVariant.Stream
        temperature                   = $Temperature
        topP                          = $TopP
        maxTokens                     = $MaxTokens
        systemPromptLength            = if ($null -ne $SystemVariant.SystemPrompt) { $SystemVariant.SystemPrompt.Length } else { 0 }
        userPromptLength              = if ($null -ne $UserPrompt) { $UserPrompt.Length } else { 0 }
        responseLength                = 0
        isEmpty                       = $true
        status                        = 'not-run'
        responsePath                  = Join-Path $OutputFolder 'response.txt'
        metaPath                      = Join-Path $OutputFolder 'meta.json'
        errorPath                     = $null
        requestBodyPath               = $null
        requestMetaPath               = $null
        rawHttpResponsePath           = $null
        rawHttpResponseMetaPath       = $null
        rawHttpErrorPath              = $null
        rawHttpErrorMetaPath          = $null
        rawFirstMessageContentLength  = $null
        rawFirstMessageContentType    = $null
        rawChoiceMessagePropertyNames = @()
        rawFinishReason               = $null
        rawToolCallsCount             = $null
        rawParseError                 = $null
    }

    try {
        Write-Step "Calling variant '$Name'"

        $invokeParams = @{
            SystemPrompt      = $SystemVariant.SystemPrompt
            usermessage       = $UserPrompt
            Temperature       = $Temperature
            TopP              = $TopP
            MaxTokens         = $MaxTokens
            LogFolder         = $OutputFolder
            Deployment        = $Deployment
            User              = $User
            Stream            = [bool]$CallModeVariant.Stream
            OneTimeUserPrompt = [bool]$CallModeVariant.OneTimeUserPrompt
        }
        if ($CallModeVariant.SimpleResponse) {
            $invokeParams['simpleresponse'] = $true
        }

        $response = PSAOAI\Invoke-PSAOAIChatCompletion @invokeParams

        if ($null -eq $response) {
            $response = ''
        }
        elseif ($response -isnot [string]) {
            $response = ($response | Out-String)
        }

        Save-TextArtifact -Path $result.responsePath -Content $response

        $trimmed = $response.Trim()
        $result.responseLength = $trimmed.Length
        $result.isEmpty = [string]::IsNullOrWhiteSpace($trimmed)
        $result.status = 'ok'
    }
    catch {
        $errorText = $_ | Out-String
        $errorPath = Join-Path $OutputFolder 'error.txt'
        Save-TextArtifact -Path $errorPath -Content $errorText
        $result.errorPath = $errorPath
        $result.status = 'error'
    }

    Update-ResultFromPsaArtifacts -Result $result -OutputFolder $OutputFolder
    Save-JsonArtifact -Path $result.metaPath -Data $result
    return [pscustomobject]$result
}

function Get-IsolationVerdict {
    param([Parameter(Mandatory)][array]$Results)

    $developerCurrentSimple = $Results | Where-Object {
        $_.systemVariant -eq 'current-developer-system' -and $_.callModeVariant -eq 'current-simpleresponse'
    }
    $developerCurrentNoSimple = $Results | Where-Object {
        $_.systemVariant -eq 'current-developer-system' -and $_.callModeVariant -eq 'without-simpleresponse'
    }
    $currentModeResults = $Results | Where-Object { $_.callModeVariant -eq 'current-simpleresponse' }

    $nonEmptySystems = @($Results | Where-Object { -not $_.isEmpty -and $_.status -eq 'ok' } | Group-Object systemVariant | Select-Object -ExpandProperty Name)
    $nonEmptyModes = @($Results | Where-Object { -not $_.isEmpty -and $_.status -eq 'ok' } | Group-Object callModeVariant | Select-Object -ExpandProperty Name)
    $rawNonEmptyButReturnedEmpty = @($Results | Where-Object {
        $_.status -eq 'ok' -and $_.isEmpty -and $null -ne $_.rawFirstMessageContentLength -and $_.rawFirstMessageContentLength -gt 0
    })
    $currentSystemModeDiffers = ($developerCurrentSimple.Count -gt 0 -and $developerCurrentNoSimple.Count -gt 0 -and ($developerCurrentSimple[0].isEmpty -ne $developerCurrentNoSimple[0].isEmpty))
    $allOkResults = @($Results | Where-Object { $_.status -eq 'ok' })
    $allOkEmpty = ($allOkResults.Count -gt 0 -and (@($allOkResults | Where-Object { -not $_.isEmpty }).Count -eq 0))

    $classification = 'mixed'
    $summary = 'Mixed result set; inspect summary table.'
    $recommendedNextFixDirection = 'Inspect the per-variant raw HTTP response artifacts and compare the first non-empty response against the empty ones.'

    if ($rawNonEmptyButReturnedEmpty.Count -gt 0) {
        $classification = 'psaoai-extraction-path'
        $summary = 'At least one variant returned empty text while the raw HTTP success payload contains non-empty choice.message.content. That strongly suggests a PSAOAI extraction/return-path bug rather than a prompt issue.'
        $recommendedNextFixDirection = 'Patch PSAOAI\Invoke-PSAOAIChatCompletion and/or Write-PSAOAIMessage return handling; compare simpleresponse and non-simpleresponse branches against the raw HTTP payload.'
    }
    elseif ($currentSystemModeDiffers) {
        $classification = 'call-mode-primary'
        $summary = 'The current Developer system prompt changes behavior when only the call-mode variant changes. That points primarily at PSAOAI call-mode / formatter / return-path behavior.'
        $recommendedNextFixDirection = 'Focus on PSAOAI call-mode handling first, especially the -simpleresponse path and how empty message.content is detected and returned.'
    }
    elseif ($nonEmptySystems.Count -gt 0 -and ($nonEmptySystems -notcontains 'current-developer-system')) {
        $classification = 'developer-system-prompt-primary'
        $summary = 'At least one alternate system prompt produced non-empty output while the current Developer system prompt stayed empty. That makes the Developer system prompt the leading suspect.'
        $recommendedNextFixDirection = 'Diff the current Developer system prompt against the minimal/empty variants and simplify it first; remove or rephrase constraints until the failure edge disappears.'
    }
    elseif ($nonEmptySystems.Count -gt 0 -and ($nonEmptySystems -contains 'current-developer-system')) {
        $classification = 'not-reproduced-consistently'
        $summary = 'The current Developer system prompt produced at least one non-empty result in this matrix, so the issue may depend on run-to-run variance, deployment state, or manager-guidelines content rather than only the prompt shape.'
        $recommendedNextFixDirection = 'Re-run with a fixed ManagerGuidelinesPath from a known empty-content case and compare raw HTTP payloads between good/bad runs.'
    }
    elseif ($allOkEmpty -and $nonEmptyModes.Count -eq 0) {
        $classification = 'all-empty-across-system-and-mode'
        $summary = 'All tested combinations stayed empty. The issue does not track with the Developer user prompt, the tested system prompts, or the simpleresponse toggle alone.'
        $recommendedNextFixDirection = 'Inspect deployment/model/API-version behavior and the raw HTTP response schema next; if raw payloads are truly empty, reproduce with a minimal direct PSAOAI call outside AIPSTeam.'
    }

    [pscustomobject]@{
        classification = $classification
        summary = $summary
        recommendedNextFixDirection = $recommendedNextFixDirection
        nonEmptySystems = $nonEmptySystems
        nonEmptyCallModes = $nonEmptyModes
        rawNonEmptyButReturnedEmptyCount = $rawNonEmptyButReturnedEmpty.Count
    }
}

if ([string]::IsNullOrWhiteSpace($AIPSTeamPath)) {
    $AIPSTeamPath = Join-Path $RepoRoot 'AIPSTeam.ps1'
}
if (-not (Test-Path -Path $AIPSTeamPath)) {
    throw "AIPSTeam.ps1 was not found at '$AIPSTeamPath'."
}
if ([string]::IsNullOrWhiteSpace($Deployment)) {
    throw 'Deployment was not provided and PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT is empty.'
}

if (-not $KeepBanner) {
    $env:PSAOAI_BANNER = '0'
}
Import-Module PSAOAI -Force

$userInputText = Resolve-UserInput -DirectInput $UserInput -FilePath $UserInputFile
$promptBlocks = Get-PromptBlocks -ScriptPath $AIPSTeamPath

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $RepoRoot ("temp/system-prompt-mode-isolation/$timestamp")
}
[void](New-Item -ItemType Directory -Path $OutputRoot -Force)

Save-TextArtifact -Path (Join-Path $OutputRoot 'user-input.txt') -Content $userInputText
Save-JsonArtifact -Path (Join-Path $OutputRoot 'run-config.json') -Data ([ordered]@{
    timestamp             = (Get-Date).ToString('o')
    repoRoot              = $RepoRoot
    aipsTeamPath          = $AIPSTeamPath
    deployment            = $Deployment
    maxTokens             = $MaxTokens
    includeTip            = [bool]$IncludeTip
    skipManager           = [bool]$SkipManager
    managerGuidelinesPath = $ManagerGuidelinesPath
    systemVariants        = @('current-developer-system', 'minimal-neutral-system', 'empty-system-prompt')
    callModeVariants      = @('current-simpleresponse', 'without-simpleresponse')
})

$managerGuidelines = $null
$managerSummary = $null

if (-not [string]::IsNullOrWhiteSpace($ManagerGuidelinesPath)) {
    Write-Step 'Using manager guidelines from file'
    $managerGuidelines = Resolve-ManagerGuidelinesContent -Path $ManagerGuidelinesPath
    Save-TextArtifact -Path (Join-Path $OutputRoot 'manager-guidelines.txt') -Content $managerGuidelines
    $managerSummary = [pscustomobject]@{
        variant = 'manager-source'
        status = 'from-file'
        systemPromptLength = $promptBlocks.ManagerSystemPrompt.Length
        userPromptLength = 0
        responseLength = $managerGuidelines.Length
        isEmpty = [string]::IsNullOrWhiteSpace($managerGuidelines)
        responsePath = Join-Path $OutputRoot 'manager-guidelines.txt'
        metaPath = $null
        errorPath = $null
    }
}
elseif ($SkipManager) {
    throw 'SkipManager was requested, but no ManagerGuidelinesPath was provided.'
}
else {
    $managerFolder = Join-Path $OutputRoot 'manager'
    $managerUserPrompt = Build-ManagerUserPrompt -UserInputText $userInputText

    $managerSystemVariant = [pscustomobject]@{
        Name = 'manager-current-system'
        Description = 'Current Manager system prompt extracted from AIPSTeam.ps1.'
        PromptKind = 'current'
        SystemPrompt = $promptBlocks.ManagerSystemPrompt
    }
    $managerCallModeVariant = [pscustomobject]@{
        Name = 'manager-current-simpleresponse'
        Description = 'Current Manager isolation path.'
        SimpleResponse = $true
        OneTimeUserPrompt = $true
        Stream = $false
    }

    $managerCall = Invoke-ChatVariant -Name 'manager-baseline' -SystemVariant $managerSystemVariant -CallModeVariant $managerCallModeVariant -UserPrompt $managerUserPrompt -Temperature $ManagerTemperature -TopP $ManagerTopP -MaxTokens $MaxTokens -Deployment $Deployment -OutputFolder $managerFolder -User 'AIPSTeamSystemModeIsolation-Manager'
    $managerSummary = $managerCall
    $managerGuidelines = if (Test-Path -Path $managerCall.responsePath) { (Get-Content -Path $managerCall.responsePath -Raw).Trim() } else { '' }
    Save-TextArtifact -Path (Join-Path $OutputRoot 'manager-guidelines.txt') -Content $managerGuidelines
}

$developerUserPrompt = Build-DeveloperBaselineUserPrompt -PromptBlocks $promptBlocks -ManagerGuidelines $managerGuidelines -IncludeTip:$IncludeTip
Save-TextArtifact -Path (Join-Path $OutputRoot 'developer-user-prompt.txt') -Content $developerUserPrompt

$systemVariants = Build-SystemPromptVariants -PromptBlocks $promptBlocks
$callModeVariants = Build-CallModeVariants

$variantResults = foreach ($systemVariant in $systemVariants) {
    foreach ($callModeVariant in $callModeVariants) {
        $variantName = "$($systemVariant.Name)__$($callModeVariant.Name)"
        $folder = Join-Path $OutputRoot $variantName
        Invoke-ChatVariant -Name $variantName -SystemVariant $systemVariant -CallModeVariant $callModeVariant -UserPrompt $developerUserPrompt -Temperature $DeveloperTemperature -TopP $DeveloperTopP -MaxTokens $MaxTokens -Deployment $Deployment -OutputFolder $folder -User 'AIPSTeamSystemModeIsolation-Developer'
    }
}

$verdict = Get-IsolationVerdict -Results $variantResults

$summary = [ordered]@{
    timestamp = (Get-Date).ToString('o')
    outputRoot = $OutputRoot
    deployment = $Deployment
    includeTip = [bool]$IncludeTip
    userInputLength = $userInputText.Length
    developerUserPromptLength = $developerUserPrompt.Length
    managerSummary = $managerSummary
    verdict = $verdict
    developerResults = $variantResults
}

$summaryJsonPath = Join-Path $OutputRoot 'summary.json'
$summaryCsvPath = Join-Path $OutputRoot 'summary.csv'
$summaryMdPath = Join-Path $OutputRoot 'summary.md'

Save-JsonArtifact -Path $summaryJsonPath -Data $summary
$variantResults | Export-Csv -Path $summaryCsvPath -NoTypeInformation -Encoding UTF8

$rows = foreach ($row in $variantResults) {
    "| $($row.systemVariant) | $($row.callModeVariant) | $($row.systemPromptLength) | $($row.userPromptLength) | $($row.isEmpty) | $($row.responseLength) | $($row.rawFirstMessageContentLength) | $($row.status) | $($row.rawHttpResponsePath) |"
}

$commands = @(
    'pwsh -NoProfile -File ./tools/diagnostics/Test-DeveloperSystemPromptModeIsolation.ps1 -UserInput "Create a PowerShell tool that checks local administrator membership, exports results to CSV, and generates basic documentation."',
    'pwsh -NoProfile -File ./tools/diagnostics/Test-DeveloperSystemPromptModeIsolation.ps1 -ManagerGuidelinesPath ./path/to/manager-guidelines.txt -UserInputFile ./path/to/user-input.txt'
)

$interpretation = @(
    '- If only alternate system prompts become non-empty while the current Developer system stays empty, blame the Developer system prompt first.',
    '- If the current Developer system prompt changes outcome only when simpleresponse is removed, blame PSAOAI call-mode/formatter handling first.',
    '- If the raw HTTP response path shows non-empty choice.message.content while response.txt is empty, blame PSAOAI extraction/return logic.',
    '- If every combination stays empty and the raw HTTP payload is also empty, inspect deployment/model/API-version behavior next.'
)

$summaryMd = @(
    '# Developer system-prompt / call-mode isolation summary',
    '',
    "- Output root: $OutputRoot",
    "- Deployment: $Deployment",
    "- Include tip: $([bool]$IncludeTip)",
    "- User input length: $($userInputText.Length)",
    "- Fixed Developer user prompt length: $($developerUserPrompt.Length)",
    "- Manager response length: $($managerSummary.responseLength)",
    "- Manager status: $($managerSummary.status)",
    '',
    '## Verdict',
    '',
    "- Classification: $($verdict.classification)",
    "- Summary: $($verdict.summary)",
    "- Recommended next fix direction: $($verdict.recommendedNextFixDirection)",
    '',
    '## Result matrix',
    '',
    '| System variant | Call mode | System prompt length | User prompt length | Empty? | Response length | Raw message.content length | Status | Raw HTTP response path |',
    '|---|---|---:|---:|---|---:|---:|---|---|'
) + $rows + @(
    '',
    '## Commands to run',
    ''
) + ($commands | ForEach-Object { '- `' + $_ + '`' }) + @(
    '',
    '## How to interpret outcomes',
    ''
) + ($interpretation | ForEach-Object { $_ })

Save-TextArtifact -Path $summaryMdPath -Content ($summaryMd -join [Environment]::NewLine)

Write-Host ''
Write-Host 'Developer system-prompt / call-mode isolation summary' -ForegroundColor Green
$variantResults |
    Select-Object systemVariant, callModeVariant, systemPromptLength, userPromptLength, isEmpty, responseLength, rawFirstMessageContentLength, status |
    Format-Table -AutoSize

Write-Host "`nVerdict:" -ForegroundColor Green
Write-Host "- Classification: $($verdict.classification)"
Write-Host "- Summary: $($verdict.summary)"
Write-Host "- Recommended next fix direction: $($verdict.recommendedNextFixDirection)"

Write-Host "`nArtifacts:" -ForegroundColor Green
Write-Host "- Summary JSON: $summaryJsonPath"
Write-Host "- Summary CSV : $summaryCsvPath"
Write-Host "- Summary MD  : $summaryMdPath"
Write-Host "- Manager text: $(Join-Path $OutputRoot 'manager-guidelines.txt')"
Write-Host "- Fixed Developer prompt: $(Join-Path $OutputRoot 'developer-user-prompt.txt')"

[pscustomobject]$summary
