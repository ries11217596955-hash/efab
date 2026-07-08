$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$triagePath='reports/self_development/BODY_MAP_CANDIDATE_TRIAGE_V1.json'
$planPath='reports/self_development/BODY_MAP_TRIAGE_PROMOTION_PLAN_V1.json'
$proofPath='tests/self_development/BODY_MAP_TRIAGE_PROMOTION_PLAN_V1_PROOF.json'
$mapPath='reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
foreach($path in @($triagePath,$planPath,$proofPath,$mapPath)){Assert (Test-Path $path) ("MISSING:{0}" -f $path)}
$t=Get-Content $triagePath -Raw|ConvertFrom-Json
$plan=Get-Content $planPath -Raw|ConvertFrom-Json
$proof=Get-Content $proofPath -Raw|ConvertFrom-Json
$m=Get-Content $mapPath -Raw|ConvertFrom-Json
Assert ($t.status -eq 'PASS_BODY_MAP_CANDIDATE_TRIAGE_V1') 'TRIAGE_STATUS_BAD'
Assert ($plan.status -eq 'PASS_BODY_MAP_TRIAGE_PROMOTION_PLAN_V1') 'PLAN_STATUS_BAD'
Assert ($proof.status -eq 'PASS_BODY_MAP_TRIAGE_PROMOTION_PLAN_V1') 'PROOF_STATUS_BAD'
$items=@($t.items)
Assert ($items.Count -eq @($m.primary_evidence_candidates).Count) 'TRIAGE_MAP_COUNT_MISMATCH'
Assert ($items.Count -eq [int]$plan.summary.total_triaged) 'PLAN_TOTAL_MISMATCH'
Assert ($items.Count -eq [int]$proof.total_triaged) 'PROOF_TOTAL_MISMATCH'
Assert (@($m.confirmed_components|Where-Object{$_.id -eq 'operations_self_model'}).Count -eq 1) 'OPERATIONS_SELF_MODEL_NOT_CONFIRMED'
Assert (@($m.primary_evidence_candidates|Where-Object{$_.id -eq 'operations_self_model'}).Count -eq 0) 'OPERATIONS_SELF_MODEL_STILL_CANDIDATE'
Assert (@($plan.promoted_to_confirmed|Where-Object{$_.component_id -eq 'operations_self_model'}).Count -eq 1) 'PROMOTED_COMPONENT_MISSING'
Assert ($plan.boundaries.no_active_passports_created -eq $true) 'ACTIVE_BOUNDARY_BAD'
Assert ($plan.boundaries.operations_self_model_promoted_by_lab_validation -eq $true) 'PROMOTION_BOUNDARY_BAD'
foreach($legacy in @('reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json','self_knowledge/BUILDER_SELF_MODEL.json')){Assert (-not(Test-Path $legacy)) ("LEGACY_MAP_PRESENT:{0}" -f $legacy)}
Write-Host 'VALIDATION_PASS=PASS_BODY_MAP_TRIAGE_PROMOTION_PLAN_V1'
Write-Host ('PLAN_PATH='+$planPath)
Write-Host ('PROOF_PATH='+$proofPath)
