[CmdletBinding()]
param(
  [string]$ProgramPath = "self_build_programs/generated/SELF_BUILD_PROGRAM_001.json",
  [string]$GeneratorReportPath = "reports/self_development/SELF_BUILD_PROGRAM_GENERATOR_REPORT.json",
  [string]$GeneratorProofPath = "proofs/self_development/SELF_BUILD_PROGRAM_GENERATOR_V1.json",
  [string]$AdmissionPath = "self_build_programs/admission/SELF_BUILD_PROGRAM_001_ADMISSION.json",
  [string]$ReportPath = "reports/self_development/GENERATED_PROGRAM_ADMISSION_REPORT.json",
  [string]$ProofPath = "proofs/self_development/GENERATED_PROGRAM_ADMISSION_V1.json",
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE89_GENERATED_PROGRAM_ADMISSION_V1"
$TaskId = "TASK_GENERATED_PROGRAM_ADMISSION_V1_001"
$PackId = "PHASE89_GENERATED_PROGRAM_ADMISSION_V1"
$NextAllowedStep = "PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1"
$AdmissionDecision = "ADMIT_CANDIDATE_FOR_CONTROLLED_EXECUTION"

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

Write-Host "GENERATED_PROGRAM_ADMISSION_START"

$program = Read-JsonRequired $ProgramPath
$generatorReport = Read-JsonRequired $GeneratorReportPath
$generatorProof = Read-JsonRequired $GeneratorProofPath

$programId = "$(Get-PropertyValue -Object $program -Name "program_id")"
if ($programId -ne "SELF_BUILD_PROGRAM_001") {
  throw "PROGRAM_ID_MISMATCH=$programId"
}
if ("$(Get-PropertyValue -Object $program -Name "status")" -ne "GENERATED_CANDIDATE") {
  throw "PROGRAM_STATUS_NOT_GENERATED_CANDIDATE"
}
if (-not [bool](Get-PropertyValue -Object $program -Name "admission_required")) {
  throw "PROGRAM_ADMISSION_REQUIRED_NOT_TRUE"
}
if ([bool](Get-PropertyValue -Object $program -Name "execution_allowed")) {
  throw "PROGRAM_EXECUTION_ALREADY_ALLOWED"
}
if ("$(Get-PropertyValue -Object $program -Name "target_next_step")" -ne "PHASE89_GENERATED_PROGRAM_ADMISSION_V1") {
  throw "PROGRAM_TARGET_NEXT_STEP_MISMATCH"
}
if ("$(Get-PropertyValue -Object $generatorReport -Name "status")" -ne "PASS") {
  throw "PHASE88_REPORT_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $generatorProof -Name "status")" -ne "PASS") {
  throw "PHASE88_PROOF_NOT_PASS"
}
if ("$(Get-PropertyValue -Object $generatorProof -Name "next_allowed_step")" -ne "PHASE89_GENERATED_PROGRAM_ADMISSION_V1") {
  throw "PHASE88_PROOF_NEXT_STEP_MISMATCH"
}
if ([bool](Get-PropertyValue -Object $generatorProof -Name "execution_performed")) {
  throw "PHASE88_PROOF_EXECUTION_PERFORMED_TRUE"
}

# PHASE164Q_OWNER_MATERIAL_ADMISSION_CONTEXT_V1
$ownerMaterialInput = Get-PropertyValue -Object $program -Name "owner_material_input"
$ownerMaterialAvailable = [bool](Get-PropertyValue -Object $program -Name "owner_material_available")
$ownerMaterialSourceCandidateId = ""
$ownerMaterialSourceCandidatePath = ""
$ownerMaterialSourceRequestPath = ""
if ($null -ne $ownerMaterialInput) {
  $ownerMaterialSourceCandidateId = "$(Get-PropertyValue -Object $ownerMaterialInput -Name "source_candidate_id")"
  $ownerMaterialSourceCandidatePath = "$(Get-PropertyValue -Object $ownerMaterialInput -Name "source_candidate_path")"
  $ownerMaterialSourceRequestPath = "$(Get-PropertyValue -Object $ownerMaterialInput -Name "source_request_path")"
}

$generatedAt = Get-UtcStamp
$admission = [ordered]@{
  status = "PASS"
  program_id = $programId
  phase = $Phase
  source_program_path = $ProgramPath
  source_generator_report_path = $GeneratorReportPath
  source_generator_proof_path = $GeneratorProofPath
    owner_material_input = $ownerMaterialInput
    owner_material_available = $ownerMaterialAvailable
    owner_material_source_candidate_id = $ownerMaterialSourceCandidateId
    owner_material_source_candidate_path = $ownerMaterialSourceCandidatePath
    owner_material_source_request_path = $ownerMaterialSourceRequestPath
  admission_decision = $AdmissionDecision
  admission_performed = $true
  execution_performed = $false
  admitted_for_next_phase = "PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1"
  generated_at = $generatedAt
  input_state = [ordered]@{
    program_status = "$(Get-PropertyValue -Object $program -Name "status")"
    admission_required = [bool](Get-PropertyValue -Object $program -Name "admission_required")
    execution_allowed_before_admission = [bool](Get-PropertyValue -Object $program -Name "execution_allowed")
    phase88_report_status = "$(Get-PropertyValue -Object $generatorReport -Name "status")"
    phase88_proof_status = "$(Get-PropertyValue -Object $generatorProof -Name "status")"
  }
  guarantees = [ordered]@{
    no_program_execution = $true
    no_external_install = $true
    no_external_fetch = $true
    no_external_agent_production = $true
  }
  next_allowed_step = $NextAllowedStep
}

$report = [ordered]@{
  next_recommended_step = "PHASE90_BUILDER_EXECUTES_OWN_GENERATED_SELF_BUILD_PROGRAM_V1"
  status = "PASS"
  phase = $Phase
  generated_at = $generatedAt
  program_id = $programId
  program_path = $ProgramPath
  admission_path = $AdmissionPath
  admission_decision = $AdmissionDecision
  admission_performed = $true
  execution_performed = $false
  program_status_before_admission = "$(Get-PropertyValue -Object $program -Name "status")"
  program_admission_required = [bool](Get-PropertyValue -Object $program -Name "admission_required")
  program_execution_allowed_before_admission = [bool](Get-PropertyValue -Object $program -Name "execution_allowed")
  owner_material_available = $ownerMaterialAvailable
  owner_material_source_candidate_id = $ownerMaterialSourceCandidateId
  owner_material_source_candidate_path = $ownerMaterialSourceCandidatePath
  owner_material_source_request_path = $ownerMaterialSourceRequestPath
  phase88_report_path = $GeneratorReportPath
  phase88_report_status = "$(Get-PropertyValue -Object $generatorReport -Name "status")"
  phase88_proof_path = $GeneratorProofPath
  phase88_proof_status = "$(Get-PropertyValue -Object $generatorProof -Name "status")"
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  next_allowed_step = $NextAllowedStep
  cut_list = @(
    "Do not execute SELF_BUILD_PROGRAM_001 in PHASE89.",
    "Do not install tools.",
    "Do not fetch external sources.",
    "Do not produce external agents.",
    "Do not edit PHASE78-PHASE88 packs."
  )
}

$proof = [ordered]@{
  queue_returned_to_none = $true
  status = "PASS"
  phase = $Phase
  task_id = $TaskId
  pack_id = $PackId
  runtime_mode = "SELF_BUILD"
  generated_at = $generatedAt
  admission_path = $AdmissionPath
  report_path = $ReportPath
  proof_path = $ProofPath
  admission_decision = $AdmissionDecision
  admission_performed = $true
  execution_performed = $false
  owner_material_available = $ownerMaterialAvailable
  owner_material_source_candidate_id = $ownerMaterialSourceCandidateId
  owner_material_source_candidate_path = $ownerMaterialSourceCandidatePath
  owner_material_source_request_path = $ownerMaterialSourceRequestPath
  next_allowed_step = $NextAllowedStep
  no_external_agent_production = $true
  no_external_install = $true
  no_external_fetch = $true
  evidence_files = @(
    $ProgramPath,
    $GeneratorReportPath,
    $GeneratorProofPath,
    $AdmissionPath,
    $ReportPath
  )
}

Write-JsonFile -Path $AdmissionPath -Object $admission
Write-JsonFile -Path $ReportPath -Object $report
Write-JsonFile -Path $ProofPath -Object $proof

Write-Host "GENERATED_PROGRAM_ADMISSION_DECISION=$AdmissionDecision"
Write-Host "GENERATED_PROGRAM_EXECUTION_PERFORMED=FALSE"
Write-Host "GENERATED_PROGRAM_ADMISSION_WRITTEN=$AdmissionPath"
Write-Host "GENERATED_PROGRAM_ADMISSION_REPORT_WRITTEN=$ReportPath"
Write-Host "GENERATED_PROGRAM_ADMISSION_PROOF_WRITTEN=$ProofPath"
Write-Host "GENERATED_PROGRAM_ADMISSION_COMPLETE"

return [pscustomobject]$report


