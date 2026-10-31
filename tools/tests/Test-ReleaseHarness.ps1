[CmdletBinding()]
param([Parameter(Mandatory)][string]$SourcePath,[Parameter(Mandatory)][string]$EvidenceRoot,[Parameter(Mandatory)][string]$PreviousResultsPath)
$ErrorActionPreference='Stop'
if(Test-Path $EvidenceRoot){throw 'Evidence root must be new'}
$null=New-Item -ItemType Directory $EvidenceRoot
$exe=(Get-Process -Id $PID).Path
$runner=Join-Path $PSScriptRoot 'Test-ReleaseContracts.ps1'
$parser=Join-Path $PSScriptRoot 'Test-PowerShellParser.ps1'
$hash=(Get-FileHash $SourcePath).Hash
$old=Get-Content $PreviousResultsPath -Raw | ConvertFrom-Json
$checks=New-Object System.Collections.ArrayList
function Assert($Name,$Pass){$null=$checks.Add(@{name=$Name;pass=[bool]$Pass});if(!$Pass){throw "Harness assertion failed: $Name"}}
function Launch($Path,$Expected,$Root,$Log){
 $savedPreference=$ErrorActionPreference
 try {
  $ErrorActionPreference='Continue'
  & $exe -NoProfile -NonInteractive -File $runner -SourcePath $Path -ExpectedSourceSHA256 $Expected -EvidenceRoot $Root *> $Log
  return $LASTEXITCODE
 } finally {$ErrorActionPreference=$savedPreference}
}
$full=Join-Path $EvidenceRoot 'contracts'
Assert 'full matrix exit' ((Launch $SourcePath $hash $full (Join-Path $EvidenceRoot 'contracts.log')) -eq 0)
$new=Get-Content (Join-Path $full 'results.json') -Raw | ConvertFrom-Json
Assert '37 cases' ($new.caseCount -eq 37 -and $new.pass -eq 37 -and $new.red -eq 0 -and $new.blocked -eq 0)
$count=0
foreach($c in $new.cases){
 $r=Get-Content (Join-Path $full $c.receipt) -Raw | ConvertFrom-Json
 $prior=Get-Content (Join-Path (Split-Path $PreviousResultsPath) $c.receipt) -Raw | ConvertFrom-Json
 $currentAssertions=$r.assertions | ConvertTo-Json -Depth 10 -Compress
 $priorAssertions=$prior.assertions | ConvertTo-Json -Depth 10 -Compress
 # Only relocate the owned case-directory prefix; preserve all other values.
 $priorRoot=if($prior.files.Count){Split-Path (Split-Path $prior.files[0].path)}else{Split-Path $PreviousResultsPath}
 if($c.id -like 'W03*file') {$priorRoot=Split-Path (Split-Path ($prior.assertions | Where-Object assertion -eq 'analyzed exact path').expected)}
 Assert "$($c.id) assertion count unchanged" ($r.assertions.Count -eq $prior.assertions.Count)
 for($j=0;$j -lt $r.assertions.Count;$j++) {
  foreach($field in @('assertion','pass')) {
   $a=$r.assertions[$j].$field | ConvertTo-Json -Depth 10 -Compress
   $b=$prior.assertions[$j].$field | ConvertTo-Json -Depth 10 -Compress
   # Historical exports intentionally embed wall-clock time; compare payload
   # after normalizing only that generated header, never the code body.
   $a=$a -replace '# exported [^\\]*(?=\\n)','# exported TIMESTAMP'
   $b=$b -replace '# exported [^\\]*(?=\\n)','# exported TIMESTAMP'
   Assert "$($c.id) assertion $j $field unchanged" ($a.Replace(($full | ConvertTo-Json -Compress).Trim('"'),'EVIDENCE') -ceq $b.Replace(($priorRoot | ConvertTo-Json -Compress).Trim('"'),'EVIDENCE'))
  }
 }
 Assert "$($c.id) independently pass/hash" ($r.status -eq 'PASS' -and $r.sourceSHA256 -eq $hash -and @($r.assertions | Where-Object {!$_.pass}).Count -eq 0)
 $count+=@($r.assertions).Count
}
Assert '172 assertions' ($count -eq 172)
Assert 'manifest count' ($new.extractionManifest.Count -eq $old.extractionManifest.Count)
for($i=0;$i -lt $old.extractionManifest.Count;$i++){Assert "original body $i identical" ($old.extractionManifest[$i].text -ceq $new.extractionManifest[$i].text)}
$consoleText=Get-Content (Join-Path $EvidenceRoot 'contracts.log') -Raw
$consoleMatch=[regex]::Matches($consoleText,'\{"runtime"[^\r\n]*"sourcePreserved"\s*:\s*(?:true|false)\}') | Select-Object -Last 1
$console=$consoleMatch.Value | ConvertFrom-Json
Assert 'console runtime/counts' ($console.runtime -eq $new.runtime -and $console.caseCount -eq 37 -and $console.pass -eq 37 -and $console.red -eq 0 -and $console.blocked -eq 0 -and $console.sourcePreserved)
$text=[IO.File]::ReadAllText($SourcePath)
$enc=New-Object System.Text.UTF8Encoding($true)
# Synthetic admission fixtures never execute whole-source startup.
$fixtures=@(
 @{id='wrong-hash';text=$text;expected=('0'*64);message='Source hash mismatch'},
 @{id='missing-workflow';text=$text.Replace('if (-not $LoadProjectStatus) {','if (-not $R3MissingWorkflow) {');message='Selection workflow requires exactly one AST node; found 0'},
 @{id='ambiguous-workflow';text=($text+"`nif (-not `$LoadProjectStatus) { New-AIPSTeamDeveloperPrompt; throw 'must never execute' }`n");message='Selection workflow requires exactly one AST node; found 2'}
)
foreach($f in $fixtures){
 $path=Join-Path $EvidenceRoot ($f.id+'.ps1');[IO.File]::WriteAllText($path,$f.text,$enc)
 $expected=if($f.expected){$f.expected}else{(Get-FileHash $path).Hash}
 $root=Join-Path $EvidenceRoot ($f.id+'-forbidden');$log=Join-Path $EvidenceRoot ($f.id+'.log')
 $before=(Get-FileHash $path).Hash
 Assert "$($f.id) rejected" ((Launch $path $expected $root $log) -ne 0)
 Assert "$($f.id) diagnostic" ((Get-Content $log -Raw).Contains($f.message))
 Assert "$($f.id) no writes or source change" (!(Test-Path $root) -and (Get-FileHash $path).Hash -eq $before)
}
$shift=Join-Path $EvidenceRoot 'shifted.ps1'
[IO.File]::WriteAllText($shift,"# disposable locator shift`n`n# second comment`n`n"+$text,$enc)
$shiftHash=(Get-FileHash $shift).Hash
$shiftRoot=Join-Path $EvidenceRoot 'shifted-contracts'
Assert 'shifted full matrix' ((Launch $shift $shiftHash $shiftRoot (Join-Path $EvidenceRoot 'shifted.log')) -eq 0)
$s=Get-Content (Join-Path $shiftRoot 'results.json') -Raw | ConvertFrom-Json
Assert 'shifted preservation and counts' ($s.sourcePreserved -and $s.sourceSHA256 -eq $shiftHash -and $s.pass -eq 37 -and $s.red -eq 0 -and $s.blocked -eq 0)
for($i=0;$i -lt $new.extractionManifest.Count;$i++){Assert "shifted body $i identical" ($new.extractionManifest[$i].text -ceq $s.extractionManifest[$i].text -and $s.extractionManifest[$i].start -eq ($new.extractionManifest[$i].start+4))}
& $exe -NoProfile -NonInteractive -File $parser -ScriptPath $SourcePath *> (Join-Path $EvidenceRoot 'parser.json')
Assert 'parser exit' ($LASTEXITCODE -eq 0)
$p=Get-Content (Join-Path $EvidenceRoot 'parser.json') -Raw | ConvertFrom-Json
Assert 'parser independent readback' ($p.ParseErrors -eq 0 -and $p.SHA256 -eq $hash -and $p.Runtime -eq $new.runtime)
Assert 'production source preserved' ((Get-FileHash $SourcePath).Hash -eq $hash)
[ordered]@{runtime=$new.runtime;caseCount=$new.caseCount;assertions=$count;sourceSHA256=$hash;shiftedSHA256=$shiftHash;checks=@($checks.ToArray());pass=$true} | ConvertTo-Json -Depth 6 | Set-Content (Join-Path $EvidenceRoot 'harness-results.json') -Encoding UTF8
Write-Output "Harness PASS: $($checks.Count) checks, 37 cases, 172 assertions"
