param()
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Sha($p){ if(Test-Path $p){ (Get-FileHash $p -Algorithm SHA256).Hash } else { 'MISSING' } }
$mem='.runtime/active_compact_semantic_memory_v1'
$before=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$runId="validator_topic_patch_plan_$(Get-Date -Format yyyyMMdd_HHmmss)"
$outPath=".runtime/school_patch_runs/$runId/topic_patch_plan.json"
$ledgerPath=".runtime/school_patch_runs/$runId/patch_ledger.jsonl"
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/plan_topic_patch_cycle_v1.ps1 -Count 5000 -Mode Test -Topics 'codex_school_task_template_strength,dynamic_topic_cell_routing' -RunId $runId -OutputPath $outPath -LedgerPath $ledgerPath *>&1 | ForEach-Object{[string]$_})
$out | Set-Content -LiteralPath ".runtime/school_patch_runs/$runId/validator_stdout.txt" -Encoding UTF8
$after=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$fail=@()
if(-not (Test-Path $outPath)){ $fail += 'PLAN_OUTPUT_MISSING' }
$plan=Get-Content $outPath -Raw | ConvertFrom-Json
if($plan.status -ne 'PASS_TOPIC_PATCH_PLAN_READY'){ $fail += "BAD_PLAN_STATUS:$($plan.status)" }
if([int]$plan.patch_size -ne 1000){ $fail += "PATCH_SIZE_NOT_1000:$($plan.patch_size)" }
if([int]$plan.next_patch.candidate_count -gt 1000){ $fail += 'NEXT_PATCH_OVER_1000' }
if(@($plan.normalized_topics).Count -ne 2){ $fail += "TOPICS_COUNT_BAD:$(@($plan.normalized_topics).Count)" }
if($plan.dynamic_budget_policy -match 'equal allocation'){ $fail += 'EQUAL_ALLOCATION_TEXT_FOUND' }
if($plan.recovery_policy.partial_absorption_allowed -ne $true){ $fail += 'PARTIAL_ABSORPTION_NOT_ALLOWED' }
if(@($plan.recovery_policy.counted_states) -notcontains 'ABSORBED'){ $fail += 'ABSORBED_NOT_COUNTED' }
if($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest){ $fail += 'MEMORY_HASH_CHANGED' }
$status=if($fail.Count -eq 0){'PASS_SCHOOL_TOPIC_PATCH_PLAN_VALIDATION_V1'}else{'FAIL_SCHOOL_TOPIC_PATCH_PLAN_VALIDATION_V1'}
$proof=[ordered]@{
  schema='school_topic_patch_plan_validation_v1'
  status=$status
  created_at=(Get-Date).ToString('o')
  run_id=$runId
  plan_path=$outPath
  ledger_path=$ledgerPath
  memory_before=$before
  memory_after=$after
  plan_summary=[ordered]@{total_count_ceiling=$plan.total_count_ceiling; topics=@($plan.normalized_topics); patch_size=$plan.patch_size; next_topic=$plan.next_patch.topic_key; next_count=$plan.next_patch.candidate_count; partial_absorption_allowed=$plan.recovery_policy.partial_absorption_allowed}
  failures=@($fail)
}
$proofPath='operations/reports/SCHOOL_TOPIC_PATCH_PLAN_VALIDATION_20260714.json'
$proof | ConvertTo-Json -Depth 80 | Set-Content -LiteralPath $proofPath -Encoding UTF8
Write-Host "SCHOOL_TOPIC_PATCH_PLAN_VALIDATION_STATUS=$status"
Write-Host "SCHOOL_TOPIC_PATCH_PLAN_VALIDATION_PROOF=$proofPath"
Write-Host "SCHOOL_TOPIC_PATCH_PLAN_NEXT_TOPIC=$($plan.next_patch.topic_key)"
Write-Host "SCHOOL_TOPIC_PATCH_PLAN_PATCH_SIZE=$($plan.patch_size)"
Write-Host "SCHOOL_TOPIC_PATCH_PLAN_MEMORY_CHANGED=$($before.cells -ne $after.cells)"
if($fail.Count -gt 0){ Write-Host "SCHOOL_TOPIC_PATCH_PLAN_FAILURES=$($fail -join ',')"; exit 1 }
