$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$proofPath='tests/live_like/SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1_PROOF.json'
Assert (Test-Path $proofPath) 'PROOF_MISSING'
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($p.status -eq 'PASS_SCHOOL_AIMO_LIVE_LIKE_OBSERVATION_GATE_V1') "BAD_STATUS=$($p.status)"
Assert ($p.runtime_ready -eq $false) 'RUNTIME_READY_OVERCLAIM'
Assert ([string]$p.boundary -match 'Live-like lab observation gate only') 'BOUNDARY_NOT_LIVE_LIKE_LAB_ONLY'
Assert ([string]$p.boundary -match 'Not live readiness') 'LIVE_READINESS_OVERCLAIM_IN_BOUNDARY'
Assert ([string]$p.boundary -match 'not continuous autonomous runtime') 'AUTONOMOUS_RUNTIME_OVERCLAIM_IN_BOUNDARY'
Assert ($p.parallel_harness.status -eq 'PASS_SCHOOL_AIMO_PARALLEL_LAB_V1') 'PARALLEL_HARNESS_NOT_PASS'
Assert ($p.parallel_harness.runtime_ready -eq $false) 'PARALLEL_HARNESS_RUNTIME_READY_OVERCLAIM'
Assert ($p.parallel_harness.school_controlled_stop -eq $true) 'SCHOOL_CONTROLLED_STOP_NOT_TRUE'
Assert ([int]$p.parallel_harness.aimo_cycles -gt 0) 'AIMO_CYCLES_NOT_POSITIVE'
Assert ($p.parallel_harness.packet_status -eq 'PASS_AGENTLIFE_PACKET_SUBMITTED_SCHOOL_ACTIVE_BACKOFF') 'PACKET_STATUS_BAD'
Assert ($p.parallel_harness.intake_status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1') 'INTAKE_STATUS_BAD'
Assert ($p.parallel_harness.merge_after_school_status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1') 'MERGE_AFTER_SCHOOL_STATUS_BAD'
Write-Host 'VALIDATION_PASS=PASS_SCHOOL_AIMO_LIVE_LIKE_SIGNAL_CONTRACT_V1'
Write-Host 'SIGNAL=LIVE_LIKE_OBSERVATION_LAB_ONLY'
Write-Host 'RUNTIME_READY=false'
Write-Host 'LIVE_READY=false'
Write-Host 'AUTONOMOUS_RUNTIME=false'
