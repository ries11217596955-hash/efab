$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$req='contracts/thinking_sandbox/THINKING_SANDBOX_V1_REQUIREMENT.md'
$tracePath='reports/self_development/THINKING_SANDBOX_V1_TRACE.json'
$atomsPath='reports/self_development/THINKING_SANDBOX_V1_KNOWLEDGE_ATOM_CANDIDATES.json'
$memoryPath='reports/self_development/THINKING_SANDBOX_V1_COMPACT_MEMORY_PROPOSALS.json'
$reportPath='reports/self_development/THINKING_SANDBOX_V1_REPORT.json'
$proofPath='tests/self_development/THINKING_SANDBOX_V1_PROOF.json'
foreach($p in @($req,$tracePath,$atomsPath,$memoryPath,$reportPath,$proofPath)){Assert (Test-Path $p) "MISSING:$p"}
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_living_loop_current_state_refresh_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'CURRENT_STATE_REFRESH_VALIDATION_FAILED'
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_priority_policy_contract_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'PRIORITY_POLICY_VALIDATION_FAILED'
$trace=Get-Content $tracePath -Raw|ConvertFrom-Json
$atoms=Get-Content $atomsPath -Raw|ConvertFrom-Json
$memory=Get-Content $memoryPath -Raw|ConvertFrom-Json
$report=Get-Content $reportPath -Raw|ConvertFrom-Json
$proof=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($trace.status -eq 'PASS_THINKING_SANDBOX_V1_TRACE') 'TRACE_STATUS_BAD'
Assert ($atoms.status -eq 'PASS_THINKING_SANDBOX_V1_ATOM_CANDIDATES') 'ATOMS_STATUS_BAD'
Assert ($memory.status -eq 'PASS_THINKING_SANDBOX_V1_MEMORY_PROPOSALS') 'MEMORY_STATUS_BAD'
Assert ($report.status -eq 'PASS_THINKING_SANDBOX_V1') 'REPORT_STATUS_BAD'
Assert ($proof.status -eq 'PASS_THINKING_SANDBOX_V1') 'PROOF_STATUS_BAD'
$cycles=@($trace.cycles)
Assert ($cycles.Count -ge 10) 'CYCLE_COUNT_TOO_LOW'
foreach($c in $cycles){foreach($f in @('observed_signal','question','reasoning_chain','new_knowledge_candidate','atom_candidate','memory_update_proposal','action_recommendation','forbidden_actions','return_to_parent_note')){Assert ($c.PSObject.Properties.Name -contains $f) "CYCLE_FIELD_MISSING:$f"}; Assert (@($c.reasoning_chain).Count -ge 4) "REASONING_CHAIN_TOO_SHORT:$($c.cycle)"; Assert ($c.atom_candidate.install_allowed -eq $false) "ATOM_INSTALL_OVERCLAIM:$($c.cycle)"; Assert ($c.memory_update_proposal.active_memory_updated -eq $false) "MEMORY_UPDATE_OVERCLAIM:$($c.cycle)"; Assert ($c.action_recommendation -eq 'NO_EXECUTION__RETURN_TO_PARENT_WITH_CANDIDATES') "ACTION_RECOMMENDATION_BAD:$($c.cycle)"}
Assert ($atoms.install_allowed -eq $false) 'ATOM_INSTALL_ALLOWED_OVERCLAIM'
Assert ($atoms.active_atoms_created -eq $false) 'ACTIVE_ATOMS_CREATED_OVERCLAIM'
Assert ($memory.active_memory_updated -eq $false) 'ACTIVE_MEMORY_UPDATED_OVERCLAIM'
Assert ($report.boundary.live_runtime_touched -eq $false) 'LIVE_TOUCHED_OVERCLAIM'
Assert ($report.boundary.pack_execution_performed -eq $false) 'PACK_EXECUTION_OVERCLAIM'
Assert ($report.boundary.active_memory_updated -eq $false) 'REPORT_MEMORY_UPDATE_OVERCLAIM'
Assert ($report.boundary.active_atom_installed -eq $false) 'REPORT_ATOM_INSTALLED_OVERCLAIM'
Assert ($proof.minimum_cycles_met -eq $true) 'MINIMUM_CYCLES_PROOF_BAD'
Assert ($proof.knowledge_candidates_only -eq $true) 'KNOWLEDGE_CANDIDATES_ONLY_BAD'
Assert ($proof.atom_candidates_only -eq $true) 'ATOM_CANDIDATES_ONLY_BAD'
Assert ($proof.compact_memory_proposals_only -eq $true) 'MEMORY_PROPOSALS_ONLY_BAD'
Assert ($proof.active_memory_updated -eq $false) 'PROOF_ACTIVE_MEMORY_OVERCLAIM'
Assert ($proof.active_atoms_installed -eq $false) 'PROOF_ACTIVE_ATOM_OVERCLAIM'
Assert ($proof.pack_execution_performed -eq $false) 'PROOF_PACK_EXECUTION_OVERCLAIM'
Assert ($proof.live_runtime_touched -eq $false) 'PROOF_LIVE_TOUCH_OVERCLAIM'
Assert ($proof.mutation_authorized -eq $false) 'PROOF_MUTATION_OVERCLAIM'
Write-Host 'VALIDATION_PASS=PASS_THINKING_SANDBOX_V1'
Write-Host "CYCLES=$($cycles.Count)"
Write-Host "KNOWLEDGE_CANDIDATES=$($proof.knowledge_candidates_created)"
Write-Host "ATOM_CANDIDATES=$($proof.atom_candidates_created)"
Write-Host "COMPACT_MEMORY_PROPOSALS=$($proof.compact_memory_proposals_created)"
Write-Host 'ACTIVE_MEMORY_UPDATED=false'
Write-Host 'PACK_EXECUTION_PERFORMED=false'
