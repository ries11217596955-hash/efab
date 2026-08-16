[CmdletBinding()]param()
$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim();Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$contractPath='self_model/CAPABILITY_INVOCATION_MAP_V1_CONTRACT.json'
$docPath='docs/operations/CAPABILITY_INVOCATION_MAP_V1_CONTRACT.md'
$retirementProof='tests/self_development/PHASE84_86_OPERATION_RUNTIME_RETIREMENT_AND_DELETE_V1_PROOF.json'
Assert (Test-Path $contractPath) 'CONTRACT_MISSING';Assert (Test-Path $docPath) 'DOC_MISSING';Assert (Test-Path $retirementProof) 'RETIREMENT_PROOF_MISSING'
$before=@(git status --porcelain=v1 -uall);$taskBefore=@(git status --porcelain=v1 -uall -- tasks)
$mr='.runtime/active_compact_semantic_memory_v1';$mh=@{};foreach($n in @('manifest.json','index.json','cells.jsonl')){$p=Join-Path $mr $n;if(Test-Path $p){$mh[$n]=(Get-FileHash -Algorithm SHA256 $p).Hash}}
$c=Get-Content $contractPath -Raw|ConvertFrom-Json
Assert ($c.schema -eq 'capability_invocation_map_v1_contract') 'SCHEMA_BAD'
Assert ($c.status -eq 'ACTIVE_CONTRACT') 'STATUS_BAD'
foreach($f in @('schema','status','generated_from','capabilities','coverage','gaps','legacy_sources','live_process_touched','active_memory_mutated','created_at')){Assert ($c.required_top_level_fields -contains $f) ("TOP_FIELD_MISSING:$f")}
foreach($f in @('capability_id','display_name','owning_organ_id','organ_inventory_ref','what_it_does','invocation_modes','primary_invocation','inputs','outputs','validator_refs','proof_refs','safety_boundary','maturity','live_or_lab_status','source_task_refs','source_script_refs','source_report_refs','gaps','do_not_use_for')){Assert ($c.capability_required_fields -contains $f) ("CAP_FIELD_MISSING:$f")}
Assert ($c.organ_link_contract.forbidden -match 'Do not merge') 'NO_MERGE_RULE_MISSING'
Assert ($c.legacy_policy.no_silent_deletion -eq $true) 'NO_SILENT_DELETION_BAD'
$cov=$c.coverage_requirements_for_v1
Assert ([int]$cov.historical_task_baseline -eq 112) 'HISTORICAL_BASELINE_BAD'
Assert ([int]$cov.expected_retired_task_count -eq 3) 'EXPECTED_RETIRED_COUNT_BAD'
Assert ([int]$cov.expected_accounted_total -eq 112) 'EXPECTED_ACCOUNTED_TOTAL_BAD'
Assert ($cov.retirement_proof_refs -contains $retirementProof) 'RETIREMENT_PROOF_REF_MISSING'
$expectedRetired=@('tasks/TASK_FIRST_SMOKE_INSTALL_TRIAL_V1_001.json','tasks/TASK_FIRST_WRAPPER_OPERATION_CONTRACTS_V1_001.json','tasks/TASK_OPERATION_RUNTIME_SKELETON_V1_001.json')
$declared=@($cov.retired_task_refs|Sort-Object);Assert (@(Compare-Object ($expectedRetired|Sort-Object) $declared).Count -eq 0) 'RETIRED_TASK_SET_BAD'
$r=Get-Content $retirementProof -Raw|ConvertFrom-Json
$deleted=@($r.deleted_tracked_files)
foreach($f in $expectedRetired){Assert ($deleted -contains $f) ("RETIREMENT_PROOF_DOES_NOT_NAME:$f");Assert (-not(Test-Path $f)) ("RETIRED_TASK_REAPPEARED:$f")}
$current=@(Get-ChildItem tasks -File -Filter '*.json')
$currentCount=$current.Count;$retiredCount=$expectedRetired.Count;$accounted=$currentCount+$retiredCount
Assert ($currentCount -eq [int]$cov.expected_current_task_count_after_known_retirements) ("CURRENT_TASK_COUNT_UNEXPECTED:{0}" -f $currentCount)
Assert ($accounted -eq [int]$cov.historical_task_baseline) ("ACCOUNTED_TASK_TOTAL_BAD:{0}" -f $accounted)
Assert (Test-Path $c.source_diagnostic_ref) 'SOURCE_DIAGNOSTIC_REF_MISSING'
$d=Get-Content $c.source_diagnostic_ref -Raw|ConvertFrom-Json
Assert ($d.design_decision.preferred_architecture -eq 'TWO_MAP_ORGANS_PLUS_THIN_SELF_MODEL_LINK') 'SOURCE_DIAGNOSTIC_ARCH_BAD'
$after=@(git status --porcelain=v1 -uall);$taskAfter=@(git status --porcelain=v1 -uall -- tasks)
Assert (($before -join "`n") -eq ($after -join "`n")) 'VALIDATOR_MUTATED_WORKTREE'
Assert (($taskBefore -join "`n") -eq ($taskAfter -join "`n")) 'VALIDATOR_MUTATED_TASKS'
foreach($n in $mh.Keys){Assert ((Get-FileHash -Algorithm SHA256 (Join-Path $mr $n)).Hash -eq $mh[$n]) ("VALIDATOR_MUTATED_MEMORY:$n")}
Write-Output ('PASS_CAPABILITY_INVOCATION_MAP_V1_CONTRACT_V2|CURRENT_TASKS='+$currentCount+'|RETIRED_TASKS='+$retiredCount+'|ACCOUNTED_TOTAL='+$accounted+'|HISTORICAL_BASELINE='+[int]$cov.historical_task_baseline+'|WORKTREE_MUTATION=0|MEMORY_MUTATION=0|RUNTIME_DEPENDENCY=0')
