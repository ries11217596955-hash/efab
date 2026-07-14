$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$errors=New-Object System.Collections.Generic.List[string]
function AddErr([string]$m){$errors.Add($m)|Out-Null}
function RequireFile([string]$p){if(-not(Test-Path $p)){AddErr "MISSING:$p"}}
$contract='operations/school/SCHOOL_CANONICAL_RUN_CONTRACT_V1.md'
$entry='operations/school/run_agent_school.ps1'
$cycle='operations/school/run_autonomous_school_cycle_v1.ps1'
$topics='operations/school/curriculum/topics/builder_night_school_topics_v1.json'
$cursor='operations/school/curriculum/candidate_factory/memory/theme_cursor_ledger.json'
foreach($p in @($contract,$entry,$cycle,$topics,$cursor,'operations/school/curriculum/source_router/run_school_source_router_v1.ps1','operations/school/curriculum/source_router/run_school_codex_source_port_v1.ps1','operations/school/curriculum/source_router/run_school_external_world_source_port_v1.ps1','operations/school/finalize_agent_school_run_v1.ps1')){RequireFile $p}
if(Test-Path $contract){
  $c=Get-Content $contract -Raw
  foreach($required in @('-Count <N> -Mode <Test|Live>','ACTIVE_SINGLE_ENTRYPOINT_TWO_FIELD_LAUNCH','Owner-facing launch surface','Internal school launch/helper surfaces are allowed')){
    if(-not $c.Contains($required)){AddErr "CONTRACT_REQUIRED_TEXT_MISSING:$required"}
  }
}
if(Test-Path $entry){
  $e=Get-Content $entry -Raw
  foreach($required in @('[ValidateSet(''Test'',''Live'')]','[int]$Count','builder_night_school_topics_v1.json','finalize_agent_school_run_v1.ps1')){
    if(-not $e.Contains($required)){AddErr "ENTRYPOINT_REQUIRED_TEXT_MISSING:$required"}
  }
}
if(Test-Path $topics){
  $t=Get-Content $topics -Raw|ConvertFrom-Json
  if($t.status -ne 'ACTIVE_AGENT_SELF_KNOWLEDGE_MAXIMAL_CURRICULUM_V1'){AddErr "TOPICS_STATUS_BAD:$($t.status)"}
  if(@($t.topics).Count -lt 80){AddErr "TOPICS_TOO_FEW:$(@($t.topics).Count)"}
  if($t.constraints.levels_continue_by_theme_cursor -ne $true){AddErr 'TOPICS_CURSOR_FLAG_FALSE'}
}
if(Test-Path $cursor){
  $l=Get-Content $cursor -Raw|ConvertFrom-Json
  if($l.status -ne 'PASS_THEME_CURSOR_LEDGER_REBUILD_V1'){AddErr "CURSOR_STATUS_BAD:$($l.status)"}
  if(@($l.cursors).Count -lt 1000){AddErr "CURSOR_THEMES_TOO_FEW:$(@($l.cursors).Count)"}
}
$root=(Get-Location).Path
$launch=@(Get-ChildItem operations/school -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^run_.*\.ps1$|^invoke_.*school.*\.ps1$' } | ForEach-Object { $rel=$_.FullName.Substring($root.Length).TrimStart([char]92,[char]47); $rel.Replace([string][char]92,'/') })
$allowedInternal=@(
 'operations/school/run_autonomous_school_cycle_v1.ps1',
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
$unexpected=@($launch|Where-Object{$_ -ne $entry -and ($allowedInternal -notcontains $_)})
foreach($b in $unexpected){AddErr "UNEXPECTED_SCHOOL_LAUNCH_SURFACE:$b"}
if($errors.Count -gt 0){
  Write-Host 'VALIDATION_STATUS=FAIL_AGENT_SCHOOL_CANONICAL_POLICY_V2'
  $errors|ForEach-Object{Write-Host ('ERROR='+$_)}
  exit 1
}
Write-Host 'VALIDATION_STATUS=PASS_AGENT_SCHOOL_CANONICAL_POLICY_V2'
Write-Host 'OWNER_FACING_ENTRYPOINT_COUNT=1'
Write-Host 'OWNER_ENTRYPOINT=operations/school/run_agent_school.ps1'
Write-Host 'OWNER_FIELDS=Count,Mode'
Write-Host 'MODE_VALUES=Test,Live'
Write-Host "INTERNAL_HELPER_SURFACES_ALLOWED=$($allowedInternal.Count)"
Write-Host 'SCHOOL_LIVE_MODE_IS_MEMORY_DIGEST_MODE_NOT_AGENT_RUNTIME=true'
Write-Host 'RUNTIME_READY=false'

