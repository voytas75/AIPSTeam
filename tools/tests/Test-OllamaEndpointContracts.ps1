param(
    [string]$SourcePath = (Join-Path $PSScriptRoot '../../AIPSTeam.ps1'),
    [Parameter(Mandatory)][string]$EvidenceRoot
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile($SourcePath,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'SOURCE_PARSE_FAILURE'}
$text=[IO.File]::ReadAllText((Resolve-Path $SourcePath))
$start=$text.IndexOf('#region ollama')
$end=$text.IndexOf('    if (Test-OllamaAPI)', $start)
if($start -lt 0 -or $end -lt 0){throw 'ENDPOINT_SECTION_MISSING'}
$section=$text.Substring($start,$end-$start) + "`n}"
$helpers=@($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-EnvValue'},$true))
if($helpers.Count -ne 1){throw 'HELPER_NOT_UNIQUE'}
# Only the OS getter is replaced; the original scope-selection logic executes.
$helper=$helpers[0].Extent.Text.Replace('[System.Environment]::GetEnvironmentVariable(', '(Get-FixtureEnvironmentValue ')
# Convert the known getter arguments into PowerShell command arguments.
$helper=$helper.Replace('$Name, "Process")','$Name "Process")').Replace('$Name, "User")','$Name "User")').Replace('$Name, "Machine")','$Name "Machine")')
function Get-FixtureEnvironmentValue {param($Name,$Scope) $script:values["$Name/$Scope"]}
Invoke-Expression $helper
$cases=@(
    @{id='endpoint'; ep='http://endpoint:11434'; host=''; expected='http://endpoint:11434/'},
    @{id='host-only'; ep=''; host='http://host:11434'; expected='http://host:11434/'},
    @{id='neither'; ep=''; host=''; expected='http://localhost:11434/'},
    @{id='both'; ep='http://endpoint:11434'; host='http://host:11434'; expected='http://endpoint:11434/'},
    @{id='slash'; ep='http://endpoint:11434/'; host=''; expected='http://endpoint:11434/'},
    @{id='whitespace-endpoint'; ep='  '; host='http://host:11434/'; expected='http://host:11434/'},
    @{id='whitespace-both'; ep=" `t"; host=' '; expected='http://localhost:11434/'},
    @{id='trim'; ep='  http://endpoint:11434/  '; host=''; expected='http://endpoint:11434/'},
    @{id='user-endpoint-over-process-host'; ep=''; user='http://user:11434'; host='http://host:11434'; expected='http://user:11434/'},
    @{id='process-over-user'; ep='http://process:11434'; user='http://user:11434'; host=''; expected='http://process:11434/'},
    @{id='user-host'; ep=''; host=''; userhost='http://userhost:11434'; expected='http://userhost:11434/'},
    @{id='machine-endpoint'; ep=''; host=''; machine='http://machine:11434'; expected='http://machine:11434/'}
)
$results=@()
foreach($case in $cases){
    $script:values=@{'OLLAMA_ENDPOINT/Process'=$case.ep; 'OLLAMA_ENDPOINT/User'=$case.user; 'OLLAMA_ENDPOINT/Machine'=$case.machine; 'OLLAMA_HOST/Process'=$case.host; 'OLLAMA_HOST/User'=$case.userhost}
    $script:ollamaEndpoint=$null
    $GlobalState=@{LLMProvider='ollama'}; $LoadProjectStatus=$false
    $passed=$false; $failure=$null
    try {
        # Refuse all environment writes before executing any extracted code.
        $safeSection=$section.Replace('$env:OLLAMA_ENDPOINT = $defaultEndpoint', "throw 'ENV_WRITE_IN_ENDPOINT_SECTION'")
        Invoke-Expression $safeSection
        $passed=$script:ollamaEndpoint -ceq $case.expected
        if(-not $passed){$failure='ENDPOINT_MISMATCH'}
    } catch {$failure=if($_.Exception.Message -eq 'ENV_WRITE_IN_ENDPOINT_SECTION'){'ENV_WRITE_IN_ENDPOINT_SECTION'}else{'EXECUTION_FAILURE'}}
    $results+= [pscustomobject]@{id=$case.id; passed=$passed; failure=$failure}
}
$results+= [pscustomobject]@{id='no-endpoint-env-writes'; passed=($section -notmatch 'SetEnvironmentVariable|\$env:'); failure=$null}
$summary=[pscustomobject]@{runtime=$PSVersionTable.PSVersion.ToString(); sourceSHA256=(Get-FileHash $SourcePath -Algorithm SHA256).Hash; cases=$results.Count; passed=@($results|Where-Object passed).Count; failed=@($results|Where-Object {-not $_.passed}).Count; parserErrors=$errors.Count; results=$results}
$json=$summary|ConvertTo-Json -Depth 5
[IO.File]::WriteAllText((Join-Path $EvidenceRoot 'summary.json'),$json)
$json
if($summary.failed){exit 1}
