$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$deletedTargets=@(
 'operations/smoke_trials','operations/contracts','operations/registry.json','operations/runtime',
 'modules/operations/register_operation_contracts.ps1','modules/operations/run_first_smoke_install_trial.ps1','modules/operations/invoke_operation_runtime.ps1','modules/operations/write_operation_contract_report.ps1',
 'packs/PHASE84_FIRST_WRAPPER_OPERATION_CONTRACTS_V1','packs/PHASE85_FIRST_SMOKE_INSTALL_TRIAL_V1','packs/PHASE86_OPERATION_RUNTIME_SKELETON_V1',
 'tasks/TASK_FIRST_WRAPPER_OPERATION_CONTRACTS_V1_001.json','tasks/TASK_FIRST_SMOKE_INSTALL_TRIAL_V1_001.json','tasks/TASK_OPERATION_RUNTIME_SKELETON_V1_001.json',
 'self_model/organ_passports/operations_contracts','self_model/organ_passports/operations_smoke_trials','self_model/organ_passports/operations_runtime',
 'self_model/organ_passports/packs_phase84_first_wrapper_operation_contracts_v1','self_model/organ_passports/packs_phase85_first_smoke_install_trial_v1','self_model/organ_passports/packs_phase86_operation_runtime_skeleton_v1'
)
foreach($p in $deletedTargets){Assert (-not(Test-Path $p)) "TARGET_STILL_EXISTS:$p"}
$patterns=@('operations/smoke_trials','operations/contracts','operations/registry.json','operations/runtime','FIRST_SMOKE_INSTALL_TRIAL','validate_json_schema_with_ajv.contract.json','validate_json_schema_with_python_jsonschema.contract.json','PHASE84_FIRST_WRAPPER_OPERATION_CONTRACTS_V1','PHASE85_FIRST_SMOKE_INSTALL_TRIAL_V1','PHASE86_OPERATION_RUNTIME_SKELETON_V1')
$excludePrefixes=@('reports/','tests/','docs/','self_model/','self_build_programs/promotions/','self_build_programs/canonical_trials/','packs/','operations/gpt_handoff/')
$all=git ls-files
$activeHits=@()
foreach($pat in $patterns){
 foreach($f in $all){
  if($excludePrefixes|Where-Object{$f -like "$_*"}){continue}
  try{ $m=Select-String -Path $f -Pattern $pat -SimpleMatch -ErrorAction SilentlyContinue; foreach($x in @($m)){$activeHits += [ordered]@{pattern=$pat;file=$f;line=$x.LineNumber;text=$x.Line.Trim()}} } catch {}
 }
}
Assert (@($activeHits).Count -eq 0) ('ACTIVE_REFS_REMAIN:' + (@($activeHits)|ConvertTo-Json -Depth 6 -Compress))
$proofPath='tests/self_development/PHASE84_86_OPERATION_RUNTIME_RETIREMENT_AND_DELETE_V1_PROOF.json'
Assert (Test-Path $proofPath) 'PROOF_MISSING'
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($p.status -eq 'PASS_PHASE84_86_OPERATION_RUNTIME_RETIREMENT_AND_DELETE_V1') 'PROOF_STATUS_BAD'
Assert ($p.no_live_runtime_touched -eq $true) 'LIVE_BOUNDARY_BAD'
Write-Host 'VALIDATION_PASS=PASS_PHASE84_86_OPERATION_RUNTIME_RETIREMENT_AND_DELETE_V1'
Write-Host ('DELETED_PATH_COUNT='+$p.deleted_path_count)
Write-Host 'ACTIVE_REFS_REMAIN=0'
Write-Host "PROOF_PATH=$proofPath"
