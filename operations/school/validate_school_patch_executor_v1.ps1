param()
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Sha($p){ if(Test-Path $p){ (Get-FileHash $p -Algorithm SHA256).Hash } else { 'MISSING' } }
$mem='.runtime/active_compact_semantic_memory_v1'
$before=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/execute_school_patch_v1.ps1 -Count 1000 -Mode Test -Topics 'codex_school_task_template_strength' -ExecutorMode MockCodex *>&1 | ForEach-Object{[string]$_})
$outDir='.runtime/school_patch_executor_validation'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$out | Set-Content -LiteralPath "$outDir/validator_stdout.txt" -Encoding UTF8
$reportPath=(($out|Where-Object{$_ -match '^SCHOOL_PATCH_EXECUTOR_REPORT='}|Select-Object -Last 1) -replace '^SCHOOL_PATCH_EXECUTOR_REPORT=','')
$after=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$fail=@()
if([string]::IsNullOrWhiteSpace($reportPath) -or -not (Test-Path $reportPath)){ $fail += 'EXECUTOR_REPORT_MISSING' }
$report=Get-Content $reportPath -Raw | ConvertFrom-Json
if($report.status -ne 'PASS_PATCH_EXECUTOR_VALIDATED_NO_ABSORB_V1'){ $fail += "BAD_EXECUTOR_STATUS:$($report.status)" }
if($report.codex_status -ne 'MOCK_CODEX_DRAFT_CREATED'){ $fail += "BAD_CODEX_STATUS:$($report.codex_status)" }
if($report.ledger_state -ne 'VALIDATED_NORMALIZED'){ $fail += "BAD_LEDGER_STATE:$($report.ledger_state)" }
if($report.memory_changed -ne $false){ $fail += 'REPORT_MEMORY_CHANGED_TRUE' }
if($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest){ $fail += 'MEMORY_HASH_CHANGED' }
if(-not (Test-Path $report.normalization_report)){ $fail += 'NORMALIZATION_REPORT_MISSING' }
else {
  $norm=Get-Content $report.normalization_report -Raw | ConvertFrom-Json
  if($norm.status -ne 'PASS_CODEX_SCHOOL_PATCH_CANDIDATE_NORMALIZATION_V1'){ $fail += "BAD_NORMALIZATION_STATUS:$($norm.status)" }
  if([int]$norm.accepted_count -ne 1000){ $fail += "ACCEPTED_COUNT_NOT_1000:$($norm.accepted_count)" }
}
$ledgerRows=@()
if(Test-Path $report.patch_ledger_path){ $ledgerRows=@(Get-Content $report.patch_ledger_path | Where-Object{$_} | ForEach-Object{$_|ConvertFrom-Json}) }
if($ledgerRows.Count -lt 1){ $fail += 'LEDGER_ROW_MISSING' }
elseif($ledgerRows[-1].state -ne 'VALIDATED_NORMALIZED'){ $fail += "LEDGER_STATE_NOT_VALIDATED_NORMALIZED:$($ledgerRows[-1].state)" }
$status=if($fail.Count -eq 0){'PASS_SCHOOL_PATCH_EXECUTOR_VALIDATION_V1'}else{'FAIL_SCHOOL_PATCH_EXECUTOR_VALIDATION_V1'}
$proof=[ordered]@{
  schema='school_patch_executor_validation_v1'
  status=$status
  created_at=(Get-Date).ToString('o')
  executor_report=$reportPath
  executor_status=$report.status
  codex_status=$report.codex_status
  ledger_state=$report.ledger_state
  normalized_atoms_jsonl=$report.normalized_atoms_jsonl
  patch_ledger_path=$report.patch_ledger_path
  memory_before=$before
  memory_after=$after
  memory_changed=($before.cells -ne $after.cells -or $before.index -ne $after.index -or $before.manifest -ne $after.manifest)
  failures=@($fail)
}
$proofPath='operations/reports/SCHOOL_PATCH_EXECUTOR_VALIDATION_20260714.json'
$proof|ConvertTo-Json -Depth 100|Set-Content -LiteralPath $proofPath -Encoding UTF8
Write-Host "SCHOOL_PATCH_EXECUTOR_VALIDATION_STATUS=$status"
Write-Host "SCHOOL_PATCH_EXECUTOR_VALIDATION_PROOF=$proofPath"
Write-Host "SCHOOL_PATCH_EXECUTOR_VALIDATION_EXECUTOR_STATUS=$($report.status)"
Write-Host "SCHOOL_PATCH_EXECUTOR_VALIDATION_LEDGER_STATE=$($report.ledger_state)"
Write-Host "SCHOOL_PATCH_EXECUTOR_VALIDATION_MEMORY_CHANGED=$($proof.memory_changed)"
if($fail.Count -gt 0){ Write-Host "SCHOOL_PATCH_EXECUTOR_VALIDATION_FAILURES=$($fail -join ',')"; exit 1 }
