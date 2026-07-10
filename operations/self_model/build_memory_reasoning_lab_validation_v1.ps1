$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function WJson($Obj,[string]$Path){$d=Split-Path $Path -Parent;if($d -and -not(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null};$Obj|ConvertTo-Json -Depth 80|Set-Content $Path -Encoding UTF8}
function RunValidator([string]$path){
  Assert (Test-Path $path) "VALIDATOR_MISSING:$path"
  $out=& powershell -ExecutionPolicy Bypass -File $path 2>&1
  $exit=$LASTEXITCODE
  if($exit -ne 0){ throw "VALIDATOR_FAILED:$path`n$($out|Out-String)" }
  $statusLine=@($out|Where-Object{$_ -match 'VALIDATION_PASS=' -or $_ -match '^STATUS=PASS'}|Select-Object -First 1)
  $proofLine=@($out|Where-Object{$_ -match 'PROOF_PATH='}|Select-Object -First 1)
  $status='PASS_WITHOUT_STANDARD_STATUS_LINE'
  if($statusLine){$status=($statusLine -replace '^.*VALIDATION_PASS=','' -replace '^STATUS=','')}
  $proof=''
  if($proofLine){$proof=($proofLine -replace '^.*PROOF_PATH=','')}
  return [pscustomobject]@{validator=$path;exit_code=$exit;status=$status;proof_path=$proof;output=@($out)}
}
$targets=@(
 [ordered]@{organ_id='operations_memory'; passport='self_model/organ_passports/operations_memory/ORGAN_PASSPORT_V1.json'; validators=@('operations/memory/episodic/validate_episode_cell_v1.ps1','operations/memory/episodic/validate_episode_recall_v1.ps1')},
 [ordered]@{organ_id='operations_reasoning'; passport='self_model/organ_passports/operations_reasoning/ORGAN_PASSPORT_V1.json'; validators=@('operations/reasoning/validate_episodic_decision_task_fork_v1.ps1','operations/reasoning/validate_episodic_recall_decision_v1.ps1','operations/reasoning/validate_reasoning_episode_v1.ps1')}
)
$results=@()
foreach($t in $targets){
  Assert (Test-Path $t.passport) "PASSPORT_MISSING:$($t.passport)"
  $runs=@()
  foreach($v in @($t.validators)){ $runs += RunValidator $v }
  $proofs=@($runs|ForEach-Object{$_.proof_path}|Where-Object{$_}|Sort-Object -Unique)
  Assert ($runs.Count -eq @($t.validators).Count) "RUN_COUNT_BAD:$($t.organ_id)"
  Assert ($runs.Count -ge 2) "MIN_TWO_VALIDATORS_REQUIRED:$($t.organ_id)"
  Assert ($proofs.Count -ge 2) "MIN_TWO_PROOFS_REQUIRED:$($t.organ_id)"
  $p=Get-Content $t.passport -Raw|ConvertFrom-Json
  Assert ($p.organ_id -eq $t.organ_id) "PASSPORT_ID_MISMATCH:$($t.organ_id)"
  $p.maturity='VALIDATED_LAB'
  $p.live_or_lab_status='PROVEN_LAB'
  $p.last_validated_at=(Get-Date).ToString('o')
  $p.proof_refs=@(($p.proof_refs + $proofs + 'tests/self_development/MEMORY_REASONING_LAB_VALIDATION_V1_PROOF.json' + 'reports/self_development/MEMORY_REASONING_LAB_VALIDATION_V1.json')|Where-Object{$_}|Sort-Object -Unique)
  $p.gaps=@('PASSPORT_ACTIVE forbidden until activation validator and owner acceptance','PROVEN_LIVE forbidden; this is lab validation only')
  if(@($p.safety_boundaries) -notcontains 'lab validated does not equal active organ'){$p.safety_boundaries=@($p.safety_boundaries)+'lab validated does not equal active organ'}
  $p|ConvertTo-Json -Depth 60|Set-Content $t.passport -Encoding UTF8
  $results += [pscustomobject]@{organ_id=$t.organ_id;passport_path=$t.passport;validators_passed=$runs.Count;proof_refs=$proofs;maturity='VALIDATED_LAB';live_or_lab_status='PROVEN_LAB';runs=$runs}
}
$reportPath='reports/self_development/MEMORY_REASONING_LAB_VALIDATION_V1.json'
$proofPath='tests/self_development/MEMORY_REASONING_LAB_VALIDATION_V1_PROOF.json'
$report=[ordered]@{schema='memory_reasoning_lab_validation_v1';status='PASS_MEMORY_REASONING_LAB_VALIDATION_V1';validated_organs=@($results.organ_id);results=$results;boundaries=[ordered]@{lab_validation_only=$true;no_active_passports_created=$true;no_proven_live_claim=$true;live_process_touched=$false};created_at=(Get-Date).ToString('o')}
$proof=[ordered]@{schema='memory_reasoning_lab_validation_v1_proof';status='PASS_MEMORY_REASONING_LAB_VALIDATION_V1';validated_organs=@($results.organ_id);validated_count=$results.Count;memory_validators_passed=(@($results|Where-Object{$_.organ_id -eq 'operations_memory'}).validators_passed);reasoning_validators_passed=(@($results|Where-Object{$_.organ_id -eq 'operations_reasoning'}).validators_passed);maturity='VALIDATED_LAB';live_or_lab_status='PROVEN_LAB';no_active_passports_created=$true;no_proven_live_claim=$true;live_process_touched=$false;report_path=$reportPath;created_at=(Get-Date).ToString('o')}
WJson $report $reportPath
WJson $proof $proofPath
Write-Host 'LAB_VALIDATION_PASS=PASS_MEMORY_REASONING_LAB_VALIDATION_V1'
Write-Host ('VALIDATED_ORGANS='+(@($results.organ_id)-join ','))
Write-Host 'MATURITY=VALIDATED_LAB'
Write-Host 'LIVE_OR_LAB_STATUS=PROVEN_LAB'
Write-Host 'NO_ACTIVE=true'
Write-Host 'NO_PROVEN_LIVE=true'
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
