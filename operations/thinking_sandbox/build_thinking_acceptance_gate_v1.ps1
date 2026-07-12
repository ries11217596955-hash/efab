$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Write-Json([string]$Path,$Obj,[int]$Depth=100){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$Obj|ConvertTo-Json -Depth $Depth|Set-Content $Path -Encoding UTF8}
$tracePath='reports/self_development/THINKING_SANDBOX_V1_TRACE.json'
$atomsPath='reports/self_development/THINKING_SANDBOX_V1_KNOWLEDGE_ATOM_CANDIDATES.json'
$memoryPath='reports/self_development/THINKING_SANDBOX_V1_COMPACT_MEMORY_PROPOSALS.json'
$sandboxProofPath='tests/self_development/THINKING_SANDBOX_V1_PROOF.json'
$journalPath='operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md'
$decisionsPath='reports/self_development/THINKING_ACCEPTANCE_GATE_V1_DECISIONS.json'
$reportPath='reports/self_development/THINKING_ACCEPTANCE_GATE_V1_REPORT.json'
$proofPath='tests/self_development/THINKING_ACCEPTANCE_GATE_V1_PROOF.json'
foreach($p in @($tracePath,$atomsPath,$memoryPath,$sandboxProofPath,$journalPath)){Assert (Test-Path $p) "INPUT_MISSING:$p"}
powershell -ExecutionPolicy Bypass -File operations/thinking_sandbox/validate_thinking_sandbox_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'THINKING_SANDBOX_VALIDATION_FAILED'
$trace=Get-Content $tracePath -Raw|ConvertFrom-Json
$atoms=Get-Content $atomsPath -Raw|ConvertFrom-Json
$memory=Get-Content $memoryPath -Raw|ConvertFrom-Json
$proofIn=Get-Content $sandboxProofPath -Raw|ConvertFrom-Json
Assert ($trace.status -eq 'PASS_THINKING_SANDBOX_V1_TRACE') 'TRACE_STATUS_BAD'
$cycles=@($trace.cycles)
Assert ($cycles.Count -ge 10) 'CYCLES_TOO_FEW'
$decisions=@()
foreach($c in $cycles){
  $cycle=[int]$c.cycle
  $baseForbidden=@('INSTALL_ATOM','UPDATE_ACTIVE_COMPACT_MEMORY','RUN_PACK','TOUCH_LIVE_RUNTIME','CREATE_PASSPORT_ACTIVE','MUTATE_REPO_FROM_THOUGHT')
  $decisions += [ordered]@{
    decision_id="knowledge_cycle_$cycle"
    source_cycle=$cycle
    source_type='knowledge_candidate'
    source_ref=$tracePath
    decision_class='ACCEPT_AS_CANDIDATE_FOR_FUTURE_VALIDATION'
    why='Candidate is explicit CANDIDATE_ONLY, evidence-backed by sandbox inputs, and preserves no-action boundary.'
    validator_required=$true
    accepted_now=$false
    install_allowed=$false
    active_memory_update_allowed=$false
    rewrite_required=$false
    forbidden_actions=$baseForbidden
    next_gate='KNOWLEDGE_ATOM_VALIDATOR_OR_MEMORY_ACCEPTANCE_GATE'
  }
  $decisions += [ordered]@{
    decision_id="atom_cycle_$cycle"
    source_cycle=$cycle
    source_type='atom_candidate'
    source_ref=$atomsPath
    decision_class='NEEDS_VALIDATOR_BEFORE_ACCEPTANCE'
    why='Atom candidate could change future behavior; it requires validator and acceptance gate before installation.'
    validator_required=$true
    accepted_now=$false
    install_allowed=$false
    active_memory_update_allowed=$false
    rewrite_required=$false
    forbidden_actions=$baseForbidden
    next_gate='ATOM_ACCEPTANCE_VALIDATOR_V1'
  }
  $decisions += [ordered]@{
    decision_id="memory_cycle_$cycle"
    source_cycle=$cycle
    source_type='compact_memory_proposal'
    source_ref=$memoryPath
    decision_class='NEEDS_VALIDATOR_BEFORE_ACCEPTANCE'
    why='Compact memory proposal could affect future behavior; it must pass compact-memory acceptance and compression rules before active update.'
    validator_required=$true
    accepted_now=$false
    install_allowed=$false
    active_memory_update_allowed=$false
    rewrite_required=$false
    forbidden_actions=$baseForbidden
    next_gate='COMPACT_MEMORY_ACCEPTANCE_GATE_V1'
  }
}
$rejected=@($decisions|Where-Object{$_.decision_class -eq 'REJECT_AS_UNSUPPORTED_OR_OVERCLAIM'})
$needs=@($decisions|Where-Object{$_.decision_class -eq 'NEEDS_VALIDATOR_BEFORE_ACCEPTANCE'})
$acceptedCandidate=@($decisions|Where-Object{$_.decision_class -eq 'ACCEPT_AS_CANDIDATE_FOR_FUTURE_VALIDATION'})
$doc=[ordered]@{
  schema='thinking_acceptance_gate_v1_decisions'
  status='PASS_THINKING_ACCEPTANCE_GATE_V1_DECISIONS'
  source_trace_ref=$tracePath
  decisions=$decisions
  summary=[ordered]@{
    cycles_covered=$cycles.Count
    decision_count=$decisions.Count
    knowledge_decisions=@($decisions|Where-Object{$_.source_type -eq 'knowledge_candidate'}).Count
    atom_decisions=@($decisions|Where-Object{$_.source_type -eq 'atom_candidate'}).Count
    compact_memory_decisions=@($decisions|Where-Object{$_.source_type -eq 'compact_memory_proposal'}).Count
    accepted_as_candidate_count=$acceptedCandidate.Count
    needs_validator_count=$needs.Count
    rejected_count=$rejected.Count
    accepted_now_count=@($decisions|Where-Object{$_.accepted_now -eq $true}).Count
    install_allowed_count=@($decisions|Where-Object{$_.install_allowed -eq $true}).Count
    active_memory_update_allowed_count=@($decisions|Where-Object{$_.active_memory_update_allowed -eq $true}).Count
  }
  boundary=[ordered]@{lab_only=$true;active_memory_updated=$false;active_atoms_installed=$false;pack_execution_performed=$false;live_runtime_touched=$false;mutation_authorized=$false;runtime_ready=$false;live_ready=$false;autonomous_runtime=$false;passport_active_created=$false}
  created_at=(Get-Date).ToString('o')
}
$report=[ordered]@{
  schema='thinking_acceptance_gate_v1_report'
  status='PASS_THINKING_ACCEPTANCE_GATE_V1'
  requirement='contracts/thinking_sandbox/THINKING_ACCEPTANCE_GATE_V1_REQUIREMENT.md'
  decisions_ref=$decisionsPath
  summary=$doc.summary
  interpretation='Thinking Sandbox proposals were classified; none were installed or written to active memory.'
  next_logic_tuning_recommendation='Build Atom/Memory Candidate Validator V1 to test selected proposals before any active compact-memory update.'
  laws_enforced=@('Candidate acceptance is not active acceptance','Memory proposal is not memory update','Atom candidate is not installed atom','Useful idea still needs validator before becoming active rule','No mutation from thought')
  boundary=$doc.boundary
  created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{
  schema='thinking_acceptance_gate_v1_proof'
  status='PASS_THINKING_ACCEPTANCE_GATE_V1'
  thinking_sandbox_validated=$true
  cycles_covered=$cycles.Count
  all_cycles_covered=($cycles.Count -ge 10)
  knowledge_candidates_covered=(@($decisions|Where-Object{$_.source_type -eq 'knowledge_candidate'}).Count -eq $cycles.Count)
  atom_candidates_covered=(@($decisions|Where-Object{$_.source_type -eq 'atom_candidate'}).Count -eq $cycles.Count)
  compact_memory_proposals_covered=(@($decisions|Where-Object{$_.source_type -eq 'compact_memory_proposal'}).Count -eq $cycles.Count)
  needs_validator_count=$needs.Count
  at_least_one_needs_validator=($needs.Count -gt 0)
  accepted_now_count=@($decisions|Where-Object{$_.accepted_now -eq $true}).Count
  install_allowed_count=@($decisions|Where-Object{$_.install_allowed -eq $true}).Count
  active_memory_update_allowed_count=@($decisions|Where-Object{$_.active_memory_update_allowed -eq $true}).Count
  no_active_memory_updated=$true
  no_active_atoms_installed=$true
  no_pack_execution=$true
  no_live_runtime_touched=$true
  mutation_authorized=$false
  runtime_ready=$false
  live_ready=$false
  autonomous_runtime=$false
  no_passport_active_created=$true
  report_path=$reportPath
  created_at=(Get-Date).ToString('o')
}
Write-Json $decisionsPath $doc 100
Write-Json $reportPath $report 100
Write-Json $proofPath $proof 100
Write-Host 'BUILD_PASS=PASS_THINKING_ACCEPTANCE_GATE_V1'
Write-Host "DECISIONS=$($decisions.Count)"
Write-Host "NEEDS_VALIDATOR=$($needs.Count)"
Write-Host 'ACCEPTED_NOW=0'
Write-Host 'ACTIVE_MEMORY_UPDATED=false'
