param([string]$ProofPath='tests/accepted_atom_retention/USEFUL_SCHOOL_30K_FULL_PROCESS_V1_PROOF.json')
$ErrorActionPreference='Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
if(-not(Test-Path $ProofPath)){ throw "PROOF_MISSING=$ProofPath" }
$P=Get-Content $ProofPath -Raw | ConvertFrom-Json
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
Assert ($P.schema -eq 'useful_school_30k_full_process_v1') 'SCHEMA_MISMATCH'
Assert ($P.status -eq 'PASS') 'STATUS_NOT_PASS'
Assert ([int]$P.accepted_total -eq 30000) 'ACCEPTED_TOTAL_NOT_30000'
Assert ([int]$P.rejected_total -ge 3000) 'REJECTED_TOTAL_LT_3000'
Assert ([int]$P.chunk_count -eq 6) 'CHUNK_COUNT_NOT_6'
Assert ([int]$P.subchunk_count -eq 300) 'SUBCHUNK_COUNT_NOT_300'
Assert ([int]$P.domain_count -eq 10) 'DOMAIN_COUNT_NOT_10'
Assert ([int]$P.level_count -eq 10) 'LEVEL_COUNT_NOT_10'
Assert ([int]$P.after_score -gt [int]$P.before_score) 'AFTER_NOT_GREATER_THAN_BEFORE'
Assert ([int]$P.improved_case_count -gt 0) 'NO_IMPROVED_CASES'
Assert ([int]$P.critical_regression_count -eq 0) 'CRITICAL_REGRESSION_PRESENT'
Assert ([int]$P.proof_confusion_after -le [int]$P.proof_confusion_before) 'PROOF_CONFUSION_REGRESSION'
Assert ([int]$P.unsafe_decision_after -le [int]$P.unsafe_decision_before) 'UNSAFE_DECISION_REGRESSION'
Assert ([int]$P.understood_atom_total -eq 30000) 'UNDERSTOOD_TOTAL_NOT_30000'
Assert ([int]$P.assimilated_atom_total -eq 30000) 'ASSIMILATED_TOTAL_NOT_30000'
Assert ([int]$P.promoted_delta_count -gt 0) 'NO_PROMOTED_DELTAS'
Assert ([int]$P.new_atoms_used_in_after_decisions -gt 0) 'NO_NEW_ATOMS_USED'
Assert ($P.retrieval_status -eq 'PASS') 'RETRIEVAL_NOT_PASS'
Assert ($P.decision_reuse_status -eq 'PASS') 'DECISION_REUSE_NOT_PASS'
Assert ($P.runtime_ready -eq $false) 'RUNTIME_READY_OVERCLAIM'
Assert ($P.legacy_runner_used -eq $false) 'LEGACY_RUNNER_USED'
Assert ($P.codex_output_treated_as_proof -eq $false) 'CODEX_OUTPUT_TREATED_AS_PROOF'
Assert ($P.raw_dump_in_repo -eq $false) 'RAW_DUMP_IN_REPO'
Assert ($P.anti_mechanical_generation_checks.serial_pattern_guard -eq $true) 'SERIAL_PATTERN_GUARD_FALSE'
Assert ($P.anti_mechanical_generation_checks.raw_dump_guard -eq $true) 'RAW_DUMP_GUARD_FALSE'
Assert ($P.anti_mechanical_generation_checks.accepted_count_only_guard -eq $true) 'ACCEPTED_COUNT_ONLY_GUARD_FALSE'
Assert ($P.anti_mechanical_generation_checks.domain_ladder_distribution_guard -eq $true) 'DOMAIN_LADDER_GUARD_FALSE'
$chain=@($P.chunk_state_chain)
Assert ($chain.Count -eq 6) 'CHAIN_COUNT_NOT_6'
for($i=1;$i -lt $chain.Count;$i++){ Assert ($chain[$i].input_hash -eq $chain[$i-1].output_hash) "CHAIN_BROKEN_AT_CHUNK_$($i+1)" }
foreach($c in @($P.chunk_summaries)){
  Assert ([int]$c.accepted_count -eq 5000) "CHUNK_ACCEPTED_NOT_5000_$($c.chunk)"
  Assert ([int]$c.rejected_count -gt 0) "CHUNK_REJECTED_ZERO_$($c.chunk)"
  Assert ([int]$c.understood_count -gt 0) "CHUNK_UNDERSTOOD_ZERO_$($c.chunk)"
  Assert ([int]$c.assimilated_count -gt 0) "CHUNK_ASSIMILATED_ZERO_$($c.chunk)"
  Assert ($c.retrieval_status -eq 'PASS') "CHUNK_RETRIEVAL_FAIL_$($c.chunk)"
  Assert ($c.decision_reuse_status -eq 'PASS') "CHUNK_DECISION_REUSE_FAIL_$($c.chunk)"
}
Write-Host 'VALIDATION_PASS=USEFUL_SCHOOL_30K_FULL_PROCESS_V1_PROVEN_LAB_MECHANICS'
Write-Host "PROOF_PATH=$ProofPath"
Write-Host 'RUNTIME_READY=false'
