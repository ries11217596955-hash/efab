$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$triagePath='reports/self_development/BODY_MAP_CANDIDATE_TRIAGE_V1.json'
$planPath='reports/self_development/BODY_MAP_TRIAGE_PROMOTION_PLAN_V1.json'
$proofPath='tests/self_development/BODY_MAP_TRIAGE_PROMOTION_PLAN_V1_PROOF.json'
foreach($p in @($triagePath,$planPath,$proofPath)){Assert (Test-Path $p) ("MISSING:{0}" -f $p)}
$t=Get-Content $triagePath -Raw|ConvertFrom-Json
$plan=Get-Content $planPath -Raw|ConvertFrom-Json
$proof=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($t.status -eq 'PASS_BODY_MAP_CANDIDATE_TRIAGE_V1') 'TRIAGE_STATUS_BAD'
Assert ($plan.status -eq 'PASS_BODY_MAP_TRIAGE_PROMOTION_PLAN_V1') 'PLAN_STATUS_BAD'
Assert ($proof.status -eq 'PASS_BODY_MAP_TRIAGE_PROMOTION_PLAN_V1') 'PROOF_STATUS_BAD'
$items=@($t.items)
$ready=@($items|Where-Object{$_.passport_readiness -eq 'CANDIDATE_READY_FOR_DRAFT'})
$notOrgan=@($items|Where-Object{$_.passport_readiness -eq 'NOT_ORGAN'})
Assert ($items.Count -eq [int]$plan.summary.total_triaged) 'TOTAL_TRIAGED_MISMATCH'
Assert ($ready.Count -eq [int]$plan.summary.candidate_ready_for_draft) 'READY_COUNT_MISMATCH'
Assert (@($plan.fast_lane).Count -eq $ready.Count) 'FAST_LANE_COUNT_MISMATCH'
Assert ($notOrgan.Count -eq [int]$plan.summary.not_organ) 'NOT_ORGAN_COUNT_MISMATCH'
Assert ($plan.boundaries.no_active_passports_created -eq $true) 'ACTIVE_PASSPORT_BOUNDARY_BAD'
Assert ($plan.boundaries.no_candidate_accepted_as_organ -eq $true) 'ORGAN_ACCEPTANCE_BOUNDARY_BAD'
Assert ($plan.boundaries.passport_generator_for_all_candidates_blocked -eq $true) 'ALL_CANDIDATE_GENERATOR_BLOCK_BAD'
Assert ($proof.next_generator_scope -eq 'candidate_ready_for_draft_only') 'NEXT_SCOPE_BAD'
foreach($legacy in @('reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json','self_knowledge/BUILDER_SELF_MODEL.json')){Assert (-not(Test-Path $legacy)) ("LEGACY_MAP_PRESENT:{0}" -f $legacy)}
Write-Host 'VALIDATION_PASS=PASS_BODY_MAP_TRIAGE_PROMOTION_PLAN_V1'
Write-Host ('PLAN_PATH='+$planPath)
Write-Host ('PROOF_PATH='+$proofPath)
