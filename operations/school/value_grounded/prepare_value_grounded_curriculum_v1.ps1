param([int]$MaxItems=80)
$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function HashFile($p){ if(Test-Path $p){ return (Get-FileHash $p -Algorithm SHA256).Hash.ToLower() } return "" }
function WriteJson($p,$o,$d=30){ $dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8) }
$signals=@("AUDIT_INVALID","NOT_PROVEN","NOT_PROMOTED","FAILED","BLOCKED","Owner","Correction","rejected=0","engine stress","processed=N","runtime_ready=false","Codex","bloat","validator","proof")
$items=@()
$files=@()
$files += Get-ChildItem operations/reports -File -ErrorAction SilentlyContinue
$files += Get-Item operations/gpt_handoff/GPT_OPERATOR_LIVING_CELL_SOURCE_LADDER_V1.md -ErrorAction SilentlyContinue
$files += Get-Item operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md -ErrorAction SilentlyContinue
foreach($f in ($files | Where-Object {$null -ne $_} | Sort-Object LastWriteTime -Descending)){
  $txt=Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
  if([string]::IsNullOrWhiteSpace($txt)){continue}
  $hits=@()
  foreach($s in $signals){ if($txt -match [regex]::Escape($s)){ $hits += $s } }
  if($hits.Count -eq 0){continue}
  $kind="evidence"
  if($txt -match "AUDIT_INVALID|NOT_PROVEN|NOT_PROMOTED"){ $kind="audit_or_gap" }
  elseif($txt -match "FAILED|BLOCKED"){ $kind="failure_or_blocker" }
  elseif($txt -match "Owner|Correction"){ $kind="owner_correction" }
  $rel=$f.FullName.Substring((Get-Location).Path.Length+1)
  $items += [pscustomobject]@{ candidate_id=("value.curriculum.candidate.{0:D4}.v1" -f ($items.Count+1)); evidence_path=$rel; evidence_sha256=(HashFile $f.FullName); evidence_kind=$kind; signal_count=$hits.Count; signals=@($hits|Select-Object -First 8); source_is_real_repo_evidence=$true; self_generated_easy_candidate=$false; promotion_allowed=$false; utility_question="What reusable behavior or validator change is justified by this evidence?"; acceptance_requires=@("specific problem extracted","utility claim","negative case or risk","behavior-use proof","return-to-parent note") }
  if($items.Count -ge $MaxItems){break}
}
$out=[pscustomobject]@{ schema="value_grounded_curriculum_prep_v1"; status="VALUE_GROUNDED_CURRICULUM_INBOX_PREPARED_NO_PROMOTION"; runtime_ready=$false; promotion_allowed=$false; source_rule="real repo evidence only; no self-authored easy candidates"; candidate_count=$items.Count; candidates=@($items); boundary="This prepares curriculum inbox only. It does not claim learning." }
WriteJson "operations/school/value_grounded/store/value_grounded_candidate_inbox_v1.json" $out 40
WriteJson "operations/reports/VALUE_GROUNDED_CURRICULUM_PREP_V1.json" $out 40
$md=@("# VALUE_GROUNDED_CURRICULUM_PREP_V1","","Status: VALUE_GROUNDED_CURRICULUM_INBOX_PREPARED_NO_PROMOTION","Runtime ready: false","Promotion allowed: false","","Candidate count: $($items.Count)","","Boundary: inbox only; no learning claim.","","Source rule: real repo evidence only; no self-authored easy candidates.")
[IO.File]::WriteAllText((Join-Path (Get-Location).Path "operations/reports/VALUE_GROUNDED_CURRICULUM_PREP_V1.md"),($md -join "`r`n"),$utf8)
Write-Host "CURRICULUM_PREP_STATUS=$($out.status)"
Write-Host "CANDIDATE_COUNT=$($items.Count)"
Write-Host "PROMOTION_ALLOWED=false"
Write-Host "RUNTIME_READY=false"