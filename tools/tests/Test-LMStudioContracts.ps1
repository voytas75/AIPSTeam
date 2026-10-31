[CmdletBinding()]
param([Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)][string]$EvidenceRoot,[Parameter(Mandatory)][string]$ExpectedSourceSHA256)
$ErrorActionPreference='Stop'
if((Get-FileHash $SourcePath -Algorithm SHA256).Hash -ne $ExpectedSourceSHA256){throw 'SOURCE_DRIFT'}
$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($SourcePath,[ref]$t,[ref]$e)
if($e.Count){throw 'PARSE'}
function One($nodes){$a=@($nodes);if($a.Count -ne 1){throw 'SELECTION'}; $a[0].Extent.Text}
$startup=One ($ast.EndBlock.Statements|Where-Object {$_ -is [Management.Automation.Language.IfStatementAst] -and $_.Clauses[0].Item1.Extent.Text -eq "$"+'GlobalState.LLMProvider -eq ''lmstudio'' -and (-not $LoadProjectStatus)'})
$chat=One ($ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)|Where-Object Name -eq 'Invoke-AIPSTeamLMStudioChatCompletion')
# Replace only the streaming transport constructor; the real request/SSE parser and logger execute.
Add-Type -AssemblyName System.Net.Http
$references=@([System.Net.Http.HttpClient].Assembly.Location,[System.Net.HttpStatusCode].Assembly.Location)
Add-Type -ReferencedAssemblies $references -TypeDefinition @'
using System; using System.Net; using System.Net.Http; using System.Threading; using System.Threading.Tasks;
public class LMFixtureHandler : HttpMessageHandler {
 public static string Auth; public static string Uri; public static bool ApiKey;
 protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage r, CancellationToken c) {
 Auth = r.Headers.Authorization == null ? null : r.Headers.Authorization.ToString(); Uri=r.RequestUri.ToString(); ApiKey=r.Headers.Contains("api-key");
 return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) {Content=new StringContent("data: {\"choices\":[{\"delta\":{\"content\":\"fixture\"}}]}\n\ndata: [DONE]\n")});
 }
}
'@
$chat=$chat.Replace('[System.Net.Http.HttpClient]::new($httpClientHandler)','[System.Net.Http.HttpClient]::new([LMFixtureHandler]::new())')
. ([scriptblock]::Create($chat))
function Invoke-WebRequest {throw 'ROOT_REQUEST_FORBIDDEN'}
function Write-VerboseWrapper {param($Message) $script:messages += $Message}
function Update-ErrorHandling {throw 'RAW_ERROR_LOG_FORBIDDEN'}
function Get-EnvValue {param($Name) if($Name -eq 'OPENAI_API_KEY'){$script:key}else{$script:base}}
function Invoke-RestMethod {
 param($Uri,$Headers,$Method,$Body,$TimeoutSec,$ErrorAction)
 $script:calls += @{uri=$Uri;headers=$Headers;method=$Method}
 if($script:mode -eq '401'){throw '401 synthetic-sensitive-detail'}
 if($Method -eq 'POST'){return @{choices=@(@{message=@{content='fixture'}})}}
 if($script:mode -eq 'empty'){return @{data=@()}}
 if($script:mode -eq 'missing'){return @{other='invalid'}}
 if($script:mode -eq 'invalid'){return @{data=@(@{id=42})}}
 if($script:mode -eq 'blank-model'){return @{data=@(@{id='  '})}}
 if($script:mode -eq 'null-model'){return @{data=@($null)}}
 return @{data=@(@{id='first'},@{id='second'})}
}
New-Item -ItemType Directory $EvidenceRoot|Out-Null
$class=One ($ast.FindAll({param($n)$n -is [Management.Automation.Language.TypeDefinitionAst] -and $n.Name -eq 'ProjectTeam'},$true))
. ([scriptblock]::Create($class))
$showHeader=One ($ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Show-Header'},$true))
. ([scriptblock]::Create($showHeader))
function UserSnapshot {
 @([Environment]::GetEnvironmentVariables('User').GetEnumerator()|Sort-Object Key|ForEach-Object {
  $sha=[Security.Cryptography.SHA256]::Create()
  try {@{name=$_.Key;valueSHA256=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes([string]$_.Value)))).Replace('-','')}}finally{$sha.Dispose()}
 })
}
$userBefore=UserSnapshot
$rows=@()
foreach($id in @('auth','no-key','whitespace','placeholder','slashes','missing-config','401','empty','missing','invalid','blank-model','null-model','post-auth','post-no-key','post-whitespace','post-placeholder','sse-auth','sse-no-key','sse-whitespace','sse-placeholder')) {
 $script:key='synthetic-fixture-token';$script:base='http://fixture.invalid/v1/';$script:mode='ok';$script:calls=@();$script:messages=@();$script:LMStudioModel=$null
 $GlobalState=[pscustomobject]@{LLMProvider='LMStudio';maxtokens=12};$LoadProjectStatus=$null;$checks=@();$caught=$null
 if($id -match 'no-key'){$script:key=$null};if($id -match 'placeholder'){$script:key='***'};if($id -match 'whitespace'){$script:key='  '};if($id -eq 'slashes'){$script:base='http://fixture.invalid/v1///'}
 if($id -eq 'missing-config'){$script:key=$null;$script:base=$null}
 if($id -in @('401','empty','missing','invalid','blank-model','null-model')){$script:mode=$id}
 try {
 if($id -match '^(post|sse)') {
  $GlobalState|Add-Member NoteProperty TeamDiscussionDataFolder $EvidenceRoot
  $logger=New-Object ProjectTeam -ArgumentList 'fixture','Developer','system',0,1,$GlobalState
  $logger|Add-Member ScriptMethod InvokeFixture {param($key,$stream) Invoke-AIPSTeamLMStudioChatCompletion -SystemPrompt 'system' -UserPrompt 'user' -Temperature 0 -TopP 1 -Model 'first' -ApiKey $key -endpoint 'http://fixture.invalid/v1///' -Stream $stream}
  $reply=$logger.InvokeFixture($script:key,($id -match '^sse'))
  $checks+=($reply.Trim() -eq 'fixture')
  if($id -match '^sse'){$checks+=([LMFixtureHandler]::Uri -eq 'http://fixture.invalid/v1/chat/completions');$checks+=(-not [LMFixtureHandler]::ApiKey);$auth=[LMFixtureHandler]::Auth}else{$checks+=($script:calls[0].uri -eq 'http://fixture.invalid/v1/chat/completions');$auth=$script:calls[0].headers.Authorization}
  $checks+=($auth -eq $(if(-not [string]::IsNullOrWhiteSpace($script:key) -and $script:key -ne '***'){'Bearer '+$script:key}else{$null}))
  $checks+=(Test-Path $logger.LogFilePath)
  $checks+=(($logger.Log|Out-String) -notmatch 'synthetic-fixture-token')
 } else {
  $out=(& ([scriptblock]::Create($startup)) 3>&1 6>&1|Out-String)
  $checks+=($script:calls.Count -eq 1);$checks+=($script:calls[0].uri -eq $(if($id -eq 'missing-config'){'http://localhost:1234/v1/models'}else{'http://fixture.invalid/v1/models'}));$checks+=($script:calls[0].method -eq 'GET')
  $auth=$script:calls[0].headers.Authorization
  $checks+=($auth -eq $(if(-not [string]::IsNullOrWhiteSpace($script:key) -and $script:key -ne '***'){'Bearer '+$script:key}else{$null}))
  if($id -in @('401','empty','missing','invalid','blank-model','null-model')){$checks+=(-not $script:LMStudioModel);$checks+=($out -notmatch '\+\+ LM Studio server is running')}else{$checks+=($script:LMStudioModel -eq 'first')}
  $checks+=($out -notmatch 'synthetic-sensitive-detail|synthetic-fixture-token')
 }
 }catch{$caught=$_.Exception.GetType().Name;$checks+=$false}
 $checks+=($startup -notmatch 'SetEnvironmentVariable');$checks+=($chat -notmatch 'SetEnvironmentVariable');$checks+=(($script:messages|Out-String) -notmatch 'synthetic-fixture-token')
 $rows+=@{id=$id;checks=$checks;exception=$caught;pass=(@($checks|Where-Object {$_ -ne $true}).Count -eq 0)}
}
$userAfter=UserSnapshot
$userEqual=(ConvertTo-Json -InputObject $userBefore -Depth 5 -Compress) -eq (ConvertTo-Json -InputObject $userAfter -Depth 5 -Compress)
@{runtime=$PSVersionTable.PSVersion.ToString();sourceSHA256=$ExpectedSourceSHA256;cases=$rows;userEnvironment=@{platform=$PSVersionTable.Platform;before=$userBefore;after=$userAfter;unchanged=$userEqual;qualification=$(if($env:OS -eq 'Windows_NT'){'Native Windows User names/value hashes before and after selected cases; no transient-write monitoring'}else{'Linux User target is not a Windows registry snapshot; source-bound static guards only on Linux'})}}|ConvertTo-Json -Depth 8|Set-Content (Join-Path $EvidenceRoot 'summary.json') -Encoding UTF8
if(-not $userEqual){throw 'USER_SNAPSHOT_DRIFT'}
if(@(Get-ChildItem $EvidenceRoot -File -Recurse|Select-String -SimpleMatch 'synthetic-fixture-token','synthetic-sensitive-detail').Count){throw 'RETAINED_SECRET'}
if(@($rows|Where-Object {!$_.pass}).Count){exit 1}
