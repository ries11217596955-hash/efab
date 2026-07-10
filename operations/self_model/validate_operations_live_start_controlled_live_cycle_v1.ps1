$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function RuntimeProcesses(){ @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.CommandLine) -and ([string]$_.CommandLine -notlike '*Get-CimInstance*') -and ([string]$_.CommandLine -like '* -File *run_agent_school.ps1*' -or [string]$_.CommandLine -like '* -File *run_autonomous_inner_motor.ps1*') }) }
$reportPath='reports/self_development/OPERATIONS_LIVE_START_CONTROLLED_LIVE_CYCLE_V1.json'
$proofPath='tests/self_development/OPERATIONS_LIVE_START_CONTROLLED_LIVE_CYCLE_V1_PROOF.json'
$passportPath='self_model/organ_passports/operations_live_start/ORGAN_PASSPORT_V1.json'
foreach($p in @($reportPath,$proofPath,$passportPath,'tests/live_start/SCHOOL_AIMO_CONTROLLED_LIVE_START_V1_PROOF.json','tests/live_start/SCHOOL_AIMO_CONTROLLED_LIVE_STOP_V1_PROOF.json')){Assert (Test-Path $p) "MISSING:$p"}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
$pass=Get-Content $passportPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_OPERATIONS_LIVE_START_CONTROLLED_LIVE_CYCLE_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_OPERATIONS_LIVE_START_CONTROLLED_LIVE_CYCLE_V1') 'PROOF_STATUS_BAD'
Assert ($p.decision -eq 'PROMOTE_TO_VALIDATED_LIVE_INITIAL_STOPPED') 'DECISION_BAD'
Assert ($p.maturity -eq 'VALIDATED_LIVE_INITIAL') 'MATURITY_BAD'
Assert ($p.live_or_lab_status -eq 'PROVEN_LIVE_INITIAL_STOPPED') 'LIVE_STATUS_BAD'
Assert ($p.start_pass -eq $true) 'START_PASS_BAD'
Assert ($p.stop_pass -eq $true) 'STOP_PASS_BAD'
Assert ([int]$p.heartbeats -ge 2) 'HEARTBEATS_TOO_LOW'
Assert ($p.owner_authorized -eq $true) 'OWNER_AUTH_BAD'
Assert ($p.live_process_touched -eq $true) 'LIVE_TOUCHED_SHOULD_BE_TRUE'
Assert ($p.runtime_active_after -eq $false) 'RUNTIME_ACTIVE_AFTER_BAD'
Assert ($p.passport_active_created -eq $false) 'PASSPORT_ACTIVE_BOUNDARY_BAD'
Assert ($p.long_soak_proven -eq $false) 'LONG_SOAK_BOUNDARY_BAD'
Assert ($pass.maturity -eq 'VALIDATED_LIVE_INITIAL') 'PASSPORT_MATURITY_BAD'
Assert ($pass.live_or_lab_status -eq 'PROVEN_LIVE_INITIAL_STOPPED') 'PASSPORT_LIVE_STATUS_BAD'
$active=@(RuntimeProcesses)
Assert ($active.Count -eq 0) "RUNTIME_STILL_ACTIVE:$($active.Count)"
Write-Host 'VALIDATION_PASS=PASS_OPERATIONS_LIVE_START_CONTROLLED_LIVE_CYCLE_V1'
Write-Host 'PASSPORT_MATURITY=VALIDATED_LIVE_INITIAL'
Write-Host 'LIVE_OR_LAB_STATUS=PROVEN_LIVE_INITIAL_STOPPED'
Write-Host 'RUNTIME_ACTIVE_AFTER=false'
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
