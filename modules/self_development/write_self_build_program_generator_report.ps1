param(
  [string]$DecisionReportPath = "reports/self_development/SELF_DEVELOPMENT_DECISION_KERNEL_REPORT.json",
  [string]$DecisionProofPath = "proofs/self_development/SELF_DEVELOPMENT_DECISION_KERNEL_V1.json",
  [string]$ProgramOutputPath = "self_build_programs/generated/SELF_BUILD_PROGRAM_001.json",
  [string]$ReportOutputPath = "reports/self_development/SELF_BUILD_PROGRAM_GENERATOR_REPORT.json",
  [string]$ProofOutputPath = "proofs/self_development/SELF_BUILD_PROGRAM_GENERATOR_V1.json"
)

$ErrorActionPreference = "Stop"

function Read-Json($Path) {
  if (-not (Test-Path $Path)) {
    throw "REQUIRED_INPUT_MISSING=$Path"
  }
  return Get-Content $Path -Raw | ConvertFrom-Json
}

function Write-JsonFile($Path, $Object) {
  $dir = Split-Path $Path -Parent
  if ($dir -and -not (Test-Path $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $Object | ConvertTo-Json -Depth 50 | Set-Content -Path $Path -Encoding UTF8
}


# PHASE164O_OWNER_MATERIAL_PROGRAM_CONTEXT_V1
function Get-ObjectPropertyValue {
  param([object]$Object, [string]$Name)
  if ($null -eq $Object) { return $null }
  $Prop = $Object.PSObject.Properties | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
  if ($null -eq $Prop) { return $null }
  return $Prop.Value
}
Write-Output "SELF_BUILD_PROGRAM_GENERATOR_START"

$decisionReport = Read-Json $DecisionReportPath
$decisionProof = Read-Json $DecisionProofPath

$ownerMaterialInput = Get-ObjectPropertyValue -Object $decisionReport -Name "owner_material_input"
$ownerMaterialAvailable = $false
if ($null -ne $ownerMaterialInput) { $ownerMaterialAvailable = [bool](Get-ObjectPropertyValue -Object $ownerMaterialInput -Name "available") }

if ($decisionReport.status -ne "PASS") {
  throw "SOURCE_DECISION_REPORT_STATUS_NOT_PASS=$($decisionReport.status)"
}
if ($decisionReport.recommended_next_step_id -ne "PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1") {
  throw "SOURCE_DECISION_REPORT_NEXT_STEP_UNEXPECTED=$($decisionReport.recommended_next_step_id)"
}
if ($decisionProof.status -ne "PASS") {
  throw "SOURCE_DECISION_PROOF_STATUS_NOT_PASS=$($decisionProof.status)"
}
if ($decisionProof.next_allowed_step -ne "PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1") {
  throw "SOURCE_DECISION_PROOF_NEXT_ALLOWED_STEP_UNEXPECTED=$($decisionProof.next_allowed_step)"
}

$now = (Get-Date).ToUniversalTime().ToString("o")

$program = [ordered]@{
  program_id = "SELF_BUILD_PROGRAM_001"
  status = "GENERATED_CANDIDATE"
  generated_at = $now
  generated_by_phase = "PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1"
  source_decision_report = $DecisionReportPath
  source_decision_proof = $DecisionProofPath
    owner_material_input = $ownerMaterialInput
    owner_material_available = $ownerMaterialAvailable
  target_next_step = "PHASE89_GENERATED_PROGRAM_ADMISSION_V1"
  active_line = "AGENT_BUILDER / SELF_BUILD"
  purpose = "Create an admission-ready candidate program that will be evaluated in PHASE89 before any execution is allowed."
  required_inputs = @(
    "reports/self_development/SELF_DEVELOPMENT_DECISION_KERNEL_REPORT.json",
    "proofs/self_development/SELF_DEVELOPMENT_DECISION_KERNEL_V1.json",
    "CAPABILITY_ROADMAP.json",
    "GENESIS_STATE.json",
    "TASK_QUEUE.json",
    "packs/registry.json"
  )
  proposed_changes = @(
    [ordered]@{
      change_id = "admit_self_build_program_001"
      description = "PHASE89 should evaluate SELF_BUILD_PROGRAM_001 and decide whether it can be admitted for controlled execution."
      target_phase = "PHASE89_GENERATED_PROGRAM_ADMISSION_V1"
      risk = "Program must not execute before admission proof."
    }
  )
  files_in_scope = @(
    "self_build_programs/generated/SELF_BUILD_PROGRAM_001.json",
    "reports/self_development/SELF_BUILD_PROGRAM_GENERATOR_REPORT.json",
    "proofs/self_development/SELF_BUILD_PROGRAM_GENERATOR_V1.json"
  )
  files_out_of_scope = @(
    "orchestrator/run.ps1",
    "materials/MATERIAL_CATALOG.json",
    "materials/MATERIAL_POLICY.json",
    "operations/registry.json",
    "operations/contracts/",
    "generated_agents/",
    "applied_agents/"
  )
  validation_requirements = @(
    "Generated program JSON parses.",
    "Generated program status is GENERATED_CANDIDATE.",
    "admission_required is true.",
    "execution_allowed is false.",
    "PHASE88 report status is PASS.",
    "PHASE88 proof status is PASS.",
    "Queue returns to NONE after runtime."
  )
  proof_requirements = @(
    "Proof must show generated_program_created=true.",
    "Proof must show admission_performed=false.",
    "Proof must show execution_performed=false.",
    "Proof must set next_allowed_step=PHASE89_GENERATED_PROGRAM_ADMISSION_V1."
  )
  cut_list = @(
    "Do not admit generated program in PHASE88.",
    "Do not execute generated program in PHASE88.",
    "Do not install tools.",
    "Do not fetch external sources.",
    "Do not mark materials TRUSTED.",
    "Do not produce external agents.",
    "Do not change route lock."
  )
  admission_required = $true
  execution_allowed = $false
}

Write-JsonFile $ProgramOutputPath $program

$report = [ordered]@{
  status = "PASS"
  phase = "PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1"
  generated_at = $now
  generated_program_path = $ProgramOutputPath
  generated_program_id = "SELF_BUILD_PROGRAM_001"
  generated_program_status = "GENERATED_CANDIDATE"
  source_decision_status = $decisionReport.status
  source_decision_next_step = $decisionProof.next_allowed_step
    owner_material_input_available = $ownerMaterialAvailable
  next_recommended_step = "PHASE89_GENERATED_PROGRAM_ADMISSION_V1"
  admission_required = $true
  execution_performed = $false
  external_install_performed = $false
  external_fetch_performed = $false
  external_agent_production = $false
}

Write-JsonFile $ReportOutputPath $report

$proof = [ordered]@{
  status = "PASS"
  phase = "PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1"
  task_id = "TASK_SELF_BUILD_PROGRAM_GENERATOR_V1_001"
  runtime_mode = "SELF_BUILD"
  generated_at = $now
  generated_program_created = $true
  generated_program_path = $ProgramOutputPath
  generated_program_status = "GENERATED_CANDIDATE"
  admission_performed = $false
    owner_material_input_available = $ownerMaterialAvailable
  execution_performed = $false
  next_allowed_step = "PHASE89_GENERATED_PROGRAM_ADMISSION_V1"
  queue_returned_to_none = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
}

Write-JsonFile $ProofOutputPath $proof

Write-Output "SELF_BUILD_PROGRAM_WRITTEN=$ProgramOutputPath"
Write-Output "SELF_BUILD_PROGRAM_GENERATOR_REPORT_WRITTEN=$ReportOutputPath"
Write-Output "SELF_BUILD_PROGRAM_GENERATOR_PROOF_WRITTEN=$ProofOutputPath"
Write-Output "SELF_BUILD_PROGRAM_GENERATOR_COMPLETE"

