$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$contractPath='self_model/CAPABILITY_INVOCATION_MAP_V1_CONTRACT.json'
$docPath='docs/operations/CAPABILITY_INVOCATION_MAP_V1_CONTRACT.md'
Assert (Test-Path $contractPath) 'CONTRACT_MISSING'
Assert (Test-Path $docPath) 'DOC_MISSING'
$c=Get-Content $contractPath -Raw|ConvertFrom-Json
Assert ($c.schema -eq 'capability_invocation_map_v1_contract') 'SCHEMA_BAD'
Assert ($c.status -eq 'ACTIVE_CONTRACT') 'STATUS_BAD'
foreach($f in @('capability_id','owning_organ_id','invocation_modes','inputs','outputs','validator_refs','proof_refs','safety_boundary','maturity','live_or_lab_status')){ Assert (@($c.capability_required_fields) -contains $f) ("REQUIRED_CAPABILITY_FIELD_MISSING:{0}" -f $f) }
foreach($f in @('command_or_entrypoint','cwd','preconditions','expected_outputs','stop_condition','rollback_or_cleanup','proof_after_run')){ Assert (@($c.invocation_mode_required_fields) -contains $f) ("REQUIRED_INVOCATION_FIELD_MISSING:{0}" -f $f) }
foreach($m in @('MATERIAL_ONLY','VALIDATED_LAB','VALIDATED_LIVE','BLOCKED')){ Assert (@($c.allowed_maturity) -contains $m) ("MATURITY_MISSING:{0}" -f $m) }
foreach($s in @('NOT_PROVEN','PROVEN_LAB','PROVEN_LIVE','BLOCKED')){ Assert (@($c.allowed_live_or_lab_status) -contains $s) ("STATUS_VALUE_MISSING:{0}" -f $s) }
$rulesText=(@($c.required_safety_rules) -join ' ')
Assert ($rulesText -match 'No capability may be marked PROVEN_LIVE') 'NO_FALSE_LIVE_RULE_MISSING'
Assert ($rulesText -match 'child-agent readiness validator') 'CHILD_AGENT_SAFETY_RULE_MISSING'
Assert ($rulesText -match 'Legacy maps may be source material only') 'LEGACY_AUTHORITY_RULE_MISSING'
Assert ($c.organ_link_contract.required_fields -contains 'owning_organ_id') 'ORGAN_LINK_FIELD_MISSING'
Assert ($c.organ_link_contract.forbidden -match 'Do not merge') 'NO_MERGE_RULE_MISSING'
Assert ($c.legacy_policy.no_silent_deletion -eq $true) 'NO_SILENT_DELETION_BAD'
Assert ($c.coverage_requirements_for_v1.minimum_source_task_count -gt 50) 'SOURCE_TASK_COUNT_TOO_LOW'
Assert (Test-Path $c.source_diagnostic_ref) 'SOURCE_DIAGNOSTIC_REF_MISSING'
$d=Get-Content $c.source_diagnostic_ref -Raw|ConvertFrom-Json
Assert ($d.status -eq 'DIAGNOSTIC_COMPLETE_RECOMMEND_TWO_MAP_ORGANS_WITH_THIN_SELF_MODEL_LINK') 'SOURCE_DIAGNOSTIC_STATUS_BAD'
Assert ($d.design_decision.preferred_architecture -eq 'TWO_MAP_ORGANS_PLUS_THIN_SELF_MODEL_LINK') 'SOURCE_DIAGNOSTIC_ARCH_BAD'
$taskDirty=@(git status --short -- tasks)
Assert ($taskDirty.Count -eq 0) 'TASK_FILES_MODIFIED_FOR_CONTRACT_ONLY'
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_BAD:{0}" -f @($liveNow).Count)
Assert ([string]$liveNow[0].CommandLine -notlike '*UseSourceAgnosticPathSelectionLabGate*') 'LIVE_AIMO_HAS_GATE'
$runtimeSize=(Get-ChildItem .runtime -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum
Assert ([Math]::Round($runtimeSize/1MB,2) -lt 80) 'RUNTIME_SIZE_BAD'
$proof=[ordered]@{
  schema='capability_invocation_map_v1_contract_validation_v1'
  status='PASS_CAPABILITY_INVOCATION_MAP_V1_CONTRACT'
  contract_path=$contractPath
  doc_path=$docPath
  source_diagnostic_ref=[string]$c.source_diagnostic_ref
  source_task_count=[int]$c.task_source_count_at_contract_time
  contract_only=$true
  task_files_modified=$false
  deletion_allowed=$false
  live_pid_now=[int]$liveNow[0].ProcessId
  live_process_touched_by_validator=$false
  active_memory_mutated=$false
  next_step='GENERATE_CAPABILITY_INVOCATION_MAP_V1_DRAFT'
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/self_development/CAPABILITY_INVOCATION_MAP_V1_CONTRACT_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_CAPABILITY_INVOCATION_MAP_V1_CONTRACT'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
