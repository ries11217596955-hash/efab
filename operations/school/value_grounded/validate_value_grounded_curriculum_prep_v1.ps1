$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
& operations/school/value_grounded/prepare_value_grounded_curriculum_v1.ps1 -MaxItems 80 | Out-Host
$r=Get-Content operations/reports/VALUE_GROUNDED_CURRICULUM_PREP_V1.json -Raw | ConvertFrom-Json
$bad=@($r.candidates | Where-Object { $_.source_is_real_repo_evidence -ne $true -or $_.self_generated_easy_candidate -ne $false -or $_.promotion_allowed -ne $false -or [string]::IsNullOrWhiteSpace($_.evidence_path) -or [string]::IsNullOrWhiteSpace($_.evidence_sha256) })
$hasWeak=@($r.candidates | Where-Object { $_.evidence_path -match "WEAK_SEMANTIC_OVERNIGHT_RUN_AUDIT" }).Count -gt 0
$hasGate=@($r.candidates | Where-Object { $_.evidence_path -match "GPT_OPERATOR_LIVING_CELL_SOURCE_LADDER" }).Count -gt 0
$ok=($r.status -eq "VALUE_GROUNDED_CURRICULUM_INBOX_PREPARED_NO_PROMOTION" -and $r.promotion_allowed -eq $false -and [int]$r.candidate_count -gt 0 -and $bad.Count -eq 0 -and $hasWeak -and $hasGate)
$status=if($ok){"PASS_VALUE_GROUNDED_CURRICULUM_PREP_V1"}else{"FAIL_VALUE_GROUNDED_CURRICULUM_PREP_V1"}
$report=[pscustomobject]@{schema="value_grounded_curriculum_prep_validator_v1"; status=$status; runtime_ready=$false; candidate_count=$r.candidate_count; bad_candidate_count=$bad.Count; has_weak_audit=$hasWeak; has_operator_gate=$hasGate; promotion_allowed=$false; boundary="Prepared evidence-grounded inbox only; no atoms promoted."}
$utf8=New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path (Get-Location).Path "operations/reports/VALUE_GROUNDED_CURRICULUM_PREP_V1_VALIDATION.json"),($report|ConvertTo-Json -Depth 20),$utf8)
Write-Host "VALIDATION_STATUS=$status"
Write-Host "CANDIDATE_COUNT=$($r.candidate_count)"
Write-Host "BAD_CANDIDATE_COUNT=$($bad.Count)"
Write-Host "HAS_WEAK_AUDIT=$hasWeak"
Write-Host "HAS_OPERATOR_GATE=$hasGate"
Write-Host "PROMOTION_ALLOWED=false"
Write-Host "RUNTIME_READY=false"
if(-not $ok){exit 1}