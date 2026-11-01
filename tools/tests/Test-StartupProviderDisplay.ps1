[CmdletBinding()]
param([Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)][string]$EvidenceRoot,[Parameter(Mandatory)][string]$ExpectedSourceSHA256)
$ErrorActionPreference='Stop'
if((Get-FileHash $SourcePath).Hash -ne $ExpectedSourceSHA256){throw 'SOURCE_DRIFT'}
$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($SourcePath,[ref]$t,[ref]$e)
if($e.Count){throw 'PARSE'}
New-Item -ItemType Directory $EvidenceRoot|Out-Null
# Execute original parameter defaults, functions/classes and complete startup in their
# original order. Stop before ProjectTeam/workflow; no inference is dispatched.
$text=[IO.File]::ReadAllText($SourcePath)
$end=$text.IndexOf('#endregion Setting Up')
if($end -lt 0){throw 'STARTUP_BOUNDARY'}
$body=$text.Substring($ast.ParamBlock.Extent.StartOffset,$end-$ast.ParamBlock.Extent.StartOffset)
$guards=@'
function Test-ModuleMinVersion {return $true}
function Import-Module {}
function Get-CheckForScriptUpdate {}
function Get-EnvValue {param($Name) [Environment]::GetEnvironmentVariable($Name,'Process')}
function Test-OllamaAPI {return $true}
function Test-OllamaRunningModel {return 'fixture-model'}
function Set-EnvOllamaModel {}
function Read-Host {throw 'PROMPT_FORBIDDEN'}
function Invoke-WebRequest {throw 'NETWORK_FORBIDDEN'}
function Invoke-RestMethod {param($Uri,$Method,$Headers,$ErrorAction,$TimeoutSec) if($Method -ne 'GET'){throw 'INFERENCE_FORBIDDEN'}; $global:AIPSTeamBannerDiscoveries++; @{data=@(@{id='fixture-model'})}}
function Install-Module {throw 'INSTALL_FORBIDDEN'}
function Install-Script {throw 'INSTALL_FORBIDDEN'}
'@
# Add guards just before original startup, retaining every startup statement.
$boundary=$body.IndexOf('#region Setting Up')
$entry=Join-Path $EvidenceRoot 'source-bound-startup.ps1'
[IO.File]::WriteAllText($entry,$body.Insert($boundary,$guards+"`n"),(New-Object Text.UTF8Encoding($true)))
$env:OLLAMA_ENDPOINT='http://fixture.invalid/'
$env:OPENAI_API_BASE='http://fixture.invalid/v1/'
$env:OPENAI_API_KEY='synthetic-banner-secret'
$env:LLAMACPP_ENDPOINT='http://fixture.invalid/v1/'
$env:LLAMACPP_API_KEY='synthetic-banner-secret'
# Bind startup ordering and the unchanged late-stage selection to original source.
$startupEnd=$ast.FindAll({param($n) $n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Write-AIPSTeamActiveProvider'},$true)
$firstFolder=$text.IndexOf('        if (-not (Test-Path -Path $GlobalState.LogFolder))')
if(@($startupEnd|Where-Object {$_.Extent.StartOffset -lt $firstFolder}).Count -ne 2){throw 'BANNER_NOT_BEFORE_FOLDERS_AND_WORKFLOW'}
if($text -notmatch "if \(\`$GlobalState.ReducedWorkflow -or \`$GlobalState.DraftOutcome -eq 'Incomplete'\) \{\s*\}\s*else"){throw 'LATE_BRANCH_DRIFT'}
if(([regex]::Matches($text,'\+\+ Reduced workflow enabled\.')).Count -ne 1){throw 'DUPLICATE_REDUCED_BANNER'}
$rows=@()
foreach($id in @('azure-default','azure-chat','llama.cpp','lmstudio','ollama','resume-override','reduced-explicit','resume-false-cli-true','resume-incomplete')){
 $root=Join-Path $EvidenceRoot $id
 $argsR=@{UserInput='fixture';NOInteraction=$true;NORAG=$true;LogFolder=$root}
 $expected='AzureOpenAI (Azure API: Responses)'
 if($id -eq 'azure-chat'){$argsR.AzureAPIProtocol='ChatCompletions';$expected='AzureOpenAI (Azure API: ChatCompletions)'}
 if($id -in @('llama.cpp','lmstudio','ollama')){$argsR.LLMProvider=$id;$expected=$id}
 $resume=$id -like 'resume-*'
 $effectiveReduced=$id -in @('reduced-explicit','resume-override')
 if($id -in @('reduced-explicit','resume-false-cli-true')){$argsR.ReducedWorkflow=$true}
 if($resume){
  New-Item -ItemType Directory $root|Out-Null
  $state=[pscustomobject]@{LLMProvider='llama.cpp';TeamDiscussionDataFolder=$root;FileVersion=1;OrgUserInput='fixture';LogFolder=$root;UserInput='fixture';LastPSDevCode='';GlobalPSDevResponse=@();GlobalResponse=@();MaxTokens=20;VerbosePrompt=$false;NOTips=$false;NOLog=$false;NODocumentator=$false;NOPM=$false;ReducedWorkflow=$true;RAG=$false;Stream=$false}
  $state.ReducedWorkflow=$effectiveReduced
  if($id -eq 'resume-incomplete'){$state|Add-Member NoteProperty DraftOutcome 'Incomplete'}
  $path=Join-Path $root 'Project.xml';$state|Export-Clixml $path
  $argsR.LoadProjectStatus=$path;$argsR.LLMProvider='AzureOpenAI';$expected='llama.cpp'
 }
 $global:AIPSTeamBannerDiscoveries=0;$caught=$null
 try{$output=(& $entry @argsR 6>&1 3>&1|Out-String -Width 4096)}catch{$caught=$_.Exception.Message;$output=''}
 $lines=@($output -split '\r?\n'|Where-Object {$_ -match '^\+\+ Active LLM provider:'})
 $checks=[ordered]@{noException=($null -eq $caught);once=($lines.Count -eq 1);effective=($lines.Count -eq 1 -and $lines[0] -ceq ('++ Active LLM provider: '+$expected));noSecrets=($output -notmatch 'synthetic-banner-secret|http://fixture.invalid');noInference=($global:AIPSTeamBannerDiscoveries -eq $(if($id -in @('llama.cpp','lmstudio','resume-override','resume-false-cli-true','resume-incomplete')){1}else{0}))}
 if(-not $resume){$checks.beforeLogs=($output.IndexOf('++ Active LLM provider:') -ge 0 -and $output.IndexOf('++ Active LLM provider:') -lt $output.IndexOf('++ The logs will be saved'))}
 else{$checks.afterLoad=($output.IndexOf('++ Active LLM provider:') -gt $output.IndexOf('++ Project state loaded successfully'));$checks.beforePaths=($output.IndexOf('++ Active LLM provider:') -ge 0 -and $output.IndexOf('++ Active LLM provider:') -lt $output.IndexOf('Team Discussion Data Folder:'))}
 $reducedLines=@($output -split '\r?\n'|Where-Object {$_ -match '^\+\+ Reduced workflow enabled\.'})
 $checks.reducedOnce=($reducedLines.Count -eq $(if($effectiveReduced){1}else{0}))
 if($effectiveReduced){
  $checks.reducedTruth=($reducedLines.Count -eq 1 -and $reducedLines[0] -ceq '++ Reduced workflow enabled. Skipping Analyst, Architect, Domain Expert, QA, intermediate PSScriptAnalyzer, Documentator, and final Project Manager report stages. Final PSScriptAnalyzer analysis remains enabled.')
  $checks.reducedAfterProvider=($output.IndexOf('++ Reduced workflow enabled.') -gt $output.IndexOf('++ Active LLM provider:'))
  $checks.reducedEarly=($output.IndexOf('++ Reduced workflow enabled.') -lt $output.IndexOf($(if($resume){'Team Discussion Data Folder:'}else{'++ The logs will be saved'})))
 }
 $rows+=@{id=$id;checks=$checks;exception=$caught;banner=$lines;pass=(@($checks.Values|Where-Object {$_ -ne $true}).Count -eq 0)}
}
@{runtime=$PSVersionTable.PSVersion.ToString();sourceSHA256=$ExpectedSourceSHA256;entry='Source-bound original parameter block and complete startup; guarded dependencies; workflow excluded';cases=$rows;sourcePreserved=((Get-FileHash $SourcePath).Hash -eq $ExpectedSourceSHA256)}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $EvidenceRoot 'summary.json') -Encoding UTF8
if(@($rows|Where-Object {!$_.pass}).Count){exit 1}
