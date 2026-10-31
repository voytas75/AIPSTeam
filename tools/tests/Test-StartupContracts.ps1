[CmdletBinding()]
param([Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)][string]$EvidenceRoot,[Parameter(Mandatory)][string]$ExpectedSourceSHA256)
$ErrorActionPreference='Stop'
if((Get-FileHash $SourcePath -Algorithm SHA256).Hash -ne $ExpectedSourceSHA256){throw 'SOURCE_DRIFT'}
$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($SourcePath,[ref]$t,[ref]$e)
if($e.Count){throw 'PARSE'}
function Select-One($nodes){$a=@($nodes);if($a.Count -ne 1){throw 'SELECTION'};[scriptblock]::Create($a[0].Extent.Text)}
$inputBody=Select-One ($ast.EndBlock.Statements|Where-Object {$_ -is [Management.Automation.Language.IfStatementAst] -and $_.Clauses[0].Item1.Extent.Text -eq '-not $UserInput'})
$codeBody=Select-One ($ast.EndBlock.Statements|Where-Object {$_ -is [Management.Automation.Language.IfStatementAst] -and $_.Clauses[0].Item1.Extent.Text -eq '$TheCodePath'})
foreach($name in @('Get-CheckForScriptUpdate','Update-ErrorHandling')){. (Select-One ($ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)|Where-Object Name -eq $name))}
function Get-LatestVersion {throw 'R4B_ORIGINAL_LOOKUP'}
function Read-Host {$script:prompts++;'interactive fixture'}
New-Item -ItemType Directory $EvidenceRoot|Out-Null
$rows=@()
foreach($id in @('I01-missing','I02-explicit','I03-code','I04-load','I05-interactive','U01-null-state','U02-null-folder','U03-log')){
 $prompts=0;$UserInput=$null;$LoadProjectStatus=$null;$TheCodePath=$null;$NOInteraction=$true;$GlobalState=[pscustomobject]@{UserInput='';UserCode='';TeamDiscussionDataFolder=$null};$caught=$null;$checks=@()
 if($id -eq 'I02-explicit'){$UserInput='explicit fixture'}
 if($id -eq 'I03-code'){$TheCodePath=Join-Path $EvidenceRoot 'fixture.ps1';"Write-Output 'never executed'"|Set-Content $TheCodePath}
 if($id -eq 'I04-load'){$LoadProjectStatus='existing-state.xml'}
 if($id -eq 'I05-interactive'){$NOInteraction=$false}
 if($id -eq 'U01-null-state'){$GlobalState=$null}
 if($id -eq 'U03-log'){$GlobalState.TeamDiscussionDataFolder=$EvidenceRoot}
 try {if($id.StartsWith('I')){if($TheCodePath){. $codeBody};. $inputBody}else{$hostText=(& {Get-CheckForScriptUpdate '3.10.3' 'AIPSTeam'} 6>&1|Out-String)}}catch{$caught=$_.Exception.Message}
 if($id -eq 'I01-missing'){$checks+=($caught -eq 'UserInput is required when NOInteraction is set unless TheCodePath supplies code or LoadProjectStatus is provided.')}
 elseif($id.StartsWith('I')){$checks+=($null -eq $caught);if($id -eq 'I02-explicit'){$checks+=($UserInput -eq 'explicit fixture')};if($id -eq 'I03-code'){$checks+=($UserInput -match 'never executed');$checks+=($GlobalState.UserCode -match 'never executed')};if($id -eq 'I04-load'){$checks+=($null -eq $UserInput)};if($id -eq 'I05-interactive'){$checks+=($UserInput -eq 'interactive fixture')}}
 else {$checks+=($null -eq $caught);$checks+=($hostText -match 'R4B_ORIGINAL_LOOKUP');$checks+=($hostText -notmatch 'Cannot bind argument');if($id -eq 'U03-log'){$checks+=((Get-Content (Join-Path $EvidenceRoot 'ERROR.txt') -Raw) -match 'R4B_ORIGINAL_LOOKUP')}}
 if($id.StartsWith('I')){$checks+=($prompts -eq [int]($id -eq 'I05-interactive'))}
 $rows+=@{id=$id;checks=$checks;exception=$caught;pass=(@($checks|Where-Object {$_ -ne $true}).Count -eq 0)}
}
@{runtime=$PSVersionTable.PSVersion.ToString();sourceSHA256=$ExpectedSourceSHA256;cases=$rows}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $EvidenceRoot 'summary.json') -Encoding UTF8
if(@($rows|Where-Object {!$_.pass}).Count){exit 1}
