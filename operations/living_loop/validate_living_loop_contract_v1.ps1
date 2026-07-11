$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$contractPath='contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json'
$mdPath='contracts/living_loop/LIVING_LOOP_CONTRACT_V1.md'
Assert (Test-Path $contractPath) 'CONTRACT_JSON_MISSING'
Assert (Test-Path $mdPath) 'CONTRACT_MD_MISSING'
$c=Get-Content $contractPath -Raw|ConvertFrom-Json
Assert ($c.status -eq 'CONTRACT_DRAFT_DERIVED_FROM_PROOF') 'CONTRACT_STATUS_BAD'
Assert ($c.not_active_runtime -eq $true) 'ACTIVE_RUNTIME_OVERCLAIM'
Assert ($c.not_autonomous_loop -eq $true) 'AUTONOMOUS_LOOP_OVERCLAIM'
$requiredStages=@('wake','observe','restore_body_model','build_body_state','emit_signals','reason_about_cause','select_lawful_outcome','act_or_block_inside_authority','verify_state_change','record_memory_reuse','return_to_parent')
foreach($s in $requiredStages){ Assert (@($c.cycle|Where-Object{$_ -eq $s}).Count -eq 1) "MISSING_STAGE:$s" }
Assert (@($c.proof_base).Count -eq 4) 'PROOF_BASE_COUNT_BAD'
$decisions=@()
foreach($pb in @($c.proof_base)){
  Assert (Test-Path $pb.proof) "PROOF_MISSING:$($pb.proof)"
  $p=Get-Content $pb.proof -Raw|ConvertFrom-Json
  Assert ($p.status -match '^PASS_') "PROOF_STATUS_NOT_PASS:$($pb.proof)"
  Assert ($p.organ_id -eq $pb.organ_id) "PROOF_ORGAN_MISMATCH:$($pb.proof)"
  Assert ($p.lifecycle_decision -eq $pb.expected_decision) "PROOF_DECISION_MISMATCH:$($pb.proof)"
  Assert ($p.state_change_verified -eq $true) "STATE_CHANGE_NOT_VERIFIED:$($pb.proof)"
  Assert ($p.no_passport_active_created -eq $true) "PASSPORT_ACTIVE_OVERCLAIM:$($pb.proof)"
  Assert ($p.no_live_runtime_touched -eq $true) "LIVE_TOUCHED_OVERCLAIM:$($pb.proof)"
  $decisions += [string]$p.lifecycle_decision
}
Assert (@($decisions|Where-Object{$_ -eq 'PROMOTE_TO_VALIDATED_LAB_KEEP_NON_ACTIVE'}).Count -ge 3) 'PROMOTION_PATTERN_MISSING'
Assert (@($decisions|Where-Object{$_ -eq 'BLOCKED_BY_MISSING_SOURCE_PROOF'}).Count -eq 1) 'BLOCKER_PATTERN_MISSING'
foreach($o in @('PROMOTE_TO_VALIDATED_LAB_KEEP_NON_ACTIVE','BLOCKED_BY_MISSING_SOURCE_PROOF','OWNER_DECISION_REQUIRED','QUARANTINE_REQUIRED')){ Assert (@($c.lawful_outcomes|Where-Object{$_ -eq $o}).Count -eq 1) "MISSING_OUTCOME:$o" }
foreach($law in @('No proof -> no claim','No signal -> no Brain input','No state-change verification -> action unfinished','No return-to-parent -> unfinished growth','Live-like observation != live readiness','PASS can mean correctly blocked, not promoted')){ Assert (@($c.laws|Where-Object{$_ -eq $law}).Count -eq 1) "MISSING_LAW:$law" }
Assert ($c.required_negative_guards.no_fake_proof -eq $true) 'NO_FAKE_PROOF_GUARD_MISSING'
Assert ($c.required_negative_guards.no_live_overclaim -eq $true) 'NO_LIVE_OVERCLAIM_GUARD_MISSING'
Assert ($c.required_negative_guards.block_is_valid_completion -eq $true) 'BLOCK_COMPLETION_GUARD_MISSING'
Write-Host 'VALIDATION_PASS=PASS_LIVING_LOOP_CONTRACT_V1'
Write-Host 'PROOF_BASE_COUNT=4'
Write-Host 'PROMOTION_PATTERNS=3'
Write-Host 'BLOCKER_PATTERNS=1'
Write-Host 'ACTIVE_RUNTIME=false'
Write-Host 'AUTONOMOUS_LOOP=false'
