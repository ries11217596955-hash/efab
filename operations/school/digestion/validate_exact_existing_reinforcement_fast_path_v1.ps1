param()
$ErrorActionPreference='Stop'
$repo=(git rev-parse --show-toplevel).Trim(); Set-Location $repo
$helper='operations/school/digestion/try_exact_existing_reinforcement_fast_path_v1.ps1'
$proofPath='H:\bridge\reports\reinforcement_fast_path_microtrial_20260814.json'
$expectedProofSha='F7049F1DAE709ABE00B39B189B8B0BF461BD82DBD7FF6B73C9306B4F3BBB450B'
$expectedAcceptedCellsSha='E49423033370B0DD01BF5C33FEAEFF558CC1AE211D1249595D0F2947B8E4599A'
$root=Join-Path ([IO.Path]::GetTempPath()) ('efab_fast_path_validator_'+[guid]::NewGuid().ToString('N'))
function Sha($p){(Get-FileHash -Algorithm SHA256 $p).Hash}
function ShaText([string]$s){$u=New-Object Text.UTF8Encoding($false);$h=[Security.Cryptography.SHA256]::Create();try{(($h.ComputeHash($u.GetBytes($s))|ForEach-Object{$_.ToString('x2')}) -join '')}finally{$h.Dispose()}}
function RunHelper($inputPath,$mem,$run){@(& powershell -NoProfile -ExecutionPolicy Bypass -File $helper -InputPath $inputPath -MemoryRoot $mem -RunId $run -SizeBudgetBytes 50000000 *>&1|ForEach-Object{[string]$_})}
function Field($out,$name){(($out|Where-Object{$_ -match ('^'+[regex]::Escape($name)+'=')}|Select-Object -Last 1)-replace ('^'+[regex]::Escape($name)+'='),'')}
function FindCellLine($path,$key){foreach($line in Get-Content $path){$o=$line|ConvertFrom-Json;if([string]$o.concept_key -eq $key){return [pscustomobject]@{line=$line;obj=$o}}};throw "CELL_NOT_FOUND:$key"}
try {
  if((Sha $proofPath) -ne $expectedProofSha){throw 'MICROTRIAL_PROOF_SHA_MISMATCH'}
  $proof=Get-Content $proofPath -Raw|ConvertFrom-Json
  $checkpoint=[string]$proof.historical_checkpoint; $accepted=[string]$proof.accepted_reference_memory; $key=[string]$proof.normalized_contract.canonical_concept_key
  if(-not(Test-Path $checkpoint)){throw 'HISTORICAL_CHECKPOINT_MISSING'}; if(-not(Test-Path $accepted)){throw 'ACCEPTED_REFERENCE_MEMORY_MISSING'}
  if((Sha (Join-Path $accepted 'cells.jsonl')) -ne $expectedAcceptedCellsSha){throw 'ACCEPTED_REFERENCE_CELLS_SHA_MISMATCH'}
  New-Item -ItemType Directory -Force -Path $root|Out-Null; $candidate=Join-Path $root 'candidate'; Copy-Item $checkpoint $candidate -Recurse
  $before=FindCellLine (Join-Path $checkpoint 'cells.jsonl') $key; $acceptedTarget=FindCellLine (Join-Path $accepted 'cells.jsonl') $key
  $atom=[ordered]@{concept_key=[string]$proof.normalized_contract.concept_key_raw;label=[string]$proof.normalized_contract.label;kind=[string]$proof.normalized_contract.kind;definition=[string]$before.obj.summary;properties=@();relations=@();uses=@()}
  $atomJson=$atom|ConvertTo-Json -Depth 20 -Compress; if((ShaText $atomJson) -ne [string]$proof.normalized_contract.normalized_sha256){throw 'RECONSTRUCTED_NORMALIZED_SHA_MISMATCH'}
  $input=Join-Path $root 'historical_reconstructed_atom.jsonl'; [IO.File]::WriteAllText($input,$atomJson+"`n",(New-Object Text.UTF8Encoding($false)))
  $indexBefore=Sha (Join-Path $candidate 'index.json'); $out=RunHelper $input $candidate 'historical_replay_candidate'; if((Field $out 'REINFORCEMENT_FAST_PATH_STATUS') -ne 'APPLIED'){throw ('FAST_PATH_NOT_APPLIED:'+(Field $out 'REINFORCEMENT_FAST_PATH_REASON'))}
  $indexAfter=Sha (Join-Path $candidate 'index.json'); if($indexAfter -ne $indexBefore){throw 'INDEX_CHANGED'}; if($indexAfter -ne [string]$proof.observed_full_digest_delta.index_sha_after){throw 'INDEX_NOT_ACCEPTED_HASH'}
  $candLines=@(Get-Content (Join-Path $candidate 'cells.jsonl')); $accLines=@(Get-Content (Join-Path $accepted 'cells.jsonl')); if($candLines.Count -ne $accLines.Count){throw 'CELL_COUNT_MISMATCH'}
  for($i=0;$i -lt $candLines.Count;$i++){ $co=$candLines[$i]|ConvertFrom-Json; if([string]$co.concept_key -ne $key){if($candLines[$i] -ne $accLines[$i]){throw "NON_TARGET_CELL_CHANGED:$i"}} }
  $candTarget=FindCellLine (Join-Path $candidate 'cells.jsonl') $key
  foreach($n in @('schema','cell_id','concept_key','label','kind','summary','observation_count','confidence','version')){if([string]$candTarget.obj.$n -ne [string]$acceptedTarget.obj.$n){throw "TARGET_FIELD_MISMATCH:$n"}}
  foreach($n in @('aliases','properties','relations','uses','source_fingerprints')){if((@($candTarget.obj.$n)|ConvertTo-Json -Compress) -ne (@($acceptedTarget.obj.$n)|ConvertTo-Json -Compress)){throw "TARGET_ARRAY_MISMATCH:$n"}}
  if(-not(@($candTarget.obj.source_fingerprints) -contains [string]$proof.normalized_contract.normalized_sha256)){throw 'TARGET_FINGERPRINT_MISSING'}
  foreach($case in @('SUMMARY_DELTA','PROPERTIES_DELTA','ATOM_COUNT_NOT_ONE')){
    $mem=Join-Path $root ('negative_'+$case); Copy-Item $checkpoint $mem -Recurse; $inp=Join-Path $root ('negative_'+$case+'.jsonl'); $bc=Sha (Join-Path $mem 'cells.jsonl');$bi=Sha (Join-Path $mem 'index.json');$bm=Sha (Join-Path $mem 'manifest.json')
    if($case -eq 'SUMMARY_DELTA'){$x=($atom|ConvertTo-Json -Depth 20|ConvertFrom-Json);$x.definition=[string]$atom.definition+' changed';$txt=$x|ConvertTo-Json -Compress -Depth 20;[IO.File]::WriteAllText($inp,$txt+"`n",(New-Object Text.UTF8Encoding($false)))}elseif($case -eq 'PROPERTIES_DELTA'){$x=($atom|ConvertTo-Json -Depth 20|ConvertFrom-Json);$x.properties=@('delta=yes');$txt=$x|ConvertTo-Json -Compress -Depth 20;[IO.File]::WriteAllText($inp,$txt+"`n",(New-Object Text.UTF8Encoding($false)))}else{[IO.File]::WriteAllText($inp,$atomJson+"`n"+$atomJson+"`n",(New-Object Text.UTF8Encoding($false)))}
    $no=RunHelper $inp $mem ('negative_'+$case); if((Field $no 'REINFORCEMENT_FAST_PATH_STATUS') -ne 'NOT_ELIGIBLE'){throw "NEGATIVE_NOT_REJECTED:$case"}; if((Sha (Join-Path $mem 'cells.jsonl')) -ne $bc -or (Sha (Join-Path $mem 'index.json')) -ne $bi -or (Sha (Join-Path $mem 'manifest.json')) -ne $bm){throw "NEGATIVE_MUTATED_MEMORY:$case"}
  }
  Write-Host 'VALIDATOR_STATUS=PASS_EXACT_EXISTING_REINFORCEMENT_FAST_PATH_V1'; Write-Host ('HISTORICAL_NORMALIZED_SHA='+$proof.normalized_contract.normalized_sha256); Write-Host ('INDEX_SHA='+$indexAfter); Write-Host 'CLAIMS_PROVEN=historical_reconstructed_atom_sha_exact,helper_semantic_match_to_accepted_full_digest,index_byte_identical,negative_cases_no_mutation'; Write-Host 'DOES_NOT_PROVE=updated_at_byte_identity_without_timestamp_pin,live500_stability,production_acceptance'
} finally {if(Test-Path $root){Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue}}