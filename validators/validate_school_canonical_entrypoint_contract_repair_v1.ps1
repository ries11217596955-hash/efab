$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){
  $dir=Split-Path $path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"
  [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false)))
}
$entry='operations/school/run_agent_school.ps1'
$canonicalValidator='operations/school/validate_agent_school_canonical_entrypoint_v1.ps1'
$proofPath='tests/self_development/SCHOOL_CANONICAL_ENTRYPOINT_CONTRACT_REPAIR_V1_PROOF.json'
if(-not(Test-Path $entry)){ Add-Err "missing_entry:$entry" }
if(-not(Test-Path $canonicalValidator)){ Add-Err "missing_validator:$canonicalValidator" }
$tokens=$null;$parseErrors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $entry),[ref]$tokens,[ref]$parseErrors)
foreach($e in $parseErrors){ Add-Err "entry_parse:$($e.Message)" }
$text=Get-Content $entry -Raw
foreach($needle in @(
  'operations/school/plan_topic_patch_cycle_v1.ps1',
  'operations/school/finalize_agent_school_run_v1.ps1',
  'TopicPatchPlanStatus',
  'topic_patch_plan_status=$TopicPatchPlanStatus',
  'FinalizerOut',
  'FINALIZER_STATUS_MISSING',
  'ready_atoms',
  'chunks=@($ExactCycleReport.batch_counts'
)){
  if($text -notlike "*$needle*"){ Add-Err "entry_missing:$needle" }
}
if($text -match 'SKIPPED_EXACT_COUNT_CYCLE_CANONICAL_ROUTE'){ Add-Err 'skipped_exact_count_finalizer_text_still_present' }
$ownerParams=@()
if($ast.ParamBlock){ $ownerParams=@($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath }) }
foreach($p in @('Count','Mode','Topics')){ if($ownerParams -notcontains $p){ Add-Err "owner_param_missing:$p" } }
foreach($bad in @('PatchSize','RunId','OutputRoot','ProducerMode','Absorb','CodexTimeoutSeconds')){ if($ownerParams -contains $bad){ Add-Err "owner_param_extra:$bad" } }
if($ownerParams.Count -ne 3){ Add-Err ("owner_param_count_or_extra:{0}" -f ($ownerParams -join ',')) }
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $canonicalValidator *>&1 | ForEach-Object{[string]$_})
$validationStatus=(($out|Where-Object{$_ -match '^VALIDATION_STATUS='}|Select-Object -Last 1) -replace '^VALIDATION_STATUS=','')
if($LASTEXITCODE -ne 0){ Add-Err "canonical_validator_exit:$LASTEXITCODE" }
if($validationStatus -ne 'PASS_AGENT_SCHOOL_CANONICAL_POLICY_V2'){ Add-Err "canonical_validator_status:$validationStatus" }
if(@($out|Where-Object{$_ -like 'ERROR=*'}).Count -gt 0){ Add-Err 'canonical_validator_errors_present' }
$allowed=@(
'operations/school/run_agent_school.ps1',
'operations/school/run_autonomous_school_cycle_v1.ps1',
'operations/school/control_autonomous_school_cycle_v1.ps1',
'operations/school/execute_school_patch_v1.ps1',
'operations/school/plan_topic_patch_cycle_v1.ps1',
'operations/school/curriculum/source_router/run_school_source_router_v1.ps1',
'operations/school/curriculum/source_router/run_school_codex_source_port_v1.ps1',
'operations/school/curriculum/source_router/run_school_external_world_source_port_v1.ps1',
'operations/school/curriculum/source_router/template_filter/run_school_source_template_filter_v1.ps1',
'operations/school/curriculum/candidate_factory/generate_codex_curriculum_candidate_factory_run_v1.ps1',
'operations/school/curriculum/streaming_absorption/process_codex_curriculum_streaming_absorption_v1.ps1',
'operations/school/curriculum/ready_lane/absorb_ready_lane_via_active_route_v1.ps1',
'operations/school/curriculum/ready_lane/promote_codex_curriculum_ready_lane_additive_active_v1.ps1',
'operations/school/curriculum/incremental_active_store/apply_ready_lane_incremental_active_delta_v1.ps1',
'operations/school/digestion/invoke_compact_semantic_digestion_organ_v1.ps1',
'operations/school/memory/query_compact_semantic_memory_v1.ps1',
'operations/school/memory/validate_compact_memory_recall_use_probe_v1.ps1',
'operations/school/finalize_agent_school_run_v1.ps1'
)
$root=(Get-Location).Path
$unexpected=@()
Get-ChildItem operations/school -Recurse -File -Filter '*.ps1' | ForEach-Object {
  $rel=$_.FullName.Substring($root.Length).TrimStart([char]92,[char]47).Replace([string][char]92,'/')
  $t=Get-Content $_.FullName -Raw
  $ownerLike=($t -match '\$Count' -and $t -match '\$Mode' -and $t -match '\$Topics')
  $nameLaunchLike=($_.Name -match '^run_.*school.*\.ps1$|^start_.*school.*\.ps1$')
  if(($ownerLike -or $nameLaunchLike) -and ($allowed -notcontains $rel)){ $unexpected += $rel }
}
if($unexpected.Count -gt 0){ Add-Err "unexpected_school_launch_surfaces:$($unexpected -join ',')" }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process|validate_school_canonical_entrypoint_contract_repair_v1.ps1|validate_agent_school_canonical_entrypoint_v1.ps1' -and $_.CommandLine -match '\s-File\s+.*(start_agent_life_v1.ps1|run_autonomous_inner_motor.ps1|run_continuous_agent_runtime_v1_lab.ps1|school|invoke_body_self_inspection_circuit_v1.ps1|run_.*school.*\.ps1|start_.*school.*\.ps1)|codex exec|node_modules.*@openai/codex|node.*codex.js|continuous_agent_runtime_v1|live_observation|validate_' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_SCHOOL_CANONICAL_ENTRYPOINT_CONTRACT_REPAIR_V1'}else{'FAIL_SCHOOL_CANONICAL_ENTRYPOINT_CONTRACT_REPAIR_V1'}
$proof=[ordered]@{
  schema='school_canonical_entrypoint_contract_repair_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  owner_entrypoint=$entry
  owner_fields=@($ownerParams)
  canonical_validator_status=$validationStatus
  canonical_validator_output=@($out)
  plan_hook='operations/school/plan_topic_patch_cycle_v1.ps1'
  finalizer_hook='operations/school/finalize_agent_school_run_v1.ps1'
  skipped_finalizer_text_present=($text -match 'SKIPPED_EXACT_COUNT_CYCLE_CANONICAL_ROUTE')
  unexpected_owner_facing_duplicate_count=$unexpected.Count
  unexpected_owner_facing_duplicates=@($unexpected)
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{static_contract_validation=$true; school_launched=$false; codex_launched=$false; web_launched=$false; active_memory_mutated=$false; files_deleted=$false}
}
WJson $proofPath $proof
Write-Host "STATUS=$status"
Write-Host "PROOF=$proofPath"
if($errors.Count -gt 0){ foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
