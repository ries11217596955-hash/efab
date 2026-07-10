$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$r=Get-Content 'reports/self_development/ORGAN_PASSPORT_MATURITY_TRIAGE_V1.json' -Raw|ConvertFrom-Json
$p=Get-Content 'tests/self_development/ORGAN_PASSPORT_MATURITY_TRIAGE_V1_PROOF.json' -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_ORGAN_PASSPORT_MATURITY_TRIAGE_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_ORGAN_PASSPORT_MATURITY_TRIAGE_V1') 'PROOF_STATUS_BAD'
Assert ([int]$r.passport_count -eq 159) 'PASSPORT_COUNT_BAD'
Assert ([int]$p.passport_count -eq 159) 'PROOF_COUNT_BAD'
Assert ([int]$p.calibrate_organ_draft_count -eq 27) 'CALIBRATE_COUNT_BAD'
Assert ([int]$p.owner_link_required_count -eq 9) 'OWNER_LINK_COUNT_BAD'
Assert ([int]$p.reference_material_count -eq 121) 'REFERENCE_COUNT_BAD'
Assert ([int]$p.blocked_runtime_count -eq 1) 'BLOCKED_COUNT_BAD'
Assert ([int]$p.meta_count -eq 1) 'META_COUNT_BAD'
Assert ($r.boundaries.triage_only -eq $true) 'TRIAGE_BOUNDARY_BAD'
Assert ($r.boundaries.no_active_passports_created -eq $true) 'ACTIVE_BOUNDARY_BAD'
Assert ($r.boundaries.no_live_claims -eq $true) 'LIVE_BOUNDARY_BAD'
Assert ($r.boundaries.live_process_touched -eq $false) 'LIVE_TOUCHED_BAD'
Write-Host 'VALIDATION_PASS=PASS_ORGAN_PASSPORT_MATURITY_TRIAGE_V1'
Write-Host 'REPORT_PATH=reports/self_development/ORGAN_PASSPORT_MATURITY_TRIAGE_V1.json'
Write-Host 'PROOF_PATH=tests/self_development/ORGAN_PASSPORT_MATURITY_TRIAGE_V1_PROOF.json'
