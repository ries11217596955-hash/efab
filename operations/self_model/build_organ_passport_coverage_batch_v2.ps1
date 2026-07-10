$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Write-Json($Obj,[string]$Path){ $dir=Split-Path $Path -Parent; if($dir -and -not(Test-Path $dir)){ New-Item -ItemType Directory -Path $dir -Force|Out-Null }; $Obj|ConvertTo-Json -Depth 50|Set-Content -Path $Path -Encoding UTF8 }
function Arr($x){ if($null -eq $x){ return @() }; return @($x) }
function SafeId([string]$s){ return ($s -replace '[^A-Za-z0-9_\-]','_') }
function Title([string]$id){ return (($id -replace '_',' ') -replace '\b(\w)',{param($m)$m.Value.ToUpperInvariant()}) }
function Norm([string]$p){ if([string]::IsNullOrWhiteSpace($p)){ return '' }; return $p.Replace('\','/').TrimEnd('/') }
function TrackedUnder([string]$root){ $r=Norm $root; return @(git ls-files | Where-Object { $n=$_.Replace('\','/'); $n -eq $r -or $n.StartsWith($r + '/') } | Sort-Object -Unique) }
function KindForLane([string]$lane){
  switch($lane){
    'REVIEW_LANE' { 'ORGAN_DRAFT_REVIEW' }
    'OWNER_LINK_REQUIRED' { 'OWNER_LINK_REQUIRED_REFERENCE' }
    'EVIDENCE_MATERIAL_BUCKET' { 'EVIDENCE_MATERIAL_REFERENCE' }
    'LEGACY_OR_ARCHIVE_BUCKET' { 'LEGACY_ARCHIVE_REFERENCE' }
    'SUPPORT_MATERIAL_BUCKET' { 'SUPPORT_MATERIAL_REFERENCE' }
    'GOVERNANCE_MATERIAL_BUCKET' { 'GOVERNANCE_MATERIAL_REFERENCE' }
    'CALIBRATED_PASSPORT_DRAFT_BLOCKED_RUNTIME' { 'BLOCKED_RUNTIME_REFERENCE' }
    'FAST_LANE_PASSPORT_DRAFT' { 'ORGAN_DRAFT_FAST_LANE' }
    default { 'COVERAGE_REFERENCE' }
  }
}
function ResponsibilitiesForKind([string]$kind,[string]$root){
  if($kind -eq 'ORGAN_DRAFT_REVIEW' -or $kind -eq 'ORGAN_DRAFT_FAST_LANE'){
    return @("Maintain bounded draft organ evidence for $root",'Expose owned files, invocations, validators, and proof references','Stay draft-only until separate maturity proof and owner acceptance')
  }
  return @("Preserve coverage reference for $root",'Make this candidate searchable and visible in the passport index','Prevent material/support/archive evidence from being confused with an active organ')
}
$contractPath='self_model/ORGAN_PASSPORT_V1_CONTRACT.json'
$lanesPath='self_model/organ_promotion_lanes/ORGAN_PROMOTION_LANES_V1.json'
$indexPath='self_model/organ_passports/_index/ORGAN_PASSPORT_DRAFT_INDEX_V1.json'
$reportPath='reports/self_development/ORGAN_PASSPORT_COVERAGE_BATCH_V2.json'
$proofPath='tests/self_development/ORGAN_PASSPORT_COVERAGE_BATCH_V2_PROOF.json'
foreach($p in @($contractPath,$lanesPath)){ Assert (Test-Path $p) "MISSING:$p" }
$contract=Get-Content $contractPath -Raw|ConvertFrom-Json
$lanes=Get-Content $lanesPath -Raw|ConvertFrom-Json
$decisions=@($lanes.lane_decisions)
$existingIds=@(Get-ChildItem 'self_model/organ_passports' -Recurse -Filter 'ORGAN_PASSPORT_V1.json' | ForEach-Object { (Get-Content $_.FullName -Raw|ConvertFrom-Json).organ_id })
$targets=@($decisions | Where-Object { $existingIds -notcontains $_.candidate_id })
Assert ($targets.Count -gt 0) 'NO_REMAINING_CANDIDATES'
$generated=@()
foreach($d in $targets){
  $id=SafeId ([string]$d.candidate_id)
  $root=Norm ([string]$d.path)
  $lane=[string]$d.lane
  $kind=KindForLane $lane
  $owned=TrackedUnder $root
  if($owned.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($root)){ $owned=@($root) }
  Assert ($owned.Count -gt 0) ("NO_OWNED_EVIDENCE:{0}:{1}" -f $id,$root)
  $inv=@($owned|Where-Object{$_ -match '\.ps1$'}|Sort-Object -Unique)
  $vals=@((Arr $d.validator_refs)+@($owned|Where-Object{$_ -match '(?i)(validate|validation).*\.ps1$'})|Where-Object{$_}|Sort-Object -Unique)
  $proofs=@(Arr $d.proof_refs|Where-Object{$_}|Sort-Object -Unique)
  $passportPath="self_model/organ_passports/$id/ORGAN_PASSPORT_V1.json"
  $docPath="docs/operations/organ_passports/$id/ORGAN_PASSPORT_V1.md"
  $now=(Get-Date).ToString('o')
  $pass=[ordered]@{
    schema='ORGAN_PASSPORT_V1'
    status='PASSPORT_DRAFT_FROM_EVIDENCE'
    organ_id=$id
    passport_kind=$kind
    source_lane=$lane
    display_name=(Title $id)
    purpose=([string]$d.reason)
    responsibilities=(ResponsibilitiesForKind $kind $root)
    what_it_is_not=@('not PASSPORT_ACTIVE','not PROVEN_LIVE','not proof of mature organ status','not a child-agent factory','not a replacement for validators or owner decision')
    owning_root=$root
    owned_files=$owned
    inputs=@('organ promotion lane decision','canonical body map','tracked owned evidence')
    outputs=@((@($owned|Where-Object{$_ -match '(?i)(report|proof|result|index|map|contract|json|md)$'}|Select-Object -First 12)+$inv)|Where-Object{$_}|Sort-Object -Unique)
    invocation_surfaces=$inv
    dependencies=@('canonical body map','organ promotion lanes','passport coverage batch v2')
    validators=$vals
    proof_refs=$proofs
    runtime_refs=@()
    exported_capabilities=@('candidate_visibility','coverage_inventory','evidence_reference_surface')
    safety_boundaries=@('draft only','no PASSPORT_ACTIVE claim','no PROVEN_LIVE claim','no live process touched','kind marks material/support/archive/reference candidates explicitly')
    failure_modes=@('candidate misclassified','generic coverage passport needs later calibration','stale lane decision','validator/proof drift')
    rollback_or_quarantine=@('revert generated passport files','rerun coverage validator','rerun passport review/index gate')
    maturity='DRAFT'
    live_or_lab_status='NOT_PROVEN'
    gaps=@('not calibrated for maturity','runtime proof missing','owner acceptance missing for active organ claim')
    source_evidence=@($lanesPath,'reports/self_development/SELF_MODEL_ACTIVE_MAP.json',$reportPath)
    last_validated_at=$now
  }
  foreach($field in @($contract.required_fields)){ Assert ($pass.Contains($field)) ("FIELD_MISSING:{0}:{1}" -f $id,$field) }
  Write-Json $pass $passportPath
  $docLines=@("# ORGAN_PASSPORT_V1 — $id",'',"status: PASSPORT_DRAFT_FROM_EVIDENCE","passport_kind: $kind","source_lane: $lane","maturity: DRAFT","live_or_lab_status: NOT_PROVEN","owning_root: $root",'','## Purpose',([string]$d.reason),'','## Boundaries','- draft only','- no PASSPORT_ACTIVE claim','- no PROVEN_LIVE claim','- no live process touched','- material/support/archive kinds are not active organ claims')
  $docDir=Split-Path $docPath -Parent; if(-not(Test-Path $docDir)){ New-Item -ItemType Directory -Path $docDir -Force|Out-Null }
  $docLines|Set-Content -Path $docPath -Encoding UTF8
  $generated += [ordered]@{organ_id=$id;passport_kind=$kind;source_lane=$lane;passport_path=$passportPath;doc_path=$docPath;owning_root=$root;status='PASSPORT_DRAFT_FROM_EVIDENCE';maturity='DRAFT';live_or_lab_status='NOT_PROVEN';owned_file_count=$owned.Count;validator_count=$vals.Count}
}
foreach($d in $lanes.lane_decisions){
  $g=@($generated|Where-Object{$_.organ_id -eq (SafeId ([string]$d.candidate_id))}|Select-Object -First 1)
  if($g.Count -eq 1){
    foreach($kv in @{passport_path=$g[0].passport_path; passport_doc_path=$g[0].doc_path; passport_status='PASSPORT_DRAFT_FROM_EVIDENCE'; passport_kind=$g[0].passport_kind}.GetEnumerator()){
      if($d.PSObject.Properties.Name -contains $kv.Key){ $d.($kv.Key)=$kv.Value } else { $d|Add-Member -NotePropertyName $kv.Key -NotePropertyValue $kv.Value }
    }
  }
}
Write-Json $lanes $lanesPath
$entries=@()
foreach($file in @(Get-ChildItem 'self_model/organ_passports' -Recurse -Filter 'ORGAN_PASSPORT_V1.json')){
  $pp=Get-Content $file.FullName -Raw|ConvertFrom-Json
  $rel=$file.FullName.Substring($RepoRoot.Length+1).Replace('\','/')
  $entries += [ordered]@{organ_id=$pp.organ_id; passport_kind=$pp.passport_kind; source_lane=$pp.source_lane; passport_path=$rel; status=$pp.status; maturity=$pp.maturity; live_or_lab_status=$pp.live_or_lab_status; owning_root=$pp.owning_root; validator_count=@($pp.validators).Count; proof_count=@($pp.proof_refs).Count}
}
$entries=@($entries|Sort-Object organ_id)
Write-Json ([ordered]@{schema='organ_passport_draft_index_v1';status='PASS_ORGAN_PASSPORT_DRAFT_INDEX_V1';generated_from='self_model/organ_passports/*/ORGAN_PASSPORT_V1.json';draft_count=$entries.Count;entries=$entries;boundaries=[ordered]@{index_only=$true;no_status_mutation=$true;no_active_passports_created=$true;no_proven_live_claims_created=$true;live_process_touched=$false};created_at=(Get-Date).ToString('o')}) $indexPath
$kindCounts=@($generated|Group-Object passport_kind|ForEach-Object{[ordered]@{passport_kind=$_.Name;count=$_.Count}})
$laneCounts=@($generated|Group-Object source_lane|ForEach-Object{[ordered]@{source_lane=$_.Name;count=$_.Count}})
Write-Json ([ordered]@{schema='organ_passport_coverage_batch_v2';status='PASS_ORGAN_PASSPORT_COVERAGE_BATCH_V2';previous_passport_count=$existingIds.Count;lane_decision_count=$decisions.Count;generated_count=$generated.Count;final_passport_count=$entries.Count;generated_by_kind=$kindCounts;generated_by_lane=$laneCounts;generated_drafts=$generated;boundaries=[ordered]@{draft_only=$true;coverage_not_activation=$true;no_active_passports_created=$true;no_live_claims=$true;live_process_touched=$false};created_at=(Get-Date).ToString('o')}) $reportPath
Write-Json ([ordered]@{schema='organ_passport_coverage_batch_v2_proof';status='PASS_ORGAN_PASSPORT_COVERAGE_BATCH_V2';report_path=$reportPath;generated_count=$generated.Count;final_passport_count=$entries.Count;lane_decision_count=$decisions.Count;coverage_complete=($entries.Count -eq $decisions.Count);no_active_passports_created=$true;no_live_claims=$true;live_process_touched=$false;created_at=(Get-Date).ToString('o')}) $proofPath
Write-Host 'GENERATOR_PASS=PASS_ORGAN_PASSPORT_COVERAGE_BATCH_V2'
Write-Host ('GENERATED='+$generated.Count)
Write-Host ('FINAL_PASSPORT_COUNT='+$entries.Count)
Write-Host ('LANE_DECISION_COUNT='+$decisions.Count)
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
