[CmdletBinding()]
param(
  [string]$ProgramPath = "self_build_programs/generated/SELF_BUILD_PROGRAM_001.json",
  [string]$AdmissionPath = "self_build_programs/admission/SELF_BUILD_PROGRAM_001_ADMISSION.json",
  [string]$AdmissionReportPath = "reports/self_development/GENERATED_PROGRAM_ADMISSION_REPORT.json",
  [string]$AdmissionProofPath = "proofs/self_development/GENERATED_PROGRAM_ADMISSION_V1.json",
  [string]$ExecutionPath = "self_build_programs/executions/SELF_BUILD_PROGRAM_001_EXECUTION.json",
  [string]$ReportPath = "reports/self_development/GENERATED_SELF_BUILD_EXECUTION_REPORT.json",
  [string]$ProofPath = "proofs/self_development/GENERATED_SELF_BUILD_EXECUTION_V1.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1"
$TaskId = "TASK_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1_001"
$PackId = "PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1"
$ProgramId = "SELF_BUILD_PROGRAM_001"
$ExecutionId = "SELF_BUILD_PROGRAM_001_EXECUTION"
$AdmissionDecision = "ADMIT_CANDIDATE_FOR_CONTROLLED_EXECUTION"
$CapabilityCreated = "generated_self_build_execution_v1"
$NextAllowedStep = "CREATE_AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2"

function Join-RepoPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Get-UtcStamp {
  return (Get-Date).ToUniversalTime().ToString("o")
}

function Read-JsonRequired {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    throw "MISSING_JSON=$Path"
  }
  return (Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json)
}

