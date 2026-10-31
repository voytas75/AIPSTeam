[CmdletBinding()]
param([Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)][string]$EvidenceRoot,[Parameter(Mandatory)][string]$ExpectedSourceSHA256)
$ErrorActionPreference='Stop'
if((Get-FileHash $SourcePath).Hash -ne $ExpectedSourceSHA256){throw 'SOURCE_DRIFT'}
New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($SourcePath,[ref]$t,[ref]$e)
if($e.Count){throw 'PARSE'}
function Original($name){$n=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true)|Where-Object Name -eq $name);if($n.Count -ne 1){throw "SELECTION $name"};$n[0].Extent.Text}
$binding=[scriptblock]::Create($ast.ParamBlock.Extent.Text+'; $AzureAPIProtocol')
if((& $binding) -ne 'Responses'){throw 'DEFAULT_NOT_RESPONSES'}
Add-Type -AssemblyName System.Net.Http
Add-Type -ReferencedAssemblies @([System.Net.Http.HttpClient].Assembly.Location,[System.Net.HttpStatusCode].Assembly.Location) -TypeDefinition @'
using System; using System.Net; using System.Net.Http; using System.Threading; using System.Threading.Tasks;
public class ResponsesFixtureHandler : HttpMessageHandler {
 public static string Body, Uri, Key, Payload; public static int Status=200, Calls;
 protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage r,CancellationToken c) {
 Calls++; Body=r.Content.ReadAsStringAsync().Result; Uri=r.RequestUri.ToString(); Key=String.Join("",r.Headers.GetValues("api-key"));
 return Task.FromResult(new HttpResponseMessage((HttpStatusCode)Status){Content=new StringContent(Payload)});
 }
}
'@
foreach($name in @('Get-EnvValue','New-AIPSTeamResponsesError','ConvertFrom-AIPSTeamResponsesOutput','Invoke-AIPSTeamAzureResponsesCompletion')) {
 $text=Original $name
 $text=$text.Replace('[System.Net.Http.HttpClient]::new()','[System.Net.Http.HttpClient]::new([ResponsesFixtureHandler]::new())')
 . ([scriptblock]::Create($text))
}
$class=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.TypeDefinitionAst] -and $n.Name -eq 'ProjectTeam'},$true))[0].Extent.Text
. ([scriptblock]::Create($class))
function Write-VerboseWrapper {}
. ([scriptblock]::Create((Original 'Show-Header')))
function Write-AIPSTeamDebugArtifact {param($LogFolder,$Name,$Content);Set-Content (Join-Path $LogFolder $Name) $Content}
function Read-Host {throw 'PROMPT_FORBIDDEN'}
$script:AzureOptions=@{Endpoint='https://fixture.invalid/'}
[Environment]::SetEnvironmentVariable('PSAOAI_API_AZURE_OPENAI_KEY','synthetic-key','Process')
$before=[Environment]::GetEnvironmentVariables('User')|ConvertTo-Json -Compress
$good=@{status='completed';usage=@{input_tokens=2;output_tokens=3;total_tokens=5;output_tokens_details=@{reasoning_tokens=1}};output=@(@{type='reasoning';summary=@()},@{type='message';role='assistant';content=@(@{type='output_text';text='one'},@{type='output_text';text='two'})},@{type='message';role='assistant';content=@(@{type='output_text';text='three'})})}
$script:ResponsesEvidenceRoot=$EvidenceRoot
$rows=@()
foreach($id in @('json','sse','incomplete','failed','refusal','tool','empty','missing-terminal','bad-json','http400','http401','http429','http500','sse-error','endpoint-v1','endpoint-responses','endpoint-dated','reasoning')) {
 [ResponsesFixtureHandler]::Calls=0;[ResponsesFixtureHandler]::Status=200
 $script:AzureOptions=@{Endpoint='https://fixture.invalid/'}
 $stream=$id -in @('sse','missing-terminal','sse-error')
 $obj=$good|ConvertTo-Json -Depth 20|ConvertFrom-Json
 if($id -eq 'incomplete'){$obj.status='incomplete';$obj|Add-Member NoteProperty incomplete_details @{reason='max_output_tokens'}}
 if($id -eq 'failed'){$obj.status='failed';$obj|Add-Member NoteProperty error @{code='server_error';param='input';message='synthetic-private'}}
 if($id -eq 'refusal'){$obj.output=@(@{type='message';role='assistant';content=@(@{type='refusal';refusal='private'})})}
 if($id -eq 'tool'){$obj.output=@(@{type='function_call';arguments='private'})}
 if($id -eq 'empty'){$obj.output=@()}
 if($id -eq 'endpoint-v1'){$script:AzureOptions.Endpoint='https://fixture.invalid/openai/v1/'}
 if($id -eq 'endpoint-responses'){$script:AzureOptions.Endpoint='https://fixture.invalid/openai/v1/responses'}
 if($id -eq 'endpoint-dated'){$script:AzureOptions.Endpoint='https://fixture.invalid/openai/deployments/x/chat/completions?api-version=2025-04-01-preview'}
 if($id -eq 'reasoning'){$script:AzureOptions.ReasoningModel=$true}
 [ResponsesFixtureHandler]::Payload=$obj|ConvertTo-Json -Depth 20 -Compress
 if($stream){[ResponsesFixtureHandler]::Payload='event: response.output_text.delta'+"`n"+'data: {"type":"response.output_text.delta","delta":"partial"}'+"`n`n";if($id -ne 'missing-terminal'){[ResponsesFixtureHandler]::Payload+='event: response.completed'+"`n"+'data: '+(@{type='response.completed';response=$obj}|ConvertTo-Json -Depth 20 -Compress)+"`n`n"}}
 if($id -eq 'sse-error'){[ResponsesFixtureHandler]::Payload='data: {"type":"error","code":"user_error","param":"input","message":"synthetic-private"}'+"`n`n"}
 if($id -eq 'bad-json'){[ResponsesFixtureHandler]::Payload='bad'}
 if($id -match '^http(\d+)$'){[ResponsesFixtureHandler]::Status=[int]$Matches[1];[ResponsesFixtureHandler]::Payload='{"error":{"code":"invalid_request","param":"input","message":"synthetic-private"}}'}
 $gs=[pscustomobject]@{TeamDiscussionDataFolder=$EvidenceRoot};$logger=New-Object ProjectTeam -ArgumentList 'fixture','Developer','system',0,1,$gs
 $logger|Add-Member ScriptMethod Run {param($s) $this.InvokeWithRetry({Invoke-AIPSTeamAzureResponsesCompletion -SystemPrompt 'system' -UserPrompt 'user' -Deployment 'deployment-name' -MaxTokens 17 -Stream $s -LogFolder $script:ResponsesEvidenceRoot})}
 $caught=$null;$reply=$null
 # Preserve actual retry logic, but eliminate wall-clock sleeps in this offline fixture.
 function Start-Sleep {}
 try{$reply=$logger.Run($stream)}catch{$caught=$_.Exception;while($caught.InnerException -and -not $caught.Data.Contains('AIPSTeamResponses')){$caught=$caught.InnerException}}
 $success=$id -in @('json','sse','endpoint-v1','endpoint-responses','reasoning')
 $checks=@()
 if($success){$checks+=($reply -eq 'onetwothree');$body=[ResponsesFixtureHandler]::Body|ConvertFrom-Json;$checks+=($body.max_output_tokens -eq 17);$checks+=($body.model -eq 'deployment-name');$checks+=($body.input[0].role -eq 'developer');$checks+=($body.input[1].content -eq 'user');$checks+=($body.stream -eq $stream);$checks+=($body.store -eq $false);$checks+=(-not $body.PSObject.Properties['max_tokens']);$checks+=(-not $body.PSObject.Properties['temperature']);$checks+=(-not $body.PSObject.Properties['reasoning']);$checks+=([ResponsesFixtureHandler]::Uri -eq 'https://fixture.invalid/openai/v1/responses');$checks+=([ResponsesFixtureHandler]::Key -eq 'synthetic-key');$checks+=(Test-Path $logger.LogFilePath);$checks+=(($logger.Log|Out-String) -notmatch 'synthetic-key');$meta=Get-Content (Join-Path $script:ResponsesEvidenceRoot 'azure-responses-meta.json') -Raw|ConvertFrom-Json;$checks+=($meta.usage.output_tokens_details.reasoning_tokens -eq 1)}
 else{$checks+=($null -ne $caught);$checks+=(-not $reply);$checks+=($caught.Message -notmatch 'synthetic-private|synthetic-key');$checks+=($caught.Data.Contains('AIPSTeamResponses'))}
 $expectedCalls=if($id -eq 'endpoint-dated'){0}elseif($id -in @('http429','http500')){5}else{1}
 $checks+=([ResponsesFixtureHandler]::Calls -eq $expectedCalls)
 $rows+=@{id=$id;pass=(@($checks|Where-Object {$_ -ne $true}).Count -eq 0);checks=$checks;calls=[ResponsesFixtureHandler]::Calls;error=if($caught){$caught.Message}else{$null}}
}
. ([scriptblock]::Create((Original 'Invoke-LLMChatCompletion')))
$script:GlobalState=[pscustomobject]@{VerbosePrompt=$false}
$script:dispatchRoute=$null
function Invoke-AIPSTeamAzureResponsesCompletion {$script:dispatchRoute='Responses';return 'route'}
function Invoke-AIPSTeamAzureOpenAIChatCompletion {$script:dispatchRoute='ChatCompletions';return 'route'}
foreach($protocol in @('Responses','ChatCompletions')) {
 $script:AzureAPIProtocol=$protocol
 $r=Invoke-LLMChatCompletion -Provider AzureOpenAI -SystemPrompt system -UserPrompt user -Stream $false
 $rows+=@{id=('dispatcher-'+$protocol);pass=($r -eq 'route' -and $script:dispatchRoute -eq $protocol)}
}
$after=[Environment]::GetEnvironmentVariables('User')|ConvertTo-Json -Compress
$rows+=@{id='no-user-writes';pass=($before -eq $after)}
$rows|ConvertTo-Json -Depth 10|Set-Content (Join-Path $EvidenceRoot 'responses-cases.json')
$failed=@($rows|Where-Object {-not $_.pass});Write-Output "Responses cases=$($rows.Count) failed=$($failed.Count)"
if($failed.Count){$failed|ConvertTo-Json -Depth 10|Write-Output;throw 'RESPONSES_CONTRACT_FAILED'}
