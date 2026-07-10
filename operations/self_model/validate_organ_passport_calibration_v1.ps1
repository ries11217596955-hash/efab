$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$r=Get-Content 'reports/self_development/ORGAN_PASSPORT_CALIBRATION_V1.json' -Raw|ConvertFrom-Json
$p=Get-Content 'tests/self_development/ORGAN_PASSPORT_CALIBRATION_V1_PROOF.json' -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_ORGAN_PASSPORT_CALIBRATION_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_ORGAN_PASSPORT_CALIBRATION_V1') 'PROOF_STATUS_BAD'
Assert ([int]$r.organ_draft_count -eq 27) 'ORGAN_DRAFT_COUNT_BAD'
Assert ([int]$p.organ_draft_count -eq 27) 'PROOF_DRAFT_COUNT_BAD'
Assert ([int]$p.ready_for_lab_validation_count -eq 1) 'READY_COUNT_BAD'
Assert ([int]$p.needs_proof_run_count -eq 9) 'NEEDS_PROOF_COUNT_BAD'
Assert ([int]$p.needs_validator_surface_count -eq 1) 'NEEDS_VALIDATOR_COUNT_BAD'
Assert ([int]$p.blocked_or_too_generic_count -eq 16) 'BLOCKED_COUNT_BAD'
Assert (@($p.shortlist_ids).Count -eq 1 -and @($p.shortlist_ids)[0] -eq 'operations_live_readiness') 'SHORTLIST_BAD'
Assert ($r.boundaries.calibration_only -eq $true) 'CALIBRATION_BOUNDARY_BAD'
Assert ($r.boundaries.no_validated_lab_claim_created -eq $true) 'VALIDATED_LAB_BOUNDARY_BAD'
Assert ($r.boundaries.no_active_passports_created -eq $true) 'ACTIVE_BOUNDARY_BAD'
Assert ($r.boundaries.no_live_claims -eq $true) 'LIVE_BOUNDARY_BAD'
Assert ($r.boundaries.live_process_touched -eq $false) 'LIVE_TOUCHED_BAD'
Write-Host 'VALIDATION_PASS=PASS_ORGAN_PASSPORT_CALIBRATION_V1'
Write-Host 'READY_FOR_LAB_VALIDATION=operations_live_readiness'
Write-Host 'REPORT_PATH=reports/self_development/ORGAN_PASSPORT_CALIBRATION_V1.json'
Write-Host 'PROOF_PATH=tests/self_development/ORGAN_PASSPORT_CALIBRATION_V1_PROOF.json'
