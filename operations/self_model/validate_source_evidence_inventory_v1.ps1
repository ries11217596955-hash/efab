$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$export='operations/self_model/export_source_evidence_inventory_v1.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $export | Out-Host
$path='reports/self_development/SOURCE_EVIDENCE_INVENTORY_V1.json'
Assert (Test-Path $path) 'INVENTORY_MISSING'
$j=Get-Content $path -Raw|ConvertFrom-Json
Assert ($j.schema -eq 'source_evidence_inventory_v1') 'SCHEMA_BAD'
Assert ($j.source_authority_rule -like 'sources_can_suggest_not_command*') 'AUTHORITY_RULE_BAD'
Assert ($j.school_dependency_rule -eq 'school_optional_and_non_blocking') 'SCHOOL_RULE_BAD'
Assert ($j.latest_signal_rule -eq 'latest_signal_is_freshness_modifier_not_authority') 'LATEST_RULE_BAD'
$sources=@($j.sources)
foreach($id in @('builder_identity_contract','current_body_capability_snapshot','builder_gap_map','owner_route_lock_v4','validator_proof_set','aimo_live_baseline','school_optional_source','episodic_memory_proofs','reasoning_episode_proofs','latest_runtime_packets')){ Assert (@($sources|Where-Object{$_.id -eq $id}).Count -eq 1) "SOURCE_MISSING:$id" }
foreach($s in $sources){ Assert ($s.can_command -eq $false) "SOURCE_CAN_COMMAND_SHOULD_BE_FALSE:$($s.id)" }
$school=$sources|Where-Object{$_.id -eq 'school_optional_source'}|Select-Object -First 1
Assert ($school.required_for_selection -eq $false) 'SCHOOL_REQUIRED_BAD'
Assert ($school.authority -eq 'optional_evidence_only') 'SCHOOL_AUTHORITY_BAD'
$runtime=$sources|Where-Object{$_.id -eq 'latest_runtime_packets'}|Select-Object -First 1
Assert ($runtime.authority -eq 'freshness_modifier_only') 'RUNTIME_AUTHORITY_BAD'
foreach($req in @('builder_identity_contract','current_body_capability_snapshot','builder_gap_map')){ Assert (@($j.required_sources_for_selection) -contains $req) "REQUIRED_SELECTION_SOURCE_MISSING:$req" }
Assert ($j.live_process_touched -eq $false -and $j.active_memory_mutated -eq $false) 'MUTATION_FLAGS_BAD'
$missingPath='reports/self_development/SOURCE_EVIDENCE_INVENTORY_V1_SCHOOL_MISSING_TEST.json'
& powershell -NoProfile -ExecutionPolicy Bypass -File $export -OutputPath $missingPath -SimulateSchoolMissing -SimulateRuntimeSourcesMissing | Out-Host
$m=Get-Content $missingPath -Raw|ConvertFrom-Json
$mschool=@($m.sources|Where-Object{$_.id -eq 'school_optional_source'}|Select-Object -First 1)[0]
Assert ($mschool.health -eq 'MISSING') 'SIMULATED_SCHOOL_MISSING_HEALTH_BAD'
Assert ($mschool.required_for_selection -eq $false) 'SIMULATED_SCHOOL_REQUIRED_BAD'
Assert (@($m.required_sources_for_selection) -notcontains 'school_optional_source') 'SCHOOL_IN_REQUIRED_LIST_BAD'
Assert (($m.sources|Where-Object{$_.id -eq 'latest_runtime_packets'}).health -eq 'MISSING') 'SIMULATED_RUNTIME_MISSING_BAD'
$proof=[ordered]@{schema='source_evidence_inventory_validation_v1';status='PASS_SOURCE_EVIDENCE_INVENTORY_V1';inventory_path=$path;school_missing_test_path=$missingPath;live_process_touched=$false;active_memory_mutated=$false;tests=@([ordered]@{name='sources_are_evidence_not_authority';status='PASS'},[ordered]@{name='required_internal_sources_present';status='PASS'},[ordered]@{name='school_optional_non_blocking';status='PASS'},[ordered]@{name='latest_runtime_packets_freshness_modifier_only';status='PASS'},[ordered]@{name='school_and_runtime_missing_simulation_non_blocking';status='PASS'});created_at=(Get-Date).ToString('o')}
$proofPath='tests/self_model/SOURCE_EVIDENCE_INVENTORY_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_SOURCE_EVIDENCE_INVENTORY_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'
