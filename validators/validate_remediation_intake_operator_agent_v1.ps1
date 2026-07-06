param(
    [switch]$FinalizePhase,
    [string]$RunId,
    [string]$RepoRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-RequiredPath {
    param(
        [string]$Path,
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "$Label path must not be empty."
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$Label missing: $Path"
    }
}

function Assert-PathMissing {
    param(
        [string]$Path,
        [string]$Label
    )

    if (Test-Path -LiteralPath $Path) {
        throw "$Label must not exist before PHASE67 runtime: $Path"
    }
}

function Read-JsonFile {
    param([string]$Path)
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    $Directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($Directory) -and -not (Test-Path -LiteralPath $Directory)) {
        New-Item -ItemType Directory -Force -Path $Directory | Out-Null
    }

    $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Assert-JsonParse {
    param([string]$Path)
    $null = Read-JsonFile -Path $Path
}

function Get-JsonValue {
    param(
        [object]$Object,
        [string]$Name,
        [string]$Label
    )

    if ($null -eq $Object) { throw "$Label is null." }
    $Property = $Object.PSObject.Properties[$Name]
    if ($null -eq $Property) { throw "$Label missing property: $Name" }
    return $Property.Value
}

function Assert-RequiredStringProperty {
    param(
        [object]$Object,
        [string]$Name,
        [string]$Label
    )

    $Value = Get-JsonValue -Object $Object -Name $Name -Label $Label
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        throw "$Label property must not be empty: $Name"
    }

    return ([string]$Value).Trim()
}

function Assert-ContainsAll {
    param(
        [object[]]$Actual,
        [string[]]$Expected,
        [string]$Label
    )

    foreach ($ExpectedValue in $Expected) {
        if (@($Actual) -notcontains $ExpectedValue) {
            throw "$Label missing expected value: $ExpectedValue"
        }
    }
}

function Assert-PowerShellParse {
    param(
        [string]$Path,
        [string]$Label
    )

    $Tokens = $null
    $Errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path -LiteralPath $Path).Path,
        [ref]$Tokens,
        [ref]$Errors
    ) | Out-Null

    if (@($Errors).Count -ne 0) {
        $Message = (@($Errors) | ForEach-Object { $_.Message }) -join "; "
        throw "$Label PowerShell parser check failed: $Message"
    }
}

function Add-CompletedCapability {
    param(
        [object]$State,
        [string]$CompletedCapabilityId
    )

    if (@($State.completed_capabilities) -notcontains $CompletedCapabilityId) {
        $State.completed_capabilities += $CompletedCapabilityId
    }
}

function Get-SingleByProperty {
    param(
        [object[]]$Items,
        [string]$PropertyName,
        [string]$ExpectedValue,
        [string]$Label
    )

    $Matches = @($Items | Where-Object { $_.$PropertyName -eq $ExpectedValue })
    if ($Matches.Count -ne 1) {
        throw "$Label expected exactly one item where $PropertyName = $ExpectedValue, found $($Matches.Count)."
    }

    return $Matches[0]
}

