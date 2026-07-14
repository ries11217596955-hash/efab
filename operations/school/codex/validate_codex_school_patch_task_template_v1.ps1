param()
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Sha($p){ if(Test-Path $p){ (Get-FileHash $p -Algorithm SHA256).Hash } else { 'MISSING' } }
$mem='.runtime/active_compact_semantic_memory_v1'
$before=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$runId="validator_codex_patch_task_$(Get-Date -Format yyyyMMdd_HHmmss)"
$selectionPath=".runtime/school_patch_runs/$runId/selection.json"
$planPath=".runtime/school_patch_runs/$runId/topic_patch_plan.json"
$taskDir=".runtime/school_patch_runs/$runId/codex_task_attempt_1"
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/memory/select_dynamic_theme_cell_v1.ps1 -RequestedTopics 'codex_school_task_template_strength' -PatchSize 1000 -OutputPath $selectionPath | Out-Host
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/plan_topic_patch_cycle_v1.ps1 -Count 5000 -Mode Test -Topics 'codex_school_task_template_strength' -RunId $runId -PatchSize 1000 -DynamicSelectionPath $selectionPath -OutputPath $planPath | Out-Host
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/codex/build_codex_school_patch_task_v1.ps1 -SelectionPath $selectionPath -PatchPlanPath $planPath -OutputDir $taskDir -Attempt 1 *>&1 | ForEach-Object{[string]$_})
$out | Set-Content -LiteralPath "$taskDir/builder_stdout.txt" -Encoding UTF8
$after=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$taskJson="$taskDir/codex_school_patch_task.json"
$taskMd="$taskDir/CODEX_SCHOOL_PATCH_TASK.md"
$fail=@()
if(-not (Test-Path $taskJson)){ $fail += 'TASK_JSON_MISSING' }
if(-not (Test-Path $taskMd)){ $fail += 'TASK_MD_MISSING' }
$task=Get-Content $taskJson -Raw | ConvertFrom-Json
$md=Get-Content $taskMd -Raw
if($task.status -ne 'CODEX_TASK_BUILT'){ $fail += "BAD_TASK_STATUS:$($task.status)" }
if([int]$task.candidate_limit -ne 1000){ $fail += "CANDIDATE_LIMIT_NOT_1000:$($task.candidate_limit)" }
foreach($field in @('topic_key','depth_level','prerequisite_depth','target_depth','source_basis','source_missing','expected_behavior','validator','proof_requirements','negative_case','return_to_parent','digest_hint')){ if(@($task.required_candidate_fields) -notcontains $field){ $fail += "MISSING_REQUIRED_FIELD:$field" } }
foreach($needle in @('PREFLIGHT_PASS','files_changed_before_preflight','do not mutate active compact memory','single topic only','candidate_limit','validator','negative_case','return_to_parent','source_basis')){ if($md -notmatch [regex]::Escape($needle)){ $fail += "TASK_MD_MISSING_TEXT:$needle" } }
if(@($task.acceptance_contract).Count -lt 8){ $fail += 'ACCEPTANCE_CONTRACT_TOO_THIN' }
if(@($task.failure_classes) -notcontains 'WRITES_BEFORE_PREFLIGHT'){ $fail += 'FAILURE_CLASS_WRITES_BEFORE_PREFLIGHT_MISSING' }
if($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest){ $fail += 'MEMORY_HASH_CHANGED' }
$status=if($fail.Count -eq 0){'PASS_CODEX_SCHOOL_PATCH_TASK_TEMPLATE_VALIDATION_V1'}else{'FAIL_CODEX_SCHOOL_PATCH_TASK_TEMPLATE_VALIDATION_V1'}
$proof=[ordered]@{
  schema='codex_school_patch_task_template_validation_v1'
  status=$status
  created_at=(Get-Date).ToString('o')
  run_id=$runId
  task_json=$taskJson
  task_md=$taskMd
  selected_topic=$task.topic_key
  candidate_limit=$task.candidate_limit
  current_depth=$task.current_depth
  target_depth=$task.target_depth
  required_candidate_fields=@($task.required_candidate_fields)
  acceptance_contract_count=@($task.acceptance_contract).Count
  failure_classes=@($task.failure_classes)
  memory_before=$before
  memory_after=$after
  failures=@($fail)
}
$proofPath='operations/reports/CODEX_SCHOOL_PATCH_TASK_TEMPLATE_VALIDATION_20260714.json'
$proof | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $proofPath -Encoding UTF8
Write-Host "CODEX_PATCH_TASK_TEMPLATE_VALIDATION_STATUS=$status"
Write-Host "CODEX_PATCH_TASK_TEMPLATE_VALIDATION_PROOF=$proofPath"
Write-Host "CODEX_PATCH_TASK_TEMPLATE_TOPIC=$($task.topic_key)"
Write-Host "CODEX_PATCH_TASK_TEMPLATE_LIMIT=$($task.candidate_limit)"
Write-Host "CODEX_PATCH_TASK_TEMPLATE_MEMORY_CHANGED=$($before.cells -ne $after.cells)"
if($fail.Count -gt 0){ Write-Host "CODEX_PATCH_TASK_TEMPLATE_FAILURES=$($fail -join ',')"; exit 1 }
