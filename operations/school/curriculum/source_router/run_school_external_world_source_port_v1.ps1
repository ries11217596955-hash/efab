param([Parameter(Mandatory=$true)][int]$TargetAccepted,[Parameter(Mandatory=$true)][string]$RunId,[Parameter(Mandatory=$true)][string]$TopicsPlan,[string]$SeedMaterialPath,[string[]]$FetchUrls=@(),[string]$RunRootBase='.runtime/school_source_ports/external_world')
$ErrorActionPreference='Stop'
Set-Location (git rev-parse --show-toplevel).Trim()
function EnsureDir($p){ if(-not(Test-Path $p)){ New-Item -ItemType Directory -Force -Path $p|Out-Null } }
function WriteJson($p,$o,$d=80){ $dir=Split-Path $p -Parent; if($dir){EnsureDir $dir}; $o|ConvertTo-Json -Depth $d|Set-Content -LiteralPath $p -Encoding UTF8 }
if(-not(Test-Path $TopicsPlan)){ throw "TOPICS_PLAN_MISSING:$TopicsPlan" }
$runRoot=Join-Path $RunRootBase $RunId; EnsureDir $runRoot
$materialPath=Join-Path $runRoot 'EXTERNAL_WORLD_SCHOOL_MATERIAL.json'
$fetchReports=@(); $materialMode=$null
if(-not [string]::IsNullOrWhiteSpace($SeedMaterialPath)){
 if(-not(Test-Path $SeedMaterialPath)){ throw "SEED_MATERIAL_MISSING:$SeedMaterialPath" }
 Copy-Item -LiteralPath $SeedMaterialPath -Destination $materialPath -Force
 $materialMode='SeededMaterial'
} elseif(@($FetchUrls).Count -gt 0){
 $sources=@(); $items=@(); $i=0
 foreach($u in @($FetchUrls|Select-Object -First 5)){
  $i++; $fetchPath=Join-Path $runRoot ("FETCH_$i.txt")
  try{ $resp=Invoke-WebRequest -UseBasicParsing -Uri $u -TimeoutSec 20; $txt=[string]$resp.Content; $txt.Substring(0,[Math]::Min(4000,$txt.Length))|Set-Content -LiteralPath $fetchPath -Encoding UTF8; $sources += [ordered]@{id="src$i";title=$u;url=$u;authority_tier='vendor_docs';provenance_note='Fetched by bounded ExternalWorldSourcePort V1; authority tier must be reviewed before promotion.'}; $items += [ordered]@{topic="external_fetch_$i";summary=('Fetched external material candidate from '+$u);source_refs=@("src$i");validation_needed=@('authority review','freshness review','license/provenance review','school validator before use')}; $fetchReports += [ordered]@{url=$u;status='PASS_FETCH';path=$fetchPath} } catch { $fetchReports += [ordered]@{url=$u;status='FAIL_FETCH';error=[string]$_.Exception.Message} }
 }
 WriteJson $materialPath ([ordered]@{schema='external_world_school_material_v1';material_status='EXTERNAL_MATERIAL_CANDIDATE';query_contract='bounded FetchUrls external scout for school candidate material';sources=@($sources);material_items=@($items);fetch_reports=@($fetchReports);boundary='ExternalWorld is material supplier only, not school brain and not route authority. Material requires validator and cannot write compact memory directly.';created_at=(Get-Date).ToString('o')}) 80
 $materialMode='WebFetch'
} else { throw 'EXTERNAL_WORLD_SOURCE_REQUIRES_SEED_MATERIAL_OR_FETCH_URLS' }
$validationProof=Join-Path $runRoot 'EXTERNAL_WORLD_SOURCE_MATERIAL_VALIDATION_V1.json'
$vout=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/curriculum/source_router/validate_external_world_source_material_v1.ps1 -MaterialPath $materialPath -ProofPath $validationProof *>&1|ForEach-Object{[string]$_})
$vstatus=($vout|Where-Object{$_ -match '^EXTERNAL_WORLD_MATERIAL_VALIDATION_STATUS='}|Select-Object -Last 1)-replace '^EXTERNAL_WORLD_MATERIAL_VALIDATION_STATUS=',''
$status=if($vstatus -eq 'PASS_EXTERNAL_WORLD_SOURCE_MATERIAL_V1'){'PASS_SCHOOL_EXTERNAL_WORLD_SOURCE_PORT_V1'}else{'FAIL_SCHOOL_EXTERNAL_WORLD_SOURCE_PORT_V1'}
$proof=Join-Path $runRoot 'SCHOOL_EXTERNAL_WORLD_SOURCE_PORT_PROOF.json'
WriteJson $proof ([ordered]@{schema='school_external_world_source_port_proof_v1';status=$status;run_id=$RunId;source='ExternalWorldSourcePort';material_mode=$materialMode;target_accepted=$TargetAccepted;topics_plan=$TopicsPlan;material_path=$materialPath;validation_status=$vstatus;validation_proof=$validationProof;material_status='EXTERNAL_MATERIAL_CANDIDATE';fetch_reports=@($fetchReports);active_memory_mutated=$false;source_role='EXTERNAL_WORLD_MATERIAL_SUPPLIER';boundary='ExternalWorldSourcePort admits external material candidate only; it cannot write compact memory, cannot decide route, and cannot bypass school validators.';created_at=(Get-Date).ToString('o')}) 80
Write-Host "SCHOOL_EXTERNAL_WORLD_SOURCE_PORT_STATUS=$status"
Write-Host "SCHOOL_EXTERNAL_WORLD_SOURCE_PORT_PROOF=$proof"
Write-Host "SCHOOL_EXTERNAL_WORLD_MATERIAL_STATUS=EXTERNAL_MATERIAL_CANDIDATE"
Write-Host "SCHOOL_EXTERNAL_WORLD_MATERIAL_MODE=$materialMode"
if($status -notlike 'PASS_*'){ exit 1 }
