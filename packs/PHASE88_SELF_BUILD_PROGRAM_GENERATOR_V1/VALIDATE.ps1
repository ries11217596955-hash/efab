$ErrorActionPreference = "Stop"

$Queue = Get-Content "TASK_QUEUE.json" -Raw | ConvertFrom-Json

$reportPath = "reports/self_development/SELF_BUILD_PROGRAM_GENERATOR_REPORT.json"
$proofPath = "proofs/self_development/SELF_BUILD_PROGRAM_GENERATOR_V1.json"
$programPath = "self_build_programs/generated/SELF_BUILD_PROGRAM_001.json"
$decisionReportPath = "reports/self_development/SELF_DEVELOPMENT_DECISION_KERNEL_REPORT.json"
$decisionProofPath = "proofs/self_development/SELF_DEVELOPMENT_DECISION_KERNEL_V1.json"

if ((Test-Path $reportPath) -and (Test-Path $proofPath) -and (Test-Path $programPath)) {
  Write-Output "VALIDATION_STAGE=Completed"
  Write-Output "VALIDATION_STAGE_AUTO_RESOLVED=Completed"

  $program = Get-Content $programPath -Raw | ConvertFrom-Json
  $report = Get-Content $reportPath -Raw | ConvertFrom-Json
  $proof = Get-Content $proofPath -Raw | ConvertFrom-Json

  if ($program.status -ne "GENERATED_CANDIDATE") {
    throw "PROGRAM_STATUS_NOT_GENERATED_CANDIDATE=$($program.status)"
  }
  if ($program.admission_required -ne $true) {
    throw "PROGRAM_ADMISSION_REQUIRED_NOT_TRUE"
  }
  if ($program.execution_allowed -ne $false) {
    throw "PROGRAM_EXECUTION_ALLOWED_NOT_FALSE"
  }
  if ($report.status -ne "PASS") {
    throw "REPORT_STATUS_NOT_PASS=$($report.status)"
  }
  if ($proof.status -ne "PASS") {
    throw "PROOF_STATUS_NOT_PASS=$($proof.status)"
  }
  if ($proof.next_allowed_step -ne "PHASE89_GENERATED_PROGRAM_ADMISSION_V1") {
    throw "PROOF_NEXT_ALLOWED_STEP_UNEXPECTED=$($proof.next_allowed_step)"
  }
  if ($Queue.active_task_id -ne "NONE") {
    throw "ACTIVE_TASK_ID_NOT_NONE=$($Queue.active_task_id)"
  }

  $task = @($Queue.tasks | Where-Object { $_.task_id -eq "TASK_SELF_BUILD_PROGRAM_GENERATOR_V1_001" })
  if ($task.Count -ne 1) {
    throw "TASK_COUNT_NOT_ONE=$($task.Count)"
  }
  if ($task[0].status -ne "COMPLETED") {
    throw "TASK_STATUS_NOT_COMPLETED=$($task[0].status)"
  }

  Write-Output "VALIDATION_RESULT=PASS"
  exit 0
}

Write-Output "VALIDATION_STAGE=Seed"
Write-Output "VALIDATION_STAGE_AUTO_RESOLVED=Seed"

$required = @(
  "packs/PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1/PACK.json",
  "packs/PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1/APPLY.ps1",
  "packs/PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1/VALIDATE.ps1",
  "tasks/TASK_SELF_BUILD_PROGRAM_GENERATOR_V1_001.json",
  "modules/self_development/write_self_build_program_generator_report.ps1",
  $decisionReportPath,
  $decisionProofPath,
  "CAPABILITY_ROADMAP.json",
  "GENESIS_STATE.json",
  "TASK_QUEUE.json",
  "packs/registry.json"
)

foreach ($p in $required) {
  if (-not (Test-Path $p)) {
    throw "REQUIRED_FILE_MISSING=$p"
  }
}

$decisionReport = Get-Content $decisionReportPath -Raw | ConvertFrom-Json
$decisionProof = Get-Content $decisionProofPath -Raw | ConvertFrom-Json

if ($decisionReport.status -ne "PASS") {
  throw "DECISION_REPORT_STATUS_NOT_PASS=$($decisionReport.status)"
}
if ($decisionReport.recommended_next_step_id -ne "PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1") {
  throw "DECISION_REPORT_NEXT_STEP_UNEXPECTED=$($decisionReport.recommended_next_step_id)"
}
if ($decisionProof.status -ne "PASS") {
  throw "DECISION_PROOF_STATUS_NOT_PASS=$($decisionProof.status)"
}
if ($decisionProof.next_allowed_step -ne "PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1") {
  throw "DECISION_PROOF_NEXT_ALLOWED_STEP_UNEXPECTED=$($decisionProof.next_allowed_step)"
}

$PackJson = Get-Content "packs/PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1/PACK.json" -Raw | ConvertFrom-Json
if ($PackJson.shell -ne "PowerShell") {
  throw "PACK_SHELL_NOT_POWERSHELL=$($PackJson.shell)"
}
if ($PackJson.apply -ne "APPLY.ps1") {
  throw "PACK_APPLY_UNEXPECTED=$($PackJson.apply)"
}
$Registry = Get-Content "packs/registry.json" -Raw | ConvertFrom-Json
$selected = @($Registry.packs | Where-Object {
  ($_.PSObject.Properties.Name -contains "task_id") -and
  ($_.task_id -eq $Queue.active_task_id)
})

if ($selected.Count -ne 1) {
  throw "SELECTED_PACK_COUNT_NOT_ONE=$($selected.Count)"
}
if ($selected[0].pack_id -ne "PHASE88_SELF_BUILD_PROGRAM_GENERATOR_V1") {
  throw "SELECTED_PACK_NOT_PHASE88=$($selected[0].pack_id)"
}

Write-Output "VALIDATION_RESULT=PASS_SEED"
exit 0

