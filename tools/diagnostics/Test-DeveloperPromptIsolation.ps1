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
        [int]$Depth = 10
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
    $managerUserPromptTemplate = Get-HereStringBlock -Content $content -Label 'Manager user prompt template' -Pattern '\$projectManagerPrompt\s*=\s*@"(.*?)"@'
    $developerUserPromptTemplate = Get-HereStringBlock -Content $content -Label 'Developer user prompt template' -Pattern '\$powerShellDeveloperPrompt\s*=\s*@"(.*?)"@'

    [pscustomobject]@{
        ManagerRole                 = 'Project Manager'
        DeveloperRole               = 'PowerShell Developer'
        ManagerName                 = 'Manager'
        DeveloperName               = 'Developer'
        ManagerSystemPrompt         = [string]::Format($managerSystemPromptRaw, 'Project Manager')
        DeveloperSystemPrompt       = [string]::Format($developerSystemPromptRaw, 'PowerShell Developer')
        ManagerUserPromptTemplate   = $managerUserPromptTemplate
        DeveloperUserPromptTemplate = $developerUserPromptTemplate
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

function Build-DeveloperPromptVariants {
    param(
        [Parameter(Mandatory)][pscustomobject]$PromptBlocks,
        [Parameter(Mandatory)][string]$ManagerGuidelines,
        [Parameter(Mandatory)][string]$UserInputText,
        [switch]$IncludeTip
    )

    $baseline = @"
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

    $shorter = @"
Write a PowerShell solution for the request below.

Return only these sections:
1. Script Purpose
2. PowerShell Code
3. Usage Example

Use the guidance block as the main task definition. Keep the answer concise but complete.

Guidance:
````````text
$ManagerGuidelines
````````
"@

    $withoutManagerGuidelines = @"
Write a PowerShell solution for the original user request below.

Keep the same general behavior as AIPSTeam's Developer stage, but do not rely on any Manager Guidelines block for this diagnostic.

Original user request:
````````text
$UserInputText
````````

Return these sections:
1. Script Purpose
2. Input Parameters
3. Output
4. PowerShell Code
5. Usage Example
6. Self-Review Notes
"@

    $simpleFormat = @"
Your task is to write PowerShell code based on the guidance below.

Use this output format only:
- Brief summary
- PowerShell code in one ```powershell block
- Short usage example

Guidance:
````````text
$ManagerGuidelines
````````
"@

    if ($IncludeTip) {
        $baseline += "`n`nNote: There is `$50 tip for this task."
        $shorter += "`n`nNote: There is `$50 tip for this task."
        $withoutManagerGuidelines += "`n`nNote: There is `$50 tip for this task."
        $simpleFormat += "`n`nNote: There is `$50 tip for this task."
    }

    return @(
        [pscustomobject]@{ Name = 'baseline-current'; Description = 'Current Developer-stage prompt shape, with Manager Guidelines block.'; UserPrompt = $baseline },
        [pscustomobject]@{ Name = 'shorter-prompt'; Description = 'Shorter instruction block, still includes Manager Guidelines.'; UserPrompt = $shorter },
        [pscustomobject]@{ Name = 'no-manager-guidelines'; Description = 'Removes the long Manager Guidelines block and uses only original user input.'; UserPrompt = $withoutManagerGuidelines },
        [pscustomobject]@{ Name = 'simple-output-format'; Description = 'Keeps guidance block, but simplifies output-format instructions.'; UserPrompt = $simpleFormat }
    )
}

