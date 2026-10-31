[CmdletBinding()]
param([Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)][string]$EvidenceRoot,[Parameter(Mandatory)][string]$ExpectedSourceSHA256,[ValidateSet('sse','json','chat','recovery')][string]$Case='sse',[string]$RecoveryPath)
$ErrorActionPreference='Stop'
$env:PSModulePath=(Join-Path (Split-Path $SourcePath) 'modules')+';'+(Join-Path $PSHOME 'Modules')
if((Get-FileHash $SourcePath).Hash -ne $ExpectedSourceSHA256){throw 'SOURCE_DRIFT'}
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
function UserHash {
 $all=[Environment]::GetEnvironmentVariables('User');$rows=@($all.Keys|Sort-Object|ForEach-Object{$_+'='+$all[$_]})
 ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes(($rows -join "`n"))))).Replace('-','')
}
$before=UserHash
# Only complete synthetic Process configuration is supplied. No real credentials are read.
$env:PSAOAI_API_AZURE_OPENAI_KEY='synthetic-original-entry-key'
$env:PSAOAI_API_AZURE_OPENAI_ENDPOINT='https://fixture.invalid/'
$env:PSAOAI_API_AZURE_OPENAI_CC_DEPLOYMENT='r4-fixture'
$env:R4_EVENTS=Join-Path $EvidenceRoot 'events.jsonl';$env:R4_CASE='canonical';$global:R4Calls=0
function Find-Script {throw 'OFFLINE_UPDATE_CHECK'}
function Read-Host {throw 'PROMPT_FORBIDDEN'}
function Invoke-WebRequest {throw 'NETWORK_FORBIDDEN'}
function Invoke-RestMethod {throw 'NETWORK_FORBIDDEN'}
function Install-Module {throw 'INSTALL_FORBIDDEN'}
function Install-Script {throw 'INSTALL_FORBIDDEN'}
function Update-Module {throw 'INSTALL_FORBIDDEN'}
function Start-Process {throw 'CHILD_FORBIDDEN'}
function Invoke-Expression {throw 'GENERATED_EXECUTION_FORBIDDEN'}
Add-Type -AssemblyName System.Net.Http
Add-Type -ReferencedAssemblies @([System.Net.Http.HttpClient].Assembly.Location,[System.Net.HttpStatusCode].Assembly.Location,$(if($PSVersionTable.PSVersion.Major -ge 7){Join-Path $PSHOME 'ref/System.Collections.dll'}else{[System.Collections.Generic.List[string]].Assembly.Location})) -TypeDefinition @'
using System; using System.Net; using System.Net.Http; using System.Threading; using System.Threading.Tasks; using System.Collections.Generic;
public class OriginalEntryHandler : HttpMessageHandler {
 public static List<string> Bodies=new List<string>(); public static List<string> Targets=new List<string>(); public static bool Stream=true;
 protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage r,CancellationToken c) {
  if(r.RequestUri.ToString()!="https://fixture.invalid/openai/v1/responses") throw new Exception("TARGET");
  if(String.Join("",r.Headers.GetValues("api-key"))!="synthetic-original-entry-key") throw new Exception("KEY");
  Bodies.Add(r.Content.ReadAsStringAsync().Result); Targets.Add(r.RequestUri.ToString());
  string text=Bodies.Count==1?"Fixture project guidelines":"```powershell\nWrite-Output 'R4_SYNTHETIC_NOT_EXECUTED'\n```";
  string escaped=text.Replace("\\","\\\\").Replace("\"","\\\"").Replace("\n","\\n");
  string obj="{\"status\":\"completed\",\"usage\":{\"input_tokens\":2,\"output_tokens\":3},\"output\":[{\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\""+escaped+"\"}]}]}";
  string payload=Stream?"data: {\"type\":\"response.completed\",\"response\":"+obj+"}\n\n":obj;
  return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK){Content=new StringContent(payload)});
 }
}
'@
[OriginalEntryHandler]::Stream=($Case -eq 'sse')
$AIPSTeamResponsesHttpClientFactory={ [System.Net.Http.HttpClient]::new([OriginalEntryHandler]::new()) }
# Fail before execution/network until the approved product seam exists (TDD RED).
if((Get-Content $SourcePath -Raw) -notmatch 'Get-Variable -Name AIPSTeamResponsesHttpClientFactory'){throw 'RESPONSES_FACTORY_SEAM_MISSING'}
$argsR=@{AzureEndpoint='https://fixture.invalid/';DeploymentChat='r4-fixture';LLMProvider='AzureOpenAI';NORAG=$true;NOInteraction=$true;ReducedWorkflow=$true;LogFolder=(Join-Path $EvidenceRoot 'product');userInput='Create a synthetic non-executed fixture draft';MaxTokens=2048}
if($Case -eq 'json'){$argsR.Stream=$false}
if($Case -eq 'chat'){$argsR.Stream=$false;$argsR.AzureAPIProtocol='ChatCompletions';$argsR.AzureReasoningModel=$true;$argsR.AzureEndpoint='https://offline.invalid/';$argsR.AzureAPIVersion='2025-04-01-preview'}
if($Case -eq 'recovery'){$argsR.Remove('userInput');$argsR.LoadProjectStatus=$RecoveryPath}
$caught=$null
try { & $SourcePath @argsR } catch { $caught=@{type=$_.Exception.GetType().FullName;message=$_.Exception.Message;stack=$_.ScriptStackTrace} }
$after=UserHash
$states=if($Case -eq 'recovery'){@(Get-Item -LiteralPath $RecoveryPath -ErrorAction SilentlyContinue)}else{@(Get-ChildItem (Join-Path $EvidenceRoot 'product') -Filter Project.xml -Recurse -ErrorAction SilentlyContinue)}
$state=if($states.Count -eq 1){Import-Clixml $states[0].FullName}else{$null}
$expected=if($Case -in @('chat','recovery')){0}else{2}
$checks=[ordered]@{noException=($null -eq $caught);sourceIdentical=((Get-FileHash $SourcePath).Hash -eq $ExpectedSourceSHA256);userEnvironmentUnchanged=($before -eq $after);responsesCalls=([OriginalEntryHandler]::Bodies.Count -eq $expected);chatCalls=($global:R4Calls -eq $(if($Case -eq 'chat'){2}else{0}));stateExists=($states.Count -eq 1)}
if($state){$checks.completeClean=($state.DraftOutcome -eq 'Complete' -and $state.ValidationOutcome -eq 'Clean');$checks.draftReadback=([string]$state.LastPSDevCode -match 'R4_SYNTHETIC_NOT_EXECUTED');$checks.exportReadback=((Get-Content (Join-Path $state.TeamDiscussionDataFolder 'TheCodeF.PS1') -Raw) -match 'R4_SYNTHETIC_NOT_EXECUTED')}
foreach($body in [OriginalEntryHandler]::Bodies){$b=$body|ConvertFrom-Json;$checks['request'+$checks.Count]=($b.store -eq $false -and $b.max_output_tokens -eq 2048 -and $b.stream -eq ($Case -eq 'sse') -and $b.input[0].role -eq 'developer')}
$receipt=@{case=$Case;runtime=$PSVersionTable.PSVersion.ToString();sourceSHA256=(Get-FileHash $SourcePath).Hash;entry='complete original source invoked by path; inherited private factory only';networkTLSVerified=$false;checks=$checks;exception=$caught;responsesCalls=[OriginalEntryHandler]::Bodies.Count;chatCalls=$global:R4Calls;userHashBefore=$before;userHashAfter=$after;statePath=if($states.Count -eq 1){$states[0].FullName}else{$null};state=$state;pass=(@($checks.Values|Where-Object{$_ -ne $true}).Count -eq 0)}
$receipt|ConvertTo-Json -Depth 20|Set-Content (Join-Path $EvidenceRoot 'original-entry-receipt.json') -Encoding UTF8
Get-EventSubscriber|Unregister-Event
Get-Job|Remove-Job -Force
try{Stop-Transcript|Out-Null}catch{}
if(-not $receipt.pass){throw 'ORIGINAL_ENTRY_ACCEPTANCE_FAILED'}
