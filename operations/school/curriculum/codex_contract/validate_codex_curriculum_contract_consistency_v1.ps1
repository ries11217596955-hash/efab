param([Parameter(Mandatory=$true)][string]$RunDir)
$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=80){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
$agg=Join-Path $RunDir 'all_candidates.jsonl'
if(-not (Test-Path $agg)){ throw "AGGREGATE_FILE_MISSING: $agg" }
& operations/school/curriculum/codex_contract/validate_codex_curriculum_batch_v1.ps1 -BatchPath $agg | Out-Host
$aggReport=Get-Content operations/reports/CODEX_CURRICULUM_CONTRACT_V1_VALIDATION.json -Raw|ConvertFrom-Json
$batchFiles=@(Get-ChildItem $RunDir -Recurse -File -Filter candidates.jsonl | Sort-Object FullName)
$totalP=0;$totalA=0;$totalR=0;$batchReports=@()
foreach($f in $batchFiles){
  & operations/school/curriculum/codex_contract/validate_codex_curriculum_batch_v1.ps1 -BatchPath $f.FullName | Out-Null
  $r=Get-Content operations/reports/CODEX_CURRICULUM_CONTRACT_V1_VALIDATION.json -Raw|ConvertFrom-Json
  $totalP += [int]$r.processed_count; $totalA += [int]$r.accepted_count; $totalR += [int]$r.rejected_count
  $batchReports += [pscustomObject]@{path=$f.FullName.Substring((Get-Location).Path.Length+1); processed=$r.processed_count; accepted=$r.accepted_count; rejected=$r.rejected_count; rejected_items=@($r.rejected)}
}
$ok=([int]$aggReport.processed_count -eq $totalP -and [int]$aggReport.accepted_count -eq $totalA -and [int]$aggReport.rejected_count -eq $totalR)
$status=if($ok){'PASS_CODEX_CURRICULUM_CONTRACT_CONSISTENCY_V1'}else{'FAIL_CODEX_CURRICULUM_CONTRACT_CONSISTENCY_V1'}
$report=[pscustomObject]@{schema='codex_curriculum_contract_consistency_v1'; status=$status; runtime_ready=$false; run_dir=$RunDir; aggregate=[pscustomObject]@{processed=$aggReport.processed_count; accepted=$aggReport.accepted_count; rejected=$aggReport.rejected_count; rejected_items=@($aggReport.rejected)}; per_batch=[pscustomObject]@{batch_count=$batchFiles.Count; processed=$totalP; accepted=$totalA; rejected=$totalR; batch_reports=@($batchReports)}; boundary='Compares aggregate contract validation with per-batch validation for the same candidate material. No promotion.'}
WriteJson 'operations/reports/CODEX_CURRICULUM_CONTRACT_CONSISTENCY_V1.json' $report 100
$md=@('# CODEX_CURRICULUM_CONTRACT_CONSISTENCY_V1','',"Status: $status",'Runtime ready: false','',"Run dir: $RunDir","Aggregate: processed=$($aggReport.processed_count), accepted=$($aggReport.accepted_count), rejected=$($aggReport.rejected_count)","Per-batch: processed=$totalP, accepted=$totalA, rejected=$totalR",'', 'Boundary: validation consistency only; no promotion.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/CODEX_CURRICULUM_CONTRACT_CONSISTENCY_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "CONSISTENCY_STATUS=$status"
Write-Host "AGG_PROCESSED=$($aggReport.processed_count)"
Write-Host "AGG_ACCEPTED=$($aggReport.accepted_count)"
Write-Host "AGG_REJECTED=$($aggReport.rejected_count)"
Write-Host "BATCH_PROCESSED=$totalP"
Write-Host "BATCH_ACCEPTED=$totalA"
Write-Host "BATCH_REJECTED=$totalR"
Write-Host "RUNTIME_READY=false"
if(-not $ok){ exit 1 }