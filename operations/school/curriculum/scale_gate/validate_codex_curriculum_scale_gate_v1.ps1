$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function Test-ExplicitPlaceholderAtom($a){
  $joined=(([string]$a.objective)+" "+([string]$a.new_knowledge)+" "+([string]$a.expected_behavior)).ToLowerInvariant()
  if($joined -match "same-as-above|lorem|todo"){ return $true }
  $topic=([string]$a.topic).Trim().ToLowerInvariant()
  if($topic -in @("placeholder","generic","filler","todo","same-as-above")){ return $true }
  if($topic -match "^(placeholder|generic|filler)[_\- ]?(text|candidate|lesson)?$"){ return $true }
  return $false
}
$activeDecisionPath="operations/reports/CODEX_CURRICULUM_ACTIVE_DECISION_USE_V1.json"
$promotionPath="operations/reports/CODEX_CURRICULUM_ACTIVE_PROMOTION_V1.json"
$checkpointPath="operations/school/curriculum/codex_digest/store/active_codex_curriculum_digest_v1/active_codex_curriculum_digest_checkpoint.json"
foreach($p in @($activeDecisionPath,$promotionPath,$checkpointPath)){ if(-not (Test-Path $p)){ throw "MISSING_REQUIRED_PROOF: $p" } }
$decision=Get-Content $activeDecisionPath -Raw | ConvertFrom-Json
$promotion=Get-Content $promotionPath -Raw | ConvertFrom-Json
$cp=Get-Content $checkpointPath -Raw | ConvertFrom-Json
$atoms=@($cp.atoms)
$issues=@()
if($decision.status -ne "PASS_CODEX_CURRICULUM_ACTIVE_DECISION_USE_V1"){$issues += "decision_use_not_pass"}
if($decision.decision_use_proven -ne $true){$issues += "decision_use_not_proven"}
if([int]$promotion.atom_count -ne $atoms.Count){$issues += "promotion_atom_count_mismatch_checkpoint"}
if($promotion.status -ne "ACTIVE_REPO_BODY_DECISION_SOURCE"){$issues += "promotion_status_not_active_repo_body"}
if($promotion.live_promotion -ne $false){$issues += "unexpected_live_promotion"}
if($promotion.accepted_core_promotion -ne $false){$issues += "unexpected_d2b_accepted_core_promotion"}
$topicCounts=@{}; $dupCounts=@{}; $sourceCounts=@{}; $levelCounts=@{}; $weakAtoms=@(); $genericAtoms=@()
foreach($a in $atoms){
  $topic=[string]$a.topic; $dup=[string]$a.duplicate_key; $src=[string]$a.source_mode; $lvl=[string]$a.level
  if(-not $topicCounts.ContainsKey($topic)){$topicCounts[$topic]=0}; $topicCounts[$topic]++
  if(-not $dupCounts.ContainsKey($dup)){$dupCounts[$dup]=0}; $dupCounts[$dup]++
  if(-not $sourceCounts.ContainsKey($src)){$sourceCounts[$src]=0}; $sourceCounts[$src]++
  if(-not $levelCounts.ContainsKey($lvl)){$levelCounts[$lvl]=0}; $levelCounts[$lvl]++
  $required=@("atom_id","source_candidate_id","topic","objective","new_knowledge","exercise","expected_behavior","negative_trap","validator_hint","source_anchor","duplicate_key")
  foreach($f in $required){ if(-not ($a.PSObject.Properties.Name -contains $f) -or [string]::IsNullOrWhiteSpace([string]$a.$f)){ $weakAtoms += "$($a.atom_id):missing_$f" } }
  if(([string]$a.expected_behavior).Length -lt 40){ $weakAtoms += "$($a.atom_id):weak_expected_behavior" }
  if(([string]$a.exercise).Length -lt 40){ $weakAtoms += "$($a.atom_id):weak_exercise" }
  if(([string]$a.negative_trap).Length -lt 20){ $weakAtoms += "$($a.atom_id):weak_negative_trap" }
  $joined=(([string]$a.objective)+" "+([string]$a.new_knowledge)+" "+([string]$a.expected_behavior)).ToLowerInvariant()
  if(Test-ExplicitPlaceholderAtom $a){$genericAtoms += $a.atom_id}
}
$duplicateTopics=@($topicCounts.GetEnumerator() | Where-Object {$_.Value -gt 1} | ForEach-Object {$_.Key})
$duplicateKeys=@($dupCounts.GetEnumerator() | Where-Object {$_.Value -gt 1} | ForEach-Object {$_.Key})
$uniqueTopicCount=$topicCounts.Keys.Count
$directedCount=if($sourceCounts.ContainsKey("directed_curriculum")){$sourceCounts["directed_curriculum"]}else{0}
$experienceCount=if($sourceCounts.ContainsKey("experience_curriculum")){$sourceCounts["experience_curriculum"]}else{0}
if($uniqueTopicCount -lt 15){$issues += "low_topic_diversity"}
if($duplicateTopics.Count -gt 0){$issues += "duplicate_topics"}
if($duplicateKeys.Count -gt 0){$issues += "duplicate_keys"}
if($experienceCount -lt 3){$issues += "low_experience_curriculum_count"}
if($directedCount -lt 10){$issues += "low_directed_curriculum_count"}
if($weakAtoms.Count -gt 0){$issues += "weak_atom_fields"}
if($genericAtoms.Count -gt 0){$issues += "generic_or_placeholder_atoms"}
$recommendedNextBatch="OWNER_SELECTED_N"
$scaleDecision="BLOCK_SCALE"
if($issues.Count -eq 0){ $scaleDecision="ALLOW_OWNER_SELECTED_BATCH_WITH_CANONICAL_5000_100_SCHEDULER" }
$report=[pscustomObject]@{
  schema="codex_curriculum_scale_gate_v1"
  status=if($issues.Count -eq 0){"PASS_CODEX_CURRICULUM_SCALE_GATE_V1"}else{"FAIL_CODEX_CURRICULUM_SCALE_GATE_V1"}
  runtime_ready=$false
  input_atom_count=$atoms.Count
  unique_topic_count=$uniqueTopicCount
  directed_count=$directedCount
  experience_count=$experienceCount
  level_counts=$levelCounts
  duplicate_topics=@($duplicateTopics)
  duplicate_keys=@($duplicateKeys)
  weak_atoms=@($weakAtoms)
  generic_atoms=@($genericAtoms)
  decision_use_status=$decision.status
  decision_use_proven=$decision.decision_use_proven
  scale_decision=$scaleDecision
  recommended_next_batch=$recommendedNextBatch
  hard_limit_note="N is a run budget, not architecture or proof of learning. Next batch must pass the same A-to-B loop."
  issues=@($issues)
  boundary="Scale gate only; does not generate candidates, promote new atoms, or set runtime_ready true."
}
[IO.File]::WriteAllText((Join-Path (Get-Location).Path "operations/reports/CODEX_CURRICULUM_SCALE_GATE_V1.json"),($report|ConvertTo-Json -Depth 50),$utf8)
$md=@(
"# CODEX_CURRICULUM_SCALE_GATE_V1",
"",
"Status: $($report.status)",
"Runtime ready: false",
"",
"Input atoms: $($report.input_atom_count)",
"Unique topics: $uniqueTopicCount",
"Directed: $directedCount",
"Experience: $experienceCount",
"Decision-use proven: $($decision.decision_use_proven)",
"Scale decision: $scaleDecision",
"Recommended next batch: $recommendedNextBatch",
"Issues: $($issues.Count)",
"",
"Boundary: scale gate only; no generation, no promotion, no live proof."
)
[IO.File]::WriteAllText((Join-Path (Get-Location).Path "operations/reports/CODEX_CURRICULUM_SCALE_GATE_V1.md"),($md -join "`r`n"),$utf8)
Write-Host "SCALE_GATE_STATUS=$($report.status)"
Write-Host "INPUT_ATOMS=$($atoms.Count)"
Write-Host "UNIQUE_TOPICS=$uniqueTopicCount"
Write-Host "DIRECTED=$directedCount"
Write-Host "EXPERIENCE=$experienceCount"
Write-Host "DECISION_USE_PROVEN=$($decision.decision_use_proven)"
Write-Host "SCALE_DECISION=$scaleDecision"
Write-Host "RECOMMENDED_NEXT_BATCH=$recommendedNextBatch"
Write-Host "ISSUES=$($issues.Count)"
Write-Host "RUNTIME_READY=false"
if($report.status -notlike "PASS_*"){exit 1}