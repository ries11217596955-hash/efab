param(
  [Parameter(Mandatory=$true)][string]$Query,
  [string]$MemoryRoot = '.runtime/active_compact_semantic_memory_v1',
  [int]$Top = 8
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
if(-not (Test-Path $MemoryRoot)){ throw "MEMORY_ROOT_NOT_FOUND:$MemoryRoot" }
$manifestPath=Join-Path $MemoryRoot 'manifest.json'
$cellsPath=Join-Path $MemoryRoot 'cells.jsonl'
if(-not (Test-Path $manifestPath)){ throw 'MEMORY_MANIFEST_MISSING' }
if(-not (Test-Path $cellsPath)){ throw 'MEMORY_CELLS_MISSING' }
$manifest=Get-Content $manifestPath -Raw|ConvertFrom-Json
if($manifest.status -notlike 'PASS_*'){ throw "MEMORY_NOT_PASS:$($manifest.status)" }
$terms=@($Query.ToLowerInvariant() -split '[^a-z0-9_]+' | Where-Object { $_.Length -ge 3 } | Select-Object -Unique)
if($terms.Count -lt 1){ throw 'QUERY_TERMS_EMPTY' }
$cells=@(Get-Content $cellsPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_|ConvertFrom-Json })
$matches=@()
foreach($c in $cells){
  $parts=@($c.label,$c.concept_key,$c.kind,$c.summary) + @($c.properties) + @($c.relations) + @($c.uses)
  $hay=$parts -join ' '
  $hay=$hay.ToLowerInvariant()
  $score=0
  $hitTerms=@()
  foreach($term in $terms){
    if($hay.Contains($term)){
      $hitTerms += $term
      $score += 1
      if(([string]$c.label).ToLowerInvariant().Contains($term)){ $score += 3 }
      if(([string]$c.concept_key).ToLowerInvariant().Contains($term)){ $score += 2 }
      if($term -eq 'source' -and ([string]$c.label).ToLowerInvariant().Contains('source_ladder')){ $score += 5 }
      if($term -eq 'guard' -and ([string]$c.label).ToLowerInvariant().Contains('guard')){ $score += 3 }
      if($term -eq 'external' -and $hay.Contains('external factual')){ $score += 2 }
    }
  }
  if($score -gt 0){
    $matches += [pscustomobject]@{
      score=$score
      hit_terms=@($hitTerms|Select-Object -Unique)
      cell_id=$c.cell_id
      label=$c.label
      concept_key=$c.concept_key
      kind=$c.kind
      summary=$c.summary
      properties=@($c.properties)
      relations=@($c.relations)
      uses=@($c.uses)
      observation_count=$c.observation_count
      version=$c.version
    }
  }
}
$topMatches=@($matches | Sort-Object @{Expression='score';Descending=$true}, label | Select-Object -First $Top)
if($topMatches.Count -gt 0){ $status='PASS_COMPACT_MEMORY_RECALL_V1' } else { $status='BLOCKED_NO_RELEVANT_MEMORY_CELLS_V1' }
Write-Host "MEMORY_RECALL_STATUS=$status"
Write-Host "QUERY=$Query"
Write-Host "QUERY_TERMS=$($terms -join ',')"
Write-Host "MEMORY_STATUS=$($manifest.status)"
Write-Host "MEMORY_CELLS=$($manifest.cell_count)"
Write-Host "MATCH_COUNT=$($matches.Count)"
$n=0
foreach($m in $topMatches){
  $n++
  Write-Host "MATCH|$n|score=$($m.score)|label=$($m.label)|hits=$(@($m.hit_terms) -join ',')|obs=$($m.observation_count)|summary=$($m.summary)"
}
if($status -ne 'PASS_COMPACT_MEMORY_RECALL_V1'){ exit 2 }