if (-not $FinalizePhase) {
    throw "PHASE67 external agent production validator requires -FinalizePhase."
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
    $RepoRoot = (Get-Location).Path
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $RepoRoot

$CapabilityId = "external_agent_production_program_test_v1"
$TaskId = "TASK_EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1_001"
$Gate = "EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1"
$AgentId = "remediation_intake_operator_agent_v1"
$AgentPath = "generated_agents/remediation_intake_operator_agent_v1"
$AgentRoot = Join-Path $RepoRoot $AgentPath
$ProofPath = "proofs/EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1.json"
$ReportPath = "reports/external_agent_production/EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1_REPORT.json"
$RuntimeOutputPath = Join-Path $AgentRoot "OUTPUT_EXAMPLE_RUNTIME.json"
$RuntimeOutputRepoPath = "$AgentPath/OUTPUT_EXAMPLE_RUNTIME.json"
$NextRecommendedTrack = "external_agent_production_test_2"

Assert-PathMissing -Path (Join-Path $RepoRoot $ProofPath) -Label "PHASE67 proof"
Assert-PathMissing -Path (Join-Path $RepoRoot $ReportPath) -Label "PHASE67 report"

$RequiredAgentFiles = @(
    "README.md",
    "AGENT_SPEC.json",
    "RUNBOOK.md",
    "INPUT_EXAMPLE.json",
    "OUTPUT_EXAMPLE.json",
    "run.ps1",
    "proofs/README.md"
)

foreach ($RelativePath in $RequiredAgentFiles) {
    Assert-RequiredPath -Path (Join-Path $AgentRoot $RelativePath) -Label "Agent required file"
}

$SpecPath = Join-Path $AgentRoot "AGENT_SPEC.json"
$InputExamplePath = Join-Path $AgentRoot "INPUT_EXAMPLE.json"
$OutputExamplePath = Join-Path $AgentRoot "OUTPUT_EXAMPLE.json"
$RunScriptPath = Join-Path $AgentRoot "run.ps1"

Assert-JsonParse -Path $SpecPath
Assert-JsonParse -Path $InputExamplePath
Assert-JsonParse -Path $OutputExamplePath
Assert-PowerShellParse -Path $RunScriptPath -Label "remediation intake operator run.ps1"

$Spec = Read-JsonFile -Path $SpecPath
if ((Assert-RequiredStringProperty -Object $Spec -Name "agent_id" -Label "AGENT_SPEC.json") -ne $AgentId) { throw "AGENT_SPEC agent_id mismatch." }
if ((Assert-RequiredStringProperty -Object $Spec -Name "agent_name" -Label "AGENT_SPEC.json") -ne "Remediation Intake Operator Agent v1") { throw "AGENT_SPEC agent_name mismatch." }
if ((Assert-RequiredStringProperty -Object $Spec -Name "agent_kind" -Label "AGENT_SPEC.json") -ne "external_operator_agent") { throw "AGENT_SPEC agent_kind mismatch." }
if ((Assert-RequiredStringProperty -Object $Spec -Name "purpose" -Label "AGENT_SPEC.json") -ne "intake and structure remediation/problem reports") { throw "AGENT_SPEC purpose mismatch." }

$InputContract = Get-JsonValue -Object $Spec -Name "input_contract" -Label "AGENT_SPEC.json"
$OutputContract = Get-JsonValue -Object $Spec -Name "output_contract" -Label "AGENT_SPEC.json"
$ValidationContract = Get-JsonValue -Object $Spec -Name "validation_contract" -Label "AGENT_SPEC.json"
$RequiredInputFields = @("problem_title", "problem_description", "affected_system", "urgency", "observed_evidence")
$RequiredOutputFields = @("normalized_problem", "severity", "likely_area", "missing_information", "recommended_next_step", "operator_note", "validation_status")
Assert-ContainsAll -Actual @(Get-JsonValue -Object $InputContract -Name "required" -Label "input_contract") -Expected $RequiredInputFields -Label "input_contract.required"
Assert-ContainsAll -Actual @(Get-JsonValue -Object $OutputContract -Name "required" -Label "output_contract") -Expected $RequiredOutputFields -Label "output_contract.required"
if ((Assert-RequiredStringProperty -Object $ValidationContract -Name "required_status" -Label "validation_contract") -ne "PASS") {
    throw "validation_contract.required_status must be PASS."
}

$InputExample = Read-JsonFile -Path $InputExamplePath
foreach ($Field in $RequiredInputFields) {
    $Value = Get-JsonValue -Object $InputExample -Name $Field -Label "INPUT_EXAMPLE.json"
    if ($Field -eq "observed_evidence") {
        if (@($Value).Count -eq 0) { throw "INPUT_EXAMPLE observed_evidence must contain at least one item." }
    }
    elseif ([string]::IsNullOrWhiteSpace([string]$Value)) {
        throw "INPUT_EXAMPLE required field must not be empty: $Field"
    }
}

$OutputExample = Read-JsonFile -Path $OutputExamplePath
foreach ($Field in $RequiredOutputFields) {
    $null = Get-JsonValue -Object $OutputExample -Name $Field -Label "OUTPUT_EXAMPLE.json"
}
if ([string](Get-JsonValue -Object $OutputExample -Name "validation_status" -Label "OUTPUT_EXAMPLE.json") -ne "PASS") {
    throw "OUTPUT_EXAMPLE validation_status must be PASS."
}

if (Test-Path -LiteralPath $RuntimeOutputPath) {
    Remove-Item -LiteralPath $RuntimeOutputPath -Force
}

$RunOutput = @(& $RunScriptPath -InputPath $InputExamplePath -OutputPath $RuntimeOutputPath 2>&1)
$RunOutputText = ($RunOutput | ForEach-Object { $_.ToString() }) -join "`n"
if ($RunOutputText -notmatch "REMEDIATION_INTAKE_OPERATOR_STATUS=PASS") {
    throw "run.ps1 did not print REMEDIATION_INTAKE_OPERATOR_STATUS=PASS."
}

Assert-RequiredPath -Path $RuntimeOutputPath -Label "runtime output"
Assert-JsonParse -Path $RuntimeOutputPath
$RuntimeOutput = Read-JsonFile -Path $RuntimeOutputPath
foreach ($Field in $RequiredOutputFields) {
    $null = Get-JsonValue -Object $RuntimeOutput -Name $Field -Label "OUTPUT_EXAMPLE_RUNTIME.json"
}
if ([string](Get-JsonValue -Object $RuntimeOutput -Name "validation_status" -Label "OUTPUT_EXAMPLE_RUNTIME.json") -ne "PASS") {
    throw "OUTPUT_EXAMPLE_RUNTIME validation_status must be PASS."
}

$State = Read-JsonFile ".\GENESIS_STATE.json"
$Roadmap = Read-JsonFile ".\CAPABILITY_ROADMAP.json"
$Queue = Read-JsonFile ".\TASK_QUEUE.json"

if ([string]$Queue.active_task_id -ne $TaskId) {
    throw "PHASE67 validator requires TASK_QUEUE active_task_id=$TaskId before runtime."
}
if ([string]$State.current_phase -ne "PHASE_67") { throw "State current_phase must be PHASE_67 before PHASE67 runtime." }
if ([string]$State.current_capability -ne $CapabilityId) { throw "State current_capability must be $CapabilityId before PHASE67 runtime." }

$Capability = Get-SingleByProperty -Items @($Roadmap.capabilities) -PropertyName "id" -ExpectedValue $CapabilityId -Label "PHASE67 capability"
$Task = Get-SingleByProperty -Items @($Queue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE67 task"
if ([string]$Capability.status -ne "ACTIVE") { throw "PHASE67 capability must be ACTIVE before runtime." }
if ([string]$Task.status -ne "ACTIVE") { throw "PHASE67 task must be ACTIVE before runtime." }

$Capability.status = "COMPLETED"
$Task.status = "COMPLETED"
$Queue.active_task_id = "NONE"
Add-CompletedCapability -State $State -CompletedCapabilityId $CapabilityId
$State.current_phase = "PHASE_67"
$State.current_capability = $CapabilityId
$State.last_run_status = "PASS"

$CreatedFiles = @(
    "$AgentPath/README.md",
    "$AgentPath/AGENT_SPEC.json",
    "$AgentPath/RUNBOOK.md",
    "$AgentPath/INPUT_EXAMPLE.json",
    "$AgentPath/OUTPUT_EXAMPLE.json",
    "$AgentPath/run.ps1",
    "$AgentPath/proofs/README.md",
    $RuntimeOutputRepoPath
)

$ChecksPassed = @(
    "required files present",
    "AGENT_SPEC.json valid and identity matched",
    "INPUT_EXAMPLE.json valid",
    "OUTPUT_EXAMPLE.json valid",
    "run.ps1 PowerShell parser check passed",
    "run.ps1 produced OUTPUT_EXAMPLE_RUNTIME.json",
    "runtime output contains required fields",
    "runtime output validation_status is PASS",
    "PHASE67 task and capability finalized",
    "TASK_QUEUE active_task_id returned to NONE"
)

$Proof = [ordered]@{
    proof_id = "EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1"
    run_id = $RunId
    status = "PASS"
    produced_agent_id = $AgentId
    produced_agent_path = $AgentPath
    required_files_present = $true
    validator_status = "PASS"
    runtime_example_status = "PASS"
    active_task_after = "NONE"
    next_recommended_track = $NextRecommendedTrack
    runtime_output_path = $RuntimeOutputRepoPath
    report_path = $ReportPath
}

$Report = [ordered]@{
    report_id = "EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1_REPORT"
    proof_id = "EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1"
    status = "PASS"
    produced_agent_id = $AgentId
    created = $CreatedFiles
    location = $AgentPath
    how_to_run = "pwsh -File generated_agents/remediation_intake_operator_agent_v1/run.ps1 -InputPath generated_agents/remediation_intake_operator_agent_v1/INPUT_EXAMPLE.json -OutputPath generated_agents/remediation_intake_operator_agent_v1/OUTPUT_EXAMPLE_RUNTIME.json"
    checks_passed = $ChecksPassed
    what_this_proves = "The Builder can produce a standalone external operator agent package, validate its local runtime contract, and complete the production-program task with proof-backed state."
    proof_path = $ProofPath
    next_recommended_track = $NextRecommendedTrack
}

Write-JsonFile -Path $ProofPath -Value $Proof
Write-JsonFile -Path $ReportPath -Value $Report
Write-JsonFile -Path ".\CAPABILITY_ROADMAP.json" -Value $Roadmap
Write-JsonFile -Path ".\TASK_QUEUE.json" -Value $Queue
Write-JsonFile -Path ".\GENESIS_STATE.json" -Value $State

Assert-JsonParse ".\CAPABILITY_ROADMAP.json"
Assert-JsonParse ".\GENESIS_STATE.json"
Assert-JsonParse ".\TASK_QUEUE.json"
Assert-JsonParse ".\packs\registry.json"
Assert-JsonParse $ProofPath
Assert-JsonParse $ReportPath

Write-Host "EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1_STATUS=PASS"
Write-Host "EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1_AGENT_ID=$AgentId"
Write-Host "EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1_ACTIVE_TASK_AFTER=NONE"
Write-Host "EXTERNAL_AGENT_PRODUCTION_PROGRAM_TEST_V1_NEXT_RECOMMENDED_TRACK=$NextRecommendedTrack"
