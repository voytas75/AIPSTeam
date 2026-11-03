param([Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)][string]$EvidenceRoot)
$ErrorActionPreference='Stop'
New-Item -ItemType Directory $EvidenceRoot -Force|Out-Null
$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($SourcePath,[ref]$t,[ref]$e)
if($e.Count){throw 'SOURCE_PARSE'}
foreach($name in @('Invoke-LLMChatCompletion','Invoke-AIPSTeamOllamaCompletion')){
 $f=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true));if($f.Count-ne 1){throw 'FUNCTION_COUNT'};Invoke-Expression $f[0].Extent.Text
}
function Write-VerboseWrapper {}
function Update-ErrorHandling {}
$this=New-Object psobject -Property @{Log=(New-Object 'Collections.Generic.List[string]');Entries=(New-Object 'Collections.Generic.List[string]')}
$this|Add-Member ScriptMethod AddLogEntry {param($entry) $this.Entries.Add($entry)}
$GlobalState=@{VerbosePrompt=$false};$script:ollamaEndpoint='http://localhost:11434/'
$script:requests=New-Object 'Collections.Generic.List[object]'
function Invoke-WebRequest {param($Method,$Body,$Uri,[switch]$UseBasicParsing,$TimeoutSec)
 $script:requests.Add([pscustomobject]@{body=($Body|ConvertFrom-Json);timeout=$TimeoutSec;timeoutBound=$PSBoundParameters.ContainsKey('TimeoutSec')})
 [pscustomobject]@{Content='{"response":"fixture"}'}
}
$results=New-Object 'Collections.Generic.List[object]'
function Case {param($id,[scriptblock]$run) try {&$run;$results.Add([pscustomobject]@{id=$id;pass=$true;error=$null})}catch{$results.Add([pscustomobject]@{id=$id;pass=$false;error=$_.Exception.GetType().FullName})}}
Case bounded-dispatcher {
 $script:requests.Clear();$r=Invoke-LLMChatCompletion -Provider ollama -SystemPrompt s -UserPrompt u -Temperature 0 -TopP 1 -MaxTokens 64 -Stream $false -LogFolder $EvidenceRoot -ollamaModel fixture -TimeoutSec 60
 if($requests.Count-ne 1 -or $requests[0].body.options.num_predict-ne 64 -or $requests[0].timeout-ne 60 -or $requests[0].body.stream-ne $false -or $r-ne 'fixture'){throw 'BOUNDS'}
}
Case bounded-direct {
 $script:requests.Clear();$r=Invoke-AIPSTeamOllamaCompletion s u 0 1 fixture $false -MaxTokens 64 -TimeoutSec 60
 if($requests.Count-ne 1 -or $requests[0].body.options.num_predict-ne 64 -or $requests[0].timeout-ne 60){throw 'BOUNDS'}
}
Case omitted-dispatcher {
 $script:requests.Clear();$r=Invoke-LLMChatCompletion ollama s u 0 1 0 $false $EvidenceRoot '' fixture
 if($requests.Count-ne 1 -or $requests[0].body.options.PSObject.Properties.Name -contains 'num_predict' -or $requests[0].timeoutBound){throw 'DEFAULT_CHANGED'}
}
Case omitted-direct-positional {
 $script:requests.Clear();$r=Invoke-AIPSTeamOllamaCompletion s u 0 1 fixture $false
 if($requests.Count-ne 1 -or $requests[0].body.options.PSObject.Properties.Name -contains 'num_predict' -or $requests[0].timeoutBound){throw 'DEFAULT_CHANGED'}
}
Case explicit-output-only {
 $script:requests.Clear();$r=Invoke-AIPSTeamOllamaCompletion s u 0 1 fixture $false -MaxTokens 64
 if($requests[0].body.options.num_predict-ne 64 -or $requests[0].timeoutBound){throw 'OPTIONAL_TIMEOUT'}
}
Case explicit-timeout-only {
 $script:requests.Clear();$r=Invoke-AIPSTeamOllamaCompletion s u 0 1 fixture $false -TimeoutSec 60
 if($requests[0].body.options.PSObject.Properties.Name -contains 'num_predict' -or $requests[0].timeout-ne 60){throw 'OPTIONAL_OUTPUT'}
}
$summary=[pscustomobject]@{runtime=$PSVersionTable.PSVersion.ToString();sourceSHA256=(Get-FileHash $SourcePath).Hash;testSHA256=(Get-FileHash $PSCommandPath).Hash;parserErrors=$e.Count;cases=$results.Count;passed=@($results|Where-Object pass).Count;failed=@($results|Where-Object {-not $_.pass}).Count;results=$results.ToArray()}
$summary|ConvertTo-Json -Depth 6|Set-Content (Join-Path $EvidenceRoot summary.json) -Encoding UTF8
if($summary.failed){exit 1}
