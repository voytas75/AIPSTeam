param([Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)][string]$EvidenceRoot,[Parameter(Mandatory)][string]$ExpectedSourceSHA256,[Parameter(Mandatory)][string]$ModuleRoot,[ValidateSet('host','endpoint','default','recovery-host','recovery-endpoint','recovery-default')][string]$Case='host',[string]$RecoveryPath)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
$env:PSModulePath=$ModuleRoot+';'+(Join-Path $PSHOME 'Modules')
$env:R4_EVENTS=Join-Path $EvidenceRoot 'events.jsonl';$env:R4_CASE='canonical'
$env:PSAOAI_API_AZURE_OPENAI_KEY='synthetic';$env:PSAOAI_API_AZURE_OPENAI_ENDPOINT='https://fixture.invalid/';$env:PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT='fixture';$env:PSAOAI_API_AZURE_OPENAI_APIVERSION='2025-04-01-preview';$env:PSAOAI_BANNER='0'
$env:OLLAMA_ENDPOINT=$null;$env:OLLAMA_HOST=$null;$env:OLLAMA_MODEL='stale-process-model'
$kind=$Case.Replace('recovery-','')
$global:FixtureEnv=@{'Process:OLLAMA_MODEL'='stale-process-model';'User:OLLAMA_MODEL'='retained-fixture-model'}
$expected=switch($kind){host {$global:FixtureEnv['Process:OLLAMA_HOST']='http://host.invalid:11434';'http://host.invalid:11434/'} endpoint {$global:FixtureEnv['User:OLLAMA_ENDPOINT']=' http://endpoint.invalid:11434/ ';$global:FixtureEnv['Process:OLLAMA_HOST']='http://host.invalid:11434';'http://endpoint.invalid:11434/'} default {'http://localhost:11434/'}}
function global:Get-FixtureEnv {param($Name,$Scope) if($Name -like 'OLLAMA_*'){return $global:FixtureEnv["${Scope}:$Name"]};return [Environment]::GetEnvironmentVariable($Name,$Scope)}
function global:Set-FixtureEnv {param($Name,$Value,$Scope) if($Name -ne 'OLLAMA_MODEL' -or $Scope -ne 'User'){throw 'UNEXPECTED_PERSISTENCE'};$global:FixtureEnv["${Scope}:$Name"]=$Value;$global:FixtureWrites++}
$global:FixtureWrites=0;$global:Requests=New-Object Collections.ArrayList
function Find-Script {throw 'OFFLINE_UPDATE'}
function Read-Host {throw 'INPUT_FORBIDDEN'}
function Install-Module {throw 'INSTALL_FORBIDDEN'}
function Update-Module {throw 'INSTALL_FORBIDDEN'}
function Install-Script {throw 'INSTALL_FORBIDDEN'}
function Start-Process {throw 'EXECUTION_FORBIDDEN'}
function Invoke-RestMethod {param($Uri,$Method,$ErrorAction);[void]$global:Requests.Add(@{uri=[string]$Uri;method='GET'});if([string]$Uri -ceq $expected){return 'Ollama is running'};if([string]$Uri -ceq ($expected+'api/ps')){return @{models=@(@{name='selected-fixture-model';size=1024})}};throw 'UNEXPECTED_GET'}
function Invoke-WebRequest {param($Uri,$Method,$Body,[switch]$UseBasicParsing);if([string]$Uri -cne ($expected+'api/generate')){throw 'UNEXPECTED_POST'};$payload=$Body|ConvertFrom-Json;[void]$global:Requests.Add(@{uri=[string]$Uri;method='POST';model=$payload.model;stream=$payload.stream});$posts=@($global:Requests|Where-Object{$_.method -eq 'POST'}).Count;$text=if($posts -eq 1){'Synthetic manager plan'}else{('```powershell'+"`n"+"Write-Output 'R4_SYNTHETIC_NOT_EXECUTED'"+"`n"+'```')};return @{Content=(@{response=$text}|ConvertTo-Json)}}
$tokens=$null;$parseErrors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($SourcePath,[ref]$tokens,[ref]$parseErrors)
if($parseErrors.Count -or (Get-FileHash $SourcePath).Hash -ne $ExpectedSourceSHA256){throw 'SOURCE_BINDING'}
$global:FixtureDefinitions=@()
foreach($name in @('Get-EnvValue','Test-OllamaRunningModel','Set-EnvOllamaModel')){
 $nodes=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true));if($nodes.Count -ne 1){throw 'AST_AMBIGUOUS'}
 $text=$nodes[0].Body.Extent.Text
 $text=$text -replace '\[(?:System\.)?Environment\]::GetEnvironmentVariable\(([^,]+),\s*([^\)]+)\)','(Get-FixtureEnv $1 $2)'
 $text=$text -replace '\[System.Environment\]::SetEnvironmentVariable\(([^,]+),\s*([^,]+),\s*([^\)]+)\)','(Set-FixtureEnv $1 $2 $3)'
 $global:FixtureDefinitions+=@{name=$name;body=[scriptblock]::Create($text.Substring(1,$text.Length-2))}
}
# Debugger installs owned OS-boundary substitutions after original function definitions, before configuration.
$line=($ast.FindAll({param($n)$n -is [Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Show-Banner'},$true)|Select-Object -Last 1).Extent.StartLineNumber
$bp=Set-PSBreakpoint -Script $SourcePath -Line $line -Action {foreach($d in $global:FixtureDefinitions){Set-Item ('Function:script:'+$d.name) $d.body}}
$argsR=@{DeploymentChat='fixture';LLMProvider='ollama';NORAG=$true;NOInteraction=$true;ReducedWorkflow=$true;Stream=$false;LogFolder=(Join-Path $EvidenceRoot 'product');userInput='Synthetic non-executed draft'}
if($Case -like 'recovery-*'){$argsR.LLMProvider='AzureOpenAI';$argsR.Remove('userInput');if(-not $RecoveryPath){throw 'RECOVERY_PATH_REQUIRED'};$argsR.LoadProjectStatus=$RecoveryPath}
$global:Effective=$null
$observe=Set-PSBreakpoint -Script $SourcePath -Command Write-AIPSTeamActiveProvider -Action {$global:Effective=@{provider=$GlobalState.LLMProvider;endpoint=$script:ollamaEndpoint;model=$script:ollamaModel}}
$exception=$null
try{& $SourcePath @argsR}catch{$exception=@{type=$_.Exception.GetType().FullName;message=$_.Exception.Message;stack=$_.ScriptStackTrace}}
Remove-PSBreakpoint $bp
$states=@(Get-ChildItem $EvidenceRoot -Filter Project.xml -Recurse)
if($RecoveryPath){$states=@(Get-Item $RecoveryPath)}
$state=$null;if($states.Count -eq 1){$state=Import-Clixml $states[0].FullName}
$posts=@($global:Requests|Where-Object{$_.method -eq 'POST'});$gets=@($global:Requests|Where-Object{$_.method -eq 'GET'})
$checks=[ordered]@{noException=($null -eq $exception);sourcePreserved=((Get-FileHash $SourcePath).Hash -eq $ExpectedSourceSHA256);parserClean=($parseErrors.Count -eq 0);stateReadback=($null -ne $state);providerRetained=($state.LLMProvider -eq 'ollama')}
if($RecoveryPath){$checks.noInference=($posts.Count -eq 0);$checks.noDiscovery=($gets.Count -eq 0);$checks.retainedModelReadback=((Get-FixtureEnv 'OLLAMA_MODEL' 'User') -eq 'retained-fixture-model');$checks.noModelRewrite=($global:FixtureWrites -eq 0);$checks.savedProviderWins=($global:Effective.provider -eq 'ollama');$checks.currentEndpointWins=($global:Effective.endpoint -ceq $expected);$checks.recoveryModelNotInitialized=($null -eq $global:Effective.model)}else{$checks.discovery=($gets.Count -eq 2 -and $gets[0].uri -ceq $expected -and $gets[1].uri -ceq ($expected+'api/ps'));$checks.twoGenerations=($posts.Count -eq 2);$checks.selectedModelForwarded=($posts.Count -eq 2 -and @($posts|Where-Object{$_.model -ne 'selected-fixture-model' -or $_.stream -ne $false}).Count -eq 0);$checks.syntheticUserRetentionReadback=((Get-FixtureEnv 'OLLAMA_MODEL' 'User') -eq 'selected-fixture-model');$checks.processRetention=($env:OLLAMA_MODEL -eq 'selected-fixture-model');$checks.persistenceCalls=($global:FixtureWrites -eq 2);$checks.draftComplete=($state.DraftOutcome -eq 'Complete');$checks.validationClean=($state.ValidationOutcome -eq 'Clean');$checks.exportReadback=(@(Get-ChildItem $EvidenceRoot -Filter 'TheCode_v*.ps1' -Recurse).Count -gt 0)}
$receipt=@{case=$Case;runtime=$PSVersionTable.PSVersion.ToString();sourceSHA256=$ExpectedSourceSHA256;runnerSHA256=(Get-FileHash $PSCommandPath).Hash;entry='hash-identical original filepath with debugger-installed AST OS boundary fixtures';persistence='synthetic in-memory User readback; not Windows User persistence';checks=$checks;requests=@($global:Requests);exception=$exception;statePath=if($states.Count -eq 1){$states[0].FullName}else{$null};pass=(@($checks.Values|Where-Object{$_ -ne $true}).Count -eq 0)}
$receipt|ConvertTo-Json -Depth 7|Set-Content (Join-Path $EvidenceRoot 'receipt.json') -Encoding UTF8
Get-EventSubscriber|Unregister-Event;Get-Job|Remove-Job -Force;try{Stop-Transcript|Out-Null}catch{}
if(-not $receipt.pass){exit 1}
