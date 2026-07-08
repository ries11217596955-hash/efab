$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$closurePath='reports/self_development/BODY_MAP_PHASE_CLOSURE_V1.json'
$proofPath='tests/self_development/BODY_MAP_PHASE_CLOSURE_V1_PROOF.json'
$mapPath='reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
$triagePath='reports/self_development/BODY_MAP_CANDIDATE_TRIAGE_V1.json'
$passportPath='self_model/organ_passports/operations_self_model/ORGAN_PASSPORT_V1.json'
foreach($path in @($closurePath,$proofPath,$mapPath,$triagePath,$passportPath)){Assert (Test-Path $path) ("MISSING:{0}" -f $path)}
$c=Get-Content $closurePath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
$m=Get-Content $mapPath -Raw|ConvertFrom-Json
$t=Get-Content $triagePath -Raw|ConvertFrom-Json
$passport=Get-Content $passportPath -Raw|ConvertFrom-Json
Assert ($c.status -eq 'PASS_BODY_MAP_PHASE_CLOSURE_V1') 'CLOSURE_STATUS_BAD'
Assert ($p.status -eq 'PASS_BODY_MAP_PHASE_CLOSURE_V1') 'PROOF_STATUS_BAD'
Assert (@($m.confirmed_components|Where-Object{$_.id -eq 'operations_self_model'}).Count -eq 1) 'OPERATIONS_SELF_MODEL_NOT_CONFIRMED'
Assert (@($m.primary_evidence_candidates|Where-Object{$_.id -eq 'operations_self_model'}).Count -eq 0) 'OPERATIONS_SELF_MODEL_STILL_CANDIDATE'
Assert (@($m.primary_evidence_candidates).Count -eq @($t.items).Count) 'TRIAGE_NOT_SYNCED_TO_CANDIDATES'
Assert ($passport.status -eq 'PASSPORT_DRAFT_FROM_EVIDENCE') 'PASSPORT_STATUS_BAD'
Assert ($passport.maturity -eq 'VALIDATED_LAB') 'PASSPORT_NOT_VALIDATED_LAB'
Assert ($passport.live_or_lab_status -eq 'PROVEN_LAB') 'PASSPORT_NOT_PROVEN_LAB'
Assert ($passport.live_or_lab_status -ne 'PROVEN_LIVE') 'PROVEN_LIVE_FORBIDDEN'
Assert ($m.component_authority_summary.child_agent_factory_readiness -eq 'NOT_PROVEN') 'CHILD_READINESS_BAD'
foreach($legacy in @('reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json','self_knowledge/BUILDER_SELF_MODEL.json')){Assert (-not(Test-Path $legacy)) ("LEGACY_MAP_PRESENT:{0}" -f $legacy)}
Write-Host 'VALIDATION_PASS=PASS_BODY_MAP_PHASE_CLOSURE_V1'
Write-Host ('REPORT_PATH='+$closurePath)
Write-Host ('PROOF_PATH='+$proofPath)
