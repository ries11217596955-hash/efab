param([string]$BatchPath=".runtime/codex_curriculum_batches/codex_curriculum_canary_batch_v1.jsonl")
$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=60){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
function SafeId($s){ return ([string]$s -replace "[^a-zA-Z0-9_.-]","_").ToLower() }
if(-not (Test-Path $BatchPath)){ throw "BATCH_NOT_FOUND: $BatchPath" }
$batchHash=(Get-FileHash $BatchPath -Algorithm SHA256).Hash.ToLower()
$batchLines=Get-Content $BatchPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
& operations/school/curriculum/codex_contract/validate_codex_curriculum_batch_v1.ps1 -BatchPath $BatchPath | Out-Host
$validation=Get-Content operations/reports/CODEX_CURRICULUM_CONTRACT_V1_VALIDATION.json -Raw | ConvertFrom-Json
if($validation.status -ne "PASS_CODEX_CURRICULUM_BATCH_VALIDATOR_V1"){ throw "BATCH_VALIDATOR_NOT_PASS: $($validation.status)" }
$rejectedIds=@{}
foreach($r in $validation.rejected){ $rejectedIds[[string]$r.candidate_id]=$true }
$acceptedIds=@{}
foreach($a in $validation.accepted){ $acceptedIds[[string]$a.candidate_id]=$true }
$all=@(); $lineNo=0
foreach($line in $batchLines){ $lineNo++; $obj=$line | ConvertFrom-Json; $obj | Add-Member -NotePropertyName line -NotePropertyValue $lineNo -Force; $all += $obj }
$atoms=@(); $rejected=@(); $seq=0
foreach($c in $all){
  $cid=[string]$c.candidate_id
  if($rejectedIds.ContainsKey($cid)){ $rejected += [pscustomObject]@{candidate_id=$cid; source_mode=$c.source_mode; topic=$c.topic; line=$c.line; reason="contract_validator_rejected"}; continue }
  if(-not $acceptedIds.ContainsKey($cid)){ $rejected += [pscustomObject]@{candidate_id=$cid; source_mode=$c.source_mode; topic=$c.topic; line=$c.line; reason="not_present_in_accepted_set"}; continue }
  $seq++
  $behaviorPass=((-not [string]::IsNullOrWhiteSpace($c.expected_behavior)) -and (-not [string]::IsNullOrWhiteSpace($c.behavior_use_proof_target)) -and (-not [string]::IsNullOrWhiteSpace($c.exercise)) -and (-not [string]::IsNullOrWhiteSpace($c.negative_trap)))
  $returnPass=(-not [string]::IsNullOrWhiteSpace($c.return_to_parent))
  $atom=[pscustomObject]@{
    atom_id=("codex.curriculum.atom.{0:D4}.{1}.v1" -f $seq,(SafeId $c.topic));
    source_candidate_id=$cid;
    proof_energy_origin="CODEX";
    acceptance_scope="CURRICULUM_SCHOOL_LOCAL";
    accepted_core_status="NOT_PROMOTED_TO_ACCEPTED_CORE";
    source_mode=$c.source_mode;
    topic=$c.topic;
    level=[int]$c.level;
    objective=$c.objective;
    new_knowledge=$c.new_knowledge;
    exercise=$c.exercise;
    expected_behavior=$c.expected_behavior;
    negative_trap=$c.negative_trap;
    validator_hint=$c.validator_hint;
    behavior_use_proof=[pscustomObject]@{target=$c.behavior_use_proof_target; probe="apply_expected_behavior_to_future_operator_decision"; pass=$behaviorPass};
    return_to_parent_proof=[pscustomObject]@{target=$c.return_to_parent; pass=$returnPass};
    source_anchor=$c.source_anchor;
    duplicate_key=$c.duplicate_key;
    rollback_path="remove_from_codex_curriculum_digest_checkpoint"
  }
  $atoms += $atom
}
$behaviorUsePass=@($atoms | Where-Object { $_.behavior_use_proof.pass -eq $true }).Count
$returnPass=@($atoms | Where-Object { $_.return_to_parent_proof.pass -eq $true }).Count
$directed=@($atoms | Where-Object { $_.source_mode -eq "directed_curriculum" }).Count
$experience=@($atoms | Where-Object { $_.source_mode -eq "experience_curriculum" }).Count
$status=if($atoms.Count -gt 0 -and $behaviorUsePass -eq $atoms.Count -and $returnPass -eq $atoms.Count -and $rejected.Count -eq [int]$validation.rejected_count){"PASS_CODEX_CURRICULUM_DIGESTION_V1"}else{"FAIL_CODEX_CURRICULUM_DIGESTION_V1"}
$checkpoint=[pscustomObject]@{schema="codex_curriculum_digest_checkpoint_v1"; status=$status; runtime_ready=$false; batch_path=$BatchPath; batch_sha256=$batchHash; processed_count=$batchLines.Count; contract_accepted_count=$validation.accepted_count; contract_rejected_count=$validation.rejected_count; digested_atom_candidate_count=$atoms.Count; behavior_use_pass_count=$behaviorUsePass; return_to_parent_pass_count=$returnPass; directed_count=$directed; experience_count=$experience; accepted_core_promotion=$false; boundary="School-local digestion of validated Codex curriculum candidates; not D2B accepted-core promotion."; atoms=@($atoms); rejected=@($rejected)}
WriteJson "operations/school/curriculum/codex_digest/store/active_codex_curriculum_digest_v1/active_codex_curriculum_digest_checkpoint.json" $checkpoint 80
$report=[pscustomObject]@{schema="codex_curriculum_digestion_report_v1"; status=$status; runtime_ready=$false; batch_path=$BatchPath; batch_sha256=$batchHash; processed_count=$batchLines.Count; contract_accepted_count=$validation.accepted_count; contract_rejected_count=$validation.rejected_count; digested_atom_candidate_count=$atoms.Count; behavior_use_pass_count=$behaviorUsePass; return_to_parent_pass_count=$returnPass; directed_count=$directed; experience_count=$experience; accepted_core_promotion=$false; checkpoint_path="operations/school/curriculum/codex_digest/store/active_codex_curriculum_digest_v1/active_codex_curriculum_digest_checkpoint.json"; boundary="VALIDATED_PENDING_ACCEPTANCE in school-local scope only; no accepted-core promotion."}
WriteJson "operations/reports/CODEX_CURRICULUM_DIGESTION_V1.json" $report 40
$md=@("# CODEX_CURRICULUM_DIGESTION_V1","","Status: $status","Runtime ready: false","","Batch SHA256: $batchHash","Processed: $($batchLines.Count)","Contract accepted: $($validation.accepted_count)","Contract rejected: $($validation.rejected_count)","Digested atom candidates: $($atoms.Count)","Behavior-use pass: $behaviorUsePass","Return-to-parent pass: $returnPass","Directed: $directed","Experience: $experience","Accepted-core promotion: false","","Boundary: school-local digestion only; not D2B accepted-core promotion.")
[IO.File]::WriteAllText((Join-Path (Get-Location).Path "operations/reports/CODEX_CURRICULUM_DIGESTION_V1.md"),($md -join "`r`n"),$utf8)
Write-Host "DIGESTION_STATUS=$status"
Write-Host "PROCESSED=$($batchLines.Count)"
Write-Host "CONTRACT_ACCEPTED=$($validation.accepted_count)"
Write-Host "CONTRACT_REJECTED=$($validation.rejected_count)"
Write-Host "DIGESTED_ATOM_CANDIDATES=$($atoms.Count)"
Write-Host "BEHAVIOR_USE_PASS=$behaviorUsePass"
Write-Host "RETURN_TO_PARENT_PASS=$returnPass"
Write-Host "ACCEPTED_CORE_PROMOTION=false"
Write-Host "RUNTIME_READY=false"
if($status -notlike "PASS_*"){exit 1}