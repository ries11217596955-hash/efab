param([string]$BatchPath=".runtime/codex_curriculum_batches/codex_curriculum_canary_sample_v1.jsonl")
$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=30){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
function Test-CountAsQualityClaim($text){
  $s=([string]$text).ToLowerInvariant()
  $hasClaim=($s -match 'processed\s*=\s*n|\bmillion\b|\bcount\s+proves\b|\bn\s+proves\b|\bvolume\s+proves\b|\bcandidate_count\s+proves\b')
  if(-not $hasClaim){ return $false }
  $isNegatedOrGuarded=($s -match 'without\s+claim|not\s+claim|no\s+claim|reject|avoid|prevent|separat|distinguish|do\s+not|don''t|false\s+proof')
  if($isNegatedOrGuarded){ return $false }
  return $true
}
$required=@("candidate_id","source_mode","topic","level","objective","new_knowledge","exercise","expected_behavior","negative_trap","validator_hint","behavior_use_proof_target","return_to_parent","source_anchor","duplicate_key","self_generated_easy_candidate")
$allowed=@("directed_curriculum","experience_curriculum")
$lines=Get-Content $BatchPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
$accepted=@(); $rejected=@(); $seen=@{}; $lineNo=0
foreach($line in $lines){
  $lineNo++
  try { $c=$line | ConvertFrom-Json } catch { $rejected += [pscustomObject]@{line=$lineNo; candidate_id="PARSE_ERROR"; failures=@("invalid_json")}; continue }
  $fail=@()
  foreach($f in $required){ if(-not ($c.PSObject.Properties.Name -contains $f)){ $fail += "missing_$f" } }
  if($fail.Count -eq 0){
    foreach($f in $required){ if($null -eq $c.$f -or ([string]$c.$f).Trim().Length -eq 0){ $fail += "empty_$f" } }
    if($c.source_mode -notin $allowed){ $fail += "bad_source_mode" }
    try { $lvl=[int]$c.level; if($lvl -lt 1){ $fail += "bad_level" } } catch { $fail += "bad_level" }
    if($c.self_generated_easy_candidate -ne $false){ $fail += "self_generated_easy" }
    if(([string]$c.exercise).Length -lt 20){ $fail += "weak_exercise" }
    if(([string]$c.negative_trap).Length -lt 10){ $fail += "weak_negative_trap" }
    if(([string]$c.behavior_use_proof_target).Length -lt 20){ $fail += "weak_behavior_use_target" }
    if(([string]$c.return_to_parent).Length -lt 10){ $fail += "weak_return_to_parent" }
    if(Test-CountAsQualityClaim $c.objective){ $fail += "uses_count_as_quality" }
    $dk=[string]$c.duplicate_key
    if($seen.ContainsKey($dk)){ $fail += "duplicate_key" } else { $seen[$dk]=$true }
  }
  if($fail.Count -eq 0){
    $accepted += [pscustomObject]@{line=$lineNo; candidate_id=$c.candidate_id; topic=$c.topic; level=$c.level; source_mode=$c.source_mode; duplicate_key=$c.duplicate_key}
  } else {
    $rejected += [pscustomObject]@{line=$lineNo; candidate_id=if($c.candidate_id){$c.candidate_id}else{"UNKNOWN"}; failures=$fail}
  }
}
$hasAccept=$accepted.Count -gt 0
$status=if($hasAccept){"PASS_CODEX_CURRICULUM_BATCH_VALIDATOR_V1"}else{"FAIL_CODEX_CURRICULUM_BATCH_VALIDATOR_V1"}
$report=[pscustomObject]@{schema="codex_curriculum_batch_validator_v1"; status=$status; runtime_ready=$false; batch_path=$BatchPath; processed_count=$lines.Count; accepted_count=$accepted.Count; rejected_count=$rejected.Count; accepted=@($accepted); rejected=@($rejected); promotion_allowed=$false; boundary="Validates Codex curriculum batch only; no atoms promoted. Rejections are allowed but not required for production batches. Count-claim detection respects negated/guarded lessons."}
WriteJson "operations/reports/CODEX_CURRICULUM_CONTRACT_V1_VALIDATION.json" $report 50
$md=@("# CODEX_CURRICULUM_CONTRACT_V1_VALIDATION","","Status: $status","Runtime ready: false","","Processed: $($lines.Count)","Accepted: $($accepted.Count)","Rejected: $($rejected.Count)","Promotion allowed: false","","Boundary: batch validator only; no atoms promoted.")
[IO.File]::WriteAllText((Join-Path (Get-Location).Path "operations/reports/CODEX_CURRICULUM_CONTRACT_V1_VALIDATION.md"),($md -join "`r`n"),$utf8)
Write-Host "VALIDATION_STATUS=$status"
Write-Host "PROCESSED=$($lines.Count)"
Write-Host "ACCEPTED=$($accepted.Count)"
Write-Host "REJECTED=$($rejected.Count)"
Write-Host "PROMOTION_ALLOWED=false"
Write-Host "RUNTIME_READY=false"
if($status -notlike "PASS_*"){exit 1}