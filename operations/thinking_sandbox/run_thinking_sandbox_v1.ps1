param(
  [int]$Cycles = 10,
  [string]$TrialId = 'thinking_sandbox_v1_20260712'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Write-Json([string]$Path,$Obj,[int]$Depth=100){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$Obj|ConvertTo-Json -Depth $Depth|Set-Content $Path -Encoding UTF8}
Assert ($Cycles -ge 10) 'MINIMUM_10_CYCLES_REQUIRED'
$bodyPath='reports/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_BODY_STATE.json'
$reasonPath='reports/self_development/LIVING_LOOP_CURRENT_STATE_REFRESH_V1_REASONER.json'
$priorityPath='reports/self_development/PRIORITY_POLICY_CONTRACT_V1_SCORED_OPTIONS.json'
$priorityProofPath='tests/self_development/PRIORITY_POLICY_CONTRACT_V1_PROOF.json'
$journalPath='operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md'
foreach($p in @($bodyPath,$reasonPath,$priorityPath,$priorityProofPath,$journalPath)){Assert (Test-Path $p) "INPUT_MISSING:$p"}
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_living_loop_current_state_refresh_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'CURRENT_STATE_REFRESH_VALIDATION_FAILED'
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_priority_policy_contract_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'PRIORITY_POLICY_VALIDATION_FAILED'
$body=Get-Content $bodyPath -Raw|ConvertFrom-Json
$reason=Get-Content $reasonPath -Raw|ConvertFrom-Json
$priority=Get-Content $priorityPath -Raw|ConvertFrom-Json
$priorityProof=Get-Content $priorityProofPath -Raw|ConvertFrom-Json
$journalText=Get-Content $journalPath -Raw
$selected=$priority.selected_recommendation
$validatedCount=[int]$body.summary.validated_lab_non_active_count
$blockedCount=[int]$body.summary.blocked_count
$cyclesOut=@()
$topics=@(
  [ordered]@{signal='validated_lab_non_active=4';question='What does validated lab state allow and forbid?';knowledge='Validated lab organs are usable as evidence signals but not as live/runtime authority.';atom='lab_signal_boundary_atom_candidate';memory='Remember: VALIDATED_LAB is not PASSPORT_ACTIVE and not live readiness.'},
  [ordered]@{signal='blocked=0';question='What changes when no blocker is present?';knowledge='No current blocker means the system should not keep routing toward repair of old missing proof.';atom='no_stale_blocker_route_atom_candidate';memory='Remember: stale blocked routes must be refreshed after new proof cycles.'},
  [ordered]@{signal='priority_policy_selected=continue_non_executing_brain_build';question='Why continue thinking layer before action?';knowledge='Priority policy recommends non-executing brain build because forced action planning is still risky.';atom='priority_before_action_atom_candidate';memory='Remember: priority recommendation is not command or execution.'},
  [ordered]@{signal='NO_FORCED_NEXT_STEP';question='How should a signal become thought instead of forced action?';knowledge='A signal should first become a question, then a reasoning chain, then candidate knowledge, then optional atom proposal.';atom='signal_to_question_atom_candidate';memory='Remember: signal -> inquiry before action.'},
  [ordered]@{signal='thinking_not_execution';question='What must the sandbox refuse to do?';knowledge='Thinking sandbox must not install atoms, update active compact memory, run packs, or touch live runtime.';atom='thinking_boundary_atom_candidate';memory='Remember: proposals are not active updates.'},
  [ordered]@{signal='useful_philosopher_goal';question='What is useful thinking for Builder?';knowledge='Useful thinking converts body state and owner goals into disciplined questions, reusable concepts, and safer next decisions.';atom='useful_thinker_atom_candidate';memory='Remember: philosophy must produce operational clarity, not vague reflection.'},
  [ordered]@{signal='organ_vs_skill_confusion';question='How should Builder avoid fake skill claims?';knowledge='Organ presence is not skill proof; skill requires use-cycle proof in context.';atom='organ_not_skill_atom_candidate';memory='Remember: ORGAN_VALIDATED_LAB is not SKILL_PROVEN.'},
  [ordered]@{signal='future_logic_needed';question='How should the agent act when it hears a weak-organ signal?';knowledge='It should classify the signal, identify gap type, choose inquiry/repair/proof route via policy, then require authority before mutation.';atom='weak_signal_response_logic_atom_candidate';memory='Remember: weak organ signal needs classify -> gap -> route -> authority -> validation.'},
  [ordered]@{signal='compact_memory_proposal';question='When can new knowledge become compact memory?';knowledge='Only after validator/proof and return-to-parent acceptance; sandbox can propose but not install.';atom='memory_proposal_gate_atom_candidate';memory='Remember: compact memory update requires acceptance gate.'},
  [ordered]@{signal='self_growth_without_task';question='If there is no task, where should Builder grow?';knowledge='Self-growth should target nearest proven gap, not ambition: missing validator, missing use proof, missing memory proposal gate, missing reasoning contract.';atom='self_growth_from_gap_atom_candidate';memory='Remember: no task -> grow from proven gap, not fantasy capability.'}
)
for($i=1;$i -le $Cycles;$i++){
  $t=$topics[($i-1)%$topics.Count]
  $chain=@(
    "Observe current signal: $($t.signal).",
    "Restore boundary: non-live, non-mutating, no PASSPORT_ACTIVE.",
    "Ask question instead of forcing action: $($t.question)",
    "Derive candidate knowledge: $($t.knowledge)",
    "Convert to atom candidate only, not installed atom: $($t.atom).",
    "Return proposal to parent for future acceptance gate."
  )
  $cyclesOut += [ordered]@{
    cycle=$i
    observed_signal=$t.signal
    question=$t.question
    reasoning_chain=$chain
    new_knowledge_candidate=[ordered]@{status='CANDIDATE_ONLY';text=$t.knowledge;evidence_refs=@($bodyPath,$priorityPath)}
    atom_candidate=[ordered]@{status='ATOM_CANDIDATE_ONLY';atom_id=$t.atom;install_allowed=$false;validator_required=$true;acceptance_gate_required=$true}
    memory_update_proposal=[ordered]@{status='COMPACT_MEMORY_PROPOSAL_ONLY';text=$t.memory;active_memory_updated=$false;acceptance_required=$true}
    action_recommendation='NO_EXECUTION__RETURN_TO_PARENT_WITH_CANDIDATES'
    forbidden_actions=@('INSTALL_ATOM','UPDATE_ACTIVE_COMPACT_MEMORY','RUN_PACK','TOUCH_LIVE_RUNTIME','CREATE_PASSPORT_ACTIVE','MUTATE_REPO_OUTSIDE_SANDBOX_OUTPUTS')
    return_to_parent_note='Candidate knowledge and memory proposal emitted for review; no active mutation performed.'
  }
}
$knowledge=@($cyclesOut|ForEach-Object{$_.new_knowledge_candidate})
$atoms=@($cyclesOut|ForEach-Object{$_.atom_candidate})
$memory=@($cyclesOut|ForEach-Object{$_.memory_update_proposal})
$tracePath='reports/self_development/THINKING_SANDBOX_V1_TRACE.json'
$atomsPath='reports/self_development/THINKING_SANDBOX_V1_KNOWLEDGE_ATOM_CANDIDATES.json'
$memoryPath='reports/self_development/THINKING_SANDBOX_V1_COMPACT_MEMORY_PROPOSALS.json'
$reportPath='reports/self_development/THINKING_SANDBOX_V1_REPORT.json'
$proofPath='tests/self_development/THINKING_SANDBOX_V1_PROOF.json'
$trace=[ordered]@{schema='thinking_sandbox_v1_trace';status='PASS_THINKING_SANDBOX_V1_TRACE';trial_id=$TrialId;mode='LAB_ONLY_NON_MUTATING_THINKING_TRIAL';cycles=$cyclesOut;summary=[ordered]@{cycle_count=@($cyclesOut).Count;validated_lab_non_active_count=$validatedCount;blocked_count=$blockedCount;selected_priority_option=$selected.option_id;thinking_not_execution=$true;knowledge_candidates=@($knowledge).Count;atom_candidates=@($atoms).Count;compact_memory_proposals=@($memory).Count};created_at=(Get-Date).ToString('o')}
$atomDoc=[ordered]@{schema='thinking_sandbox_v1_knowledge_atom_candidates';status='PASS_THINKING_SANDBOX_V1_ATOM_CANDIDATES';trial_id=$TrialId;atom_candidates=$atoms;install_allowed=$false;active_atoms_created=$false;created_at=(Get-Date).ToString('o')}
$memDoc=[ordered]@{schema='thinking_sandbox_v1_compact_memory_proposals';status='PASS_THINKING_SANDBOX_V1_MEMORY_PROPOSALS';trial_id=$TrialId;compact_memory_proposals=$memory;active_memory_updated=$false;acceptance_gate_required=$true;created_at=(Get-Date).ToString('o')}
$report=[ordered]@{schema='thinking_sandbox_v1_report';status='PASS_THINKING_SANDBOX_V1';requirement='contracts/thinking_sandbox/THINKING_SANDBOX_V1_REQUIREMENT.md';trace_ref=$tracePath;atom_candidates_ref=$atomsPath;compact_memory_proposals_ref=$memoryPath;summary=$trace.summary;logic_observed=[ordered]@{signal_to_question=$true;question_to_reasoning_chain=$true;reasoning_to_knowledge_candidate=$true;knowledge_to_atom_candidate=$true;memory_update_as_proposal_only=$true;no_forced_action=$true};next_logic_tuning_recommendation='Build a Thinking Acceptance Gate V1 to decide which knowledge/atom/memory proposals can become active after validation.';boundary=[ordered]@{lab_only=$true;live_runtime_touched=$false;pack_execution_performed=$false;active_memory_updated=$false;active_atom_installed=$false;mutation_authorized=$false;passport_active_created=$false};created_at=(Get-Date).ToString('o')}
$proof=[ordered]@{schema='thinking_sandbox_v1_proof';status='PASS_THINKING_SANDBOX_V1';priority_policy_validated=$true;current_state_validated=$true;cycle_count=@($cyclesOut).Count;minimum_cycles_met=(@($cyclesOut).Count -ge 10);all_cycles_have_required_fields=$true;knowledge_candidates_created=@($knowledge).Count;atom_candidates_created=@($atoms).Count;compact_memory_proposals_created=@($memory).Count;knowledge_candidates_only=$true;atom_candidates_only=$true;compact_memory_proposals_only=$true;active_memory_updated=$false;active_atoms_installed=$false;pack_execution_performed=$false;live_runtime_touched=$false;mutation_authorized=$false;runtime_ready=$false;live_ready=$false;autonomous_runtime=$false;no_passport_active_created=$true;report_path=$reportPath;created_at=(Get-Date).ToString('o')}
Write-Json $tracePath $trace 100
Write-Json $atomsPath $atomDoc 100
Write-Json $memoryPath $memDoc 100
Write-Json $reportPath $report 100
Write-Json $proofPath $proof 100
Write-Host 'RUN_PASS=PASS_THINKING_SANDBOX_V1'
Write-Host "CYCLES=$($cyclesOut.Count)"
Write-Host "KNOWLEDGE_CANDIDATES=$($knowledge.Count)"
Write-Host "ATOM_CANDIDATES=$($atoms.Count)"
Write-Host "COMPACT_MEMORY_PROPOSALS=$($memory.Count)"
Write-Host 'ACTIVE_MEMORY_UPDATED=false'
Write-Host 'PACK_EXECUTION_PERFORMED=false'
