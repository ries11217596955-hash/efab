param(
  [Parameter(Mandatory=$true)][string]$PacketPath,
  [string]$PolicyPath = "operations/compact_memory_intake/multi_source_compact_memory_intake_policy.json"
)
$ErrorActionPreference = 'Stop'
function Fail($Code,$Message){
  Write-Host "PACKET_VALIDATION_STATUS=FAIL"
  Write-Host "PACKET_VALIDATION_ERROR=$Code"
  throw $Message
}
if(-not (Test-Path $PacketPath)){ Fail 'PACKET_MISSING' "Packet not found: $PacketPath" }
if(-not (Test-Path $PolicyPath)){ Fail 'POLICY_MISSING' "Policy not found: $PolicyPath" }
$policy = Get-Content $PolicyPath -Raw | ConvertFrom-Json
$packet = Get-Content $PacketPath -Raw | ConvertFrom-Json
if($packet.schema -ne 'compact_memory_knowledge_packet_v1'){ Fail 'BAD_SCHEMA' 'Expected compact_memory_knowledge_packet_v1' }
if(@($policy.allowed_sources) -notcontains [string]$packet.source_kind){ Fail 'SOURCE_NOT_ALLOWED' "Source not allowed: $($packet.source_kind)" }
if(-not $packet.source_id){ Fail 'SOURCE_ID_MISSING' 'source_id is required' }
$atoms=@($packet.atoms)
if($atoms.Count -lt 1){ Fail 'ATOMS_EMPTY' 'at least one atom/summary atom is required' }
if($atoms.Count -gt [int]$policy.max_packet_atoms){ Fail 'TOO_MANY_ATOMS_IN_PACKET' 'packet exceeds max_packet_atoms; submit compact summary or split packet' }
$topicSet=@{}
$minQuality=1.0
$minNovelty=1.0
foreach($a in $atoms){
  if(-not $a.id){ Fail 'ATOM_ID_MISSING' 'atom.id is required' }
  if(-not $a.topic){ Fail 'ATOM_TOPIC_MISSING' "atom.topic is required for $($a.id)" }
  if($null -eq $a.level){ Fail 'ATOM_LEVEL_MISSING' "atom.level is required for $($a.id)" }
  if($null -eq $a.quality_score){ Fail 'ATOM_QUALITY_MISSING' "atom.quality_score is required for $($a.id)" }
  if([double]$a.quality_score -lt [double]$policy.min_quality_score){ Fail 'ATOM_QUALITY_TOO_LOW' "quality_score too low for $($a.id)" }
  if($null -ne $a.novelty_score -and [double]$a.novelty_score -lt [double]$policy.min_novelty_score){ Fail 'ATOM_NOVELTY_TOO_LOW' "novelty_score too low for $($a.id)" }
  $topicSet[[string]$a.topic]=$true
  $minQuality=[Math]::Min($minQuality,[double]$a.quality_score)
  if($null -ne $a.novelty_score){ $minNovelty=[Math]::Min($minNovelty,[double]$a.novelty_score) }
}
$declaredAtomCount = if($packet.quality_summary -and $packet.quality_summary.atom_count){ [int]$packet.quality_summary.atom_count } else { $atoms.Count }
if($declaredAtomCount -lt $atoms.Count){ Fail 'ATOM_COUNT_LT_PACKET_ATOMS' 'quality_summary.atom_count cannot be lower than atoms.Count' }
$result=[ordered]@{
  schema='compact_memory_knowledge_packet_validation_v1'
  status='PASS_COMPACT_MEMORY_KNOWLEDGE_PACKET_V1'
  packet_path=$PacketPath
  source_kind=$packet.source_kind
  source_id=$packet.source_id
  declared_atom_count=$declaredAtomCount
  packet_atoms=$atoms.Count
  topic_count=$topicSet.Keys.Count
  min_quality_score=$minQuality
  min_novelty_score=$minNovelty
  direct_active_memory_mutation_allowed=[bool]$policy.direct_active_memory_mutation_allowed
  validated_at=(Get-Date).ToString('o')
}
Write-Host "PACKET_VALIDATION_STATUS=$($result.status)"
Write-Host "PACKET_SOURCE=$($result.source_kind)"
Write-Host "PACKET_DECLARED_ATOMS=$($result.declared_atom_count)"
Write-Host "PACKET_TOPICS=$($result.topic_count)"
$result | ConvertTo-Json -Depth 40