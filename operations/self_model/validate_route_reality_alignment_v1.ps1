$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function Write-Json($Obj,[string]$Path){$dir=Split-Path $Path -Parent; if($dir -and -not(Test-Path $dir)){New-Item -ItemType Directory -Path $dir -Force|Out-Null}; $Obj|ConvertTo-Json -Depth 30|Set-Content -Path $Path -Encoding UTF8}
$activePath='route_locks/ACTIVE_ROUTE_LOCK.json'
$routePath='route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V6_ORGAN_PASSPORT_SYSTEM.md'
$reportPath='reports/self_development/ROUTE_REALITY_ALIGNMENT_V1.json'
$proofPath='tests/self_development/ROUTE_REALITY_ALIGNMENT_V1_PROOF.json'
foreach($p in @($activePath,$routePath)){Assert (Test-Path $p) "MISSING:$p"}
$active=Get-Content $activePath -Raw|ConvertFrom-Json
Assert ($active.active_route_lock_file -eq $routePath) 'ACTIVE_ROUTE_FILE_BAD'
Assert ($active.active_route_lock_version -eq 'V6_ORGAN_PASSPORT_SYSTEM') 'ACTIVE_ROUTE_VERSION_BAD'
Assert ($active.active_line -match 'ORGAN_PASSPORT_SYSTEM') 'ACTIVE_LINE_NOT_PASSPORT_SYSTEM'
Assert ($active.proof_boundary -match 'NO_LIVE_PROOF') 'NO_LIVE_PROOF_BOUNDARY_MISSING'
Assert ($active.proof_boundary -match 'NO_PASSPORT_ACTIVE') 'NO_PASSPORT_ACTIVE_BOUNDARY_MISSING'
Assert ($active.proof_boundary -match 'LIFECYCLE_CONTRACT_STASH_NOT_APPLIED') 'STASH_NOT_APPLIED_BOUNDARY_MISSING'
$routeText=Get-Content $routePath -Raw
Assert ($routeText -match 'Do not apply lifecycle-contract stash') 'ROUTE_STASH_BOUNDARY_MISSING'
Assert ($routeText -match 'PASSPORT_REPEATABILITY_SECOND_SAMPLE_V1') 'NEXT_STEP_SECOND_SAMPLE_MISSING'
$hooksPath=(git config --get core.hooksPath)
Assert ($hooksPath -eq '.githooks') 'HOOKS_PATH_NOT_GITHOOKS'
Assert (Test-Path '.githooks/pre-commit') 'PRE_COMMIT_HOOK_MISSING'
$pre=Get-Content '.githooks/pre-commit' -Raw
Assert ($pre -match 'invoke_branch_agnostic_map_refresh_after_structural_change_001.ps1') 'PRE_COMMIT_MAP_REFRESH_MISSING'
Assert ($pre -match 'validate_agent_body_composition_map_current_v1.ps1') 'PRE_COMMIT_MAP_VALIDATOR_MISSING'
$stashList=@(git stash list)
$stashPresent=@($stashList|Where-Object{$_ -match 'preserve lifecycle contract route dirty state'}).Count -ge 1
Assert ($stashPresent) 'LIFECYCLE_CONTRACT_STASH_MISSING'
$report=[ordered]@{
  schema='route_reality_alignment_v1'
  status='PASS_ROUTE_REALITY_ALIGNMENT_V1'
  active_route_lock_file=$active.active_route_lock_file
  active_route_lock_version=$active.active_route_lock_version
  active_line=$active.active_line
  route_baseline_head=$active.route_baseline_head
  hooksPath=$hooksPath
  pre_commit_map_refresh_proven_local_config=$true
  lifecycle_contract_stash_preserved=$true
  lifecycle_contract_stash_applied=$false
  no_live_proof_claimed=$true
  no_passport_active_claimed=$true
  next_target_phase=$active.next_target_phase
  created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{
  schema='route_reality_alignment_v1_proof'
  status='PASS_ROUTE_REALITY_ALIGNMENT_V1'
  report_path=$reportPath
  active_route_pointer_valid=$true
  active_route_is_passport_system=$true
  githooks_pre_commit_map_refresh_present=$true
  githooks_pre_commit_map_validator_present=$true
  lifecycle_contract_stash_preserved_not_applied=$true
  live_process_touched=$false
  created_at=(Get-Date).ToString('o')
}
Write-Json $report $reportPath
Write-Json $proof $proofPath
Write-Host 'VALIDATION_PASS=PASS_ROUTE_REALITY_ALIGNMENT_V1'
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
