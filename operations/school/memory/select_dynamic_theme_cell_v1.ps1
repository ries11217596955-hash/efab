param(
  [string]$MemoryRoot = '.runtime/active_compact_semantic_memory_v1',
  [string]$OutputPath = '.runtime/school_dynamic_theme_selection/latest_selection.json',
  [ValidateRange(1,50)][int]$Top = 12
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function WriteJson($Path,$Obj,$Depth=40){
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
if(-not (Test-Path $MemoryRoot)){ throw "MEMORY_ROOT_NOT_FOUND:$MemoryRoot" }
$manifestPath=Join-Path $MemoryRoot 'manifest.json'
$cellsPath=Join-Path $MemoryRoot 'cells.jsonl'
if(-not (Test-Path $manifestPath)){ throw 'MEMORY_MANIFEST_MISSING' }
if(-not (Test-Path $cellsPath)){ throw 'MEMORY_CELLS_MISSING' }
$manifest=Get-Content $manifestPath -Raw | ConvertFrom-Json
if($manifest.status -notlike 'PASS_*'){ throw "MEMORY_NOT_PASS:$($manifest.status)" }
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
    $groups[$key]=[ordered]@{
      topic_key=$key
      labels=(NewList)
      concept_keys=(NewList)
      cell_ids=(NewList)
      cell_count=0
      observation_sum=0
      proof_signal_count=0
      validator_signal_count=0
      return_signal_count=0
      source_signal_count=0
      summary_bytes=0
      raw_text=''
    }
  }
  $g=$groups[$key]
  $g['cell_count']=[int]$g['cell_count'] + 1
  $obs=0
  [void][int]::TryParse([string]$c.observation_count,[ref]$obs)
  $g['observation_sum']=[int]$g['observation_sum'] + $obs
  AddUnique ($g['labels']) $label
  AddUnique ($g['concept_keys']) $concept
  AddUnique ($g['cell_ids']) $cellId
  $parts=@($c.label,$c.concept_key,$c.kind,$c.summary,$c.definition,$c.expected_behavior,$c.return_to_parent) + @($c.properties) + @($c.relations) + @($c.uses)
  $txt=($parts -join ' ')
  $g['raw_text']=([string]$g['raw_text']) + ' ' + $txt
  $g['summary_bytes']=[int]$g['summary_bytes'] + ([Text.Encoding]::UTF8.GetByteCount([string]$c.summary))
  if($txt -match '(?i)proof|evidence'){ $g['proof_signal_count']=[int]$g['proof_signal_count'] + 1 }
  if($txt -match '(?i)validator|validation'){ $g['validator_signal_count']=[int]$g['validator_signal_count'] + 1 }
  if($txt -match '(?i)return_to_parent|return'){ $g['return_signal_count']=[int]$g['return_signal_count'] + 1 }
  if($txt -match '(?i)source'){ $g['source_signal_count']=[int]$g['source_signal_count'] + 1 }
}
$candidates=@()
foreach($k in $groups.Keys){
  $g=$groups[$k]
  $score=0
  $reasons=NewList
  if([int]$g['observation_sum'] -le 5){ $score += 40; [void]$reasons.Add('low_observation_sum') }
  elseif([int]$g['observation_sum'] -le 50){ $score += 20; [void]$reasons.Add('medium_observation_sum') }
  if([int]$g['proof_signal_count'] -lt 1){ $score += 25; [void]$reasons.Add('missing_proof_signal') }
  if([int]$g['validator_signal_count'] -lt 1){ $score += 15; [void]$reasons.Add('missing_validator_signal') }
  if([int]$g['return_signal_count'] -lt 1){ $score += 10; [void]$reasons.Add('missing_return_signal') }
  if([int]$g['source_signal_count'] -lt 1){ $score += 10; [void]$reasons.Add('missing_source_signal') }
  if([int]$g['cell_count'] -gt 20){ $score += 12; [void]$reasons.Add('large_cluster_needs_compression') }
  if([int]$g['summary_bytes'] -lt 200){ $score += 8; [void]$reasons.Add('thin_summary') }
  $label=@(($g['labels']) | Select-Object -First 1)[0]
  if([string]::IsNullOrWhiteSpace($label)){ $label=$k }
  $candidates += [pscustomobject]@{
    score=$score
    topic_key=$k
    label=$label
    cell_count=[int]$g['cell_count']
    observation_sum=[int]$g['observation_sum']
    proof_signal_count=[int]$g['proof_signal_count']
    validator_signal_count=[int]$g['validator_signal_count']
    return_signal_count=[int]$g['return_signal_count']
    source_signal_count=[int]$g['source_signal_count']
    reasons=@($reasons)
    sample_cell_ids=@(($g['cell_ids']) | Select-Object -First 5)
    sample_concept_keys=@(($g['concept_keys']) | Select-Object -First 5)
  }
}
$ranked=@($candidates | Sort-Object @{Expression='score';Descending=$true}, @{Expression='observation_sum';Descending=$false}, topic_key | Select-Object -First $Top)
$selected=$ranked | Select-Object -First 1
if(-not $selected){ throw 'NO_DYNAMIC_TOPIC_SELECTION' }
$codexTemplate=[ordered]@{
  role='bounded_school_material_author'
  target_topic=$selected.topic_key
  target_label=$selected.label
  candidate_limit_hint=1000
  requirements=@(
    'author material only for the selected topic',
    'preserve source proof validator return_to_parent fields',
    'do not create broad multi-topic campaign',
    'do not mutate active memory',
    'output remains CODEX_DRAFT until school validators pass'
  )
  expected_school_result='compact memory update after full school cycle'
}
$result=[ordered]@{
  schema='dynamic_theme_cell_selection_v1'
  status='PASS_DYNAMIC_THEME_CELL_SELECTION_V1'
  created_at=(Get-Date).ToString('o')
  memory_root=$MemoryRoot
  manifest_status=$manifest.status
  manifest_cell_count=$manifest.cell_count
  observed_cell_count=$cells.Count
  dynamic_topic_count=$groups.Count
  selected_topic=$selected
  ranked_topics=@($ranked)
  new_cell_rule='If no existing semantic topic matches future material, create a new topic cell. No fixed cell count is required.'
  codex_request_template=$codexTemplate
  memory_mutated=$false
}
WriteJson $OutputPath $result 80
Write-Host "DYNAMIC_THEME_SELECTION_STATUS=$($result.status)"
Write-Host "DYNAMIC_THEME_SELECTED_TOPIC=$($selected.topic_key)"
Write-Host "DYNAMIC_THEME_SELECTED_LABEL=$($selected.label)"
Write-Host "DYNAMIC_THEME_SELECTED_SCORE=$($selected.score)"
Write-Host "DYNAMIC_THEME_TOPIC_COUNT=$($groups.Count)"
Write-Host "DYNAMIC_THEME_SELECTION_PROOF=$OutputPath"
