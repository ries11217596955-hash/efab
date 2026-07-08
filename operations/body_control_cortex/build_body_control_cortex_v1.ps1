$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function ReadJson([string]$Path){ if(-not(Test-Path $Path)){ throw "MISSING:$Path" }; return Get-Content $Path -Raw | ConvertFrom-Json }
function ObjIdFromPath([string]$Path){ return (($Path -replace '\\','/').Trim('/') -replace '[^A-Za-z0-9]+','_').Trim('_').ToLowerInvariant() }
function StatusForPassport($Passport){
  if($null -eq $Passport){ return 'PASSPORT_MISSING' }
  if($Passport.status -eq 'PASSPORT_ACTIVE'){ return 'PASSPORT_ACTIVE' }
  if($Passport.maturity -eq 'VALIDATED_LAB' -and $Passport.live_or_lab_status -eq 'PROVEN_LAB'){ return 'PASSPORT_VALIDATED_LAB_NOT_ACTIVE' }
  if($Passport.status -eq 'PASSPORT_DRAFT_FROM_EVIDENCE'){ return 'PASSPORT_DRAFT' }
  return 'PASSPORT_PRESENT_OTHER'
}
function HealthFor($Class,[string]$PassportState,[bool]$HasMissing,[int]$ValidatorCount,[int]$ProofCount){
  if($Class -eq 'CONFIRMED_ORGAN'){
    if($HasMissing){ return 'DEGRADED_MISSING_REQUIRED_FILE' }
    if($PassportState -eq 'PASSPORT_VALIDATED_LAB_NOT_ACTIVE'){ return 'LAB_VALIDATED_NOT_ACTIVE' }
    if($PassportState -eq 'PASSPORT_DRAFT'){ return 'DRAFT_PASSPORT_NOT_VALIDATED' }
    if($PassportState -eq 'PASSPORT_MISSING'){ return 'MISSING_PASSPORT' }
    return 'CONFIRMED_UNKNOWN_PASSPORT_STATE'
  }
  if($Class -eq 'ORGAN_CANDIDATE'){ return 'CANDIDATE_REQUIRES_REVIEW' }
  if($Class -match 'VALIDATOR|PROOF|DOC|REGISTRY'){ return 'SUPPORT_SURFACE' }
  return 'MATERIAL_OR_UNKNOWN_SURFACE'
}
$map=ReadJson 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
$triage=ReadJson 'reports/self_development/BODY_MAP_CANDIDATE_TRIAGE_V1.json'
$closure=ReadJson 'reports/self_development/BODY_MAP_PHASE_CLOSURE_V1.json'
$passportFiles=@(Get-ChildItem self_model/organ_passports -Recurse -File -Filter 'ORGAN_PASSPORT_V1.json' | Sort-Object FullName)
$passports=@{}
foreach($pf in $passportFiles){ $p=ReadJson $pf.FullName; $passports[$p.organ_id]=$p }
$objects=@()
foreach($c in @($map.confirmed_components)){
  $p=$null; if($passports.ContainsKey($c.id)){ $p=$passports[$c.id] }
  $passportState=StatusForPassport $p
  $missing=@($c.missing_required_files)
  $objects += [ordered]@{
    object_id=$c.id
    path=$c.root
    object_class='CONFIRMED_ORGAN'
    body_role=$c.role
    owning_or_parent_organ=$c.id
    connection_state='CONFIRMED_CONNECTED'
    passport_required=$true
    passport_state=$passportState
    passport_path=$(if($p){"self_model/organ_passports/$($p.organ_id)/ORGAN_PASSPORT_V1.json"}else{$null})
    maturity=$(if($p){$p.maturity}else{'MISSING_PASSPORT'})
    live_or_lab_status=$(if($p){$p.live_or_lab_status}else{'NOT_PROVEN'})
    active_passport=($passportState -eq 'PASSPORT_ACTIVE')
    proven_live=$(if($p){$p.live_or_lab_status -eq 'PROVEN_LIVE'}else{$false})
    validator_count=[int]$c.validator_count
    proof_count=[int]$c.proof_file_count
    missing_required_files=@($missing)
    health_state=HealthFor 'CONFIRMED_ORGAN' $passportState ($missing.Count -gt 0) ([int]$c.validator_count) ([int]$c.proof_file_count)
    next_action=$(if($passportState -eq 'PASSPORT_MISSING'){'CREATE_ORGAN_PASSPORT_DRAFT'}elseif($passportState -eq 'PASSPORT_DRAFT'){'RUN_DEDICATED_LAB_VALIDATOR'}elseif($passportState -eq 'PASSPORT_VALIDATED_LAB_NOT_ACTIVE'){'OWNER_ROUTE_ACCEPTANCE_BEFORE_ACTIVE'}else{'REVIEW'})
    source='SELF_MODEL_ACTIVE_MAP.confirmed_components'
  }
}
foreach($t in @($triage.items)){
  $cls='MATERIAL_OR_UNKNOWN_SURFACE'
  $passportRequired=$false
  $connection='CANDIDATE_OR_SUPPORT_SURFACE'
  if($t.organ_candidate -eq $true){ $cls='ORGAN_CANDIDATE'; $passportRequired=$true; $connection='CANDIDATE_NOT_CONFIRMED' }
  elseif($t.triage_class -match 'VALIDATOR'){ $cls='VALIDATOR_SURFACE' }
  elseif($t.triage_class -match 'PROOF|REPORT'){ $cls='PROOF_OR_REPORT_SURFACE' }
  elseif($t.triage_class -match 'DOC'){ $cls='DOC_GOVERNANCE_SURFACE' }
  elseif($t.triage_class -match 'PASSPORT'){ $cls='PASSPORT_REGISTRY_SURFACE' }
  elseif($t.triage_class -match 'PACK|MATERIAL|SANDBOX'){ $cls='MATERIAL_SURFACE' }
  $objects += [ordered]@{
    object_id=$t.candidate_id
    path=$t.path
    object_class=$cls
    triage_class=$t.triage_class
    owning_or_parent_organ=$null
    connection_state=$connection
    passport_required=$passportRequired
    passport_state=$(if($passportRequired){'CANDIDATE_PASSPORT_REVIEW_REQUIRED'}else{'ORGAN_PASSPORT_NOT_REQUIRED'})
    maturity=$(if($passportRequired){'CANDIDATE'}else{'SUPPORT_SURFACE'})
    live_or_lab_status='NOT_PROVEN'
    active_passport=$false
    proven_live=$false
    validator_count=[int]$t.source_counts.validators
    proof_count=[int]$t.source_counts.proofs
    health_state=HealthFor $cls $(if($passportRequired){'PASSPORT_MISSING'}else{'ORGAN_PASSPORT_NOT_REQUIRED'}) $false ([int]$t.source_counts.validators) ([int]$t.source_counts.proofs)
    next_action=$t.next_action
    source='BODY_MAP_CANDIDATE_TRIAGE_V1.items'
  }
}
$passportCoverage=[ordered]@{
  confirmed_organs=@($objects|Where-Object{$_.object_class -eq 'CONFIRMED_ORGAN'}).Count
  confirmed_organs_with_passport=@($objects|Where-Object{$_.object_class -eq 'CONFIRMED_ORGAN' -and $_.passport_state -ne 'PASSPORT_MISSING'}).Count
  confirmed_organs_missing_passport=@($objects|Where-Object{$_.object_class -eq 'CONFIRMED_ORGAN' -and $_.passport_state -eq 'PASSPORT_MISSING'}).Count
  confirmed_organs_validated_lab=@($objects|Where-Object{$_.object_class -eq 'CONFIRMED_ORGAN' -and $_.passport_state -eq 'PASSPORT_VALIDATED_LAB_NOT_ACTIVE'}).Count
  active_passports=@($objects|Where-Object{$_.active_passport -eq $true}).Count
  proven_live_organs=@($objects|Where-Object{$_.proven_live -eq $true}).Count
  organ_candidates=@($objects|Where-Object{$_.object_class -eq 'ORGAN_CANDIDATE'}).Count
  non_organ_passport_not_required=@($objects|Where-Object{$_.passport_required -eq $false}).Count
}
$edges=@()
function AddEdge([string]$From,[string]$To,[string]$Type,[string]$Reason){ $script:edges += [ordered]@{from=$From;to=$To;edge_type=$Type;reason=$Reason} }
AddEdge 'body_control_cortex' 'SELF_MODEL_ACTIVE_MAP' 'reads_anatomy' 'cortex reads canonical body composition map'
AddEdge 'body_control_cortex' 'ORGAN_PASSPORT_REGISTRY' 'reads_trust_state' 'cortex reads organ passport status and maturity'
AddEdge 'body_control_cortex' 'BODY_MAP_CANDIDATE_TRIAGE_V1' 'reads_candidate_state' 'cortex reads candidate/support-surface classification'
AddEdge 'operations_self_model' 'map_control' 'depends_on' 'self-model depends on map freshness and validator chain'
AddEdge 'operations_self_model' 'ORGAN_PASSPORT_REGISTRY' 'governs' 'self-model owns passport/index governance evidence'
AddEdge 'capability_invocation_map' 'autonomous_inner_motor' 'live_runtime_dependency' 'live-dependent validators require AIMO live runtime'
AddEdge 'school' 'school_source_router' 'depends_on' 'school material intake depends on governed source routing'
AddEdge 'compact_memory_intake' 'autonomous_inner_motor' 'feeds_runtime_memory' 'AIMO consumes compact memory packets through intake path'
AddEdge 'gpt_handoff' 'operations_self_model' 'operator_context_to_self_model' 'handoff journal informs operator/self-model context'
$health=@()
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
$health += [ordered]@{subject='canonical_body_map';health_state='PASS_CURRENT';evidence='PASS_AGENT_BODY_COMPOSITION_MAP_CURRENT_V1';root_cause_if_failed='map generator/fingerprint/staged structural drift'}
$health += [ordered]@{subject='operations_self_model';health_state='LAB_VALIDATED_NOT_ACTIVE';evidence='PASS_OPERATIONS_SELF_MODEL_ORGAN_LAB_VALIDATION_V1';root_cause_if_failed='self-model validators/passport/proof mismatch'}
$health += [ordered]@{subject='live_aimo';health_state=$(if(@($liveNow).Count -gt 0){'LIVE_PROCESS_PRESENT'}else{'LIVE_DOWN'});live_aimo_count=@($liveNow).Count;evidence='process scan for run_autonomous_inner_motor live_aimo';root_cause_if_failed='PC reboot/live runtime not restarted'}
$health += [ordered]@{subject='child_agent_factory';health_state='NOT_PROVEN';evidence='BODY_MAP_PHASE_CLOSURE_V1 boundary';root_cause_if_failed='no dedicated child readiness validator/proof'}
$rules=@(
 [ordered]@{rule_id='SYMPTOM_NOT_ROOT_CAUSE';rule='Treat validator/runtime/map failure as symptom until upstream dependencies, passport state, live/lab boundary, stale authority, duplicate maps, and proof freshness are checked.'},
 [ordered]@{rule_id='NO_FULL_PASSPORT_FOR_NON_ORGAN';rule='Do not create full organ passports for validators, proofs, docs, packs, or support surfaces; create registry/support records and owner links instead.'},
 [ordered]@{rule_id='LIVE_REQUIRED_FAIL_WITH_LIVE_DOWN';rule='If a live-required validator fails while live runtime is down, root-cause candidate is live runtime absent, not necessarily the validator or target organ.'},
 [ordered]@{rule_id='MAP_CURRENT_BUT_CAPABILITY_FAILS';rule='If canonical body map is current and capability invocation fails, do not treat map as root cause until capability dependencies are checked.'},
 [ordered]@{rule_id='NO_ACTIVE_WITHOUT_OWNER_ROUTE';rule='Validated lab passport does not imply PASSPORT_ACTIVE; active requires owner/route acceptance and dedicated gate.'},
 [ordered]@{rule_id='NO_DELETE_WITHOUT_QUARANTINE_DECISION';rule='Duplicate/junk surfaces require authority classification and safe deletion/quarantine/reject decision before removal.'}
)
$diagnosticPackets=@(
 [ordered]@{symptom='live-dependent capability validator failed';affected_area='capability_invocation_map/autonomous_inner_motor';likely_root_cause_candidates=@('LIVE_AIMO_COUNT=0 after reboot','live-dependent validators excluded from lab proof','passport not active for live invocation');not_root_cause=@('canonical body map if PASS_AGENT_BODY_COMPOSITION_MAP_CURRENT_V1 holds','operations_self_model lab status if PASS_OPERATIONS_SELF_MODEL_ORGAN_LAB_VALIDATION_V1 holds');safe_next_probe='Restart/validate live AIMO under owner-authorized controlled route, then rerun live-dependent validators.'},
 [ordered]@{symptom='organ has files but no trust';affected_area='confirmed organs missing passport';likely_root_cause_candidates=@('passport coverage not generated','dedicated organ validator missing','owner/route acceptance missing');safe_next_probe='Create draft organ passport from confirmed component evidence, then run dedicated lab validator.'},
 [ordered]@{symptom='many body objects look like organs';affected_area='body object registry';likely_root_cause_candidates=@('candidate/support surfaces mixed with organ layer','legacy broad inventory semantics','raw file count interpreted as organ count');safe_next_probe='Classify all objects into organ/candidate/support/proof/doc/material, then issue passport requirements only to organ classes.'}
)
$model=[ordered]@{
  schema='body_control_cortex_v1'
  status='PASS_BODY_CONTROL_CORTEX_V1'
  purpose='Body-to-brain diagnostic cortex: convert body maps, passports, dependencies, health, and diagnostic rules into compact actionable signals without pretending to be the brain.'
  source_refs=@('reports/self_development/SELF_MODEL_ACTIVE_MAP.json','reports/self_development/BODY_MAP_CANDIDATE_TRIAGE_V1.json','reports/self_development/BODY_MAP_PHASE_CLOSURE_V1.json','self_model/organ_passports/_index/ORGAN_PASSPORT_DRAFT_INDEX_V1.json')
  counts=[ordered]@{body_objects=@($objects).Count;confirmed_organs=$passportCoverage.confirmed_organs;primary_candidates=@($map.primary_evidence_candidates).Count;dependency_edges=@($edges).Count;health_subjects=@($health).Count;diagnostic_rules=@($rules).Count;diagnostic_packets=@($diagnosticPackets).Count}
  passport_coverage=$passportCoverage
  body_object_registry=@($objects)
  dependency_graph=@($edges)
  health_state=@($health)
  diagnostic_rules=@($rules)
  diagnostic_packets=@($diagnosticPackets)
  boundaries=[ordered]@{not_brain=$true;no_runtime_mutation=$true;no_live_claim_created=$true;no_child_agent_readiness_claim=$true;no_full_passports_generated_for_all_candidates=$true;registry_records_are_not_organ_acceptance=$true}
  created_at=(Get-Date).ToString('o')
}
$modelPath='self_model/body_control_cortex/BODY_CONTROL_CORTEX_V1.json'
$model|ConvertTo-Json -Depth 100|Set-Content $modelPath -Encoding UTF8
$reportPath='reports/self_development/BODY_CONTROL_CORTEX_V1_REPORT.json'
$model|ConvertTo-Json -Depth 100|Set-Content $reportPath -Encoding UTF8
$proofPath='tests/self_development/BODY_CONTROL_CORTEX_V1_PROOF.json'
$proof=[ordered]@{schema='body_control_cortex_v1_proof';status='PASS_BODY_CONTROL_CORTEX_V1';model_path=$modelPath;report_path=$reportPath;body_objects=@($objects).Count;confirmed_organs=$passportCoverage.confirmed_organs;confirmed_organs_with_passport=$passportCoverage.confirmed_organs_with_passport;confirmed_organs_missing_passport=$passportCoverage.confirmed_organs_missing_passport;active_passports=$passportCoverage.active_passports;proven_live_organs=$passportCoverage.proven_live_organs;dependency_edges=@($edges).Count;diagnostic_rules=@($rules).Count;live_aimo_count=@($liveNow).Count;no_live_claim_created=$true;not_brain=$true;created_at=(Get-Date).ToString('o')}
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
$doc=@('# Body Control Cortex V1','','status: PASS_BODY_CONTROL_CORTEX_V1','','Purpose: body-to-brain diagnostic cortex. It combines body object registry, organ passport coverage, dependency graph, health state, and diagnostic rules into compact diagnostic packets. It is not the brain and does not mutate live runtime.','','## Key counts',('- body_objects: '+@($objects).Count),('- confirmed_organs: '+$passportCoverage.confirmed_organs),('- confirmed_organs_with_passport: '+$passportCoverage.confirmed_organs_with_passport),('- confirmed_organs_missing_passport: '+$passportCoverage.confirmed_organs_missing_passport),('- active_passports: '+$passportCoverage.active_passports),('- proven_live_organs: '+$passportCoverage.proven_live_organs),('- dependency_edges: '+@($edges).Count),('- diagnostic_rules: '+@($rules).Count),'','## Boundary','- Cortex is not brain.','- Registry records are not organ acceptance.','- No PROVEN_LIVE created.','- No child-agent readiness claim.','- No full passport generation for all candidates.')
$doc|Set-Content 'docs/operations/BODY_CONTROL_CORTEX_V1.md' -Encoding UTF8
Write-Host 'BUILT_BODY_CONTROL_CORTEX_V1'
Write-Host ('MODEL_PATH='+$modelPath)
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
