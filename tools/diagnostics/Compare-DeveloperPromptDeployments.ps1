[CmdletBinding()]
param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path,
    [string]$AIPSTeamPath,
    [string]$UserInput,
    [string]$UserInputFile,
    [string]$ManagerGuidelinesPath,
    [string]$PrimaryDeployment = $env:PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT,
    [string]$ControlDeployment = $env:PSAOAI_API_AZURE_OPENAI_CONTROL_DEPLOYMENT,
    [string]$VariantName = 'baseline-current',
    [string]$OutputRoot,
    [int]$MaxTokens = 1200,
    [double]$ManagerTemperature = 0.4,
    [double]$ManagerTopP = 0.8,
    [double]$DeveloperTemperature = 0.3,
    [double]$DeveloperTopP = 0.7,
    [switch]$IncludeTip,
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

function Resolve-UserInputText {
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

function Invoke-IsolationRun {
    param(
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][string]$Deployment,
        [Parameter(Mandatory)][string]$RunOutputRoot,
        [Parameter(Mandatory)][string]$ResolvedUserInput,
        [AllowNull()][string]$ManagerGuidelinesFile,
        [Parameter(Mandatory)][int]$MaxTokens,
        [Parameter(Mandatory)][double]$ManagerTemperature,
        [Parameter(Mandatory)][double]$ManagerTopP,
        [Parameter(Mandatory)][double]$DeveloperTemperature,
        [Parameter(Mandatory)][double]$DeveloperTopP,
        [switch]$IncludeTip,
        [switch]$KeepBanner,
        [AllowNull()][string]$AIPSTeamPath
    )

    $invokeArgs = @{
        RepoRoot = $RepoRoot
        UserInput = $ResolvedUserInput
        Deployment = $Deployment
        OutputRoot = $RunOutputRoot
        MaxTokens = $MaxTokens
        ManagerTemperature = $ManagerTemperature
        ManagerTopP = $ManagerTopP
        DeveloperTemperature = $DeveloperTemperature
        DeveloperTopP = $DeveloperTopP
    }

    if ($IncludeTip) {
        $invokeArgs['IncludeTip'] = $true
    }
    if ($KeepBanner) {
        $invokeArgs['KeepBanner'] = $true
    }
    if (-not [string]::IsNullOrWhiteSpace($AIPSTeamPath)) {
        $invokeArgs['AIPSTeamPath'] = $AIPSTeamPath
    }
    if (-not [string]::IsNullOrWhiteSpace($ManagerGuidelinesFile)) {
        $invokeArgs['ManagerGuidelinesPath'] = $ManagerGuidelinesFile
    }

    & $ScriptPath @invokeArgs | Out-Null
    $summaryPath = Join-Path $RunOutputRoot 'summary.json'
    if (-not (Test-Path -Path $summaryPath)) {
        throw "Isolation run did not produce summary.json at '$summaryPath'."
    }

    return Get-Content -Path $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json -Depth 100
}

function Get-VariantResult {
    param(
        [Parameter(Mandatory)]$Summary,
        [Parameter(Mandatory)][string]$VariantName
    )

    $variant = $Summary.developerResults | Where-Object { $_.variant -eq $VariantName } | Select-Object -First 1
    if ($null -eq $variant) {
        throw "Variant '$VariantName' was not found in summary '$($Summary.outputRoot)'."
    }

    return $variant
}

if ([string]::IsNullOrWhiteSpace($PrimaryDeployment)) {
    throw 'PrimaryDeployment was not provided and PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT is empty.'
}
if ([string]::IsNullOrWhiteSpace($ControlDeployment)) {
    throw 'ControlDeployment cannot be empty. Pass -ControlDeployment or set PSAOAI_API_AZURE_OPENAI_CONTROL_DEPLOYMENT.'
}

if ([string]::IsNullOrWhiteSpace($AIPSTeamPath)) {
    $AIPSTeamPath = Join-Path $RepoRoot 'AIPSTeam.ps1'
}
if (-not (Test-Path -Path $AIPSTeamPath)) {
    throw "AIPSTeam.ps1 was not found at '$AIPSTeamPath'."
}

