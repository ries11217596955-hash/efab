$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function CountOf($x){ return @($x).Count }
$modelPath='self_model/organ_promotion_lanes/ORGAN_PROMOTION_LANES_V1.json'
$proofPath='tests/self_development/ORGAN_PROMOTION_LANES_V1_PROOF.json'
$triagePath='reports/self_development/BODY_MAP_CANDIDATE_TRIAGE_V1.json'
$mapPath='reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
foreach($p in @($modelPath,$proofPath,$triagePath,$mapPath)){ Assert (Test-Path $p) "MISSING:$p" }
$model=Get-Content $modelPath -Raw|ConvertFrom-Json
$proof=Get-Content $proofPath -Raw|ConvertFrom-Json
$triage=Get-Content $triagePath -Raw|ConvertFrom-Json
$map=Get-Content $mapPath -Raw|ConvertFrom-Json
$decisions=@($model.lane_decisions)
$items=@($triage.items)
$mapCandidates=@($map.primary_evidence_candidates)
Assert ($model.status -eq 'PASS_ORGAN_PROMOTION_LANES_V1') 'MODEL_NOT_PASS'
Assert ($proof.status -eq 'PASS_ORGAN_PROMOTION_LANES_V1') 'PROOF_NOT_PASS'
Assert ((CountOf $decisions) -eq (CountOf $items)) 'DECISION_TRIAGE_COUNT_MISMATCH'
Assert ((CountOf $items) -eq (CountOf $mapCandidates)) 'TRIAGE_MAP_COUNT_MISMATCH'
$triageIds=@($items|ForEach-Object{[string]$_.candidate_id}|Sort-Object)
$decisionIds=@($decisions|ForEach-Object{[string]$_.candidate_id}|Sort-Object)
$mapIds=@($mapCandidates|ForEach-Object{[string]$_.id}|Sort-Object)
Assert (($triageIds -join '|') -eq ($decisionIds -join '|')) 'DECISION_IDS_DO_NOT_MATCH_TRIAGE_IDS'
Assert (($triageIds -join '|') -eq ($mapIds -join '|')) 'TRIAGE_IDS_DO_NOT_MATCH_MAP_IDS'
$bad=@()
foreach($d in $decisions){
  if([string]::IsNullOrWhiteSpace([string]$d.candidate_id)){ $bad += 'MISSING_ID'; continue }
  if([string]::IsNullOrWhiteSpace([string]$d.lane)){ $bad += "MISSING_LANE:$($d.candidate_id)" }
  if($d.PSObject.Properties.Name -notcontains 'required_gates' -or (CountOf $d.required_gates) -eq 0){ $bad += "MISSING_REQUIRED_GATES:$($d.candidate_id)" }
  if($d.PSObject.Properties.Name -contains 'active_allowed' -and ([string]$d.active_allowed).ToLowerInvariant() -eq 'true'){ $bad += "ACTIVE_ALLOWED:$($d.candidate_id)" }
}
Assert ((CountOf $bad) -eq 0) ('BAD_DECISIONS:' + ($bad -join ','))
$hasReview=(CountOf @($decisions|Where-Object{$_.lane -eq 'REVIEW_LANE'})) -gt 0
$hasOwner=(CountOf @($decisions|Where-Object{$_.lane -eq 'OWNER_LINK_REQUIRED'})) -gt 0
$hasMaterial=(CountOf @($decisions|Where-Object{$_.lane -match 'MATERIAL|ARCHIVE|SUPPORT'})) -gt 0
Assert $hasReview 'NO_REVIEW_LANE_SIGNAL'
Assert $hasOwner 'NO_OWNER_LINK_REQUIRED_SIGNAL'
Assert $hasMaterial 'NO_MATERIAL_OR_ARCHIVE_SIGNAL'
Assert ($model.persistent_contract.no_candidate_accepted_as_organ_from_lanes_alone -eq $true) 'LANE_ACCEPTANCE_OVERCLAIM'
Assert ($model.counts.active_passports -eq 0) 'ACTIVE_PASSPORT_OVERCLAIM'
Write-Host 'VALIDATION_PASS=PASS_ORGAN_PROMOTION_LANES_SIGNAL_CONTRACT_V1'
Write-Host ('DECISIONS='+$decisions.Count)
Write-Host 'ACTIVE_ALLOWED=0'
Write-Host 'BRAIN_INPUT=LANE_SIGNALS_WITH_EVIDENCE_REFS_NOT_RAW_REPO'
