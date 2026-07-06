param([Parameter(Mandatory=$true)][string]$MaterialPath,[string]$ProofPath)
$ErrorActionPreference='Stop'
Set-Location (git rev-parse --show-toplevel).Trim()
if(-not (Test-Path $MaterialPath)){ throw "EXTERNAL_MATERIAL_MISSING:$MaterialPath" }
$m=Get-Content $MaterialPath -Raw|ConvertFrom-Json
$blockers=@()
if($m.schema -ne 'external_world_school_material_v1'){ $blockers+='SCHEMA_BAD' }
if($m.material_status -ne 'EXTERNAL_MATERIAL_CANDIDATE'){ $blockers+='MATERIAL_STATUS_BAD' }
if([string]::IsNullOrWhiteSpace([string]$m.query_contract)){ $blockers+='QUERY_CONTRACT_MISSING' }
if(@($m.sources).Count -lt 1){ $blockers+='NO_SOURCES' }
$allowed=@('official_docs','primary_source','standards_specification','repository_source','vendor_docs','reputable_technical_article')
foreach($s in @($m.sources)){
 if([string]::IsNullOrWhiteSpace([string]$s.title)){ $blockers+='SOURCE_TITLE_MISSING' }
 if([string]::IsNullOrWhiteSpace([string]$s.url)){ $blockers+='SOURCE_URL_MISSING' }
 if(@($allowed) -notcontains [string]$s.authority_tier){ $blockers+='SOURCE_AUTHORITY_TIER_NOT_ALLOWED' }
 if([string]::IsNullOrWhiteSpace([string]$s.provenance_note)){ $blockers+='SOURCE_PROVENANCE_NOTE_MISSING' }
}
if(@($m.material_items).Count -lt 1){ $blockers+='NO_MATERIAL_ITEMS' }
foreach($it in @($m.material_items)){
 if([string]::IsNullOrWhiteSpace([string]$it.topic)){ $blockers+='ITEM_TOPIC_MISSING' }
 if([string]::IsNullOrWhiteSpace([string]$it.summary)){ $blockers+='ITEM_SUMMARY_MISSING' }
 if(@($it.source_refs).Count -lt 1){ $blockers+='ITEM_SOURCE_REFS_MISSING' }
 if(@($it.validation_needed).Count -lt 1){ $blockers+='ITEM_VALIDATION_NEEDED_MISSING' }
}
if($m.boundary -notmatch 'not.*brain|material supplier|not route authority'){ $blockers+='BOUNDARY_NOT_STRONG_ENOUGH' }
$status=if($blockers.Count -eq 0){'PASS_EXTERNAL_WORLD_SOURCE_MATERIAL_V1'}else{'FAIL_EXTERNAL_WORLD_SOURCE_MATERIAL_V1'}
if([string]::IsNullOrWhiteSpace($ProofPath)){ $ProofPath=Join-Path (Split-Path $MaterialPath -Parent) 'EXTERNAL_WORLD_SOURCE_MATERIAL_VALIDATION_V1.json' }
[ordered]@{schema='external_world_source_material_validation_v1';status=$status;material_path=$MaterialPath;material_status=$m.material_status;source_count=@($m.sources).Count;material_item_count=@($m.material_items).Count;blockers=@($blockers);boundary='Validation admits external material as candidate material only; not accepted memory and not route authority.';checked_at=(Get-Date).ToString('o')} | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $ProofPath -Encoding UTF8
Write-Host "EXTERNAL_WORLD_MATERIAL_VALIDATION_STATUS=$status"
Write-Host "EXTERNAL_WORLD_MATERIAL_VALIDATION_PROOF=$ProofPath"
if($status -notlike 'PASS_*'){ exit 1 }
