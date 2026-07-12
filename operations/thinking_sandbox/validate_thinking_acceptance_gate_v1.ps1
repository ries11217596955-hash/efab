$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$req='contracts/thinking_sandbox/THINKING_ACCEPTANCE_GATE_V1_REQUIREMENT.md'
$decisionsPath='reports/self_development/THINKING_ACCEPTANCE_GATE_V1_DECISIONS.json'
$reportPath='reports/self_development/THINKING_ACCEPTANCE_GATE_V1_REPORT.json'
$proofPath='tests/self_development/THINKING_ACCEPTANCE_GATE_V1_PROOF.json'
foreach($p in @($req,$decisionsPath,$reportPath,$proofPath)){Assert (Test-Path $p) "MISSING:$p"}
powershell -ExecutionPolicy Bypass -File operations/thinking_sandbox/validate_thinking_sandbox_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'THINKING_SANDBOX_VALIDATION_FAILED'
$d=Get-Content $decisionsPath -Raw|ConvertFrom-Json
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($d.status -eq 'PASS_THINKING_ACCEPTANCE_GATE_V1_DECISIONS') 'DECISIONS_STATUS_BAD'
Assert ($r.status -eq 'PASS_THINKING_ACCEPTANCE_GATE_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_THINKING_ACCEPTANCE_GATE_V1') 'PROOF_STATUS_BAD'
$decisions=@($d.decisions)
Assert ($decisions.Count -ge 30) 'DECISION_COUNT_TOO_LOW'
foreach($decision in $decisions){foreach($f in @('decision_id','source_cycle','source_type','source_ref','decision_class','why','validator_required','accepted_now','install_allowed','active_memory_update_allowed','rewrite_required','forbidden_actions','next_gate')){Assert ($decision.PSObject.Properties.Name -contains $f) "DECISION_FIELD_MISSING:$f"}; Assert ($decision.accepted_now -eq $false) "ACCEPTED_NOW_OVERCLAIM:$($decision.decision_id)"; Assert ($decision.install_allowed -eq $false) "INSTALL_ALLOWED_OVERCLAIM:$($decision.decision_id)"; Assert ($decision.active_memory_update_allowed -eq $false) "MEMORY_UPDATE_ALLOWED_OVERCLAIM:$($decision.decision_id)"; Assert (@($decision.forbidden_actions).Count -gt 0) "FORBIDDEN_ACTIONS_MISSING:$($decision.decision_id)"}
Assert ([int]$d.summary.cycles_covered -ge 10) 'CYCLES_COVERED_BAD'
Assert ([int]$d.summary.knowledge_decisions -eq [int]$d.summary.cycles_covered) 'KNOWLEDGE_COVERAGE_BAD'
Assert ([int]$d.summary.atom_decisions -eq [int]$d.summary.cycles_covered) 'ATOM_COVERAGE_BAD'
Assert ([int]$d.summary.compact_memory_decisions -eq [int]$d.summary.cycles_covered) 'MEMORY_COVERAGE_BAD'
Assert ([int]$d.summary.needs_validator_count -gt 0) 'NEEDS_VALIDATOR_MISSING'
Assert ([int]$d.summary.accepted_now_count -eq 0) 'ACCEPTED_NOW_COUNT_BAD'
Assert ([int]$d.summary.install_allowed_count -eq 0) 'INSTALL_ALLOWED_COUNT_BAD'
Assert ([int]$d.summary.active_memory_update_allowed_count -eq 0) 'MEMORY_UPDATE_ALLOWED_COUNT_BAD'
Assert ($d.boundary.active_memory_updated -eq $false) 'ACTIVE_MEMORY_UPDATED_OVERCLAIM'
Assert ($d.boundary.active_atoms_installed -eq $false) 'ACTIVE_ATOMS_INSTALLED_OVERCLAIM'
Assert ($d.boundary.pack_execution_performed -eq $false) 'PACK_EXECUTION_OVERCLAIM'
Assert ($d.boundary.live_runtime_touched -eq $false) 'LIVE_TOUCH_OVERCLAIM'
Assert ($d.boundary.mutation_authorized -eq $false) 'MUTATION_OVERCLAIM'
Assert ($p.at_least_one_needs_validator -eq $true) 'PROOF_NEEDS_VALIDATOR_BAD'
Assert ([int]$p.accepted_now_count -eq 0) 'PROOF_ACCEPTED_NOW_BAD'
Assert ([int]$p.install_allowed_count -eq 0) 'PROOF_INSTALL_ALLOWED_BAD'
Assert ([int]$p.active_memory_update_allowed_count -eq 0) 'PROOF_MEMORY_UPDATE_ALLOWED_BAD'
Write-Host 'VALIDATION_PASS=PASS_THINKING_ACCEPTANCE_GATE_V1'
Write-Host "DECISIONS=$($decisions.Count)"
Write-Host "NEEDS_VALIDATOR=$($d.summary.needs_validator_count)"
Write-Host 'ACCEPTED_NOW=0'
Write-Host 'ACTIVE_MEMORY_UPDATED=false'
