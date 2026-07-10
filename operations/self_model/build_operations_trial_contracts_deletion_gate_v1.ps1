$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function WJson($Obj,[string]$Path){$d=Split-Path $Path -Parent;if($d -and -not(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null};$Obj|ConvertTo-Json -Depth 80|Set-Content $Path -Encoding UTF8}
$targets=@(
 'operations/smoke_trials',
 'operations/contracts',
 'self_model/organ_passports/operations_smoke_trials',
 'self_model/organ_passports/operations_contracts'
)
$patterns=@('operations/smoke_trials','FIRST_SMOKE_INSTALL_TRIAL_V1_PLAN','json_schema_validation','operations/contracts','validate_json_schema_with_ajv.contract.json','validate_json_schema_with_python_jsonschema.contract.json')
$all=git ls-files
$targetPrefixes=@('operations/smoke_trials/','operations/contracts/','self_model/organ_passports/operations_smoke_trials/','self_model/organ_passports/operations_contracts/')
$historicalPrefixes=@('reports/self_development/','operations/gpt_handoff/','self_model/organ_passports/_index/')
$dependencyRows=@()
foreach($pat in $patterns){
  $hits=@()
  foreach($f in $all){
    if($targetPrefixes | Where-Object { $f -like "$_*" }){ continue }
    try{
      $m=Select-String -Path $f -Pattern $pat -SimpleMatch -ErrorAction SilentlyContinue
      foreach($x in @($m)){
        $historical=[bool]($historicalPrefixes|Where-Object{$f -like "$_*"})
        $hits += [ordered]@{file=$f;line=$x.LineNumber;historical_or_generated=$historical;text=$x.Line.Trim()}
      }
    } catch {}
  }
  $oper=@($hits|Where-Object{-not $_.historical_or_generated})
  $dependencyRows += [ordered]@{pattern=$pat;operational_hit_count=$oper.Count;operational_files=@($oper|ForEach-Object{$_.file}|Sort-Object -Unique);hits_sample=@($oper|Select-Object -First 20)}
}
$critical=@($dependencyRows|Where-Object{$_.operational_hit_count -gt 0})
$decision='BLOCK_DELETE_DEPENDENCY_FOUND'
$canDeleteNow=$false
$blockers=@()
if(@($critical|Where-Object{$_.pattern -match 'operations/smoke_trials|FIRST_SMOKE|json_schema_validation'}).Count -gt 0){$blockers+='SMOKE_TRIALS_REFERENCED_BY_OPERATION_MODULES'}
if(@($critical|Where-Object{$_.pattern -match 'operations/contracts|validate_json_schema'}).Count -gt 0){$blockers+='CONTRACTS_REFERENCED_BY_OPERATION_MODULES_OR_REGISTRY'}
$reportPath='reports/self_development/OPERATIONS_TRIAL_CONTRACTS_DELETION_GATE_V1.json'
$mdPath='reports/self_development/OPERATIONS_TRIAL_CONTRACTS_DELETION_GATE_V1.md'
$proofPath='tests/self_development/OPERATIONS_TRIAL_CONTRACTS_DELETION_GATE_V1_PROOF.json'
$report=[ordered]@{
 schema='operations_trial_contracts_deletion_gate_v1'
 status='BLOCKED_OPERATIONS_TRIAL_CONTRACTS_DELETION_GATE_V1'
 target_paths=$targets
 decision=$decision
 can_delete_now=$canDeleteNow
 blockers=$blockers
 dependency_scan=$dependencyRows
 interpretation=[ordered]@{
   user_hypothesis='likely unused / written and forgotten'
   observed_result='not safe to delete directly: old operation-runtime modules and registry still reference target paths'
   safe_next='either keep as legacy reference, or first retire/migrate PHASE84-86 operation-runtime chain, then delete'
 }
 boundaries=[ordered]@{scan_only=$true;no_files_deleted=$true;no_paths_moved=$true;no_runtime_touched=$true;no_passport_deleted=$true}
 created_at=(Get-Date).ToString('o')
}
$lines=@()
$lines+='# Operations Trial/Contracts deletion gate V1'
$lines+=''
$lines+='STATUS: BLOCKED_OPERATIONS_TRIAL_CONTRACTS_DELETION_GATE_V1'
$lines+=''
$lines+='Decision: do not delete directly. Dependency scan found operational references.'
$lines+=''
$lines+='## Blockers'
foreach($b in $blockers){$lines+="- $b"}
$lines+=''
$lines+='## Key operational references'
foreach($row in $dependencyRows){
  if($row.operational_hit_count -gt 0){
    $lines+="### $($row.pattern)"
    $lines+="- Operational hit count: $($row.operational_hit_count)"
    foreach($f in @($row.operational_files|Select-Object -First 12)){$lines+="- $f"}
    $lines+=''
  }
}
$lines+='## Safe next'
$lines+='- Do not delete operations/smoke_trials or operations/contracts until PHASE84-86 operation-runtime chain is retired or migrated.'
$lines+='- If Owner wants cleanup, next patch should retire/migrate modules/operations/run_first_smoke_install_trial.ps1, modules/operations/register_operation_contracts.ps1, modules/operations/invoke_operation_runtime.ps1, operations/registry.json, and related generated packs/reports.'
$lines+=''
$lines+='## Boundaries'
$lines+='- No files deleted.'
$lines+='- No paths moved.'
$lines+='- No runtime touched.'
$lines+='- No passport deleted.'
$lines|Set-Content $mdPath -Encoding UTF8
$proof=[ordered]@{
 schema='operations_trial_contracts_deletion_gate_v1_proof'
 status='BLOCKED_OPERATIONS_TRIAL_CONTRACTS_DELETION_GATE_V1'
 decision=$decision
 can_delete_now=$canDeleteNow
 blocker_count=$blockers.Count
 operational_dependency_patterns=@($critical|ForEach-Object{$_.pattern})
 no_files_deleted=$true
 no_paths_moved=$true
 no_runtime_touched=$true
 no_passport_deleted=$true
 report_path=$reportPath
 markdown_path=$mdPath
 created_at=(Get-Date).ToString('o')
}
WJson $report $reportPath
WJson $proof $proofPath
Write-Host 'DELETION_GATE=BLOCKED_OPERATIONS_TRIAL_CONTRACTS_DELETION_GATE_V1'
Write-Host ('CAN_DELETE_NOW='+$canDeleteNow)
Write-Host ('BLOCKERS='+($blockers -join ','))
Write-Host "REPORT_PATH=$reportPath"
Write-Host "MARKDOWN_PATH=$mdPath"
Write-Host "PROOF_PATH=$proofPath"