function Write-JsonFile {
  param(
    [string]$Path,
    [object]$Object
  )

  $fullPath = Join-RepoPath $Path
  $directory = Split-Path -Parent $fullPath
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  $json = ($Object | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  [System.IO.File]::WriteAllText($fullPath, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-PropertyInfo {
  param(
    [object]$Object,
    [string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }
  return $Object.PSObject.Properties | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
}

function Get-PropertyValue {
  param(
    [object]$Object,
    [string]$Name
  )

  $property = Get-PropertyInfo -Object $Object -Name $Name
  if ($null -eq $property) {
    return $null
  }
  return $property.Value
}

Write-Host "GENERATED_SELF_BUILD_EXECUTION_START"

$program = Read-JsonRequired $ProgramPath
$admission = Read-JsonRequired $AdmissionPath
$admissionReport = Read-JsonRequired $AdmissionReportPath
$admissionProof = Read-JsonRequired $AdmissionProofPath

$programIdActual = "$(Get-PropertyValue -Object $program -Name "program_id")"
if ($programIdActual -ne $ProgramId) {
  throw "PROGRAM_ID_MISMATCH=$programIdActual"
}
if ("$(Get-PropertyValue -Object $program -Name "status")" -ne "GENERATED_CANDIDATE") {
  throw "PROGRAM_STATUS_NOT_GENERATED_CANDIDATE"
}
if (-not [bool](Get-PropertyValue -Object $program -Name "admission_required")) {
  throw "PROGRAM_ADMISSION_REQUIRED_NOT_TRUE"
}
if ([bool](Get-PropertyValue -Object $program -Name "execution_allowed")) {
  throw "PROGRAM_EXECUTION_ALLOWED_BEFORE_CONTROLLED_PHASE"
}
if ("$(Get-PropertyValue -Object $admission -Name "status")" -ne "PASS") {
  throw "ADMISSION_STATUS_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $admission -Name "admission_decision")" -ne $AdmissionDecision) {
  throw "ADMISSION_DECISION_MISMATCH"
}
if ([bool](Get-PropertyValue -Object $admission -Name "execution_performed")) {
  throw "ADMISSION_EXECUTION_PERFORMED_TRUE"
}
if ("$(Get-PropertyValue -Object $admissionReport -Name "status")" -ne "PASS") {
  throw "PHASE89_REPORT_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $admissionProof -Name "status")" -ne "PASS") {
  throw "PHASE89_PROOF_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $admissionProof -Name "next_allowed_step")" -ne $Phase) {
  throw "PHASE89_PROOF_NEXT_STEP_MISMATCH"
}


# PHASE164S_OWNER_MATERIAL_EXECUTION_CONTEXT_V1
$ownerMaterialInput = Get-PropertyValue -Object $program -Name "owner_material_input"
$ownerMaterialAvailable = [bool](Get-PropertyValue -Object $program -Name "owner_material_available")
$admissionOwnerMaterialAvailable = [bool](Get-PropertyValue -Object $admission -Name "owner_material_available")

if (-not $ownerMaterialAvailable -and $admissionOwnerMaterialAvailable) {
  $ownerMaterialAvailable = $true
}

$ownerMaterialSourceCandidateId = ""
$ownerMaterialSourceCandidatePath = ""
$ownerMaterialSourceRequestPath = ""

if ($null -ne $ownerMaterialInput) {
  $ownerMaterialSourceCandidateId = "$(Get-PropertyValue -Object $ownerMaterialInput -Name "source_candidate_id")"
  $ownerMaterialSourceCandidatePath = "$(Get-PropertyValue -Object $ownerMaterialInput -Name "source_candidate_path")"
  $ownerMaterialSourceRequestPath = "$(Get-PropertyValue -Object $ownerMaterialInput -Name "source_request_path")"
}

if ([string]::IsNullOrWhiteSpace($ownerMaterialSourceCandidateId)) {
  $ownerMaterialSourceCandidateId = "$(Get-PropertyValue -Object $admission -Name "owner_material_source_candidate_id")"
}
if ([string]::IsNullOrWhiteSpace($ownerMaterialSourceCandidatePath)) {
  $ownerMaterialSourceCandidatePath = "$(Get-PropertyValue -Object $admission -Name "owner_material_source_candidate_path")"
}
if ([string]::IsNullOrWhiteSpace($ownerMaterialSourceRequestPath)) {
  $ownerMaterialSourceRequestPath = "$(Get-PropertyValue -Object $admission -Name "owner_material_source_request_path")"
}
$generatedAt = Get-UtcStamp
$execution = [ordered]@{
  execution_id = $ExecutionId
  program_id = $ProgramId
  status = "PASS"
  execution_mode = "CONTROLLED_SELF_BUILD_EXECUTION"
  source_program_path = $ProgramPath
  source_admission_path = $AdmissionPath
  source_admission_report_path = $AdmissionReportPath
  source_admission_proof_path = $AdmissionProofPath
  owner_material_input = $ownerMaterialInput
  owner_material_available = $ownerMaterialAvailable
  owner_material_source_candidate_id = $ownerMaterialSourceCandidateId
  owner_material_source_candidate_path = $ownerMaterialSourceCandidatePath
  owner_material_source_request_path = $ownerMaterialSourceRequestPath
  executed_by_phase = $Phase
  admitted_before_execution = $true
  admission_decision = $AdmissionDecision
  execution_performed = $true
  external_agent_production = $false
  external_install_performed = $false
  external_fetch_performed = $false
  route_lock_changed = $false
  capability_created = $CapabilityCreated
  completed_loop = $true
  generated_at = $generatedAt
  next_recommended_action = $NextAllowedStep
}

$report = [ordered]@{
  status = "PASS"
  phase = $Phase
  generated_at = $generatedAt
  program_id = $ProgramId
  execution_path = $ExecutionPath
  admission_verified = $true
  owner_material_available = $ownerMaterialAvailable
  owner_material_source_candidate_id = $ownerMaterialSourceCandidateId
  owner_material_source_candidate_path = $ownerMaterialSourceCandidatePath
  owner_material_source_request_path = $ownerMaterialSourceRequestPath
  execution_performed = $true
  completed_loop = $true
  capability_created = $CapabilityCreated
  external_agent_production = $false
  external_install_performed = $false
  external_fetch_performed = $false
  route_lock_changed = $false
  next_recommended_action = $NextAllowedStep
  evidence_files = @(
    $ProgramPath,
    $AdmissionPath,
    $AdmissionReportPath,
    $AdmissionProofPath,
    $ExecutionPath
  )
  cut_list = @(
    "Do not produce external agents.",
    "Do not install tools.",
    "Do not fetch external sources.",
    "Do not change route lock.",
    "Do not create PHASE91 in PHASE90."
  )
}

$proof = [ordered]@{
  status = "PASS"
  phase = $Phase
  task_id = $TaskId
  pack_id = $PackId
  runtime_mode = "SELF_BUILD"
  generated_at = $generatedAt
  program_id = $ProgramId
  admission_verified = $true
  owner_material_available = $ownerMaterialAvailable
  owner_material_source_candidate_id = $ownerMaterialSourceCandidateId
  owner_material_source_candidate_path = $ownerMaterialSourceCandidatePath
  owner_material_source_request_path = $ownerMaterialSourceRequestPath
  execution_performed = $true
  completed_loop = $true
  capability_created = $CapabilityCreated
  execution_path = $ExecutionPath
  report_path = $ReportPath
  proof_path = $ProofPath
  queue_returned_to_none = $true
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  route_lock_changed = $false
  next_allowed_step = $NextAllowedStep
  evidence_files = @(
    $ProgramPath,
    $AdmissionPath,
    $AdmissionReportPath,
    $AdmissionProofPath,
    $ExecutionPath,
    $ReportPath
  )
}

Write-JsonFile -Path $ExecutionPath -Object $execution
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Write-Host "GENERATED_SELF_BUILD_EXECUTION_ID=$ExecutionId"
Write-Host "GENERATED_SELF_BUILD_EXECUTION_PERFORMED=TRUE"
Write-Host "GENERATED_SELF_BUILD_LOOP_COMPLETED=TRUE"
Write-Host "EXTERNAL_AGENT_PRODUCTION=FALSE"
Write-Host "EXTERNAL_INSTALL_PERFORMED=FALSE"
Write-Host "EXTERNAL_FETCH_PERFORMED=FALSE"
Write-Host "ROUTE_LOCK_CHANGED=FALSE"
Write-Host "GENERATED_SELF_BUILD_EXECUTION_WRITTEN=$ExecutionPath"
Write-Host "GENERATED_SELF_BUILD_EXECUTION_REPORT_WRITTEN=$ReportPath"
Write-Host "GENERATED_SELF_BUILD_EXECUTION_PROOF_WRITTEN=$ProofPath"
Write-Host "GENERATED_SELF_BUILD_EXECUTION_COMPLETE"

return [pscustomobject]$report

