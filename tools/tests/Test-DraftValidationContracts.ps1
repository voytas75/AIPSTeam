[CmdletBinding()]
param([string]$SourcePath,[string]$EvidenceRoot,[string]$ExpectedSourceSHA256)
$ErrorActionPreference='Stop'
if((Get-FileHash $SourcePath).Hash -ne $ExpectedSourceSHA256){throw 'SOURCE_DRIFT'}
$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($SourcePath,[ref]$t,[ref]$e)
if($e.Count){throw 'PARSE'}
New-Item -ItemType Directory $EvidenceRoot|Out-Null
$manifest=@()
foreach($name in @('Export-AndWritePowerShellCodeBlocks','Update-GlobalStateWithResponse','Save-AndUpdateCode','Add-ToGlobalResponses','Invoke-CodeWithPSScriptAnalyzer','Save-ProjectState')){
 $n=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)|Where-Object Name -eq $name)
 if($n.Count -ne 1){throw 'SELECTION'};$manifest+=@{name=$name;text=$n[0].Extent.Text};. ([scriptblock]::Create($n[0].Extent.Text))
}
function Write-VerboseWrapper {param($Message,[switch]$notruncate)}
function Update-ErrorHandling {param($ErrorRecord,$ErrorContext,$LogFilePath)}
function Get-Module {param([switch]$ListAvailable,$Name);[pscustomobject]@{Name=$Name}}
function Import-Module {param($Name,$ErrorAction)}
function Invoke-ScriptAnalyzer {param($Path,$ScriptDefinition,$Severity,$ErrorAction);$script:analyzerCalls++;if($script:mode -eq 'throw'){throw 'FIXTURE_ANALYZER_FAILURE'};if($script:mode -eq 'findings'){[pscustomobject]@{Line=1;Message='fixture diagnostic';RuleName='FixtureRule'}}}
$rows=@()
foreach($id in @('no-code','empty-block','invalid-code','valid-code','analyzer-zero','analyzer-findings','analyzer-throw','captured-main','multiple-main','ambiguous-blocks','duplicate-main','unknown-section','noncode-fence')){
 $dir=Join-Path $EvidenceRoot $id;New-Item -ItemType Directory $dir|Out-Null
 $GlobalState=[pscustomobject]@{TeamDiscussionDataFolder=$dir;lastPSDevCode="Write-Output 'prior never executed'";FileVersion=1;GlobalPSDevResponse='';GlobalResponse='';GlobalResponses=@();NOLog=$false}
 $prior=$GlobalState.lastPSDevCode;$checks=@();$caught=$null;$analyzerCalls=0;$mode=$id.Replace('analyzer-','')
 if($id -like 'analyzer-*'){
  try{$r=Invoke-CodeWithPSScriptAnalyzer -ScriptBlock $prior}catch{$caught=$_.Exception.Message}
  $checks+=($analyzerCalls -eq 1)
  if($id -eq 'analyzer-throw'){$checks+=($caught -match 'FIXTURE_ANALYZER_FAILURE')}
  elseif($id -eq 'analyzer-zero'){$checks+=($null -eq $caught);$checks+=($r -ceq $false)}
  else{$checks+=($null -eq $caught);$checks+=($r.Message -eq 'fixture diagnostic')}
 }else{
  $reply=switch($id){'no-code'{'prose only'};'empty-block'{"``````powershell`n `n``````"};'invalid-code'{"``````powershell`nfunction {`n``````"};'valid-code'{"``````powershell`nWrite-Output 'never executed'`n``````"}}
  $fence='```powershell';$end='```'
  $main="$fence`nfunction Get-FixtureHelper { 'helper' }`n$end`n$fence`nGet-FixtureHelper`n$end"
  switch($id){
   'captured-main' {$fixturePath=Join-Path $PSScriptRoot 'fixtures/DeveloperResponse-b2fa536f.txt';if((Get-FileHash $fixturePath).Hash -ne 'f16e0fca501cc8a20cfbf6cccdd33fefa380dbd879fc14cc10a9245bf4b74098'){throw 'FIXTURE_DRIFT'};$reply=Get-Content $fixturePath -Raw}
   'multiple-main' {$reply="## 1. Script Purpose`nfixture`n## 2. PowerShell Code`n$main`n## 3. Usage Example`n$fence`n.\usage.ps1`n$end"}
   'ambiguous-blocks' {$reply=$main}
   'duplicate-main' {$reply="## 2. PowerShell Code`n$main`n## 2. PowerShell Code`n$main`n## 3. Usage Example"}
   'unknown-section' {$reply="## Other Code`n$main"}
   'noncode-fence' {$reply='```text'+"`n$fence`nWrite-Output 'not code'`n$end`n"+'```'}
  }
  Save-AndUpdateCode $reply $GlobalState
  if($id -eq 'captured-main'){$checks+=($GlobalState.lastPSDevCode.Contains('Get-NetTCPConnection -State Listen |'));$checks+=($GlobalState.lastPSDevCode.Contains('Select-Object -Property LocalAddress, LocalPort, State'));$checks+=(-not $GlobalState.lastPSDevCode.Contains('.\LocalTcpListenerSnapshot.ps1'))}
  if($id -eq 'multiple-main'){$checks+=($GlobalState.lastPSDevCode.Contains("function Get-FixtureHelper { 'helper' }"));$checks+=($GlobalState.lastPSDevCode -match '(?m)^ Get-FixtureHelper');$checks+=(-not $GlobalState.lastPSDevCode.Contains('.\usage.ps1'))}
  if($id -in @('valid-code','captured-main','multiple-main')){$checks+=($GlobalState.DraftOutcome -eq 'Complete');$checks+=($GlobalState.FileVersion -eq 2)}
  else{$checks+=($GlobalState.DraftOutcome -eq 'Incomplete');$checks+=($GlobalState.lastPSDevCode -ceq $prior);$checks+=($GlobalState.FileVersion -eq 1);$checks+=(@(Get-ChildItem $dir -File).Count -eq 0)}
 }
 $p=Join-Path $dir 'state.xml';$saved=Save-ProjectState $p $GlobalState;$checks+=($saved -ceq $true);$loaded=Import-Clixml $p;$checks+=($loaded.lastPSDevCode -ceq $GlobalState.lastPSDevCode)
 $row=@{id=$id;checks=$checks;pass=(@($checks|Where-Object{$_ -ne $true}).Count -eq 0);exception=$caught;analyzerCalls=$analyzerCalls;state=@{code=[string]$GlobalState.lastPSDevCode;version=$GlobalState.FileVersion;draftOutcome=$GlobalState.DraftOutcome};files=@(Get-ChildItem $dir -File|ForEach-Object{@{name=$_.Name;sha256=(Get-FileHash $_.FullName).Hash}})}
 $row|ConvertTo-Json -Depth 10|Set-Content (Join-Path $dir 'receipt.json') -Encoding UTF8;$rows+=$row
}
@{runtime=$PSVersionTable.PSVersion.ToString();sourceSHA256=$ExpectedSourceSHA256;cases=$rows;originalBodies=$manifest}|ConvertTo-Json -Depth 12|Set-Content (Join-Path $EvidenceRoot 'summary.json') -Encoding UTF8
if(@($rows|Where-Object{!$_.pass}).Count){exit 1}
