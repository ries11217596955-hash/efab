param(
  [Parameter(Mandatory=$true)][string]$InputPath,
  [Parameter(Mandatory=$true)][string]$MemoryRoot,
  [Parameter(Mandatory=$true)][string]$RunId,
  [int]$SizeBudgetBytes = 1048576,
  [switch]$CleanupInput
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function Resolve-OrFull([string]$Path){ if([IO.Path]::IsPathRooted($Path)){ return $Path }; return (Join-Path (Get-Location).Path $Path) }
function WriteText($Path,[string]$Text){ [IO.File]::WriteAllText((Resolve-OrFull $Path),$Text,$utf8) }
function Sha256Text([string]$Text){
  $sha=[Security.Cryptography.SHA256]::Create()
  try { $bytes=$utf8.GetBytes($Text); return (($sha.ComputeHash($bytes)|ForEach-Object{$_.ToString('x2')}) -join '') }
  finally { $sha.Dispose() }
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
function CompactSummary([string]$Text){
  $s=(([string]$Text) -replace '\s+',' ').Trim()
  if($s.Length -gt 360){ $s=$s.Substring(0,360).Trim() }
  return $s
}
function CellToOrdered($Cell){
  [ordered]@{
    schema='compact_semantic_cell_v1'; cell_id=[string]$Cell.cell_id; concept_key=[string]$Cell.concept_key; label=[string]$Cell.label
    aliases=@($Cell.aliases); kind=[string]$Cell.kind; summary=[string]$Cell.summary; properties=@($Cell.properties); relations=@($Cell.relations); uses=@($Cell.uses)
    source_fingerprints=@($Cell.source_fingerprints); observation_count=[int]$Cell.observation_count; confidence=[double]$Cell.confidence; version=[int]$Cell.version; updated_at=[string]$Cell.updated_at
  }
}
function EmitNotEligible([string]$Reason,[string]$ConceptKey=''){
  Write-Host 'REINFORCEMENT_FAST_PATH_STATUS=NOT_ELIGIBLE'; Write-Host "REINFORCEMENT_FAST_PATH_REASON=$Reason"; Write-Host "REINFORCEMENT_FAST_PATH_CONCEPT_KEY=$ConceptKey"; Write-Host 'REINFORCEMENT_FAST_PATH_FINGERPRINT='; exit 0
}
$inputFull=Resolve-OrFull $InputPath; $memoryFull=Resolve-OrFull $MemoryRoot
if(-not(Test-Path $inputFull)){ EmitNotEligible 'PARSE_ERROR' }
$rawLines=@(Get-Content $inputFull | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
if($rawLines.Count -ne 1){ EmitNotEligible 'ATOM_COUNT_NOT_ONE' }
try { $atom=([string]$rawLines[0] | ConvertFrom-Json) } catch { EmitNotEligible 'PARSE_ERROR' }
$cellsPath=Join-Path $memoryFull 'cells.jsonl'; $indexPath=Join-Path $memoryFull 'index.json'; $manifestPath=Join-Path $memoryFull 'manifest.json'
if(-not(Test-Path $cellsPath) -or -not(Test-Path $indexPath) -or -not(Test-Path $manifestPath)){ EmitNotEligible 'MEMORY_FILES_MISSING' }
$concept=[string](GetProp $atom 'concept_key'); if([string]::IsNullOrWhiteSpace($concept)){ $concept=[string](GetProp $atom 'concept') }; if([string]::IsNullOrWhiteSpace($concept)){ $concept=[string](GetProp $atom 'label') }; if([string]::IsNullOrWhiteSpace($concept)){ $concept=[string](GetProp $atom 'title') }; if([string]::IsNullOrWhiteSpace($concept)){ $concept=[string](GetProp $atom 'text') }
$conceptKey=CanonicalSlug $concept
$label=[string](GetProp $atom 'label'); if([string]::IsNullOrWhiteSpace($label)){ $label=$conceptKey }
$kind=[string](GetProp $atom 'kind'); if([string]::IsNullOrWhiteSpace($kind)){ $kind='concept' }
$definition=[string](GetProp $atom 'definition'); if([string]::IsNullOrWhiteSpace($definition)){ $definition=[string](GetProp $atom 'summary') }; if([string]::IsNullOrWhiteSpace($definition)){ $definition=[string](GetProp $atom 'text') }
$summary=CompactSummary $definition
if([string]::IsNullOrWhiteSpace($summary)){ EmitNotEligible 'SUMMARY_DELTA' $conceptKey }
if((ArrayFrom (GetProp $atom 'aliases')).Count -gt 0){ EmitNotEligible 'ALIASES_DELTA' $conceptKey }
if((ArrayFrom (GetProp $atom 'properties')).Count -gt 0){ EmitNotEligible 'PROPERTIES_DELTA' $conceptKey }
if((ArrayFrom (GetProp $atom 'relations')).Count -gt 0){ EmitNotEligible 'RELATIONS_DELTA' $conceptKey }
if((ArrayFrom (GetProp $atom 'uses')).Count -gt 0){ EmitNotEligible 'USES_DELTA' $conceptKey }
$cellLines=@(Get-Content $cellsPath); $needle='"concept_key":"'+$conceptKey+'"'; $matchIndexes=New-Object System.Collections.Generic.List[int]
for($i=0;$i -lt $cellLines.Count;$i++){ if(([string]$cellLines[$i]).IndexOf($needle,[StringComparison]::Ordinal) -ge 0){ $matchIndexes.Add($i)|Out-Null } }
if($matchIndexes.Count -ne 1){ EmitNotEligible 'CONCEPT_MATCH_COUNT_NOT_ONE' $conceptKey }
$targetIndex=[int]$matchIndexes[0]
try { $existing=([string]$cellLines[$targetIndex] | ConvertFrom-Json) } catch { EmitNotEligible 'PARSE_ERROR' $conceptKey }
if([string]$existing.label -ne $label){ EmitNotEligible 'LABEL_DELTA' $conceptKey }
if([string]$existing.kind -ne $kind){ EmitNotEligible 'KIND_DELTA' $conceptKey }
if([string]$existing.summary -ne $summary){ EmitNotEligible 'SUMMARY_DELTA' $conceptKey }
$rawCanonical=($atom|ConvertTo-Json -Depth 80 -Compress); $fp=Sha256Text $rawCanonical
$newCell=$existing; $newCell.source_fingerprints=MergeUnique $existing.source_fingerprints @($fp); $newCell.observation_count=[int]$existing.observation_count+1; $newCell.version=[int]$existing.version+1; $newCell.updated_at=(Get-Date).ToString('o')
$newLine=((CellToOrdered $newCell)|ConvertTo-Json -Depth 80 -Compress)
$oldCellsBytes=[IO.File]::ReadAllBytes($cellsPath); $oldManifestBytes=[IO.File]::ReadAllBytes($manifestPath)
try {
  $prospectiveBytes=$oldCellsBytes.Length-$utf8.GetByteCount([string]$cellLines[$targetIndex])+$utf8.GetByteCount($newLine); $indexBytes=(Get-Item $indexPath).Length
  if(($prospectiveBytes+$indexBytes) -gt $SizeBudgetBytes){ EmitNotEligible 'SIZE_BUDGET_EXCEEDED' $conceptKey }
  $cellLines[$targetIndex]=$newLine; $cellsJsonl=($cellLines -join "`n"); WriteText $cellsPath ($cellsJsonl+"`n")
  $cellBytes=(Get-Item $cellsPath).Length; $indexBytes=(Get-Item $indexPath).Length; $totalBytes=$cellBytes+$indexBytes; $rawDeleted=[bool]$CleanupInput
  $manifest=[ordered]@{schema='compact_semantic_memory_manifest_v1';status='PASS_COMPACT_SEMANTIC_DIGESTION_ORGAN_V1';run_id=$RunId;input_count=1;cell_count=$cellLines.Count;merged_count=1;raw_source_path=$inputFull;raw_source_deleted=$rawDeleted;raw_source_dependency_removed=([bool]$CleanupInput -and $rawDeleted);size_budget_bytes=$SizeBudgetBytes;cells_bytes=$cellBytes;index_bytes=$indexBytes;total_memory_bytes=$totalBytes;cells_sha256=Sha256Text $cellsJsonl;index_sha256=Sha256Text ((Get-Content $indexPath -Raw));blockers=@();boundary='Compact semantic memory contains meaning cells, not raw candidate/ready/source traces.';runtime_ready=$false}
  [IO.File]::WriteAllText($manifestPath,($manifest|ConvertTo-Json -Depth 80),$utf8)
  if($CleanupInput){ Remove-Item $inputFull -Force; if(Test-Path $inputFull){ throw 'CLEANUP_INPUT_NOT_DELETED' } }
} catch {
  [IO.File]::WriteAllBytes($cellsPath,$oldCellsBytes); [IO.File]::WriteAllBytes($manifestPath,$oldManifestBytes); Write-Error "REINFORCEMENT_FAST_PATH_ERROR:$($_.Exception.Message)"; exit 1
}
Write-Host 'REINFORCEMENT_FAST_PATH_STATUS=APPLIED'; Write-Host 'REINFORCEMENT_FAST_PATH_REASON=EXACT_EXISTING_REINFORCEMENT'; Write-Host "REINFORCEMENT_FAST_PATH_CONCEPT_KEY=$conceptKey"; Write-Host "REINFORCEMENT_FAST_PATH_FINGERPRINT=$fp"
