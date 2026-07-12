$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$req='contracts/living_loop/AUTHORITY_PREFLIGHT_GATE_V1_REQUIREMENT.md'
$decisionPath='reports/self_development/AUTHORITY_PREFLIGHT_GATE_V1_DECISION.json'
$reportPath='reports/self_development/AUTHORITY_PREFLIGHT_GATE_V1_REPORT.json'
$proofPath='tests/self_development/AUTHORITY_PREFLIGHT_GATE_V1_PROOF.json'
foreach($p in @($req,$decisionPath,$reportPath,$proofPath)){Assert (Test-Path $p) "MISSING:$p"}
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_brain_selector_stub_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'BRAIN_SELECTOR_STUB_VALIDATION_FAILED'
$d=Get-Content $decisionPath -Raw|ConvertFrom-Json
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($d.status -eq 'PASS_AUTHORITY_PREFLIGHT_GATE_V1_DECISION') 'DECISION_STATUS_BAD'
Assert ($r.status -eq 'PASS_AUTHORITY_PREFLIGHT_GATE_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_AUTHORITY_PREFLIGHT_GATE_V1') 'PROOF_STATUS_BAD'
Assert ($d.gate_decision -eq 'BLOCKED_PREFLIGHT') 'GATE_DECISION_NOT_BLOCKED'
Assert ($d.preflight_pass -eq $false) 'PREFLIGHT_PASS_OVERCLAIM'
Assert ($d.owner_authority_required -eq $true) 'OWNER_AUTHORITY_NOT_REQUIRED'
Assert ($d.owner_authority_proof_exists -eq $false) 'OWNER_AUTHORITY_UNEXPECTEDLY_EXISTS'
foreach($b in @('OWNER_REPAIR_AUTHORITY_MISSING','REPAIR_SCOPE_NOT_FORMALIZED_AS_TASK','REPAIR_VALIDATORS_NOT_DECLARED','ROLLBACK_OR_QUARANTINE_BOUNDARY_NOT_DECLARED','NO_FILE_WRITES_ALLOWED_BEFORE_PREFLIGHT_PASS')){Assert (@($d.blockers|Where-Object{$_ -eq $b}).Count -eq 1) "BLOCKER_MISSING:$b"}
Assert ($d.execution_allowed -eq $false) 'EXECUTION_ALLOWED_OVERCLAIM'
Assert ($d.mutation_authorized -eq $false) 'MUTATION_AUTHORIZED_OVERCLAIM'
Assert ($d.file_writes_allowed -eq $false) 'FILE_WRITES_ALLOWED_OVERCLAIM'
Assert ($d.runtime_ready -eq $false) 'RUNTIME_READY_OVERCLAIM'
Assert ($d.live_ready -eq $false) 'LIVE_READY_OVERCLAIM'
Assert ($d.autonomous_runtime -eq $false) 'AUTONOMOUS_OVERCLAIM'
Assert ($d.passport_active_allowed -eq $false) 'PASSPORT_ACTIVE_OVERCLAIM'
Assert ($p.required_blockers_present -eq $true) 'REQUIRED_BLOCKERS_PROOF_BAD'
Assert ($p.no_repair_performed -eq $true) 'REPAIR_PERFORMED_OVERCLAIM'
Assert ($p.no_file_writes_by_repair -eq $true) 'REPAIR_FILE_WRITES_OVERCLAIM'
Assert ($p.preflight_pass -eq $false) 'PROOF_PREFLIGHT_PASS_OVERCLAIM'
Assert ($p.mutation_authorized -eq $false) 'PROOF_MUTATION_OVERCLAIM'
Write-Host 'VALIDATION_PASS=PASS_AUTHORITY_PREFLIGHT_GATE_V1'
Write-Host 'GATE_DECISION=BLOCKED_PREFLIGHT'
Write-Host 'BLOCKERS=5'
Write-Host 'PREFLIGHT_PASS=false'
Write-Host 'MUTATION_AUTHORIZED=false'
Write-Host 'FILE_WRITES_ALLOWED=false'
