$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$targets=@('reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json','self_knowledge/BUILDER_SELF_MODEL.json')
foreach($p in $targets){Assert (-not(Test-Path $p)) ("LEGACY_MAP_STILL_EXISTS:{0}" -f $p)}
$proofPath='tests/self_development/LEGACY_DUPLICATE_MAP_REMOVAL_V1_PROOF.json'
$reportPath='reports/self_development/LEGACY_DUPLICATE_MAP_REMOVAL_V1.json'
foreach($p in @($proofPath,$reportPath,'reports/self_development/SELF_MODEL_ACTIVE_MAP.json')){Assert (Test-Path $p) ("MISSING:{0}" -f $p)}
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$m=Get-Content reports/self_development/SELF_MODEL_ACTIVE_MAP.json -Raw|ConvertFrom-Json
Assert ($p.status -eq 'PASS_LEGACY_DUPLICATE_MAP_REMOVAL_V1') 'PROOF_STATUS_BAD'
Assert ($r.status -eq 'PASS_LEGACY_DUPLICATE_MAP_REMOVAL_V1') 'REPORT_STATUS_BAD'
Assert (@($p.deleted_maps).Count -eq 2) 'DELETED_MAP_COUNT_BAD'
Assert (@($m.confirmed_components).Count -ge 7) 'CONFIRMED_COMPONENTS_TOO_LOW'
Assert (@($m.primary_evidence_candidates).Count -gt 0) 'PRIMARY_CANDIDATES_MISSING'
Assert ($m.component_authority_summary.legacy_maps_raw_authority -eq $false) 'LEGACY_RAW_AUTHORITY_BAD'
Assert ($m.component_authority_summary.old_maps_read_as_authority -eq $false) 'OLD_MAPS_READ_AUTHORITY_BAD'
Assert ($m.component_authority_summary.passport_generator_blocked_until_candidate_triage -eq $true) 'PASSPORT_BLOCK_BAD'
Assert ($m.component_authority_summary.child_agent_factory_readiness -eq 'NOT_PROVEN') 'CHILD_READINESS_BAD'
Write-Host 'VALIDATION_PASS=PASS_LEGACY_DUPLICATE_MAP_REMOVAL_V1'
Write-Host ('PROOF_PATH='+$proofPath)