$promptIsolationScript = Join-Path $RepoRoot 'tools/diagnostics/Test-DeveloperPromptIsolation.ps1'
if (-not (Test-Path -Path $promptIsolationScript)) {
    throw "Prompt isolation script was not found at '$promptIsolationScript'."
}

if (-not $KeepBanner) {
    $env:PSAOAI_BANNER = '0'
}
Import-Module PSAOAI -Force

$userInputText = Resolve-UserInputText -DirectInput $UserInput -FilePath $UserInputFile
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $RepoRoot ("temp/developer-deployment-comparison/$timestamp")
}
[void](New-Item -ItemType Directory -Path $OutputRoot -Force)
Save-TextArtifact -Path (Join-Path $OutputRoot 'user-input.txt') -Content $userInputText

$sharedManagerGuidelinesPath = $ManagerGuidelinesPath
$bootstrapSummary = $null
if ([string]::IsNullOrWhiteSpace($sharedManagerGuidelinesPath)) {
    Write-Step "Bootstrapping shared manager guidelines with primary deployment '$PrimaryDeployment'"
    $bootstrapOutputRoot = Join-Path $OutputRoot 'bootstrap-manager'
    $bootstrapSummary = Invoke-IsolationRun -ScriptPath $promptIsolationScript -Deployment $PrimaryDeployment -RunOutputRoot $bootstrapOutputRoot -ResolvedUserInput $userInputText -MaxTokens $MaxTokens -ManagerTemperature $ManagerTemperature -ManagerTopP $ManagerTopP -DeveloperTemperature $DeveloperTemperature -DeveloperTopP $DeveloperTopP -IncludeTip:$IncludeTip -KeepBanner:$KeepBanner -AIPSTeamPath $AIPSTeamPath
    $sharedManagerGuidelinesPath = Join-Path $bootstrapOutputRoot 'manager-guidelines.txt'
    if (-not (Test-Path -Path $sharedManagerGuidelinesPath)) {
        throw "Bootstrap run did not produce manager-guidelines.txt at '$sharedManagerGuidelinesPath'."
    }
}
else {
    Write-Step 'Using provided manager guidelines file for both deployments'
}

Write-Step "Running primary deployment '$PrimaryDeployment' with shared manager guidelines"
$primaryOutputRoot = Join-Path $OutputRoot 'primary'
$primarySummary = Invoke-IsolationRun -ScriptPath $promptIsolationScript -Deployment $PrimaryDeployment -RunOutputRoot $primaryOutputRoot -ResolvedUserInput $userInputText -ManagerGuidelinesFile $sharedManagerGuidelinesPath -MaxTokens $MaxTokens -ManagerTemperature $ManagerTemperature -ManagerTopP $ManagerTopP -DeveloperTemperature $DeveloperTemperature -DeveloperTopP $DeveloperTopP -IncludeTip:$IncludeTip -KeepBanner:$KeepBanner -AIPSTeamPath $AIPSTeamPath

Write-Step "Running control deployment '$ControlDeployment' with shared manager guidelines"
$controlOutputRoot = Join-Path $OutputRoot 'control'
$controlSummary = Invoke-IsolationRun -ScriptPath $promptIsolationScript -Deployment $ControlDeployment -RunOutputRoot $controlOutputRoot -ResolvedUserInput $userInputText -ManagerGuidelinesFile $sharedManagerGuidelinesPath -MaxTokens $MaxTokens -ManagerTemperature $ManagerTemperature -ManagerTopP $ManagerTopP -DeveloperTemperature $DeveloperTemperature -DeveloperTopP $DeveloperTopP -IncludeTip:$IncludeTip -KeepBanner:$KeepBanner -AIPSTeamPath $AIPSTeamPath

$primaryVariant = Get-VariantResult -Summary $primarySummary -VariantName $VariantName
$controlVariant = Get-VariantResult -Summary $controlSummary -VariantName $VariantName

