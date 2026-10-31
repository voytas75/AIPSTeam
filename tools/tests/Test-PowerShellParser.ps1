param(
    [string]$ScriptPath = (Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'AIPSTeam.ps1')
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
    throw "Script not found: $ScriptPath"
}
$tokens = $null
$parseErrors = $null
[void][System.Management.Automation.Language.Parser]::ParseFile(
    $ScriptPath, [ref]$tokens, [ref]$parseErrors
)
$result = [ordered]@{
    Runtime = $PSVersionTable.PSVersion.ToString()
    ScriptPath = $ScriptPath
    SHA256 = (Get-FileHash -LiteralPath $ScriptPath -Algorithm SHA256).Hash
    ParseErrors = @($parseErrors).Count
    Errors = @($parseErrors | ForEach-Object {
        [ordered]@{ Line = $_.Extent.StartLineNumber; Id = $_.ErrorId; Message = $_.Message }
    })
}
$result | ConvertTo-Json -Depth 5
if (@($parseErrors).Count -gt 0) { exit 1 }
exit 0
