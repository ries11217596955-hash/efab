$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$modelPath='self_model/body_control_cortex/BODY_CONTROL_CORTEX_V1.json'
$reportPath='reports/self_development/BODY_CONTROL_CORTEX_V1_REPORT.json'
$proofPath='tests/self_development/BODY_CONTROL_CORTEX_V1_PROOF.json'
foreach($path in @($modelPath,$reportPath,$proofPath,'reports/self_development/SELF_MODEL_ACTIVE_MAP.json','reports/self_development/BODY_MAP_PHASE_CLOSURE_V1.json')){Assert (Test-Path $path) ("MISSING:{0}" -f $path)}
$m=Get-Content $modelPath -Raw|ConvertFrom-Json
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
$map=Get-Content reports/self_development/SELF_MODEL_ACTIVE_MAP.json -Raw|ConvertFrom-Json
Assert ($m.status -eq 'PASS_BODY_CONTROL_CORTEX_V1') 'MODEL_STATUS_BAD'
Assert ($r.status -eq 'PASS_BODY_CONTROL_CORTEX_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_BODY_CONTROL_CORTEX_V1') 'PROOF_STATUS_BAD'
Assert ($m.boundaries.not_brain -eq $true) 'BOUNDARY_NOT_BRAIN_FALSE'
Assert ($m.boundaries.no_runtime_mutation -eq $true) 'RUNTIME_MUTATION_BOUNDARY_BAD'
Assert ($m.boundaries.no_live_claim_created -eq $true) 'LIVE_BOUNDARY_BAD'
Assert ($m.boundaries.no_full_passports_generated_for_all_candidates -eq $true) 'FALSE_PASSPORT_BOUNDARY_BAD'
Assert ([int]$m.counts.body_objects -eq (@($map.confirmed_components).Count + @($map.primary_evidence_candidates).Count)) 'BODY_OBJECT_COUNT_MISMATCH'
Assert ([int]$m.counts.confirmed_organs -eq @($map.confirmed_components).Count) 'CONFIRMED_COUNT_MISMATCH'
Assert (@($m.body_object_registry|Where-Object{$_.object_class -eq 'CONFIRMED_ORGAN'}).Count -eq @($map.confirmed_components).Count) 'CONFIRMED_REGISTRY_COUNT_BAD'
Assert (@($m.body_object_registry|Where-Object{$_.object_id -eq 'operations_self_model' -and $_.object_class -eq 'CONFIRMED_ORGAN'}).Count -eq 1) 'OPERATIONS_SELF_MODEL_NOT_CONFIRMED_IN_CORTEX'
Assert (@($m.body_object_registry|Where-Object{$_.object_id -eq 'operations_self_model' -and $_.passport_state -eq 'PASSPORT_VALIDATED_LAB_NOT_ACTIVE'}).Count -eq 1) 'OPERATIONS_SELF_MODEL_PASSPORT_STATE_BAD'
Assert (@($m.diagnostic_rules).Count -ge 5) 'DIAGNOSTIC_RULES_TOO_FEW'
Assert (@($m.dependency_graph).Count -ge 5) 'DEPENDENCY_EDGES_TOO_FEW'
Assert (@($m.diagnostic_packets|Where-Object{$_.symptom -match 'live-dependent'}).Count -ge 1) 'LIVE_DIAGNOSTIC_PACKET_MISSING'
Assert ([int]$m.passport_coverage.active_passports -eq 0) 'ACTIVE_PASSPORTS_UNEXPECTED'
Assert ([int]$m.passport_coverage.proven_live_organs -eq 0) 'PROVEN_LIVE_UNEXPECTED'
Assert ($p.no_live_claim_created -eq $true) 'PROOF_LIVE_BOUNDARY_BAD'
Assert ($p.not_brain -eq $true) 'PROOF_NOT_BRAIN_BAD'
foreach($legacy in @('reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json','self_knowledge/BUILDER_SELF_MODEL.json')){Assert (-not(Test-Path $legacy)) ("LEGACY_MAP_PRESENT:{0}" -f $legacy)}
Write-Host 'VALIDATION_PASS=PASS_BODY_CONTROL_CORTEX_V1'
Write-Host ('MODEL_PATH='+$modelPath)
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
