$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$ledgerPath='operations/school/curriculum/candidate_factory/memory/theme_cursor_ledger.json'
$factoryLedgerPath='operations/school/curriculum/candidate_factory/memory/factory_ledger.jsonl'
$proofPath='tests/school/candidate_factory/THEME_CURSOR_LEDGER_REBUILD_V1_PROOF.json'
$reportPath='operations/school/curriculum/candidate_factory/reports/THEME_CURSOR_LEDGER_REBUILD_V1_REPORT.json'
foreach($p in @($ledgerPath,$factoryLedgerPath,$proofPath,$reportPath)){Assert (Test-Path $p) "MISSING:$p"}
$l=Get-Content $ledgerPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($l.status -eq 'PASS_THEME_CURSOR_LEDGER_REBUILD_V1') 'LEDGER_STATUS_BAD'
Assert ($p.status -eq 'PASS_THEME_CURSOR_LEDGER_REBUILD_V1') 'PROOF_STATUS_BAD'
Assert ($l.policy -match 'known theme continues') 'POLICY_MISSING'
$cursors=@($l.cursors)
Assert ($cursors.Count -gt 10) 'TOO_FEW_THEME_CURSORS'
$seen=@{}
foreach($c in $cursors){
  $k=[string]$c.theme_key
  Assert (-not [string]::IsNullOrWhiteSpace($k)) 'EMPTY_THEME_KEY'
  Assert (-not $seen.ContainsKey($k)) "DUP_THEME_KEY:$k"; $seen[$k]=$true
  Assert ([int]$c.last_level -ge 0) "BAD_LAST_LEVEL:$k"
  Assert ([int]$c.next_level -eq ([int]$c.last_level + 1)) "BAD_NEXT_LEVEL:$k"
  Assert ([int]$c.next_level -ge 1) "NEXT_LEVEL_LT_1:$k"
}
Assert ($p.historic_depth_invented -eq $false) 'HISTORIC_DEPTH_INVENTED'
Assert ($p.active_school_only -eq $true) 'ACTIVE_SCHOOL_ONLY_BAD'
Assert ($p.no_school_run_performed -eq $true) 'SCHOOL_RUN_OVERCLAIM'
Assert ($p.compact_memory_updated -eq $false) 'COMPACT_MEMORY_OVERCLAIM'
Write-Host 'VALIDATION_PASS=PASS_THEME_CURSOR_LEDGER_V1'
Write-Host "THEMES=$($cursors.Count)"
Write-Host 'POLICY=known_theme_last_plus_one_new_theme_level_1'
