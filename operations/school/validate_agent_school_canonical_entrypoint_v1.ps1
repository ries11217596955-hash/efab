$ErrorActionPreference='Stop'
$runner='operations/school/run_agent_school.ps1'
$contract='operations/school/SCHOOL_CANONICAL_RUN_CONTRACT_V1.md'
$defaultTopics='operations/school/curriculum/topics/builder_night_school_topics_v1.json'
$errors=New-Object System.Collections.Generic.List[string]
function AddErr($m){$errors.Add($m)|Out-Null}
if(-not (Test-Path $runner)){AddErr "CANONICAL_RUNNER_MISSING:$runner"}
if(-not (Test-Path $contract)){AddErr "CANONICAL_CONTRACT_MISSING:$contract"}
if(-not (Test-Path $defaultTopics)){AddErr "DEFAULT_TOPICS_PLAN_MISSING:$defaultTopics"}
if(Test-Path $runner){
  $r=Get-Content $runner -Raw
  $header=(($r -split "`r?`n") | Select-Object -First 5) -join "`n"
  if(-not $header.Contains('[int]$Count')){AddErr 'OWNER_PARAM_COUNT_MISSING'}
  if(-not $header.Contains('[string]$Mode')){AddErr 'OWNER_PARAM_MODE_MISSING'}
  if(-not $header.Contains('[string]$TopicsPlan')){AddErr 'OWNER_PARAM_TOPICSPLAN_MISSING'}
  if(-not $header.Contains("ValidateSet('Test','Live')")){AddErr 'OWNER_MODE_VALIDATESET_TEST_LIVE_MISSING'}
  foreach($forbidden in @('TargetAccepted','RunKind','ResumeOrdinalOffset','ResumeCompletedChunks','ResumePlannedTotalAccepted')){
    if($header.Contains($forbidden)){AddErr "OWNER_FORBIDDEN_PARAM:$forbidden"}
  }
  foreach($required in @('generate_codex_curriculum_candidate_factory_run_v1.ps1','-TopicsPlan $TopicsPlan','validate_codex_curriculum_streaming_absorption_v1.ps1','absorb_atom_file_via_digest_pipeline_v1.ps1','validate_compact_memory_recall_use_probe_v1.ps1')){
    if(-not $r.Contains($required)){AddErr "RUNNER_REQUIRED_TEXT_MISSING:$required"}
  }
}
if(Test-Path $contract){
  $c=Get-Content $contract -Raw
  foreach($required in @('-Count <N> -Mode <Test|Live> -TopicsPlan <path-to-json>','ACTIVE_SINGLE_ENTRYPOINT_THREE_FIELD_LAUNCH','No owner-facing resume fields are allowed')){
    if(-not $c.Contains($required)){AddErr "CONTRACT_REQUIRED_TEXT_MISSING:$required"}
  }
}
$root=(Get-Location).Path
$launch=@(Get-ChildItem operations/school -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^run_.*\.ps1$|^invoke_.*school.*\.ps1$' } | ForEach-Object { $rel=$_.FullName.Substring($root.Length).TrimStart([char]92,[char]47); $rel.Replace([string][char]92,'/') })
$badLaunch=@($launch|Where-Object{$_ -ne 'operations/school/run_agent_school.ps1'})
foreach($b in $badLaunch){AddErr "UNEXPECTED_SCHOOL_LAUNCH_SURFACE:$b"}
if($errors.Count -gt 0){
  Write-Host 'VALIDATION_STATUS=FAIL_AGENT_SCHOOL_THREE_FIELD_ENTRYPOINT_V1'
  $errors|ForEach-Object{Write-Host ('ERROR='+$_)}
  exit 1
}
Write-Host 'VALIDATION_STATUS=PASS_AGENT_SCHOOL_THREE_FIELD_ENTRYPOINT_V1'
Write-Host 'OWNER_FACING_ENTRYPOINT_COUNT=1'
Write-Host 'OWNER_FIELDS=Count,Mode,TopicsPlan'
Write-Host 'MODE_VALUES=Test,Live'
Write-Host 'RUNTIME_READY=false'
