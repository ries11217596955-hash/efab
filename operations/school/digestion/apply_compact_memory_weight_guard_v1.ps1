param(
  [Parameter(Mandatory=$true)][string]$MemoryRoot,
  [string]$ReportPath='',
  [ValidateSet('Conservative')][string]$Mode='Conservative',
  [int]$MaxListItems=1000,
  [int]$MaxFieldBytes=262144,
  [int]$SampleCount=3
)
$ErrorActionPreference='Stop'
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($Path,$Obj,$Depth=80){
  $dir=Split-Path -Parent $Path
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path),($Obj|ConvertTo-Json -Depth $Depth),$utf8)
}
function FileSha256($Path){ (Get-FileHash $Path -Algorithm SHA256).Hash }
function JsonString($Value){
  $s=$Value | ConvertTo-Json -Depth 80 -Compress
  if($null -eq $s){
    if($Value -is [array] -and $Value.Count -eq 0){ return '[]' }
    return 'null'
  }
  return [string]$s
}
function JsonBytes($Value){
  $s=JsonString $Value
  return [Text.Encoding]::UTF8.GetByteCount($s)
}
function JsonSha256($Value){
  $s=JsonString $Value
  $bytes=[Text.Encoding]::UTF8.GetBytes($s)
  $sha=[Security.Cryptography.SHA256]::Create()
  try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','') } finally { $sha.Dispose() }
}
function SummarizeList($List,$Field,$CellId,$OriginalBytes){
  $arr=@($List)
  $tail=@()
  if($arr.Count -gt $SampleCount){ $tail=@($arr | Select-Object -Last $SampleCount) }
  return [ordered]@{
    schema='compact_memory_weight_guard_list_summary_v1'
    field=$Field
    cell_id=$CellId
    original_type='list'
    original_count=[int]$arr.Count
    original_bytes=[int]$OriginalBytes
    original_sha256=(JsonSha256 $arr)
    sample_head=@($arr | Select-Object -First $SampleCount)
    sample_tail=@($tail)
    compaction_rule='count_sha256_head_tail_only'
  }
}
function ApplyGuardToCell($Cell){
  $changed=$false
  $events=New-Object 'System.Collections.Generic.List[object]'
  $cellId=[string]$Cell.cell_id
  foreach($field in @('relations','source_fingerprints')){
    $prop=$Cell.PSObject.Properties[$field]
    if(-not $prop){ continue }
    $list=@($prop.Value)
    $fieldBytes=JsonBytes $list
    $alreadySummarized=($Cell.PSObject.Properties[($field + '_summary')] -ne $null)
    $tooLarge=($list.Count -gt $MaxListItems -or $fieldBytes -gt $MaxFieldBytes)
    if($tooLarge -and -not $alreadySummarized){
      $summary=SummarizeList $list $field $cellId $fieldBytes
      $sample=@($list | Select-Object -First $SampleCount)
      if($list.Count -gt $SampleCount){ $sample += @($list | Select-Object -Last $SampleCount) }
      $Cell.$field=@($sample)
      $Cell | Add-Member -NotePropertyName ($field + '_summary') -NotePropertyValue ([pscustomobject]$summary) -Force
      $changed=$true
      [void]$events.Add([ordered]@{ cell_id=$cellId; field=$field; original_count=$list.Count; original_bytes=$fieldBytes; retained_sample_count=$sample.Count; original_sha256=$summary.original_sha256 })
    } elseif($tooLarge -and $alreadySummarized){
      [void]$events.Add([ordered]@{ cell_id=$cellId; field=$field; action='already_summarized_large_sample_or_legacy'; current_count=$list.Count; current_bytes=$fieldBytes })
    }
  }
  if($changed){
    $Cell | Add-Member -NotePropertyName 'storage_weight_guard' -NotePropertyValue ([pscustomobject][ordered]@{
      schema='compact_memory_weight_guard_cell_v1'
      mode=$Mode
      applied_at=(Get-Date).ToString('o')
      fields_guarded=@('relations','source_fingerprints')
      properties_preserved_full=$true
      rule='large proof-tail lists summarized; properties remain full for query compatibility'
    }) -Force
  }
  return [ordered]@{ cell=$Cell; changed=$changed; events=@($events.ToArray()) }
}
if(-not (Test-Path $MemoryRoot)){ throw "MEMORY_ROOT_MISSING:$MemoryRoot" }
$cellsPath=Join-Path $MemoryRoot 'cells.jsonl'
$indexPath=Join-Path $MemoryRoot 'index.json'
$manifestPath=Join-Path $MemoryRoot 'manifest.json'
foreach($p in @($cellsPath,$indexPath,$manifestPath)){ if(-not (Test-Path $p)){ throw "MEMORY_FILE_MISSING:$p" } }
$before=[ordered]@{ cells_bytes=(Get-Item $cellsPath).Length; index_bytes=(Get-Item $indexPath).Length; manifest_bytes=(Get-Item $manifestPath).Length; cells_sha256=(FileSha256 $cellsPath); index_sha256=(FileSha256 $indexPath); manifest_sha256=(FileSha256 $manifestPath) }
$cells=New-Object 'System.Collections.Generic.List[object]'
$events=New-Object 'System.Collections.Generic.List[object]'
Get-Content $cellsPath | ForEach-Object {
  $line=[string]$_
  if([string]::IsNullOrWhiteSpace($line)){ return }
  $obj=$line | ConvertFrom-Json
  $res=ApplyGuardToCell $obj
  [void]$cells.Add($res.cell)
  foreach($e in @($res.events)){ [void]$events.Add($e) }
}
$tmpCells=$cellsPath + '.guard_tmp'
($cells | ForEach-Object { $_ | ConvertTo-Json -Depth 80 -Compress }) -join "`n" | Set-Content -LiteralPath $tmpCells -Encoding UTF8
Move-Item -LiteralPath $tmpCells -Destination $cellsPath -Force
$manifest=Get-Content $manifestPath -Raw | ConvertFrom-Json
$manifest | Add-Member -NotePropertyName 'storage_weight_guard' -NotePropertyValue ([pscustomobject][ordered]@{
  schema='compact_memory_weight_guard_manifest_v1'
  status='ACTIVE'
  mode=$Mode
  last_applied_at=(Get-Date).ToString('o')
  max_list_items=$MaxListItems
  max_field_bytes=$MaxFieldBytes
  sample_count=$SampleCount
  guarded_fields=@('relations','source_fingerprints')
  properties_preserved_full=$true
  compacted_event_count=[int]$events.Count
}) -Force
$manifest.cells_bytes=(Get-Item $cellsPath).Length
$manifest.index_bytes=(Get-Item $indexPath).Length
# Estimate total after manifest rewrite; exact manifest bytes recalculated after write.
$manifest.total_memory_bytes=[int64]($manifest.cells_bytes + $manifest.index_bytes + (JsonBytes $manifest))
[IO.File]::WriteAllText((Join-Path (Get-Location).Path $manifestPath),($manifest|ConvertTo-Json -Depth 80),$utf8)
$after=[ordered]@{ cells_bytes=(Get-Item $cellsPath).Length; index_bytes=(Get-Item $indexPath).Length; manifest_bytes=(Get-Item $manifestPath).Length; cells_sha256=(FileSha256 $cellsPath); index_sha256=(FileSha256 $indexPath); manifest_sha256=(FileSha256 $manifestPath) }
# Basic validation
$lineCount=(Get-Content $cellsPath | Measure-Object).Count
if($lineCount -ne $cells.Count){ throw "CELL_LINE_COUNT_MISMATCH_AFTER_GUARD:$lineCount/$($cells.Count)" }
$indexAfter=Get-Content $indexPath -Raw | ConvertFrom-Json
if([int]$indexAfter.term_count -lt 1){ throw 'INDEX_EMPTY_AFTER_GUARD' }
$status='PASS_COMPACT_MEMORY_WEIGHT_GUARD_V1'
$report=[ordered]@{
  schema='compact_memory_weight_guard_v1'
  status=$status
  memory_root=$MemoryRoot
  mode=$Mode
  max_list_items=$MaxListItems
  max_field_bytes=$MaxFieldBytes
  sample_count=$SampleCount
  before=$before
  after=$after
  cell_count=[int]$cells.Count
  compacted_event_count=[int]$events.Count
  compacted_events=@($events.ToArray())
  fields_guarded=@('relations','source_fingerprints')
  properties_preserved_full=$true
  index_sha256_unchanged=($before.index_sha256 -eq $after.index_sha256)
  bytes_saved=[int64]($before.cells_bytes - $after.cells_bytes)
  boundary='Guard compacts proof-tail list fields only. It preserves properties, index, and semantic cell fields.'
  created_at=(Get-Date).ToString('o')
}
if([string]::IsNullOrWhiteSpace($ReportPath)){ $ReportPath=".runtime/compact_memory_weight_guard_v1/WEIGHT_GUARD_REPORT_$(Get-Date -Format 'yyyyMMdd_HHmmss').json" }
WriteJson $ReportPath $report 100
Write-Host "MEMORY_WEIGHT_GUARD_STATUS=$status"
Write-Host "MEMORY_WEIGHT_GUARD_REPORT=$ReportPath"
Write-Host "MEMORY_WEIGHT_GUARD_EVENTS=$($events.Count)"
Write-Host "MEMORY_WEIGHT_GUARD_BYTES_SAVED=$($report.bytes_saved)"
Write-Host "MEMORY_WEIGHT_GUARD_CELLS_BYTES_AFTER=$($after.cells_bytes)"