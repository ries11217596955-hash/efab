$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function WJson($Obj,[string]$Path){$d=Split-Path $Path -Parent;if($d -and -not(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null};$Obj|ConvertTo-Json -Depth 80|Set-Content $Path -Encoding UTF8}
function ExtractRefs($vals){
  $refs=@()
  foreach($v in @($vals)){
    $s=[string]$v
    if([string]::IsNullOrWhiteSpace($s)){continue}
    $matches=[regex]::Matches($s,'[A-Za-z0-9_./-]+?\.ps1|[A-Za-z0-9_./-]+?\.contract\.json|[A-Za-z0-9_./-]+?\.json')
    if($matches.Count -gt 0){ foreach($m in $matches){ $refs += $m.Value } } else { $refs += $s }
  }
  return @($refs|Sort-Object -Unique)
}
function RunValidator([string]$path){
  $out=& powershell -ExecutionPolicy Bypass -File $path 2>&1
  $exit=$LASTEXITCODE
  $statusLine=@($out|Where-Object{$_ -match 'VALIDATION_PASS=' -or $_ -match '^STATUS=PASS'}|Select-Object -First 1)
  $proofLine=@($out|Where-Object{$_ -match 'PROOF_PATH='}|Select-Object -First 1)
  $status='UNKNOWN_PASS_OUTPUT'
  if($statusLine){$status=($statusLine -replace '^.*VALIDATION_PASS=','' -replace '^STATUS=','')}
  $proof=''
  if($proofLine){$proof=($proofLine -replace '^.*PROOF_PATH=','')}
  return [pscustomobject]@{path=$path;exit_code=$exit;status=$status;proof_path=$proof;output=@($out)}
}
$calPath='reports/self_development/ORGAN_PASSPORT_CALIBRATION_V1.json'
Assert (Test-Path $calPath) 'MISSING_CALIBRATION_REPORT'
$cal=Get-Content $calPath -Raw|ConvertFrom-Json
$targets=@($cal.items|Where-Object{$_.calibration_decision -eq 'NEEDS_PROOF_RUN'})
Assert ($targets.Count -eq 9) 'EXPECTED_9_NEEDS_PROOF_RUN'
$items=@()
foreach($t in $targets){
  $passportPath=[string]$t.passport_path
  Assert (Test-Path $passportPath) "PASSPORT_MISSING:$passportPath"
  $p=Get-Content $passportPath -Raw|ConvertFrom-Json
  $refs=ExtractRefs $p.validators
  $ps1=@($refs|Where-Object{$_ -match '\.ps1$'})
  $json=@($refs|Where-Object{$_ -match '\.json$' -and $_ -notmatch '\.ps1$'})
  $missing=@($refs|Where-Object{ -not(Test-Path $_) })
  $runs=@()
  $blocked=@()
  foreach($v in $ps1){
    if(-not(Test-Path $v)){ $blocked += "MISSING_VALIDATOR:$v"; continue }
    try{
      $res=RunValidator $v
      $runs += $res
      if($res.exit_code -ne 0){ $blocked += "VALIDATOR_FAILED:$v" }
    } catch { $blocked += ("VALIDATOR_EXCEPTION:{0}:{1}" -f $v,$_.Exception.Message) }
  }
  $passed=@($runs|Where-Object{$_.exit_code -eq 0})
  $proofs=@($passed|ForEach-Object{$_.proof_path}|Where-Object{$_}|Sort-Object -Unique)
  $jsonExisting=@($json|Where-Object{Test-Path $_})
  $decision='BLOCKED_OR_TOO_GENERIC'
  $reason='no runnable proof validators passed'
  if($passed.Count -ge 2){$decision='READY_FOR_LAB_VALIDATION';$reason='two or more executable validators passed'}
  elseif($passed.Count -eq 1){$decision='SINGLE_VALIDATOR_PROOF_NEEDS_SECOND_SURFACE';$reason='one executable validator passed; needs second independent validator/proof'}
  elseif($jsonExisting.Count -gt 0){$decision='CONTRACT_REFERENCE_NEEDS_EXECUTABLE_VALIDATOR';$reason='contract/json refs exist but no executable proof validator'}
  if($missing.Count -gt 0 -and $passed.Count -eq 0){$decision='BLOCKED_BAD_VALIDATOR_REFS';$reason='missing or non-executable validator refs'}
  $newProofRefs=@(($p.proof_refs + $proofs)|Where-Object{$_}|Sort-Object -Unique)
  $p.proof_refs=$newProofRefs
  $p.last_validated_at=(Get-Date).ToString('o')
  if($decision -eq 'READY_FOR_LAB_VALIDATION'){
    $p.gaps=@('READY_FOR_LAB_VALIDATION only; dedicated lab validation still required','PROVEN_LIVE forbidden','PASSPORT_ACTIVE forbidden')
  }
  $p|ConvertTo-Json -Depth 60|Set-Content $passportPath -Encoding UTF8
  $items += [pscustomobject]@{organ_id=$p.organ_id;passport_path=$passportPath;decision=$decision;reason=$reason;validator_refs=$refs;json_contract_refs=$jsonExisting;passed_validator_count=$passed.Count;proof_refs_added=$proofs;blocked=$blocked;missing_refs=$missing;live_or_lab_status=$p.live_or_lab_status;maturity=$p.maturity}
}
$byDecision=@($items|Group-Object decision|Sort-Object Name|ForEach-Object{[ordered]@{decision=$_.Name;count=$_.Count}})
$ready=@($items|Where-Object{$_.decision -eq 'READY_FOR_LAB_VALIDATION'})
$single=@($items|Where-Object{$_.decision -eq 'SINGLE_VALIDATOR_PROOF_NEEDS_SECOND_SURFACE'})
$report=[ordered]@{schema='organ_passport_proof_run_calibration_v1';status='PASS_ORGAN_PASSPORT_PROOF_RUN_CALIBRATION_V1';source_calibration=$calPath;target_count=$targets.Count;by_decision=$byDecision;ready_for_lab_validation=@($ready.organ_id);single_validator_candidates=@($single.organ_id);items=$items;boundaries=[ordered]@{proof_run_calibration_only=$true;no_validated_lab_claim_created=$true;no_active_passports_created=$true;no_proven_live_claim=$true;live_process_touched=$false};created_at=(Get-Date).ToString('o')}
$proof=[ordered]@{schema='organ_passport_proof_run_calibration_v1_proof';status='PASS_ORGAN_PASSPORT_PROOF_RUN_CALIBRATION_V1';target_count=$targets.Count;ready_for_lab_validation_count=$ready.Count;single_validator_candidate_count=$single.Count;ready_for_lab_validation_ids=@($ready.organ_id);no_validated_lab_claim_created=$true;no_active_passports_created=$true;no_proven_live_claim=$true;live_process_touched=$false;report_path='reports/self_development/ORGAN_PASSPORT_PROOF_RUN_CALIBRATION_V1.json';created_at=(Get-Date).ToString('o')}
WJson $report 'reports/self_development/ORGAN_PASSPORT_PROOF_RUN_CALIBRATION_V1.json'
WJson $proof 'tests/self_development/ORGAN_PASSPORT_PROOF_RUN_CALIBRATION_V1_PROOF.json'
Write-Host 'PROOF_RUN_CALIBRATION_PASS=PASS_ORGAN_PASSPORT_PROOF_RUN_CALIBRATION_V1'
Write-Host ('TARGET_COUNT='+$targets.Count)
$byDecision|ForEach-Object{Write-Host ($_.decision+'='+$_.count)}
Write-Host ('READY_IDS='+(@($ready.organ_id)-join ','))

