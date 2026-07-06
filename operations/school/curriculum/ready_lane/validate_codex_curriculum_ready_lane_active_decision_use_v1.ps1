$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
$promotion=Get-Content operations/reports/CODEX_CURRICULUM_ACTIVE_PROMOTION_V1.json -Raw | ConvertFrom-Json
$activeAtomCount=[int]$promotion.atom_count
$protected=@("reports/self_development/SELF_MODEL_ACTIVE_MAP.json","reports/self_development/accepted_change_memory_snapshot.json","packs/registry.json")
$before=@{}; foreach($p in $protected){$before[$p]=(Get-FileHash $p -Algorithm SHA256).Hash.ToLower()}
$tasks=@(
  [pscustomObject]@{id='proof_boundary'; text='Before claiming proof or learned status, choose the correct proof boundary.'},
  [pscustomObject]@{id='school_life_split'; text='Classify whether this is school or life before launching a run.'},
  [pscustomObject]@{id='validator_side_effects'; text='Codex validator has side effects and must not mutate active surfaces unexpectedly.'},
  [pscustomObject]@{id='duplicate_key_hygiene'; text='Detect duplicate curriculum candidate keys before accepting a batch.'},
  [pscustomObject]@{id='return_to_parent'; text='After a school atom is created, require return to parent proof.'},
  [pscustomObject]@{id='streaming_absorption'; text='When a school batch is ready, process it through streaming absorption without waiting for full TargetAccepted.'},
  [pscustomObject]@{id='count_not_learning'; text='Line count and candidate count are run metrics, not proof that the agent learned.'}
)
$results=@()
foreach($t in $tasks){
  $res=& operations/school/curriculum/codex_active/invoke_codex_curriculum_active_decision_v1.ps1 -TaskText $t.text -AsJson | ConvertFrom-Json
  $deltaOk=($res.behavior_delta_status -eq 'PASS' -and $res.baseline_decision -ne $res.active_decision)
  $atomOk=([int]$res.atom_count -ge 1 -and @($res.atom_ids_used).Count -ge 1)
  $results += [pscustomObject]@{id=$t.id; status=if($deltaOk -and $atomOk){'PASS'}else{'FAIL'}; matched_topics=@($res.matched_topics); atom_ids_used=@($res.atom_ids_used); atom_count=$res.atom_count; behavior_delta_status=$res.behavior_delta_status; baseline_decision=$res.baseline_decision; active_decision=$res.active_decision}
}
$after=@{}; foreach($p in $protected){$after[$p]=(Get-FileHash $p -Algorithm SHA256).Hash.ToLower()}
$fail=@($results|Where-Object {$_.status -ne 'PASS'}).Count
$status=if($fail -eq 0){'PASS_CODEX_CURRICULUM_ACTIVE_DECISION_USE_V1'}else{'FAIL_CODEX_CURRICULUM_ACTIVE_DECISION_USE_V1'}
$report=[pscustomObject]@{schema='codex_curriculum_active_decision_use_v1'; status=$status; runtime_ready=$false; task_count=$tasks.Count; pass_count=@($results|Where-Object {$_.status -eq 'PASS'}).Count; fail_count=$fail; active_pointer_promoted=$true; atom_count=$activeAtomCount; decision_use_proven=($fail -eq 0); proof_gate='ready_lane_behavior_delta_plus_active_atom_use'; protected_before_sha256=$before; protected_after_sha256=$after; results=@($results); boundary='Repo-body active decision-use proof for ready-lane Codex curriculum digest. Not live and not D2B accepted-core.'}
$report|ConvertTo-Json -Depth 80 | Set-Content -Encoding utf8 operations/reports/CODEX_CURRICULUM_ACTIVE_DECISION_USE_V1.json
$report|ConvertTo-Json -Depth 80 | Set-Content -Encoding utf8 operations/reports/CODEX_CURRICULUM_READY_LANE_ACTIVE_DECISION_USE_V1.json
$lines=@('# CODEX_CURRICULUM_READY_LANE_ACTIVE_DECISION_USE_V1','',"Status: $status",'Runtime ready: false','',"Task count: $($tasks.Count)","Pass: $($report.pass_count)","Fail: $fail","Atom count: $activeAtomCount","Decision-use proven: $($report.decision_use_proven)",'','Boundary: repo-body active decision-use only; not live and not D2B accepted-core.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/CODEX_CURRICULUM_ACTIVE_DECISION_USE_V1.md'),($lines -join "`r`n"),$utf8)
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/CODEX_CURRICULUM_READY_LANE_ACTIVE_DECISION_USE_V1.md'),($lines -join "`r`n"),$utf8)
Write-Host "VALIDATION_STATUS=$status"
Write-Host "TASK_COUNT=$($tasks.Count)"
Write-Host "PASS_COUNT=$($report.pass_count)"
Write-Host "FAIL_COUNT=$fail"
Write-Host "ATOM_COUNT=$activeAtomCount"
Write-Host "DECISION_USE_PROVEN=$($report.decision_use_proven)"
Write-Host "RUNTIME_READY=false"
if($status -notlike 'PASS_*'){ exit 1 }