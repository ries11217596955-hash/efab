param(
  [string]$MemoryRoot = '.runtime/active_compact_semantic_memory_v1',
  [string]$VectorMapPath = 'operations/school/curriculum/development_vector/school_development_vector_map_v1.json',
  [string]$OutputPath = '.runtime/school_dynamic_theme_selection/latest_selection.json',
  [ValidateRange(1,50)][int]$Top = 12
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function WriteJson($Path,$Obj,$Depth=60){
  $dir=Split-Path -Parent $Path
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $Obj | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}
function NormalizeTopic($s){
  $x=([string]$s).Trim().ToLowerInvariant()
  $x=[regex]::Replace($x, '[^\p{L}\p{Nd}]+', '_')
  $x=$x.Trim('_')
  if([string]::IsNullOrWhiteSpace($x)){ $x='unknown_topic' }
  return $x
}
function NewList(){ $x=New-Object System.Collections.ArrayList; return ,$x }
function AddUnique($list,$value){
  $v=[string]$value
  if(-not [string]::IsNullOrWhiteSpace($v) -and -not $list.Contains($v)){ [void]$list.Add($v) }
}
function EstimateDepth($g){
  if($null -eq $g){ return 0 }
  $depth=1
  if([int]$g['observation_sum'] -ge 10 -or [int]$g['summary_bytes'] -ge 250){ $depth=2 }
  if([int]$g['proof_signal_count'] -ge 1 -and [int]$g['validator_signal_count'] -ge 1){ $depth=3 }
  if([int]$g['return_signal_count'] -ge 1 -and [int]$g['source_signal_count'] -ge 1 -and [int]$g['observation_sum'] -ge 50){ $depth=4 }
  if([int]$g['proof_signal_count'] -ge 2 -and [int]$g['validator_signal_count'] -ge 2 -and [int]$g['return_signal_count'] -ge 2 -and [int]$g['observation_sum'] -ge 100){ $depth=5 }
  return $depth
}
function MatchExpectedTopic($expectedKey,$expectedLabel,$groups){
  $normKey=NormalizeTopic $expectedKey
  $normLabel=NormalizeTopic $expectedLabel
  if($groups.ContainsKey($normKey)){ return $normKey }
  if($groups.ContainsKey($normLabel)){ return $normLabel }
  foreach($k in $groups.Keys){
    $g=$groups[$k]
    $hay=($k + ' ' + ($g['labels'] -join ' ') + ' ' + ($g['concept_keys'] -join ' ')).ToLowerInvariant()
    if($hay.Contains($normKey) -or $hay.Contains($normLabel)){ return $k }
  }
  return $null
}
if(-not (Test-Path $MemoryRoot)){ throw "MEMORY_ROOT_NOT_FOUND:$MemoryRoot" }
if(-not (Test-Path $VectorMapPath)){ throw "VECTOR_MAP_MISSING:$VectorMapPath" }
$manifestPath=Join-Path $MemoryRoot 'manifest.json'
$cellsPath=Join-Path $MemoryRoot 'cells.jsonl'
if(-not (Test-Path $manifestPath)){ throw 'MEMORY_MANIFEST_MISSING' }
if(-not (Test-Path $cellsPath)){ throw 'MEMORY_CELLS_MISSING' }
$manifest=Get-Content $manifestPath -Raw | ConvertFrom-Json
if($manifest.status -notlike 'PASS_*'){ throw "MEMORY_NOT_PASS:$($manifest.status)" }
$vector=Get-Content $VectorMapPath -Raw | ConvertFrom-Json
if($vector.status -ne 'ACTIVE'){ throw "VECTOR_MAP_NOT_ACTIVE:$($vector.status)" }
$cells=@(Get-Content $cellsPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json })
if($cells.Count -lt 1){ throw 'MEMORY_CELLS_EMPTY' }
$groups=@{}
foreach($c in $cells){
  $label=[string]$c.label
  $concept=[string]$c.concept_key
  $theme=[string]$c.theme_key
  $cellId=[string]$c.cell_id
  $topic=$theme
  if([string]::IsNullOrWhiteSpace($topic)){ $topic=$concept }
  if([string]::IsNullOrWhiteSpace($topic)){ $topic=$label }
  if([string]::IsNullOrWhiteSpace($topic)){ $topic=$cellId }
  $key=NormalizeTopic $topic
  if(-not $groups.ContainsKey($key)){
    $groups[$key]=[ordered]@{ topic_key=$key; labels=(NewList); concept_keys=(NewList); cell_ids=(NewList); cell_count=0; observation_sum=0; proof_signal_count=0; validator_signal_count=0; return_signal_count=0; source_signal_count=0; summary_bytes=0 }
  }
  $g=$groups[$key]
  $g['cell_count']=[int]$g['cell_count']+1
  $obs=0; [void][int]::TryParse([string]$c.observation_count,[ref]$obs); $g['observation_sum']=[int]$g['observation_sum']+$obs
  AddUnique ($g['labels']) $label; AddUnique ($g['concept_keys']) $concept; AddUnique ($g['cell_ids']) $cellId
  $parts=@($c.label,$c.concept_key,$c.kind,$c.summary,$c.definition,$c.expected_behavior,$c.return_to_parent) + @($c.properties) + @($c.relations) + @($c.uses)
  $txt=($parts -join ' ')
  $g['summary_bytes']=[int]$g['summary_bytes'] + ([Text.Encoding]::UTF8.GetByteCount([string]$c.summary))
  if($txt -match '(?i)proof|evidence'){ $g['proof_signal_count']=[int]$g['proof_signal_count']+1 }
  if($txt -match '(?i)validator|validation'){ $g['validator_signal_count']=[int]$g['validator_signal_count']+1 }
  if($txt -match '(?i)return_to_parent|return'){ $g['return_signal_count']=[int]$g['return_signal_count']+1 }
  if($txt -match '(?i)source'){ $g['source_signal_count']=[int]$g['source_signal_count']+1 }
}
$expectedCandidates=@()
foreach($t in @($vector.topics)){
  $matchKey=MatchExpectedTopic $t.topic_key $t.label $groups
  $g=$null
  if($matchKey){ $g=$groups[$matchKey] }
  $currentDepth=EstimateDepth $g
  $targetDepth=[int]$t.target_depth
  $queue=[int]$t.priority_queue
  $missing=($null -eq $matchKey)
  $underDepth=($currentDepth -lt $targetDepth)
  $gap=$targetDepth-$currentDepth
  $score=(1000-(100*$queue)) + (120*$gap)
  if($missing){ $score += 300 }
  if($queue -eq 1){ $score += 80 }
  $reason= if($missing){ 'missing_expected_topic' } elseif($underDepth){ 'under_depth_expected_topic' } else { 'target_depth_met' }
  $expectedCandidates += [pscustomobject]@{
    score=$score
    selection_reason=$reason
    topic_key=[string]$t.topic_key
    label=[string]$t.label
    priority_queue=$queue
    current_depth=$currentDepth
    target_depth=$targetDepth
    start_depth=$currentDepth
    depth_gap=$gap
    matched_memory_topic=$matchKey
    why=[string]$t.why
    source_basis=@($t.source_basis)
    codex_depth_focus=[string]$t.codex_depth_focus
  }
}
$actionable=@($expectedCandidates | Where-Object { $_.selection_reason -ne 'target_depth_met' } | Sort-Object @{Expression='score';Descending=$true}, @{Expression='priority_queue';Descending=$false}, @{Expression='depth_gap';Descending=$true}, topic_key)
$ranked=@($actionable | Select-Object -First $Top)
# Fallback to weak existing memory if all expected topics are satisfied.
$fallbackUsed=$false
if($ranked.Count -lt 1){
  $fallbackUsed=$true
  $weak=@()
  foreach($k in $groups.Keys){
    $g=$groups[$k]
    $score=0; $reasons=NewList
    if([int]$g['observation_sum'] -le 5){ $score += 40; [void]$reasons.Add('low_observation_sum') }
    if([int]$g['proof_signal_count'] -lt 1){ $score += 25; [void]$reasons.Add('missing_proof_signal') }
    if([int]$g['validator_signal_count'] -lt 1){ $score += 15; [void]$reasons.Add('missing_validator_signal') }
    if([int]$g['return_signal_count'] -lt 1){ $score += 10; [void]$reasons.Add('missing_return_signal') }
    $label=@(($g['labels']) | Select-Object -First 1)[0]
    if([string]::IsNullOrWhiteSpace($label)){ $label=$k }
    $weak += [pscustomobject]@{ score=$score; selection_reason='weak_existing_memory_topic'; topic_key=$k; label=$label; priority_queue=99; current_depth=(EstimateDepth $g); target_depth=3; start_depth=(EstimateDepth $g); depth_gap=(3-(EstimateDepth $g)); matched_memory_topic=$k; why='fallback weak existing topic'; source_basis=@('active compact memory'); codex_depth_focus='repair weak existing memory topic' }
  }
  $ranked=@($weak | Sort-Object @{Expression='score';Descending=$true}, topic_key | Select-Object -First $Top)
}
$selected=$ranked | Select-Object -First 1
if(-not $selected){ throw 'NO_VECTOR_OR_TOPIC_SELECTION' }
$codexTemplate=[ordered]@{
  role='bounded_school_material_author'
  target_topic=$selected.topic_key
  target_label=$selected.label
  priority_queue=$selected.priority_queue
  current_depth=$selected.current_depth
  target_depth=$selected.target_depth
  start_depth=$selected.start_depth
  depth_gap=$selected.depth_gap
  candidate_limit_hint=$vector.candidate_cycle_default
  single_topic_boundary="Only this topic is allowed: $($selected.topic_key). Do not broaden into adjacent topics."
  depth_task="Start at depth $($selected.start_depth) and create material that advances toward depth $($selected.target_depth)."
  candidate_rules=@($vector.codex_task_template_contract.candidate_rules)
  required_fields=@($vector.codex_task_template_contract.must_include)
  cut_lines=@($vector.codex_task_template_contract.cut_lines)
  acceptance_contract=@(
    'candidate declares topic_key exactly',
    'candidate declares depth_level and prerequisite_depth',
    'candidate includes source_basis or source_missing=true',
    'candidate includes validator and negative case',
    'candidate includes return_to_parent relation',
    'candidate is compact-digest friendly',
    'no active memory mutation by Codex'
  )
  output_status='CODEX_DRAFT_UNTIL_SCHOOL_VALIDATED'
}
$result=[ordered]@{
  schema='development_vector_theme_selection_v1'
  status='PASS_DEVELOPMENT_VECTOR_THEME_SELECTION_V1'
  created_at=(Get-Date).ToString('o')
  memory_root=$MemoryRoot
  vector_map_path=$VectorMapPath
  manifest_status=$manifest.status
  observed_cell_count=$cells.Count
  existing_dynamic_topic_count=$groups.Count
  expected_topic_count=@($vector.topics).Count
  missing_expected_topic_count=@($expectedCandidates | Where-Object { $_.selection_reason -eq 'missing_expected_topic' }).Count
  under_depth_expected_topic_count=@($expectedCandidates | Where-Object { $_.selection_reason -eq 'under_depth_expected_topic' }).Count
  selected_topic=$selected
  ranked_topics=@($ranked)
  fallback_used=$fallbackUsed
  codex_request_template=$codexTemplate
  memory_mutated=$false
}
WriteJson $OutputPath $result 100
Write-Host "DYNAMIC_THEME_SELECTION_STATUS=$($result.status)"
Write-Host "DYNAMIC_THEME_SELECTED_TOPIC=$($selected.topic_key)"
Write-Host "DYNAMIC_THEME_SELECTED_LABEL=$($selected.label)"
Write-Host "DYNAMIC_THEME_SELECTION_REASON=$($selected.selection_reason)"
Write-Host "DYNAMIC_THEME_CURRENT_DEPTH=$($selected.current_depth)"
Write-Host "DYNAMIC_THEME_TARGET_DEPTH=$($selected.target_depth)"
Write-Host "DYNAMIC_THEME_MISSING_EXPECTED_COUNT=$($result.missing_expected_topic_count)"
Write-Host "DYNAMIC_THEME_UNDER_DEPTH_COUNT=$($result.under_depth_expected_topic_count)"
Write-Host "DYNAMIC_THEME_SELECTION_PROOF=$OutputPath"