function Invoke-ChatVariant {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$SystemPrompt,
        [Parameter(Mandatory)][string]$UserPrompt,
        [Parameter(Mandatory)][double]$Temperature,
        [Parameter(Mandatory)][double]$TopP,
        [Parameter(Mandatory)][int]$MaxTokens,
        [Parameter(Mandatory)][string]$Deployment,
        [Parameter(Mandatory)][string]$OutputFolder,
        [string]$User = 'AIPSTeamPromptIsolation'
    )

    if (-not (Test-Path -Path $OutputFolder)) {
        [void](New-Item -ItemType Directory -Path $OutputFolder -Force)
    }

    Save-TextArtifact -Path (Join-Path $OutputFolder 'system-prompt.txt') -Content $SystemPrompt
    Save-TextArtifact -Path (Join-Path $OutputFolder 'user-prompt.txt') -Content $UserPrompt

    $result = [ordered]@{
        variant            = $Name
        timestamp          = (Get-Date).ToString('o')
        deployment         = $Deployment
        temperature        = $Temperature
        topP               = $TopP
        maxTokens          = $MaxTokens
        systemPromptLength = $SystemPrompt.Length
        userPromptLength   = $UserPrompt.Length
        responseLength     = 0
        isEmpty            = $true
        status             = 'not-run'
        responsePath       = Join-Path $OutputFolder 'response.txt'
        metaPath           = Join-Path $OutputFolder 'meta.json'
        errorPath          = $null
    }

    try {
        Write-Step "Calling variant '$Name'"
        $response = PSAOAI\Invoke-PSAOAIChatCompletion `
            -SystemPrompt $SystemPrompt `
            -usermessage $UserPrompt `
            -Temperature $Temperature `
            -TopP $TopP `
            -MaxTokens $MaxTokens `
            -LogFolder $OutputFolder `
            -Deployment $Deployment `
            -User $User `
            -Stream $false `
            -simpleresponse `
            -OneTimeUserPrompt

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

    Save-JsonArtifact -Path $result.metaPath -Data $result
    return [pscustomobject]$result
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
    $OutputRoot = Join-Path $RepoRoot ("temp/prompt-isolation/$timestamp")
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
})

$managerGuidelines = $null
$managerSummary = $null

if (-not [string]::IsNullOrWhiteSpace($ManagerGuidelinesPath)) {
    Write-Step 'Using manager guidelines from file'
    $managerGuidelines = Resolve-ManagerGuidelinesContent -Path $ManagerGuidelinesPath
    Save-TextArtifact -Path (Join-Path $OutputRoot 'manager-guidelines.txt') -Content $managerGuidelines
    $managerSummary = [pscustomobject]@{
        variant            = 'manager-source'
        status             = 'from-file'
        systemPromptLength = $promptBlocks.ManagerSystemPrompt.Length
        userPromptLength   = 0
        responseLength     = $managerGuidelines.Length
        isEmpty            = [string]::IsNullOrWhiteSpace($managerGuidelines)
        responsePath       = Join-Path $OutputRoot 'manager-guidelines.txt'
        metaPath           = $null
        errorPath          = $null
    }
}
elseif ($SkipManager) {
    throw 'SkipManager was requested, but no ManagerGuidelinesPath was provided.'
}
else {
    $managerFolder = Join-Path $OutputRoot 'manager'
    $managerUserPrompt = Build-ManagerUserPrompt -UserInputText $userInputText
    $managerCall = Invoke-ChatVariant -Name 'manager-baseline' -SystemPrompt $promptBlocks.ManagerSystemPrompt -UserPrompt $managerUserPrompt -Temperature $ManagerTemperature -TopP $ManagerTopP -MaxTokens $MaxTokens -Deployment $Deployment -OutputFolder $managerFolder -User 'AIPSTeamPromptIsolation-Manager'
    $managerSummary = $managerCall
    $managerGuidelines = if (Test-Path -Path $managerCall.responsePath) { (Get-Content -Path $managerCall.responsePath -Raw).Trim() } else { '' }
    Save-TextArtifact -Path (Join-Path $OutputRoot 'manager-guidelines.txt') -Content $managerGuidelines
}

$variants = Build-DeveloperPromptVariants -PromptBlocks $promptBlocks -ManagerGuidelines $managerGuidelines -UserInputText $userInputText -IncludeTip:$IncludeTip
$variantResults = foreach ($variant in $variants) {
    $folder = Join-Path $OutputRoot $variant.Name
    $call = Invoke-ChatVariant -Name $variant.Name -SystemPrompt $promptBlocks.DeveloperSystemPrompt -UserPrompt $variant.UserPrompt -Temperature $DeveloperTemperature -TopP $DeveloperTopP -MaxTokens $MaxTokens -Deployment $Deployment -OutputFolder $folder -User 'AIPSTeamPromptIsolation-Developer'
    [pscustomobject]@{
        variant            = $call.variant
        description        = $variant.Description
        systemPromptLength = $call.systemPromptLength
        userPromptLength   = $call.userPromptLength
        responseLength     = $call.responseLength
        isEmpty            = $call.isEmpty
        status             = $call.status
        responsePath       = $call.responsePath
        metaPath           = $call.metaPath
        errorPath          = $call.errorPath
    }
}

$summary = [ordered]@{
    timestamp        = (Get-Date).ToString('o')
    outputRoot       = $OutputRoot
    deployment       = $Deployment
    includeTip       = [bool]$IncludeTip
    userInputLength  = $userInputText.Length
    managerSummary   = $managerSummary
    developerResults = $variantResults
}

$summaryJsonPath = Join-Path $OutputRoot 'summary.json'
$summaryCsvPath = Join-Path $OutputRoot 'summary.csv'
$summaryMdPath = Join-Path $OutputRoot 'summary.md'

Save-JsonArtifact -Path $summaryJsonPath -Data $summary
$variantResults | Export-Csv -Path $summaryCsvPath -NoTypeInformation -Encoding UTF8

$rows = foreach ($row in $variantResults) {
    "| $($row.variant) | $($row.userPromptLength) | $($row.isEmpty) | $($row.responseLength) | $($row.status) | $($row.responsePath) |"
}
$summaryMd = @(
    '# Developer prompt isolation summary',
    '',
    "- Output root: $OutputRoot",
    "- Deployment: $Deployment",
    "- Include tip: $([bool]$IncludeTip)",
    "- User input length: $($userInputText.Length)",
    "- Manager response length: $($managerSummary.responseLength)",
    "- Manager status: $($managerSummary.status)",
    '',
    '| Variant | User prompt length | Empty? | Response length | Status | Response path |',
    '|---|---:|---|---:|---|---|'
) + $rows
Save-TextArtifact -Path $summaryMdPath -Content ($summaryMd -join [Environment]::NewLine)

Write-Host ''
Write-Host 'Developer prompt isolation summary' -ForegroundColor Green
$variantResults |
    Select-Object variant, userPromptLength, isEmpty, responseLength, status, responsePath |
    Format-Table -AutoSize

Write-Host "`nArtifacts:" -ForegroundColor Green
Write-Host "- Summary JSON: $summaryJsonPath"
Write-Host "- Summary CSV : $summaryCsvPath"
Write-Host "- Summary MD  : $summaryMdPath"
Write-Host "- Manager text: $(Join-Path $OutputRoot 'manager-guidelines.txt')"

[pscustomobject]$summary
