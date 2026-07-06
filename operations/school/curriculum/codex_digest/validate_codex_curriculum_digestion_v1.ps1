param([string]$BatchPath=".runtime/codex_curriculum_batches/codex_curriculum_canary_batch_v1.jsonl")
$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
& operations/school/curriculum/codex_digest/digest_codex_curriculum_batch_v1.ps1 -BatchPath $BatchPath | Out-Host
$r=Get-Content operations/reports/CODEX_CURRICULUM_DIGESTION_V1.json -Raw | ConvertFrom-Json
$cp=Get-Content operations/school/curriculum/codex_digest/store/active_codex_curriculum_digest_v1/active_codex_curriculum_digest_checkpoint.json -Raw | ConvertFrom-Json
$ok=($r.status -eq "PASS_CODEX_CURRICULUM_DIGESTION_V1" -and [int]$r.processed_count -ge 1 -and [int]$r.contract_accepted_count -ge 1 -and [int]$r.digested_atom_candidate_count -eq [int]$r.contract_accepted_count -and [int]$r.behavior_use_pass_count -eq [int]$r.digested_atom_candidate_count -and [int]$r.return_to_parent_pass_count -eq [int]$r.digested_atom_candidate_count -and $r.accepted_core_promotion -eq $false -and $cp.accepted_core_promotion -eq $false -and [int]$cp.digested_atom_candidate_count -eq [int]$r.digested_atom_candidate_count)
$status=if($ok){"PASS_CODEX_CURRICULUM_DIGESTION_VALIDATION_V1"}else{"FAIL_CODEX_CURRICULUM_DIGESTION_VALIDATION_V1"}
$v=[pscustomObject]@{schema="codex_curriculum_digestion_validator_v1"; status=$status; runtime_ready=$false; batch_path=$BatchPath; processed_count=$r.processed_count; contract_accepted_count=$r.contract_accepted_count; contract_rejected_count=$r.contract_rejected_count; digested_atom_candidate_count=$r.digested_atom_candidate_count; behavior_use_pass_count=$r.behavior_use_pass_count; return_to_parent_pass_count=$r.return_to_parent_pass_count; accepted_core_promotion=$false; boundary="School-local validation; no accepted-core promotion. Dynamic counts allowed."}
$utf8=New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path (Get-Location).Path "operations/reports/CODEX_CURRICULUM_DIGESTION_V1_VALIDATION.json"),($v|ConvertTo-Json -Depth 30),$utf8)
$md=@("# CODEX_CURRICULUM_DIGESTION_V1_VALIDATION","","Status: $status","Runtime ready: false","","Batch path: $BatchPath","Processed: $($r.processed_count)","Contract accepted: $($r.contract_accepted_count)","Contract rejected: $($r.contract_rejected_count)","Digested atom candidates: $($r.digested_atom_candidate_count)","Behavior-use pass: $($r.behavior_use_pass_count)","Return-to-parent pass: $($r.return_to_parent_pass_count)","Accepted-core promotion: false","","Boundary: dynamic school-local validation only; no accepted-core promotion.")
[IO.File]::WriteAllText((Join-Path (Get-Location).Path "operations/reports/CODEX_CURRICULUM_DIGESTION_V1_VALIDATION.md"),($md -join "`r`n"),$utf8)
Write-Host "VALIDATION_STATUS=$status"
Write-Host "PROCESSED=$($r.processed_count)"
Write-Host "CONTRACT_ACCEPTED=$($r.contract_accepted_count)"
Write-Host "CONTRACT_REJECTED=$($r.contract_rejected_count)"
Write-Host "DIGESTED_ATOM_CANDIDATES=$($r.digested_atom_candidate_count)"
Write-Host "BEHAVIOR_USE_PASS=$($r.behavior_use_pass_count)"
Write-Host "RETURN_TO_PARENT_PASS=$($r.return_to_parent_pass_count)"
Write-Host "ACCEPTED_CORE_PROMOTION=false"
Write-Host "RUNTIME_READY=false"
if(-not $ok){exit 1}