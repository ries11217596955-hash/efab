$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$export='operations/self_model/export_current_body_capability_snapshot_v1.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $export | Out-Host
$path='reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json'
Assert (Test-Path $path) 'SNAPSHOT_MISSING'
$j=Get-Content $path -Raw|ConvertFrom-Json
Assert ($j.schema -eq 'current_body_capability_snapshot_v1') 'SCHEMA_BAD'
Assert ($j.distinction_rule -like '*built_vs_wired*') 'DISTINCTION_RULE_MISSING'
$components=@($j.components)
foreach($name in @('autonomous_inner_motor','compact_memory_intake','episodic_memory','reasoning_episode','school','builder_identity_contract','source_agnostic_path_selector','builder_mission_scoring','provenance_rejection_trace','child_agent_factory')){ Assert (@($components|Where-Object{$_.name -eq $name}).Count -eq 1) "COMPONENT_MISSING:$name" }
$aimo=$components|Where-Object{$_.name -eq 'autonomous_inner_motor'}|Select-Object -First 1
Assert ($aimo.built -eq $true) 'AIMO_NOT_BUILT'
Assert ($aimo.live_proven -eq $true) 'AIMO_NOT_LIVE_PROVEN'
$school=$components|Where-Object{$_.name -eq 'school'}|Select-Object -First 1
Assert ($school.kind -eq 'optional_source') 'SCHOOL_NOT_OPTIONAL_SOURCE'
Assert ($school.selection_authority -eq 'optional_material_source_not_required_brain') 'SCHOOL_AUTHORITY_BAD'
$selector=$components|Where-Object{$_.name -eq 'source_agnostic_path_selector'}|Select-Object -First 1
Assert ($selector.built -eq $false -and $selector.live_proven -eq $false) 'SOURCE_AGNOSTIC_SELECTOR_FALSE_POSITIVE'
$identity=$components|Where-Object{$_.name -eq 'builder_identity_contract'}|Select-Object -First 1
Assert ($identity.built -eq $true) 'IDENTITY_CONTRACT_NOT_IN_SNAPSHOT'
Assert ($j.live_process_touched -eq $false -and $j.active_memory_mutated -eq $false) 'SNAPSHOT_MUTATION_FLAGS_BAD'
$proof=[ordered]@{schema='current_body_capability_snapshot_validation_v1';status='PASS_CURRENT_BODY_CAPABILITY_SNAPSHOT_V1';snapshot_path=$path;live_process_touched=$false;active_memory_mutated=$false;tests=@([ordered]@{name='distinguishes_built_wired_lab_live';status='PASS'},[ordered]@{name='known_components_present';status='PASS'},[ordered]@{name='school_optional_not_brain';status='PASS'},[ordered]@{name='source_agnostic_selector_not_false_claimed';status='PASS'});created_at=(Get-Date).ToString('o')}
$proofPath='tests/self_model/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 50|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_CURRENT_BODY_CAPABILITY_SNAPSHOT_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'
