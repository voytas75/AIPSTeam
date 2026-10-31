[CmdletBinding()]
param([Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)][string]$EvidenceRoot,[Parameter(Mandatory)][string]$ExpectedSourceSHA256,[Parameter(Mandatory)][string]$PSAOAIPath)
$ErrorActionPreference='Stop'
if((Get-FileHash $SourcePath).Hash -ne $ExpectedSourceSHA256){throw 'SOURCE_DRIFT'}
New-Item -ItemType Directory $EvidenceRoot | Out-Null
$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($SourcePath,[ref]$t,[ref]$e)
if($e.Count){throw 'PARSE'}
$rows=New-Object Collections.ArrayList
function Check($id,$checks,$detail){[void]$rows.Add(@{id=$id;checks=@($checks);pass=(@($checks|Where-Object {$_ -ne $true}).Count -eq 0);detail=$detail})}
function Original($tree,$name){$n=@($tree.FindAll({param($x)$x -is [Management.Automation.Language.FunctionDefinitionAst]},$true)|Where-Object Name -eq $name);if($n.Count -ne 1){throw "SELECTION $name"};[scriptblock]::Create($n[0].Extent.Text)}
$binding=[scriptblock]::Create($ast.ParamBlock.Extent.Text+'; [pscustomobject]@{input=$userInput;provider=$LLMProvider;tokens=$MaxTokens;stream=$Stream;reasoning=[bool]$AzureReasoningModel;endpoint=$AzureEndpoint;api=$AzureAPIVersion;bound=@($PSBoundParameters.Keys)}')
try{$b=& $binding;Check 'P01-defaults' @(($b.provider -eq 'AzureOpenAI'),($b.tokens -eq 20480),($b.stream -eq $true),($b.reasoning -eq $false),([string]::IsNullOrEmpty($b.endpoint)),([string]::IsNullOrEmpty($b.api))) $b}catch{Check 'P01-defaults' @($false) $_.ToString()}
try{$b='pipeline fixture'|& $binding -AzureReasoningModel -AzureEndpoint 'https://synthetic.invalid/' -AzureAPIVersion '2025-04-01-preview';Check 'P02-binding' @(($b.input -eq 'pipeline fixture'),($b.reasoning -eq $true),($b.endpoint -eq 'https://synthetic.invalid/'),($b.api -eq '2025-04-01-preview')) $b}catch{Check 'P02-binding' @($false) $_.ToString()}
Check 'P03-order' @((($ast.ParamBlock.Parameters|ForEach-Object {$_.Name.VariablePath.UserPath}) -join ',') -eq 'userInput,TheCodePath,Stream,NORAG,NOPM,NODocumentator,NOLog,NOTips,NOUserInputCheck,NOInteraction,ReducedWorkflow,VerbosePrompt,LogFolder,DeploymentChat,LoadProjectStatus,MaxTokens,LLMProvider,AzureReasoningModel,AzureEndpoint,AzureAPIVersion,AzureAPIProtocol') $null
foreach($name in @('Invoke-AIPSTeamAzureOpenAIChatCompletion','Test-AIPSTeamShouldUseDeveloperFallback','New-AIPSTeamDeveloperFallbackPrompt','Get-AIPSTeamTextWithinLimit')){. (Original $ast $name)}
function Write-VerboseWrapper {}
function Write-AIPSTeamDebugArtifact {}
function Get-AIPSTeamLatestAzureSuccessDiagnostic {$null}
function Update-ErrorHandling {}
$m=New-Module -Name PSAOAI -ScriptBlock {
 function Invoke-PSAOAIChatCompletion {param($SystemPrompt,$usermessage,$Temperature,$TopP,$LogFolder,$Deployment,$User,$Stream,[switch]$simpleresponse,[switch]$OneTimeUserPrompt,$MaxTokens,[switch]$ReasoningModel,$Endpoint,$APIVersion)
 $schema=@{};foreach($k in $PSBoundParameters.Keys){$schema[$k]=$PSBoundParameters[$k]};[void]$global:legacyCalls.Add($schema)
 if($global:legacyFallback -and $global:legacyCalls.Count -eq 1){return ''};return 'fixture output'
 };Export-ModuleMember Invoke-PSAOAIChatCompletion
};Import-Module $m
foreach($id in @('C01-omitted','C02-explicit-primary','C03-explicit-fallback','C04-explicit-false','C05-gpt6-no-fallback')){
 $global:legacyCalls=New-Object Collections.ArrayList;$global:legacyFallback=$id -in @('C03-explicit-fallback','C05-gpt6-no-fallback')
 $AzureReasoningModel=$false;$AzureEndpoint=$null;$AzureAPIVersion=$null
 $publicArgs=@{}
 if($id -ne 'C01-omitted'){$publicArgs=@{AzureReasoningModel=($id -ne 'C04-explicit-false');AzureEndpoint='https://synthetic.invalid/';AzureAPIVersion='2025-04-01-preview'}}
 $initializers=@($ast.EndBlock.Statements|Where-Object {$_.Extent.Text -like '$script:AzureOptions =*' -or ($_.Extent.Text.Contains("$"+'PSBoundParameters.ContainsKey') -and $_.Extent.Text.Contains('Azure'))})
 $init=[scriptblock]::Create($ast.ParamBlock.Extent.Text+';'+(($initializers|ForEach-Object {$_.Extent.Text}) -join ';'))
 & $init @publicArgs

 $deployment=if($id -eq 'C05-gpt6-no-fallback'){'gpt-6.1-sol'}else{'gpt-5.4'}
 $caught=$null;try{$result=Invoke-AIPSTeamAzureOpenAIChatCompletion -SystemPrompt 'system fixture' -UserPrompt '1. Script Purpose 2. PowerShell Code 3. Usage Example' -Temperature 0.2 -TopP 0.5 -MaxTokens 256 -Stream $false -LogFolder $EvidenceRoot -Deployment $deployment}catch{$caught=$_.Exception.Message}
 $checks=@($global:legacyCalls.Count -eq $(if($id -eq 'C03-explicit-fallback'){2}else{1}))
 foreach($call in $global:legacyCalls){if($id -eq 'C01-omitted'){$checks+=(-not $call.ContainsKey('ReasoningModel'));$checks+=(-not $call.ContainsKey('Endpoint'));$checks+=(-not $call.ContainsKey('APIVersion'))}else{$checks+=($call.ContainsKey('ReasoningModel'));$checks+=([bool]$call.ReasoningModel -eq ($id -ne 'C04-explicit-false'));$checks+=($call.Endpoint -eq 'https://synthetic.invalid/');$checks+=($call.APIVersion -eq '2025-04-01-preview')}}
 Check $id $checks @{calls=@($global:legacyCalls);exception=$caught}
}
Remove-Module $m
# Shipping original function definitions and selected original active statements, no module bootstrap/import.
$pt=$null;$pe=$null;$pa=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSAOAIPath 'Public/Invoke-PSAOAIChatCompletion.ps1'),[ref]$pt,[ref]$pe)
foreach($name in @('Get-PSAOAIMessages','Get-PSAOAIMessageso1')){. (Original $pa $name)}
foreach($name in @('Get-PSAOAIChatBody','Get-PSAOAIChatBodyo1','Get-PSAOAIUrl','Get-EnvironmentVariable','Set-EnvironmentVariable','Test-UserEnvironmentVariable','Get-Headers')){. (Join-Path $PSAOAIPath ('Private/'+$name+'.ps1'))}
$all=$pa.FindAll({param($n)$n -is [Management.Automation.Language.IfStatementAst]},$true)
$msg=@($all|Where-Object {$_.Clauses[0].Item1.Extent.Text -eq '$o1 -or $o3' -and $_.Extent.Text -match 'Get-PSAOAIMessages -systemmessage'})
$bodyNode=@($all|Where-Object {$_.Clauses[0].Item1.Extent.Text -eq '$o1 -or $o3 -or $ReasoningModel' -and $_.Clauses[0].Item2.Statements[0].Extent.Text -like '$body = Get-PSAOAIChatBodyo1*'})
if($msg.Count -ne 1 -or $bodyNode.Count -ne 1){throw 'BUILDER_SELECTION'}
foreach($reason in @($false,$true)){
 $ReasoningModel=$reason;$o1=$false;$o3=$false;$system_message='system fixture';$userMessage='user fixture';$MaxTokens=256;$parameters=@{Temperature=0.2;TopP=0.5};$FrequencyPenalty=0;$PresencePenalty=0;$User='AIPSTeam';$N=1;$Stop=$null;$Stream=$false;$JSONMode=$false
 . ([scriptblock]::Create($msg[0].Extent.Text));. ([scriptblock]::Create($bodyNode[0].Extent.Text))
 $url=Get-PSAOAIUrl -Endpoint 'https://synthetic.invalid/' -Deployment 'gpt-6.1-sol' -APIVersion '2025-04-01-preview' -Mode chat
 $checks=@(($url -eq 'https://synthetic.invalid/openai/deployments/gpt-6.1-sol/chat/completions?api-version=2025-04-01-preview'),($url -notmatch '/v1/'),($messages[1].role -eq 'user'))
 if($reason){$checks+=($body.max_completion_tokens -eq 256);$checks+=($body.reasoning_effort -eq 'medium');$checks+=(-not $body.ContainsKey('max_tokens'));$checks+=($messages[0].role -eq 'developer')}else{$checks+=($body.max_tokens -eq 256);$checks+=($body.temperature -eq 0.2);$checks+=($body.top_p -eq 0.5);$checks+=($messages[0].role -eq 'system');$checks+=(-not $body.ContainsKey('reasoning_effort'))}
 Check ('B01-body-'+$reason) $checks @{body=$body;url=$url;messages=$messages}
}
function Read-Host {throw 'UNEXPECTED_PROMPT'}
$names=@('API_AZURE_OPENAI_APIVERSION','API_AZURE_OPENAI_ENDPOINT','API_AZURE_OPENAI_CC_DEPLOYMENT','API_AZURE_OPENAI_KEY','PSAOAI_BANNER')
$before=@{};$persistent=@{};foreach($n in $names){$before[$n]=[Environment]::GetEnvironmentVariable($n,'Process');foreach($target in @('User','Machine')){$v=[Environment]::GetEnvironmentVariable($n,$target);if($v){throw 'SYNTHETIC_TEST_REQUIRES_ABSENT_PERSISTENT_CONFIG'};$persistent[$n+$target]=$v}}
try{
 $values=@('2025-04-01-preview','https://synthetic.invalid/','gpt-6.1-sol','synthetic-key-only','0')
 for($i=0;$i -lt $names.Count;$i++){[Environment]::SetEnvironmentVariable($names[$i],$values[$i],'Process')}
 $checks=@();for($i=0;$i -lt 4;$i++){$value=Set-EnvironmentVariable -VariableName $names[$i] -Secure:($i -eq 3);$checks+=($value -eq $values[$i])}
 $headers=Get-Headers -ApiKeyVariable $names[3] -Secure;$checks+=($headers['api-key'] -eq 'synthetic-key-only')
 foreach($n in $names){foreach($target in @('User','Machine')){$checks+=([Environment]::GetEnvironmentVariable($n,$target) -eq $persistent[$n+$target])}}
 Check 'R01-original-resolvers-process' $checks @{prompts=0;persistentChanges=0;logic='original active private definitions; no mocked setter; no import'}
}finally{foreach($n in $names){[Environment]::SetEnvironmentVariable($n,$before[$n],'Process')}}
$checks=@();foreach($n in $names){$checks+=([string][Environment]::GetEnvironmentVariable($n,'Process') -ceq [string]$before[$n])};Check 'R02-child-restoration' $checks $null
Check 'S01-banner' @((-not $ast.Extent.Text.Contains('[System.Environment]::SetEnvironmentVariable("PSAOAI_BANNER", "0", "User")')),($ast.Extent.Text.Contains('$env:PSAOAI_BANNER = "0"'))) $null
@{runtime=$PSVersionTable.PSVersion.ToString();sourceSHA256=$ExpectedSourceSHA256;runnerSHA256=(Get-FileHash $PSCommandPath).Hash;cases=@($rows);isolation='AST/function logic only; no real module import, bootstrap or provider qualification'}|ConvertTo-Json -Depth 20|Set-Content (Join-Path $EvidenceRoot 'summary.json') -Encoding UTF8
if(@($rows|Where-Object {!$_.pass}).Count){exit 1}
