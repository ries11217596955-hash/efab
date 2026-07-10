$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$reportPath='reports/self_development/OPERATIONS_TRIAL_CONTRACTS_DELETION_GATE_V1.json'
$proofPath='tests/self_development/OPERATIONS_TRIAL_CONTRACTS_DELETION_GATE_V1_PROOF.json'
$mdPath='reports/self_development/OPERATIONS_TRIAL_CONTRACTS_DELETION_GATE_V1.md'
foreach($p in @($reportPath,$proofPath,$mdPath)){Assert (Test-Path $p) "MISSING:$p"}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'BLOCKED_OPERATIONS_TRIAL_CONTRACTS_DELETION_GATE_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'BLOCKED_OPERATIONS_TRIAL_CONTRACTS_DELETION_GATE_V1') 'PROOF_STATUS_BAD'
Assert ($r.can_delete_now -eq $false) 'CAN_DELETE_SHOULD_BE_FALSE'
Assert ($p.can_delete_now -eq $false) 'PROOF_CAN_DELETE_SHOULD_BE_FALSE'
Assert (@($r.blockers) -contains 'SMOKE_TRIALS_REFERENCED_BY_OPERATION_MODULES') 'SMOKE_BLOCKER_MISSING'
Assert (@($r.blockers) -contains 'CONTRACTS_REFERENCED_BY_OPERATION_MODULES_OR_REGISTRY') 'CONTRACTS_BLOCKER_MISSING'
foreach($target in @('operations/smoke_trials/FIRST_SMOKE_INSTALL_TRIAL_V1_PLAN.json','operations/smoke_trials/fixtures/json_schema_validation/schema.json','operations/contracts/validate_json_schema_with_ajv.contract.json','operations/contracts/validate_json_schema_with_python_jsonschema.contract.json')){Assert (Test-Path $target) "TARGET_SHOULD_STILL_EXIST:$target"}
foreach($path in @('modules/operations/run_first_smoke_install_trial.ps1','modules/operations/invoke_operation_runtime.ps1','modules/operations/register_operation_contracts.ps1','operations/registry.json')){Assert (Test-Path $path) "DEPENDENCY_PATH_MISSING:$path"}
Assert (@($r.dependency_scan|Where-Object{$_.pattern -eq 'operations/smoke_trials' -and $_.operational_hit_count -gt 0}).Count -eq 1) 'SMOKE_SCAN_BAD'
Assert (@($r.dependency_scan|Where-Object{$_.pattern -eq 'operations/contracts' -and $_.operational_hit_count -gt 0}).Count -eq 1) 'CONTRACTS_SCAN_BAD'
Assert ($p.no_files_deleted -eq $true) 'NO_DELETE_BAD'
Assert ($p.no_paths_moved -eq $true) 'NO_MOVE_BAD'
Assert ($p.no_runtime_touched -eq $true) 'NO_RUNTIME_BAD'
Assert ($p.no_passport_deleted -eq $true) 'NO_PASSPORT_DELETE_BAD'
Write-Host 'VALIDATION_PASS=BLOCKED_OPERATIONS_TRIAL_CONTRACTS_DELETION_GATE_V1'
Write-Host 'CAN_DELETE_NOW=false'
Write-Host 'BLOCKERS=SMOKE_TRIALS_REFERENCED_BY_OPERATION_MODULES,CONTRACTS_REFERENCED_BY_OPERATION_MODULES_OR_REGISTRY'
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
