[CmdletBinding()]
param([Parameter(Mandatory)][string]$RepositoryRoot,[Parameter(Mandatory)][string]$EvidenceRoot,[Parameter(Mandatory)][string]$PSAOAIPath)
$ErrorActionPreference='Stop'
if(Test-Path $EvidenceRoot){throw 'Evidence root must be new'}
$null=New-Item -ItemType Directory $EvidenceRoot
Set-Location $RepositoryRoot
$exe=(Get-Process -Id $PID).Path
$failed=$false
try {
 foreach($path in @('AIPSTeam.ps1','README.md','LICENSE')){if(!(Test-Path -LiteralPath $path)){throw "Missing required file: $path"}}
 $pin='6a19493e954214dfb193733edbaebd6922a23c4d'
 $head= & git -C $PSAOAIPath rev-parse HEAD
 if($LASTEXITCODE -ne 0 -or $head -ne $pin){throw 'PSAOAI checkout commit mismatch'}
 # SHA256 of Git file bytes with CRLF pairs normalized to LF ONLY.
 # UTF8 decoding/encoding preserves the BOM; no trim or platform text defaults.
 $pins=@{
 'Public/Invoke-PSAOAIChatCompletion.ps1'='8C7171BAE763BBCC5D27EF68FEAF97480370DFD71A7AB62BBAE9373CDFE972E3'
 'Private/Get-PSAOAIChatBody.ps1'='00E246C9C024A46ADBCE1F081627D88D34CDDD72B298B01E27D0B779979959CF'
 'Private/Get-PSAOAIChatBodyo1.ps1'='03911D3F8272099095595D6428AFDD86FCEC48F4AC338E48E322C5A7712667A1'
 'Private/Get-PSAOAIUrl.ps1'='E88AC6FD42914927C203D42DDC37E95FBA5CA2DC8F8FFFD98C84D388C883874F'
 'Private/Get-EnvironmentVariable.ps1'='417D6C8A3E5B7C889B21EE754C7186D94C8478FC7186F5E6673796A5403CA1D1'
 'Private/Set-EnvironmentVariable.ps1'='B6A69D5503E9F28E5CDB91A2E350DF8744B0AF30F40B642014FF55FB01F0A81E'
 'Private/Test-UserEnvironmentVariable.ps1'='C248C7DBD0F47BD7C1F45B7E9D8BF510EBB0C0E29F266E3A86552CD4C15677D1'
 'Private/Get-Headers.ps1'='A98155448CCFB949623977F3C188DF6C7DAC408B76C70FC3E37842B45779BB23'
 }
 $guards=@(foreach($path in ($pins.Keys | Sort-Object)){
  $bytes=[IO.File]::ReadAllBytes((Join-Path $PSAOAIPath $path))
  $text=[Text.Encoding]::UTF8.GetString($bytes).Replace("`r`n","`n")
  $sha=[Security.Cryptography.SHA256]::Create()
  try{$actual=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)))).Replace('-','')}finally{$sha.Dispose()}
  if($actual -ne $pins[$path]){throw "PSAOAI file mismatch: $path"}
  @{path=$path;normalizedSHA256=$actual}
 })
 @{commit=$head;normalization='CRLF to LF only; UTF8 BOM preserved';files=$guards}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $EvidenceRoot 'psaoai-pin.json') -Encoding UTF8
 $files=@(Get-ChildItem -Path . -Recurse -Include *.ps1,*.psm1,*.psd1 -File | Where-Object {$_.FullName -notmatch '[\\/]\.git[\\/]'})
 if(!$files.Count){throw 'No PowerShell source files found'}
 $reports=@(foreach($file in $files){$t=$null;$e=$null;$null=[System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$t,[ref]$e);@{file=$file.FullName;errors=@($e | ForEach-Object {$_.Message});count=@($e).Count}})
 $reports | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $EvidenceRoot 'whole-source-parser.json') -Encoding UTF8
 if(@($reports | Where-Object {$_.count}).Count){throw 'PowerShell parse errors detected'}
 $hash=(Get-FileHash -LiteralPath './AIPSTeam.ps1' -Algorithm SHA256).Hash
 $ErrorActionPreference='Continue'
 & $exe -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot 'Test-PowerShellParser.ps1') -ScriptPath ./AIPSTeam.ps1 *> (Join-Path $EvidenceRoot 'parser.json')
 if($LASTEXITCODE -ne 0){$failed=$true}
 $runs=@(
  @{name='contracts';runner='Test-ReleaseContracts.ps1'},
  @{name='startup';runner='Test-StartupContracts.ps1'},
  @{name='draft';runner='Test-DraftValidationContracts.ps1'},
  @{name='legacy';runner='Test-LegacyAzureIntegration.ps1'}
 )
 $exits=@(foreach($run in $runs){
  $args=@{SourcePath='./AIPSTeam.ps1';ExpectedSourceSHA256=$hash;EvidenceRoot=(Join-Path $EvidenceRoot $run.name)}
  if($run.name -eq 'legacy'){$args.PSAOAIPath=$PSAOAIPath}
  & $exe -NoProfile -NonInteractive -File (Join-Path $PSScriptRoot $run.runner) @args *> (Join-Path $EvidenceRoot ($run.name+'.log'))
  $code=$LASTEXITCODE;if($code -ne 0){$failed=$true}
  @{suite=$run.name;exitCode=$code}
 })
 $ErrorActionPreference='Stop'
 @{runtime=$PSVersionTable.PSVersion.ToString();sourceSHA256=$hash;suites=$exits;sourcePreserved=((Get-FileHash './AIPSTeam.ps1').Hash -eq $hash)}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $EvidenceRoot 'runner-results.json') -Encoding UTF8
 if((Get-FileHash './AIPSTeam.ps1').Hash -ne $hash){throw 'Source preservation failed'}
} catch {$_ | Out-String | Set-Content (Join-Path $EvidenceRoot 'failure.log');$failed=$true}
foreach($report in @('psaoai-pin.json','whole-source-parser.json','parser.json','runner-results.json','contracts/results.json','contracts.log','startup/summary.json','startup.log','draft/summary.json','draft.log','legacy/summary.json','legacy.log')){if(!(Test-Path (Join-Path $EvidenceRoot $report))){$failed=$true;Write-Error "Missing report: $report" -ErrorAction Continue}}
if($failed){exit 1}
exit 0
