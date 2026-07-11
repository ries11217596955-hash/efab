$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$proofPath='tests/parallel_life/SCHOOL_AIMO_PARALLEL_LAB_V1_PROOF.json'
Assert (Test-Path $proofPath) 'PROOF_MISSING'
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($p.status -eq 'PASS_SCHOOL_AIMO_PARALLEL_LAB_V1') "BAD_STATUS=$($p.status)"
Assert ($p.runtime_ready -eq $false) 'RUNTIME_READY_OVERCLAIM'
Assert ($p.parallel_evidence.school_seen_before_aimo -eq $true) 'SCHOOL_NOT_SEEN_BEFORE_AIMO'
Assert ($p.parallel_evidence.school_process_observed_during_aimo -eq $true) 'SCHOOL_NOT_OBSERVED_DURING_AIMO'
Assert ($p.parallel_evidence.aimo_detected_school_active -eq $true) 'AIMO_DID_NOT_DETECT_SCHOOL'
Assert ($p.parallel_evidence.aimo_coordination_hint_present -eq $true) 'COORDINATION_HINT_MISSING'
Assert ($p.intake_merge.agentlife_packet.merge_attempted -eq $false) 'MERGE_ATTEMPTED_DURING_SCHOOL'
Assert ($p.intake_merge.merge_after_school.attempted -eq $true) 'MERGE_AFTER_SCHOOL_NOT_ATTEMPTED'
Assert ($p.intake_merge.merge_after_school.exit_code -eq 0) 'MERGE_AFTER_SCHOOL_FAILED'
$boundary=[string]$p.boundary
Assert ($boundary -match 'Repeatable lab proof only') 'BOUNDARY_NOT_LAB_ONLY'
Assert ($boundary -match 'Not live readiness') 'BOUNDARY_LIVE_OVERCLAIM'
Write-Host 'VALIDATION_PASS=PASS_SCHOOL_AIMO_PARALLEL_LAB_SIGNAL_CONTRACT_V1'
Write-Host 'SIGNAL=PARALLEL_LAB_COORDINATION_PROVEN'
Write-Host 'RUNTIME_READY=false'
Write-Host 'LIVE_READY=false'
