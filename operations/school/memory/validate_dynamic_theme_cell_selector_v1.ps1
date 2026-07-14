param(
  [string]$MemoryRoot = '.runtime/active_compact_semantic_memory_v1',
  [string]$VectorMapPath = 'operations/school/curriculum/development_vector/school_development_vector_map_v1.json'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Sha($p){ if(Test-Path $p){ (Get-FileHash $p -Algorithm SHA256).Hash } else { 'MISSING' } }
$cellsPath=Join-Path $MemoryRoot 'cells.jsonl'
$indexPath=Join-Path $MemoryRoot 'index.json'
$manifestPath=Join-Path $MemoryRoot 'manifest.json'
$before=[ordered]@{ cells=Sha $cellsPath; index=Sha $indexPath; manifest=Sha $manifestPath }
$outPath='.runtime/school_dynamic_theme_selection/validator_selection.json'
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/memory/select_dynamic_theme_cell_v1.ps1 -MemoryRoot $MemoryRoot -VectorMapPath $VectorMapPath -OutputPath $outPath *>&1 | ForEach-Object{[string]$_})
$out | Set-Content -LiteralPath '.runtime/school_dynamic_theme_selection/validator_stdout.txt' -Encoding UTF8
$after=[ordered]@{ cells=Sha $cellsPath; index=Sha $indexPath; manifest=Sha $manifestPath }
if(-not (Test-Path $outPath)){ throw 'SELECTION_OUTPUT_MISSING' }
$result=Get-Content $outPath -Raw | ConvertFrom-Json
$fail=@()
if($result.status -ne 'PASS_DEVELOPMENT_VECTOR_THEME_SELECTION_V1'){ $fail += "BAD_STATUS:$($result.status)" }
if([string]::IsNullOrWhiteSpace([string]$result.selected_topic.topic_key)){ $fail += 'SELECTED_TOPIC_EMPTY' }
if($result.expected_topic_count -lt 1){ $fail += 'EXPECTED_TOPIC_COUNT_EMPTY' }
if($result.missing_expected_topic_count -lt 1 -and $result.under_depth_expected_topic_count -lt 1){ $fail += 'NO_MISSING_OR_UNDER_DEPTH_TOPIC' }
if($null -eq $result.codex_request_template){ $fail += 'CODEX_TEMPLATE_MISSING' }
if($null -eq $result.codex_request_template.target_depth){ $fail += 'CODEX_TEMPLATE_TARGET_DEPTH_MISSING' }
if($null -eq $result.codex_request_template.current_depth){ $fail += 'CODEX_TEMPLATE_CURRENT_DEPTH_MISSING' }
if($null -eq $result.codex_request_template.acceptance_contract){ $fail += 'CODEX_TEMPLATE_ACCEPTANCE_CONTRACT_MISSING' }
if($result.memory_mutated -ne $false){ $fail += 'MEMORY_MUTATED_FLAG_NOT_FALSE' }
if($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest){ $fail += 'MEMORY_HASH_CHANGED' }
$status= if($fail.Count -eq 0){ 'PASS_DEVELOPMENT_VECTOR_THEME_SELECTOR_VALIDATION_V1' } else { 'FAIL_DEVELOPMENT_VECTOR_THEME_SELECTOR_VALIDATION_V1' }
$proof=[ordered]@{
  schema='development_vector_theme_selector_validation_v1'
  status=$status
  created_at=(Get-Date).ToString('o')
  memory_before=$before
  memory_after=$after
  selected_topic=$result.selected_topic
  expected_topic_count=$result.expected_topic_count
  missing_expected_topic_count=$result.missing_expected_topic_count
  under_depth_expected_topic_count=$result.under_depth_expected_topic_count
  codex_request_template=$result.codex_request_template
  output_path=$outPath
  stdout_path='.runtime/school_dynamic_theme_selection/validator_stdout.txt'
  failures=@($fail)
}
$proofPath='operations/reports/DEVELOPMENT_VECTOR_THEME_SELECTOR_VALIDATION_20260714.json'
$proof | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $proofPath -Encoding UTF8
Write-Host "DEVELOPMENT_VECTOR_SELECTOR_VALIDATION_STATUS=$status"
Write-Host "DEVELOPMENT_VECTOR_SELECTOR_VALIDATION_PROOF=$proofPath"
Write-Host "DEVELOPMENT_VECTOR_SELECTED_TOPIC=$($result.selected_topic.topic_key)"
Write-Host "DEVELOPMENT_VECTOR_SELECTED_REASON=$($result.selected_topic.selection_reason)"
Write-Host "DEVELOPMENT_VECTOR_SELECTED_DEPTH=$($result.selected_topic.current_depth)->$($result.selected_topic.target_depth)"
Write-Host "DEVELOPMENT_VECTOR_MEMORY_CHANGED=$($before.cells -ne $after.cells)"
if($fail.Count -gt 0){ Write-Host "DEVELOPMENT_VECTOR_FAILURES=$($fail -join ',')"; exit 1 }
