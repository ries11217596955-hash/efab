param(
  [Parameter(Mandatory=$true)][string]$InputPath,
  [Parameter(Mandatory=$true)][string]$MemoryRoot,
  [string]$RunId = "compact_semantic_digest_$(Get-Date -Format yyyyMMdd_HHmmss)",
  [switch]$CleanupRawSource,
  [int]$SizeBudgetBytes = 1048576
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function EnsureDir($Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Force $Path | Out-Null } }
function WriteText($Path,$Text){ $d=Split-Path $Path -Parent; if($d){ EnsureDir $d }; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path),$Text,$utf8) }
function WriteJson($Path,$Obj,$Depth=80){ WriteText $Path ($Obj|ConvertTo-Json -Depth $Depth) }
function Sha256Text([string]$Text){
  $sha=[System.Security.Cryptography.SHA256]::Create()
  $bytes=$utf8.GetBytes($Text)
  (($sha.ComputeHash($bytes)|ForEach-Object{$_.ToString('x2')}) -join '')
}
function CanonicalSlug([string]$Text){
  $t=([string]$Text).ToLowerInvariant() -replace '[^a-z0-9]+','-'
  $t=$t.Trim('-')
  if([string]::IsNullOrWhiteSpace($t)){ $t='unnamed-concept' }
  if($t.Length -gt 80){ $t=$t.Substring(0,80).Trim('-') }
  return $t
}
function ArrayFrom($Value){
  if($null -eq $Value){ return @() }
  if($Value -is [System.Array]){ return @($Value | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) }
  return @([string]$Value | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
}
function GetProp($Obj,[string]$Name){
  if($null -eq $Obj){ return $null }
  $p=$Obj.PSObject.Properties[$Name]
  if($p){ return $p.Value }
  return $null
}
function MergeUnique($A,$B){
  $set=New-Object System.Collections.Generic.SortedSet[string]
  foreach($x in @($A)+@($B)){
    $s=[string]$x
    if(-not [string]::IsNullOrWhiteSpace($s)){ [void]$set.Add($s) }
  }
  return @($set)
}
function MergeProperties($A,$B){
  $normal=New-Object System.Collections.Generic.SortedSet[string]
  $singleton=[ordered]@{}
  foreach($x in @($A)+@($B)){
    $text=[string]$x
    if([string]::IsNullOrWhiteSpace($text)){ continue }
    $eq=$text.IndexOf('=')
    $key=if($eq -gt 0){$text.Substring(0,$eq)}else{''}
    if($key -match '^(latest_|current_)'){ $singleton[$key]=$text } else { [void]$normal.Add($text) }
  }
  $out=New-Object System.Collections.Generic.List[string]
  foreach($v in $normal){ [void]$out.Add($v) }
  foreach($k in @($singleton.Keys | Sort-Object)){ [void]$out.Add([string]$singleton[$k]) }
  return @($out.ToArray())
}
function CompactSummary([string]$Text){
  $s=(([string]$Text) -replace '\s+',' ').Trim()
  if($s.Length -gt 360){ $s=$s.Substring(0,360).Trim() }
  return $s
}
function ReadJsonl($Path){
  if(-not (Test-Path $Path)){ throw "INPUT_MISSING:$Path" }
  $rows=New-Object System.Collections.Generic.List[object]
  $n=0
  foreach($rawLine in (Get-Content $Path)){
    $line=[string]$rawLine
    if([string]::IsNullOrWhiteSpace($line)){ continue }
    $n++
    try { $rows.Add(($line | ConvertFrom-Json)) | Out-Null } catch { throw "BAD_JSONL_LINE:${n}:$($_.Exception.Message)" }
  }
  return @($rows.ToArray())
}
function LoadExistingCells($Root){
  $map=@{}
  $cellsPath=Join-Path $Root 'cells.jsonl'
  if(Test-Path $cellsPath){
    Get-Content $cellsPath | ForEach-Object {
      if([string]::IsNullOrWhiteSpace($_)){ return }
      $c=$_|ConvertFrom-Json
      $map[[string]$c.concept_key]=$c
    }
  }
  return $map
}
function CellToOrdered($Cell){
  [ordered]@{
    schema='compact_semantic_cell_v1'
    cell_id=[string]$Cell.cell_id
    concept_key=[string]$Cell.concept_key
    label=[string]$Cell.label
    aliases=@($Cell.aliases)
    kind=[string]$Cell.kind
    summary=[string]$Cell.summary
    properties=@($Cell.properties)
    relations=@($Cell.relations)
    uses=@($Cell.uses)
    source_fingerprints=@($Cell.source_fingerprints)
    observation_count=[int]$Cell.observation_count
    confidence=[double]$Cell.confidence
    version=[int]$Cell.version
    updated_at=[string]$Cell.updated_at
  }
}
$resolvedInput=(Resolve-Path $InputPath).Path
EnsureDir $MemoryRoot
$rows=@(ReadJsonl $InputPath)
if($rows.Count -lt 1){ throw 'NO_INPUT_ROWS' }
$cells=LoadExistingCells $MemoryRoot
$existingCellCountBefore=$cells.Keys.Count
$createdCellCount=0
$mergedObservationCount=0
$inputFingerprints=New-Object System.Collections.Generic.List[string]
$groups=@{}
$groupOrder=New-Object System.Collections.Generic.List[string]
$indexDirty=$false
foreach($r in $rows){
  $concept=[string](GetProp $r 'concept_key')
  if([string]::IsNullOrWhiteSpace($concept)){ $concept=[string](GetProp $r 'concept') }
  if([string]::IsNullOrWhiteSpace($concept)){ $concept=[string](GetProp $r 'label') }
  if([string]::IsNullOrWhiteSpace($concept)){ $concept=[string](GetProp $r 'title') }
  if([string]::IsNullOrWhiteSpace($concept)){ $concept=[string](GetProp $r 'text') }
  $conceptKey=CanonicalSlug $concept
  $label=[string](GetProp $r 'label')
  if([string]::IsNullOrWhiteSpace($label)){ $label=$conceptKey }
  $kind=[string](GetProp $r 'kind')
  if([string]::IsNullOrWhiteSpace($kind)){ $kind='concept' }
  $definition=[string](GetProp $r 'definition')
  if([string]::IsNullOrWhiteSpace($definition)){ $definition=[string](GetProp $r 'summary') }
  if([string]::IsNullOrWhiteSpace($definition)){ $definition=[string](GetProp $r 'text') }
  $summary=CompactSummary $definition
  if([string]::IsNullOrWhiteSpace($summary)){ throw "DIGEST_SUMMARY_EMPTY:$conceptKey" }
  $aliases=ArrayFrom (GetProp $r 'aliases')
  $props=ArrayFrom (GetProp $r 'properties')
  $relations=ArrayFrom (GetProp $r 'relations')
  $uses=ArrayFrom (GetProp $r 'uses')
  $rawCanonical=($r|ConvertTo-Json -Depth 80 -Compress)
  $fp=Sha256Text $rawCanonical
  $inputFingerprints.Add($fp) | Out-Null
  if(-not $groups.ContainsKey($conceptKey)){
    $g=[pscustomobject]@{
      concept_key=$conceptKey; label=$label; kind=$kind; summary=$summary; count=0
      aliases=(New-Object System.Collections.Generic.SortedSet[string])
      properties=(New-Object System.Collections.Generic.SortedSet[string])
      relations=(New-Object System.Collections.Generic.SortedSet[string])
      uses=(New-Object System.Collections.Generic.SortedSet[string])
      source_fingerprints=(New-Object System.Collections.Generic.SortedSet[string])
    }
    $groups[$conceptKey]=$g
    $groupOrder.Add($conceptKey) | Out-Null
  }
  $g=$groups[$conceptKey]
  $g.count=[int]$g.count+1
  foreach($x in $aliases){ if(-not [string]::IsNullOrWhiteSpace([string]$x)){ [void]$g.aliases.Add([string]$x) } }
  foreach($x in $props){ if(-not [string]::IsNullOrWhiteSpace([string]$x)){ [void]$g.properties.Add([string]$x) } }
  foreach($x in $relations){ if(-not [string]::IsNullOrWhiteSpace([string]$x)){ [void]$g.relations.Add([string]$x) } }
  foreach($x in $uses){ if(-not [string]::IsNullOrWhiteSpace([string]$x)){ [void]$g.uses.Add([string]$x) } }
  [void]$g.source_fingerprints.Add($fp)
  if(([string]$g.summary).Length -lt $summary.Length){ $g.summary=$summary }
}
foreach($conceptKey in $groupOrder){
  $g=$groups[$conceptKey]
  if($cells.ContainsKey($conceptKey)){
    $old=$cells[$conceptKey]
    $oldAliasesUnique=MergeUnique $old.aliases @()
    $newAliases=MergeUnique $old.aliases @($g.aliases)
    $oldPropertiesUnique=MergeProperties $old.properties @()
    $newProperties=MergeProperties $old.properties @($g.properties)
    $oldUsesUnique=MergeUnique $old.uses @()
    $newUses=MergeUnique $old.uses @($g.uses)
    if($newAliases.Count -ne $oldAliasesUnique.Count -or $newProperties.Count -ne $oldPropertiesUnique.Count -or $newUses.Count -ne $oldUsesUnique.Count){ $indexDirty=$true }
    $old.aliases=$newAliases
    $old.properties=$newProperties
    $old.relations=MergeUnique $old.relations @($g.relations)
    $old.uses=$newUses
    $old.source_fingerprints=MergeUnique $old.source_fingerprints @($g.source_fingerprints)
    $old.observation_count=[int]$old.observation_count + [int]$g.count
    $old.version=[int]$old.version + [int]$g.count
    if(([string]$old.summary).Length -lt ([string]$g.summary).Length){ $old.summary=[string]$g.summary }
    $old.updated_at=(Get-Date).ToString('o')
    $cells[$conceptKey]=$old
    $mergedObservationCount += [int]$g.count
  } else {
    $indexDirty=$true
    $cell=[pscustomobject]@{
      schema='compact_semantic_cell_v1'
      cell_id=('cell_'+(Sha256Text $conceptKey).Substring(0,16))
      concept_key=$conceptKey
      label=[string]$g.label
      aliases=@($g.aliases)
      kind=[string]$g.kind
      summary=[string]$g.summary
      properties=@($g.properties)
      relations=@($g.relations)
      uses=@($g.uses)
      source_fingerprints=@($g.source_fingerprints)
      observation_count=[int]$g.count
      confidence=0.75
      version=[int]$g.count
      updated_at=(Get-Date).ToString('o')
    }
    $cells[$conceptKey]=$cell
    $createdCellCount++
    $mergedObservationCount += [Math]::Max(0,[int]$g.count-1)
  }
}
$orderedCells=@($cells.Keys | Sort-Object | ForEach-Object { CellToOrdered $cells[$_] })
$cellsPath=Join-Path $MemoryRoot 'cells.jsonl'
$indexPath=Join-Path $MemoryRoot 'index.json'
$manifestPath=Join-Path $MemoryRoot 'manifest.json'
$cellsJsonl=($orderedCells | ForEach-Object { $_|ConvertTo-Json -Depth 80 -Compress }) -join "`n"
# Guard: raw text/source bodies must not survive in cells. Scan serialized memory once, not per cell.
foreach($forbidden in @('raw_text','source_text','ready_atoms','batch_trace','prompt_trace')){
  if($cellsJsonl -match $forbidden){ throw "RAW_FIELD_SURVIVED_IN_CELL:$forbidden" }
}
WriteText $cellsPath ($cellsJsonl + "`n")
if($indexDirty -or -not (Test-Path $indexPath)){
  $index=@{}
  foreach($c in $orderedCells){
    $terms=@($c.concept_key,$c.label)+@($c.aliases)+@($c.properties)+@($c.uses)
    foreach($t in $terms){
      $k=CanonicalSlug ([string]$t)
      if(-not [string]::IsNullOrWhiteSpace($k)){ $index[$k]=[string]$c.cell_id }
    }
  }
  $indexObj=[ordered]@{ schema='compact_semantic_lookup_index_v1'; term_count=$index.Keys.Count; terms=$index }
  WriteJson $indexPath $indexObj 100
  Write-Host 'INDEX_ACTION=REBUILT'
} else {
  Write-Host 'INDEX_ACTION=PRESERVED_CLEAN'
}
$cellBytes=(Get-Item $cellsPath).Length
$indexBytes=(Get-Item $indexPath).Length
$totalBytes=$cellBytes+$indexBytes
$status='PASS_COMPACT_SEMANTIC_DIGESTION_ORGAN_V1'
$blockers=@()
if($totalBytes -gt $SizeBudgetBytes){ $status='FAIL_SIZE_BUDGET_EXCEEDED_V1'; $blockers += 'SIZE_BUDGET_EXCEEDED' }
$rawDeleted=$false
if($CleanupRawSource){ Remove-Item $InputPath -Force; $rawDeleted=(-not (Test-Path $InputPath)) }
$manifest=[ordered]@{
  schema='compact_semantic_memory_manifest_v1'
  status=$status
  run_id=$RunId
  input_count=$rows.Count
  cell_count=$orderedCells.Count
  merged_count=$mergedObservationCount
  raw_source_path=$resolvedInput
  raw_source_deleted=$rawDeleted
  raw_source_dependency_removed=([bool]$CleanupRawSource -and $rawDeleted)
  size_budget_bytes=$SizeBudgetBytes
  cells_bytes=$cellBytes
  index_bytes=$indexBytes
  total_memory_bytes=$totalBytes
  cells_sha256=Sha256Text $cellsJsonl
  index_sha256=Sha256Text ((Get-Content $indexPath -Raw))
  blockers=$blockers
  boundary='Compact semantic memory contains meaning cells, not raw candidate/ready/source traces.'
  runtime_ready=$false
}
WriteJson $manifestPath $manifest 80
$proofPath=".runtime/digestion_reports/$RunId/COMPACT_SEMANTIC_DIGESTION_ORGAN_V1.json"
WriteJson $proofPath $manifest 80
Write-Host "DIGEST_STATUS=$status"
Write-Host "PROOF_PATH=$proofPath"
Write-Host "MEMORY_ROOT=$MemoryRoot"
Write-Host "INPUT_COUNT=$($rows.Count)"
Write-Host "CELL_COUNT=$($orderedCells.Count)"
Write-Host "MERGED_COUNT=$($manifest.merged_count)"
Write-Host "RAW_SOURCE_DELETED=$rawDeleted"
Write-Host "TOTAL_MEMORY_BYTES=$totalBytes"
Write-Host 'RUNTIME_READY=false'
if($status -notlike 'PASS_*'){ exit 1 }