$comparison = [ordered]@{
    timestamp = (Get-Date).ToString('o')
    outputRoot = $OutputRoot
    variantName = $VariantName
    primaryDeployment = $PrimaryDeployment
    controlDeployment = $ControlDeployment
    managerGuidelinesPath = $sharedManagerGuidelinesPath
    bootstrapOutputRoot = if ($null -ne $bootstrapSummary) { $bootstrapSummary.outputRoot } else { $null }
    primary = [ordered]@{
        outputRoot = $primarySummary.outputRoot
        variant = $primaryVariant.variant
        userPromptLength = $primaryVariant.userPromptLength
        responseLength = $primaryVariant.responseLength
        isEmpty = $primaryVariant.isEmpty
        status = $primaryVariant.status
        responsePath = $primaryVariant.responsePath
        errorPath = $primaryVariant.errorPath
    }
    control = [ordered]@{
        outputRoot = $controlSummary.outputRoot
        variant = $controlVariant.variant
        userPromptLength = $controlVariant.userPromptLength
        responseLength = $controlVariant.responseLength
        isEmpty = $controlVariant.isEmpty
        status = $controlVariant.status
        responsePath = $controlVariant.responsePath
        errorPath = $controlVariant.errorPath
    }
    interpretation = if (($primaryVariant.isEmpty -eq $true) -and ($controlVariant.isEmpty -eq $false)) {
        'same developer-stage request shape stayed empty on primary but produced non-empty content on control; this supports model-specific behavior rather than general Developer-stage logic.'
    }
    elseif (($primaryVariant.isEmpty -eq $false) -and ($controlVariant.isEmpty -eq $false)) {
        'both deployments produced non-empty content for the selected developer-stage request shape.'
    }
    elseif (($primaryVariant.isEmpty -eq $true) -and ($controlVariant.isEmpty -eq $true)) {
        'both deployments stayed empty for the selected developer-stage request shape; this weakens the case for a primary-deployment-specific issue.'
    }
    else {
        'primary produced non-empty content while control did not; this does not match the expected primary-empty vs control-non-empty comparison signal.'
    }
}

$summaryJsonPath = Join-Path $OutputRoot 'comparison-summary.json'
$summaryMdPath = Join-Path $OutputRoot 'comparison-summary.md'
Save-JsonArtifact -Path $summaryJsonPath -Data $comparison

$summaryMd = @(
    '# Developer deployment comparison',
    '',
    "- Variant: $VariantName",
    "- Primary deployment: $PrimaryDeployment",
    "- Control deployment: $ControlDeployment",
    "- Shared manager guidelines: $sharedManagerGuidelinesPath",
    '',
    '| Deployment | Empty? | Response length | Status | Response path |',
    '|---|---|---:|---|---|',
    "| $PrimaryDeployment | $($primaryVariant.isEmpty) | $($primaryVariant.responseLength) | $($primaryVariant.status) | $($primaryVariant.responsePath) |",
    "| $ControlDeployment | $($controlVariant.isEmpty) | $($controlVariant.responseLength) | $($controlVariant.status) | $($controlVariant.responsePath) |",
    '',
    "Interpretation: $($comparison.interpretation)"
)
Save-TextArtifact -Path $summaryMdPath -Content ($summaryMd -join [Environment]::NewLine)

Write-Host ''
Write-Host 'Developer deployment comparison summary' -ForegroundColor Green
[pscustomobject]@{
    Variant = $VariantName
    PrimaryDeployment = $PrimaryDeployment
    PrimaryEmpty = $primaryVariant.isEmpty
    PrimaryResponseLength = $primaryVariant.responseLength
    ControlDeployment = $ControlDeployment
    ControlEmpty = $controlVariant.isEmpty
    ControlResponseLength = $controlVariant.responseLength
} | Format-Table -AutoSize

Write-Host "`nArtifacts:" -ForegroundColor Green
Write-Host "- Comparison JSON: $summaryJsonPath"
Write-Host "- Comparison MD  : $summaryMdPath"
Write-Host "- Primary root   : $primaryOutputRoot"
Write-Host "- Control root   : $controlOutputRoot"

[pscustomobject]$comparison
