param([string]$ProofPath='tests/parallel_life/SCHOOL_AIMO_PARALLEL_LAB_V1_PROOF.json')
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
if(-not(Test-Path $ProofPath)){ throw "PROOF_MISSING=$ProofPath" }
$P=Get-Content $ProofPath -Raw | ConvertFrom-Json
Assert ($P.schema -eq 'school_aimo_parallel_lab_v1') 'SCHEMA_MISMATCH'
Assert ($P.status -eq 'PASS_SCHOOL_AIMO_PARALLEL_LAB_V1') "STATUS_NOT_PASS:$($P.status)"
Assert ($P.proof_label -eq 'PROVEN_LAB_PARALLEL_MECHANICS_NOT_LIVE') 'PROOF_LABEL_MISMATCH'
Assert ($P.repo.root -eq 'H:/efab') 'REPO_ROOT_NOT_H_EFAB'
Assert ($P.repo.branch -eq 'main') 'BRANCH_NOT_MAIN'
Assert ($P.repo.origin -eq 'https://github.com/ries11217596955-hash/efab.git') 'ORIGIN_MISMATCH'
Assert ($P.school.exit_code -eq 0) 'SCHOOL_EXIT_NOT_ZERO'
Assert ($P.aimo.exit_code -eq 0) 'AIMO_EXIT_NOT_ZERO'
Assert ($P.parallel_evidence.school_seen_before_aimo -eq $true) 'SCHOOL_NOT_SEEN_BEFORE_AIMO'
Assert ($P.parallel_evidence.school_process_observed_during_aimo -eq $true) 'SCHOOL_NOT_OBSERVED_DURING_AIMO'
Assert ($P.parallel_evidence.aimo_detected_school_active -eq $true) 'AIMO_DID_NOT_DETECT_SCHOOL_ACTIVE'
Assert ($P.parallel_evidence.aimo_coordination_hint_present -eq $true) 'AIMO_COORDINATION_HINT_MISSING'
Assert ($P.aimo.cycles -ge 1) 'AIMO_NO_CYCLES'
Assert ($P.aimo.proof_summary.school_coordination_hint.memory_write_rule -eq 'no_direct_active_memory_write_use_intake_merge_queue_only') 'MEMORY_WRITE_RULE_MISMATCH'
Assert ($P.aimo.proof_summary.mutation_audit.active_memory_mutated -eq $false) 'AIMO_DIRECT_MEMORY_MUTATION'
Assert ($P.aimo.proof_summary.mutation_audit.school_started -eq $false) 'AIMO_STARTED_SCHOOL'
$packet=$P.intake_merge.agentlife_packet
Assert ($null -ne $packet) 'AGENTLIFE_PACKET_MISSING'
Assert ($packet.intake_status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1') "INTAKE_NOT_PASS:$($packet.intake_status)"
Assert ($packet.status -in @('PASS_AGENTLIFE_PACKET_SUBMITTED_SCHOOL_ACTIVE_BACKOFF','PASS_AGENTLIFE_PACKET_SUBMITTED_MERGE_BACKOFF_LOCK')) "BACKOFF_STATUS_NOT_PASS:$($packet.status)"
Assert ($packet.merge_attempted -eq $false) 'MERGE_ATTEMPTED_DURING_BACKOFF'
Assert ($P.intake_merge.merge_after_school.attempted -eq $true) 'POST_SCHOOL_MERGE_NOT_ATTEMPTED'
Assert ($P.intake_merge.merge_after_school.status -eq 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1') "POST_SCHOOL_MERGE_NOT_PASS:$($P.intake_merge.merge_after_school.status)"
Assert (@($P.blockers).Count -eq 0) "BLOCKERS_PRESENT:$(@($P.blockers) -join ',')"
Write-Host 'VALIDATION_PASS=PASS_SCHOOL_AIMO_PARALLEL_LAB_V1'
Write-Host "PROOF_PATH=$ProofPath"
Write-Host 'RUNTIME_READY=false'