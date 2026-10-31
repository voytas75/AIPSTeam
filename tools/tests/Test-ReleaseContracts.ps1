[CmdletBinding()]
param([Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)][string]$EvidenceRoot,
 [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{64}$')][string]$ExpectedSourceSHA256)
$ErrorActionPreference = 'Continue'
$expectedHash = $ExpectedSourceSHA256
$before = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
if ($before -ne $expectedHash) { throw 'Source hash mismatch' }
if (Test-Path -LiteralPath $EvidenceRoot) { throw 'Evidence root must be new' }
# No filesystem writes or extracted-body execution until all selections pass.
$tokens=$null; $parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($SourcePath,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count) { throw 'Source parse failed' }
$manifest=New-Object System.Collections.ArrayList
function UniqueNode([string]$Name,$Candidates) {
 $nodes=@($Candidates)
 if ($nodes.Count -ne 1) {throw "Selection $Name requires exactly one AST node; found $($nodes.Count)"}
 return $nodes[0]
}
function OriginalFunction([string]$Name) {
 $node=UniqueNode $Name @($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst]},$true) | Where-Object Name -eq $Name)
 $null=$manifest.Add(@{kind='function';name=$Name;start=$node.Extent.StartLineNumber;end=$node.Extent.EndLineNumber;text=$node.Extent.Text})
 return [scriptblock]::Create($node.Extent.Text)
}
function ConditionKey($Node) {
 # Tokens ignore formatting/comments, while AST scope/type determines ownership.
 $t=$null;$e=$null
 $null=[System.Management.Automation.Language.Parser]::ParseInput($Node.Extent.Text,[ref]$t,[ref]$e)
 return (($t | Where-Object {$_.Kind -notin @('NewLine','Comment','EndOfInput')} | ForEach-Object {$_.Text}) -join '').ToLowerInvariant()
}
function OriginalSection([string]$Name,$Candidates) {
 $node=UniqueNode $Name $Candidates
 $null=$manifest.Add(@{kind='section';name=$Name;start=$node.Extent.StartLineNumber;end=$node.Extent.EndLineNumber;text=$node.Extent.Text})
 return [scriptblock]::Create($node.Extent.Text)
}
$functions=New-Object System.Collections.ArrayList
foreach($name in @('Get-AIPSTeamTextWithinLimit','New-AIPSTeamDeveloperPrompt','New-AIPSTeamDeveloperFallbackPrompt','Get-AIPSTeamLatestAzureSuccessDiagnostic','Test-AIPSTeamShouldUseDeveloperFallback','Invoke-AIPSTeamAzureOpenAIChatCompletion','Export-AndWritePowerShellCodeBlocks','Add-ToGlobalResponses','Add-ToGlobalPSDevResponses','Update-GlobalStateWithResponse','Save-AndUpdateCode','Save-ProjectState','Get-ProjectState')) { $null=$functions.Add((OriginalFunction $name)) }
$top=@($ast.EndBlock.Statements)
$workflow=OriginalSection 'workflow' @($top | Where-Object {$_ -is [System.Management.Automation.Language.IfStatementAst] -and (ConditionKey $_.Clauses[0].Item1) -eq '-not$loadprojectstatus' -and $_.Clauses[0].Item2.Find({param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'New-AIPSTeamDeveloperPrompt'},$true)})
$final=OriginalSection 'final' @($top | Where-Object {$_ -is [System.Management.Automation.Language.IfStatementAst] -and (ConditionKey $_.Clauses[0].Item1) -eq '-not$globalstate.nolog' -and $_.Find({param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Invoke-CodeWithPSScriptAnalyzer'},$true)})
$saveCall=OriginalSection 'final-save-call' @($top | Where-Object {$_ -is [System.Management.Automation.Language.AssignmentStatementAst] -and (ConditionKey $_.Left) -eq '$projectstatesaved' -and $_.Right.Find({param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Save-ProjectState'},$true)})
$saveMessage=OriginalSection 'final-save-message' @($top | Where-Object {$_ -is [System.Management.Automation.Language.IfStatementAst] -and (ConditionKey $_.Clauses[0].Item1) -eq '$projectstatesaved-ceq$true'})
$menuCandidates=@($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.SwitchStatementAst]},$true) | Where-Object {(ConditionKey $_.Condition) -eq '$useroption'} | ForEach-Object {foreach($clause in $_.Clauses) {if($clause.Item1 -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $clause.Item1.Value -eq '8') {$clause.Item2.Statements}}} | Where-Object {$_ -is [System.Management.Automation.Language.IfStatementAst] -and (ConditionKey $_.Clauses[0].Item1) -eq '-not(test-path$projectfilepath)'})
$menuSave=OriginalSection 'menu-save' $menuCandidates
if ((Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash -ne $expectedHash) {throw 'Source changed during selection'}
$null = New-Item -ItemType Directory -Path $EvidenceRoot
foreach($body in $functions) { . $body }
function Write-VerboseWrapper {param($Message,[switch]$notruncate)}
function Write-AIPSTeamDebugArtifact {param($LogFolder,$Name,$Content)}
function Update-ErrorHandling {param($ErrorRecord,$ErrorContext,$LogFilePath) $null=$global:R2Errors.Add(@{context=$ErrorContext;message=$ErrorRecord.Exception.Message;path=$LogFilePath})}
function Invoke-WebRequest {throw 'BLOCKED unintended transport'}
function Invoke-RestMethod {throw 'BLOCKED unintended transport'}
function Invoke-CodeWithPSScriptAnalyzer {param($FilePath,$ScriptBlock) $null=$global:R2Stages.Add(@{role='FinalAnalyzer';path=$FilePath;code=$ScriptBlock}); return $null}
function Invoke-ProcessFeedbackAndResponse {param($reviewer,$recipient,$GlobalState,$tipAmount) $null=$global:R2Stages.Add(@{role=$reviewer.Name;method='Review';tip=$tipAmount})}
function Invoke-AnalyzeCodeWithPSScriptAnalyzer {param($InputString,$Role,$GlobalState) $null=$global:R2Stages.Add(@{role='IntermediateAnalyzer';code=$InputString})}
function Stop-Transcript {}
if (Get-Module PSAOAI) {throw 'Installed PSAOAI already loaded'}
$stub=New-Module -Name PSAOAI -ScriptBlock {
 function Invoke-PSAOAIChatCompletion {
 param($SystemPrompt,$usermessage,$Temperature,$TopP,$LogFolder,$Deployment,$User,[bool]$Stream,[switch]$simpleresponse,[switch]$OneTimeUserPrompt,$MaxTokens)
 $index=$global:R2Calls.Count
 $null=$global:R2Calls.Add(@{case=$global:R2Case;index=$index;parameters=@{SystemPrompt=$SystemPrompt;usermessage=$usermessage;Temperature=$Temperature;TopP=$TopP;LogFolder=$LogFolder;Deployment=$Deployment;User=$User;Stream=$Stream;OneTimeUserPrompt=[bool]$OneTimeUserPrompt;MaxTokens=$MaxTokens};simpleresponse=[bool]$simpleresponse;simplePresent=$PSBoundParameters.ContainsKey('simpleresponse')})
 if ($index -ge $global:R2Replies.Count) {throw 'Stub reply queue exhausted'}
 return $global:R2Replies[$index]
 }
 Export-ModuleMember -Function Invoke-PSAOAIChatCompletion
}
Import-Module $stub
$results=New-Object System.Collections.ArrayList
function Check($Name,$Expected,$Actual) {
 $ok=($Expected -ceq $Actual)
 $null=$script:checks.Add(@{assertion=$Name;expected=$Expected;actual=$Actual;pass=[bool]$ok})
}
function Case([string]$Id,[scriptblock]$Body) {
 $global:R2Case=$Id; $global:R2Calls=New-Object System.Collections.ArrayList; $global:R2Errors=New-Object System.Collections.ArrayList; $global:R2Stages=New-Object System.Collections.ArrayList
 $global:R2Replies=@(); $script:checks=New-Object System.Collections.ArrayList
 $script:dir=Join-Path $EvidenceRoot $Id; $null=New-Item -ItemType Directory -Path $dir
 $script:GlobalState=[pscustomobject]@{TeamDiscussionDataFolder=$dir;FileVersion=1;lastPSDevCode='retained';GlobalResponse=@();GlobalPSDevResponse='';LLMProvider='AzureOpenAI';ReducedWorkflow=$false;NOLog=$true;NOTips=$true;NODocumentator=$false;NOPM=$false;OrgUserInput='';userInput='';RAG=$false;NORAG=$true;NOInteraction=$true;Stream=$false}
 $caught=$null
 try { & $Body } catch {$caught=$_.Exception.Message; Check 'Unexpected harness exception' 'none' $caught}
 $bad=@($checks | Where-Object {!$_.pass}).Count
 $status=if ($caught -match 'BLOCKED|queue exhausted') {'BLOCKED'} elseif($bad) {'RED'} else {'PASS'}
 $null=$results.Add([ordered]@{id=$Id;status=$status;sourceSHA256=$before;assertions=@($checks.ToArray());providerCalls=@($global:R2Calls.ToArray());errors=@($global:R2Errors.ToArray());stageCalls=@($global:R2Stages.ToArray());exception=$caught;files=@(Get-ChildItem -LiteralPath $dir -File | ForEach-Object {@{path=$_.FullName;sha256=(Get-FileHash $_.FullName).Hash}})})
}
$developerPrompt=New-AIPSTeamDeveloperPrompt -GuidelinesText 'Write a minimal hello script'
function Chat($Deployment='gpt-5.1',$Prompt=$developerPrompt) {
 $script:terminal=$null; $script:reply=$null
 try {$script:reply=Invoke-AIPSTeamAzureOpenAIChatCompletion -SystemPrompt 'Developer' -UserPrompt $Prompt -Temperature 0.2 -TopP 1 -MaxTokens 100 -Stream $false -LogFolder $dir -Deployment $Deployment 2>$null} catch {$script:terminal=$_.Exception.Message}
}
function CallChecks($Count) {
 Check 'provider count' $Count $global:R2Calls.Count
 Check 'first simpleresponse' $true $global:R2Calls[0].simpleresponse
 Check 'first one-time' $true ([bool]$global:R2Calls[0].parameters.OneTimeUserPrompt)
 Check 'stream disabled' $false $global:R2Calls[0].parameters.Stream
 if ($Count -eq 2 -and $global:R2Calls.Count -eq 2) {
 Check 'fallback omits simpleresponse' $false $global:R2Calls[1].simplePresent
 Check 'fallback prompt exact' (New-AIPSTeamDeveloperFallbackPrompt $developerPrompt) $global:R2Calls[1].parameters.usermessage
 }
}
Case A01 {$global:R2Replies=@('exact reply');Chat;CallChecks 1;Check 'exact result' 'exact reply' $reply;Check 'no terminal error' $true ($null -eq $terminal)}
Case A02 {$global:R2Replies=@('');Chat 'gpt-4';CallChecks 1;Check 'terminal error' $true ([bool]$terminal)}
Case A03 {$global:R2Replies=@('', '  fallback code  ');Chat;CallChecks 2;Check 'trimmed result' 'fallback code' $reply}
Case A04 {$global:R2Replies=@('',[pscustomobject]@{choices=@([pscustomobject]@{message=[pscustomobject]@{content='  object code  '}})});Chat;CallChecks 2;Check 'trimmed content' 'object code' $reply}
Case A05 {$global:R2Replies=@('','');Chat;CallChecks 2;Check 'terminal error' $true ([bool]$terminal)}
Case 'A06-non-gpt5' {$global:R2Replies=@('   ');Chat 'gpt-4';CallChecks 1;Check 'whitespace rejected' $true ([bool]$terminal)}
Case 'A06-gpt5' {$global:R2Replies=@('   ','   ');Chat;CallChecks 2;Check 'whitespace rejected' $true ([bool]$terminal)}
Case A07 {$global:R2Replies=@('code');Chat;CallChecks 1;Check 'no fallback' 'code' $reply}
foreach($spec in @(@('A08-length',@{finishReason='length';contentLength=0},$true),@('A08-reasoning',@{finishReason='stop';contentLength=0;reasoningTokens=10;completionTokens=10},$true),@('A08-content-control',@{finishReason='length';contentLength=5;reasoningTokens=10;completionTokens=10},$false),@('A08-budget-control',@{finishReason='stop';contentLength=0;reasoningTokens=9;completionTokens=10},$false))) {
 Case $spec[0] { $actual=Test-AIPSTeamShouldUseDeveloperFallback -Response 'nonempty' -Diagnostic ([pscustomobject]$spec[1]);Check 'independent predicate' $spec[2] $actual }
}
Case 'A08-unrelated-prompt' {$global:R2Replies=@('');Chat 'gpt-5.1' 'unrelated prompt';CallChecks 1;Check 'no retry and terminal' $true ([bool]$terminal)}
Case D01 {
 '{"choices":[{"finish_reason":"length","message":{"content":""}}],"usage":{"completion_tokens":10,"total_tokens":20,"completion_tokens_details":{"reasoning_tokens":10}}}' | Set-Content -LiteralPath (Join-Path $dir 'fixture.http-success-response.json') -Encoding UTF8
 $d=Get-AIPSTeamLatestAzureSuccessDiagnostic $dir
 Check 'finish_reason' 'length' $d.finishReason;Check 'content length' 0 $d.contentLength;Check 'completion tokens' 10 $d.completionTokens;Check 'total tokens' 20 $d.totalTokens;Check 'reasoning tokens' 10 $d.reasoningTokens
}
Case 'D02-malformed' {'{bad' | Set-Content (Join-Path $dir 'fixture.http-success-response.json');$d=Get-AIPSTeamLatestAzureSuccessDiagnostic $dir;Check 'bounded parseError' $true (![string]::IsNullOrWhiteSpace($d.parseError));Check 'rawPath retained' $true (Test-Path $d.rawPath)}
Case 'D02-missing-folder' {Check 'null diagnostic' $true ($null -eq (Get-AIPSTeamLatestAzureSuccessDiagnostic (Join-Path $dir 'missing')))}
Case 'D02-missing-file' {Check 'null diagnostic' $true ($null -eq (Get-AIPSTeamLatestAzureSuccessDiagnostic $dir))}
$one='```powershell' + "`nWrite-Output 'one'`n" + '```'
$two=$one + "`n" + '```powershell' + "`nWrite-Output 'two'`n" + '```'
Case E01 {Save-AndUpdateCode $one $GlobalState;$file=Join-Path $dir 'TheCode_v1.ps1';Check 'file exists' $true (Test-Path $file);Check 'version once' 2 $GlobalState.FileVersion;Check 'disk equals last code' (Get-Content $file -Raw) $GlobalState.lastPSDevCode;Check 'code preserved' $true ($GlobalState.lastPSDevCode.Contains("Write-Output 'one'"))}
Case E02 {Save-AndUpdateCode $two $GlobalState;Check 'version once' 2 $GlobalState.FileVersion;$code=$GlobalState.lastPSDevCode;Check 'both blocks ordered' $true ($code.IndexOf("Write-Output 'one'") -ge 0 -and $code.IndexOf("Write-Output 'two'") -gt $code.IndexOf("Write-Output 'one'"));Check 'disk equals last' (Get-Content (Join-Path $dir 'TheCode_v1.ps1') -Raw) $code}
Case E03 {$r=Export-AndWritePowerShellCodeBlocks 'no block' -OutputFilePath (Join-Path $dir 'none.ps1') -StartDelimiter '```powershell' -EndDelimiter '```';Check 'false return' $false $r;Save-AndUpdateCode 'no block' $GlobalState;Check 'no file' 0 @(Get-ChildItem $dir -File).Count;Check 'unchanged code' 'retained' $GlobalState.lastPSDevCode;Check 'unchanged version' 1 $GlobalState.FileVersion}
Case E04 {Save-AndUpdateCode '' $GlobalState;Check 'unchanged code' 'retained' $GlobalState.lastPSDevCode;Check 'unchanged version' 1 $GlobalState.FileVersion;Check 'no file' 0 @(Get-ChildItem $dir -File).Count;Check 'explicit error' $true ($global:R2Errors.Count -gt 0)}
Case S01 {$GlobalState.ReducedWorkflow=$true;$GlobalState.FileVersion=7;$GlobalState.lastPSDevCode='saved code';$GlobalState.LLMProvider='LMStudio';$p=Join-Path $dir 'state.xml';Save-ProjectState $p $GlobalState;$loaded=Get-ProjectState $p;foreach($prop in @('LLMProvider','lastPSDevCode','FileVersion','ReducedWorkflow','NOLog','NORAG','NOInteraction','Stream')) {Check $prop $GlobalState.$prop $loaded.$prop}}
Case S02 {$GlobalState.PSObject.Properties.Remove('ReducedWorkflow');$p=Join-Path $dir 'legacy.xml';Save-ProjectState $p $GlobalState;$loaded=Get-ProjectState $p;Check 'default false explicitly present' $true ($null -ne $loaded.PSObject.Properties['ReducedWorkflow'] -and $loaded.ReducedWorkflow -eq $false);Check 'existing code' 'retained' $loaded.lastPSDevCode;Check 'existing version' 1 $loaded.FileVersion}
Case S03 {$GlobalState.PSObject.Properties.Remove('LLMProvider');$p=Join-Path $dir 'legacy.xml';Save-ProjectState $p $GlobalState;$loaded=Get-ProjectState $p;Check 'default provider' 'AzureOpenAI' $loaded.LLMProvider;Check 'existing code retained' 'retained' $loaded.lastPSDevCode;Check 'existing version' 1 $loaded.FileVersion}
Case 'S04-function' {$p=Join-Path $dir 'nonexistent/state.xml';$r=Save-ProjectState $p $GlobalState;Check 'file absent' $false (Test-Path $p);Check 'explicit unsuccessful result or error' $true ($r -ceq $false -or $global:R2Errors.Count -gt 0)}
Case 'S04-final-caller' {$ProjectfilePath=Join-Path $dir 'nonexistent/state.xml';$stream=@(& { . $saveCall; . $saveMessage } 6>&1);Check 'file absent' $false (Test-Path $ProjectfilePath);Check 'no false success message' $false (($stream | Out-String) -match 'has been saved!');Check 'error observed' $true ($global:R2Errors.Count -gt 0)}
function Role([string]$Name) {
 $r=[pscustomobject]@{Name=$Name}
 $r | Add-Member ScriptMethod Feedback {param($recipient,$prompt) $null=$global:R2Stages.Add(@{role=$this.Name;method='Feedback';prompt=$prompt});return 'manager guidelines'}
 $r | Add-Member ScriptMethod ProcessInput {param($prompt,$unused) $null=$global:R2Stages.Add(@{role=$this.Name;method='ProcessInput';prompt=$prompt});return ('```powershell' + "`nWrite-Output 'fixture'`n" + '```')}
 $r | Add-Member ScriptMethod GetLastMemory {return [pscustomobject]@{Response='fixture response'}}
 return $r
}
foreach($reduced in @($true,$false)) {
 $id=if($reduced){'W01'}else{'W02'}
 Case $id {
 $GlobalState.ReducedWorkflow=$reduced;$GlobalState.NOLog=$true;$LoadProjectStatus=$false;$userInput='fixture requirements';$RAGpromptAddon=$null
 $projectManager=Role 'Manager';$powerShellDeveloper=Role 'Developer';$requirementsAnalyst=Role 'Analyst';$systemArchitect=Role 'Architect';$domainExpert=Role 'DomainExpert';$qaEngineer=Role 'QA';$documentationSpecialist=Role 'Documentator'
 . $workflow
 Check 'Manager feedback once' 1 @($global:R2Stages | Where-Object {$_.role -eq 'Manager' -and $_.method -eq 'Feedback'}).Count
 Check 'Developer once' 1 @($global:R2Stages | Where-Object role -eq 'Developer').Count
 foreach($roleName in @('Analyst','Architect','DomainExpert','QA','IntermediateAnalyzer','Documentator')) {Check $roleName $(if($reduced){0}else{1}) @($global:R2Stages | Where-Object role -eq $roleName).Count}
 Check 'Manager final report' $(if($reduced){0}else{1}) @($global:R2Stages | Where-Object {$_.role -eq 'Manager' -and $_.method -eq 'ProcessInput'}).Count
 Check 'version advanced' 2 $GlobalState.FileVersion
 }
 foreach($nolog in @($true,$false)) {
 $suffix=if($reduced){'reduced'}else{'normal'};$logging=if($nolog){'nolog'}else{'file'}
 Case "W03-$suffix-$logging" {$GlobalState.ReducedWorkflow=$reduced;$GlobalState.NOLog=$nolog;$Team=@();. $final;Check 'final analysis once' 1 $global:R2Stages.Count;Check 'analyzer identity' 'FinalAnalyzer' $global:R2Stages[0].role;if(!$nolog){Check 'final file' $true (Test-Path (Join-Path $dir 'TheCodeF.PS1'));Check 'analyzed exact path' (Join-Path $dir 'TheCodeF.PS1') $global:R2Stages[0].path}else{Check 'analyzed retained code' 'retained' $global:R2Stages[0].code}}
 }
}
# R3a: execute the original menu save if/else AST, not a rewritten caller.
foreach($existing in @($false,$true)) {
 foreach($failure in @($false,$true)) {
  $kind=if($existing){'existing'}else{'new'};$outcome=if($failure){'failure'}else{'success'}
  Case "S05-menu-$kind-$outcome" {
   $ProjectfilePath=Join-Path $dir 'state.xml'
   $script:promptCount=0
   function Read-Host {param($Prompt) $script:promptCount++; return 'Y'}
   if($existing) {
    $fixture=[pscustomobject]@{marker='original fixture'}
    $fixture | Microsoft.PowerShell.Utility\Export-Clixml -LiteralPath $ProjectfilePath
    $fixtureHash=(Get-FileHash $ProjectfilePath).Hash
   } elseif($failure) {$ProjectfilePath=Join-Path $dir 'nonexistent/state.xml'}
   if($existing -and $failure) {
    # Synthetic failure only at this existing-file fixture's Export-Clixml boundary.
    function Export-Clixml {
     [CmdletBinding()]param([Parameter(ValueFromPipeline)]$InputObject,[string]$Path)
     process {
      if($Path -cne $ProjectfilePath){throw 'BLOCKED synthetic boundary outside failure fixture'}
      throw 'Synthetic existing-file Export-Clixml failure'
     }
    }
   }
   try {$stream=@(& { . $menuSave; $script:projectStateSaved=$projectStateSaved } 3>&1 6>&1)} finally {if($existing -and $failure){Remove-Item Function:Export-Clixml}}
   Check 'overwrite prompt count' $(if($existing){1}else{0}) $script:promptCount
   Check 'caller boolean result' (!$failure) $projectStateSaved
   Check 'success message' (!$failure) (($stream | Out-String) -match 'Project state saved successfully')
   Check 'warning on failure' $failure (($stream | Out-String) -match 'Project state was not saved')
   Check 'file existence' ($existing -or !$failure) (Test-Path $ProjectfilePath)
   if($failure) {
    Check 'error observed' $true ($global:R2Errors.Count -gt 0)
    if($existing) {
     Check 'synthetic failure labeled' $true (($global:R2Errors | Out-String) -match 'Synthetic existing-file')
     Check 'existing file is not success' $false ($projectStateSaved -ceq $true)
     Check 'original fixture unchanged' $fixtureHash (Get-FileHash $ProjectfilePath).Hash
    }
   } else {
    $loaded=Microsoft.PowerShell.Utility\Import-Clixml -LiteralPath $ProjectfilePath
    Check 'real CLIXML retained code' $GlobalState.lastPSDevCode $loaded.lastPSDevCode
    Check 'real CLIXML version' $GlobalState.FileVersion $loaded.FileVersion
    Check 'real CLIXML provider' $GlobalState.LLMProvider $loaded.LLMProvider
   }
  }
 }
}
Case 'S05-final-success' {
 $ProjectfilePath=Join-Path $dir 'final.xml'
 $stream=@(& { . $saveCall; . $saveMessage; $script:projectStateSaved=$projectStateSaved } 6>&1)
 Check 'caller result' $true $projectStateSaved
 Check 'success message' $true (($stream | Out-String) -match 'has been saved!')
 Check 'file exists' $true (Test-Path $ProjectfilePath)
 $loaded=Microsoft.PowerShell.Utility\Import-Clixml -LiteralPath $ProjectfilePath
 Check 'real CLIXML retained code' $GlobalState.lastPSDevCode $loaded.lastPSDevCode
 Check 'real CLIXML version' $GlobalState.FileVersion $loaded.FileVersion
 Check 'no save errors' 0 $global:R2Errors.Count
}
$after=(Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
$summary=[ordered]@{runtime=$PSVersionTable.PSVersion.ToString();edition=$PSVersionTable.PSEdition;sourcePath=$SourcePath;sourceSHA256=$before;sourceSHA256After=$after;sourcePreserved=($before -eq $after);runnerSHA256=(Get-FileHash $PSCommandPath).Hash;stubModulePath=$stub.Path;stubModuleType=$stub.ModuleType.ToString();caseCount=$results.Count;pass=@($results | Where-Object status -eq PASS).Count;red=@($results | Where-Object status -eq RED).Count;blocked=@($results | Where-Object status -eq BLOCKED).Count;cases=@($results.ToArray());extractionManifest=@($manifest.ToArray())}
# Serialization-only projection: comparisons above retain their original operands.
# Get-Content strings on Windows PowerShell carry live filesystem note properties.
# Copy their exact characters into a new CLR string, never serialize PSObject metadata.
function ReceiptValue($Value, [int]$Depth=0) {
 if($Depth -gt 12){throw 'RECEIPT_DEPTH_LIMIT'}
 if($null -eq $Value){return $null}
 if($Value -is [string]){return (New-Object string -ArgumentList (,$Value.ToCharArray()))}
 if($Value -is [bool] -or $Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]){return $Value}
 if($Value -is [Collections.IDictionary]){$copy=[ordered]@{};foreach($key in $Value.Keys){$copy[[string]$key]=ReceiptValue $Value[$key] ($Depth+1)};return $copy}
 if($Value -is [Collections.IEnumerable]){$copy=@(foreach($item in $Value){ReceiptValue $item ($Depth+1)});return ,$copy}
 throw ('RECEIPT_UNSUPPORTED_TYPE: '+$Value.GetType().FullName)
}
$pending=New-Object Collections.ArrayList
foreach($receipt in $results){$json=ReceiptValue $receipt | ConvertTo-Json -Depth 14;[void]$pending.Add(@{name=($receipt.id+'.json');json=$json})}
$summary.cases = @($results | ForEach-Object { @{id=$_.id;status=$_.status;receipt=($_.id + '.json')} })
[void]$pending.Add(@{name='results.json';json=(ReceiptValue $summary | ConvertTo-Json -Depth 14)})
$bytes=0L;foreach($item in $pending){$size=[Text.Encoding]::UTF8.GetByteCount($item.json)+5;if($size -gt 1048576){throw 'RECEIPT_SIZE_LIMIT'};$bytes+=$size}
$existing=0L;Get-ChildItem $EvidenceRoot -Recurse -File | ForEach-Object {$existing+=$_.Length}
if($existing+$bytes -gt 10485760){throw 'RECEIPT_TOTAL_LIMIT'}
foreach($item in $pending){[IO.File]::WriteAllText((Join-Path $EvidenceRoot $item.name),$item.json,(New-Object Text.UTF8Encoding($true)))}
Remove-Module $stub
[ordered]@{runtime=$summary.runtime;caseCount=$summary.caseCount;pass=$summary.pass;red=$summary.red;blocked=$summary.blocked;sourcePreserved=$summary.sourcePreserved} | ConvertTo-Json -Compress
if($before -ne $after -or $summary.blocked) {exit 2}
if($summary.red) {exit 1}
exit 0
