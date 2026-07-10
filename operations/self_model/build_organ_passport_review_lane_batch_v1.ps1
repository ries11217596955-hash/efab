param([string[]]$CandidateIds=@())
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function WJson($Obj,[string]$Path){$d=Split-Path $Path -Parent;if($d -and -not(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null};$Obj|ConvertTo-Json -Depth 40|Set-Content $Path -Encoding UTF8}
function Arr($x){if($null -eq $x){@()}else{@($x)}}
function Tracked([string]$Root){$r=$Root.Replace('\\','/').TrimEnd('/');@(git ls-files|Where-Object{$n=$_.Replace('\\','/'); $n -eq $r -or $n.StartsWith($r+'/')}|Sort-Object -Unique)}
function Title([string]$Id){(($Id -replace '_',' ') -replace '\b(\w)',{param($m)$m.Value.ToUpperInvariant()})}
$contractPath='self_model/ORGAN_PASSPORT_V1_CONTRACT.json'
$lanesPath='self_model/organ_promotion_lanes/ORGAN_PROMOTION_LANES_V1.json'
$reportPath='reports/self_development/ORGAN_PASSPORT_REVIEW_LANE_BATCH_GENERATOR_V1.json'
$proofPath='tests/self_development/ORGAN_PASSPORT_REVIEW_LANE_BATCH_GENERATOR_V1_PROOF.json'
$indexPath='self_model/organ_passports/_index/ORGAN_PASSPORT_DRAFT_INDEX_V1.json'
foreach($x in @($contractPath,$lanesPath)){Assert (Test-Path $x) "MISSING:$x"}
$contract=Get-Content $contractPath -Raw|ConvertFrom-Json
$lanes=Get-Content $lanesPath -Raw|ConvertFrom-Json
$decisions=@($lanes.lane_decisions)
if($CandidateIds.Count -eq 0){$CandidateIds=@($decisions|Where-Object{$_.lane -eq 'REVIEW_LANE' -and $_.candidate_id -like 'operations_*' -and $_.candidate_id -ne 'operations_readme_md'}|ForEach-Object{$_.candidate_id})}
$targets=@($decisions|Where-Object{$CandidateIds -contains $_.candidate_id})
Assert ($targets.Count -eq $CandidateIds.Count) 'SOME_TARGETS_NOT_FOUND'
$generated=@()
foreach($d in $targets){
  Assert ($d.lane -eq 'REVIEW_LANE') "TARGET_NOT_REVIEW_LANE:$($d.candidate_id):$($d.lane)"
  $id=[string]$d.candidate_id;$root=[string]$d.path
  Assert (-not [string]::IsNullOrWhiteSpace($root)) "ROOT_EMPTY:$id"
  $owned=Tracked $root; Assert ($owned.Count -gt 0) ("NO_TRACKED_FILES:{0}:{1}" -f $id,$root)
  $inv=@($owned|Where-Object{$_ -match '\.ps1$'}|Sort-Object -Unique)
  $vals=@((Arr $d.validator_refs)+@($owned|Where-Object{$_ -match '(?i)(validate|validation).*\.ps1$'})|Where-Object{$_}|Sort-Object -Unique)
  $proofs=@(Arr $d.proof_refs|Where-Object{$_}|Sort-Object -Unique)
  $passPath="self_model/organ_passports/$id/ORGAN_PASSPORT_V1.json"
  $docPath="docs/operations/organ_passports/$id/ORGAN_PASSPORT_V1.md"
  $now=(Get-Date).ToString('o')
  $pass=[ordered]@{
    schema='ORGAN_PASSPORT_V1';status='PASSPORT_DRAFT_FROM_EVIDENCE';organ_id=$id;display_name=(Title $id);purpose=([string]$d.reason)
    responsibilities=@("Maintain the bounded capability surface under $root",'Preserve owned files/invocations/validators as draft organ evidence','Remain draft-only until separate maturity proof and owner acceptance')
    what_it_is_not=@('not PASSPORT_ACTIVE','not PROVEN_LIVE','not a mature organ','not a child-agent factory','not a replacement for validators')
    owning_root=$root;owned_files=$owned
    inputs=@('canonical body map','review-lane decision','tracked owned files')
    outputs=@((@($owned|Where-Object{$_ -match '(?i)(report|proof|result|index|map|contract|json|md)$'}|Select-Object -First 12)+$inv)|Where-Object{$_}|Sort-Object -Unique)
    invocation_surfaces=$inv;dependencies=@('canonical body map','organ promotion lanes','passport review/index gate')
    validators=$vals;proof_refs=$proofs;runtime_refs=@();exported_capabilities=@('draft_organ_evidence_surface','owned_file_inventory','invocation_and_validator_inventory')
    safety_boundaries=@('draft only','no PASSPORT_ACTIVE claim','no PROVEN_LIVE claim','no live process touched','activation requires separate validator/proof/Owner acceptance')
    failure_modes=@('stale body map','review-lane misclassification','generic draft needs organ-specific calibration','validator/proof drift')
    rollback_or_quarantine=@('revert passport draft files','rerun review/index gate','rerun map refresh/currentness validator')
    maturity='DRAFT';live_or_lab_status='NOT_PROVEN'
    gaps=@('organ-specific calibration missing','runtime proof missing','ACTIVE status forbidden','PROVEN_LIVE forbidden')
    source_evidence=@($lanesPath,'reports/self_development/SELF_MODEL_ACTIVE_MAP.json',$reportPath)
    last_validated_at=$now
  }
  foreach($f in @($contract.required_fields)){Assert ($pass.Contains($f)) ("FIELD_MISSING:{0}:{1}" -f $id,$f)}
  WJson $pass $passPath
  $md=@("# ORGAN_PASSPORT_V1 — $id",'','status: PASSPORT_DRAFT_FROM_EVIDENCE','maturity: DRAFT','live_or_lab_status: NOT_PROVEN',"owning_root: $root",'','## Purpose',([string]$d.reason),'','## Boundaries','- draft only','- no PASSPORT_ACTIVE claim','- no PROVEN_LIVE claim','- no live process touched','- organ-specific calibration still required')
  $dd=Split-Path $docPath -Parent;if(-not(Test-Path $dd)){New-Item -ItemType Directory -Path $dd -Force|Out-Null};$md|Set-Content $docPath -Encoding UTF8
  $generated += [ordered]@{organ_id=$id;passport_path=$passPath;doc_path=$docPath;owning_root=$root;status='PASSPORT_DRAFT_FROM_EVIDENCE';maturity='DRAFT';live_or_lab_status='NOT_PROVEN';owned_file_count=$owned.Count;validator_count=$vals.Count}
}
foreach($d in $lanes.lane_decisions){$g=@($generated|Where-Object{$_.organ_id -eq $d.candidate_id}|Select-Object -First 1);if($g.Count -eq 1){foreach($kv in @{passport_path=$g[0].passport_path;passport_doc_path=$g[0].doc_path;passport_status='PASSPORT_DRAFT_FROM_EVIDENCE'}.GetEnumerator()){if($d.PSObject.Properties.Name -contains $kv.Key){$d.($kv.Key)=$kv.Value}else{$d|Add-Member -NotePropertyName $kv.Key -NotePropertyValue $kv.Value}}}}
WJson $lanes $lanesPath
$entries=@();foreach($f in @(Get-ChildItem 'self_model/organ_passports' -Recurse -Filter 'ORGAN_PASSPORT_V1.json')){$pp=Get-Content $f.FullName -Raw|ConvertFrom-Json;$rel=$f.FullName.Substring($RepoRoot.Length+1).Replace('\\','/');$entries += [ordered]@{organ_id=$pp.organ_id;passport_path=$rel;status=$pp.status;maturity=$pp.maturity;live_or_lab_status=$pp.live_or_lab_status;owning_root=$pp.owning_root;validator_count=@($pp.validators).Count;proof_count=@($pp.proof_refs).Count}}
$entries=@($entries|Sort-Object organ_id)
WJson ([ordered]@{schema='organ_passport_draft_index_v1';status='PASS_ORGAN_PASSPORT_DRAFT_INDEX_V1';generated_from='self_model/organ_passports/*/ORGAN_PASSPORT_V1.json';draft_count=$entries.Count;entries=$entries;boundaries=[ordered]@{index_only=$true;no_status_mutation=$true;no_active_passports_created=$true;no_proven_live_claims_created=$true;live_process_touched=$false};created_at=(Get-Date).ToString('o')}) $indexPath
WJson ([ordered]@{schema='organ_passport_review_lane_batch_generator_v1';status='PASS_ORGAN_PASSPORT_REVIEW_LANE_BATCH_GENERATOR_V1';input_candidate_ids=$CandidateIds;generated_count=$generated.Count;generated_drafts=$generated;boundaries=[ordered]@{draft_only=$true;review_lane_only=$true;no_active_passports_created=$true;no_live_claims=$true;live_process_touched=$false};created_at=(Get-Date).ToString('o')}) $reportPath
WJson ([ordered]@{schema='organ_passport_review_lane_batch_generator_v1_proof';status='PASS_ORGAN_PASSPORT_REVIEW_LANE_BATCH_GENERATOR_V1';report_path=$reportPath;generated_count=$generated.Count;generated_organ_ids=@($generated.organ_id);no_active_passports_created=$true;no_live_claims=$true;live_process_touched=$false;created_at=(Get-Date).ToString('o')}) $proofPath
Write-Host 'GENERATOR_PASS=PASS_ORGAN_PASSPORT_REVIEW_LANE_BATCH_GENERATOR_V1'
Write-Host ('GENERATED='+(@($generated.organ_id)-join ','))
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('INDEX_PATH='+$indexPath)


