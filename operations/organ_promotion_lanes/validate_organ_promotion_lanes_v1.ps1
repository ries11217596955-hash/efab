$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function CountOf($x){ return @($x).Count }
function IsTrueValue($v){ return ([string]$v).ToLowerInvariant() -eq 'true' }
$modelPath='self_model/organ_promotion_lanes/ORGAN_PROMOTION_LANES_V1.json'
$reportPath='reports/self_development/ORGAN_PROMOTION_LANES_V1_REPORT.json'
$proofPath='tests/self_development/ORGAN_PROMOTION_LANES_V1_PROOF.json'
$triagePath='reports/self_development/BODY_MAP_CANDIDATE_TRIAGE_V1.json'
$mapPath='reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
foreach($p in @($modelPath,$reportPath,$proofPath,$triagePath,$mapPath)){ Assert (Test-Path $p) "MISSING:$p" }
$model=Get-Content $modelPath -Raw|ConvertFrom-Json
$report=Get-Content $reportPath -Raw|ConvertFrom-Json
$proof=Get-Content $proofPath -Raw|ConvertFrom-Json
$triage=Get-Content $triagePath -Raw|ConvertFrom-Json
$map=Get-Content $mapPath -Raw|ConvertFrom-Json
Assert ($model.status -eq 'PASS_ORGAN_PROMOTION_LANES_V1') 'MODEL_STATUS_BAD'
Assert ($report.status -eq 'PASS_ORGAN_PROMOTION_LANES_V1') 'REPORT_STATUS_BAD'
Assert ($proof.status -eq 'PASS_ORGAN_PROMOTION_LANES_V1') 'PROOF_STATUS_BAD'
$items=@($triage.items);$decisions=@($model.lane_decisions)
Assert ((CountOf $items) -eq (CountOf $map.primary_evidence_candidates)) 'TRIAGE_MAP_COUNT_MISMATCH'
Assert ((CountOf $decisions) -eq (CountOf $items)) 'DECISION_TRIAGE_COUNT_MISMATCH'
Assert ([int]$model.counts.source_candidates -eq (CountOf $map.primary_evidence_candidates)) 'MODEL_SOURCE_COUNT_BAD'
Assert ([int]$model.counts.lane_decisions -eq (CountOf $decisions)) 'MODEL_DECISION_COUNT_BAD'
Assert ($proof.all_candidates_have_lane -eq $true) 'PROOF_ALL_CANDIDATES_HAVE_LANE_FALSE'
Assert ($proof.unique_candidate_ids -eq $true) 'PROOF_UNIQUE_CANDIDATE_IDS_FALSE'
Assert ($proof.no_candidate_active_allowed -eq $true) 'PROOF_ACTIVE_ALLOWED_BAD'
Assert ([int]$proof.cortex_refs_in_lanes -eq 0) 'CORTEX_REF_PRESENT_IN_LANES'
Assert ($model.persistent_contract.not_temporary -eq $true) 'MODEL_TEMPORARY_BAD'
Assert ($model.persistent_contract.no_candidate_accepted_as_organ_from_lanes_alone -eq $true) 'MODEL_ACCEPTANCE_BOUNDARY_BAD'
$badActive=@($decisions|Where-Object{IsTrueValue $_.active_allowed}); Assert ((CountOf $badActive) -eq 0) 'DECISION_ACTIVE_ALLOWED_PRESENT'
$missingLane=@($decisions|Where-Object{[string]::IsNullOrWhiteSpace([string]$_.lane)}); Assert ((CountOf $missingLane) -eq 0) 'DECISION_MISSING_LANE'
$missingGates=@($decisions|Where-Object{(CountOf $_.required_gates) -eq 0}); Assert ((CountOf $missingGates) -eq 0) 'DECISION_MISSING_GATES'
$calibrated=@($decisions|Where-Object{$_.lane -eq 'CALIBRATED_PASSPORT_DRAFT_BLOCKED_RUNTIME'})
Assert (@($calibrated|Where-Object{$_.candidate_id -eq 'contracts_accepted_atom_retention_organ'}).Count -eq 1) 'ACCEPTED_ATOM_NOT_CALIBRATED_BLOCKED_RUNTIME'
$unique=(CountOf ($decisions.candidate_id|Sort-Object -Unique)); Assert ($unique -eq (CountOf $decisions)) 'DUPLICATE_DECISION_IDS'
Assert ((CountOf @($model.lanes)) -ge 5) 'LANE_GROUPS_TOO_FEW'
Write-Host 'VALIDATION_PASS=PASS_ORGAN_PROMOTION_LANES_V1'
Write-Host ('MODEL_PATH='+$modelPath)
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
