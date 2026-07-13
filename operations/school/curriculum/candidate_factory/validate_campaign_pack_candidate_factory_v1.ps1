param(
  [int]$TargetAccepted=100,
  [int]$BatchSize=100,
  [string]$CampaignPack='operations/school/curriculum/candidate_factory/campaign_packs/builder_self_knowledge_deep_v1.jsonl',
  [string]$TopicsPlan='operations/school/curriculum/topics/builder_night_school_topics_v1.json',
  [string]$RunId='',
  [switch]$RunStreaming
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($Path,$Obj,$Depth=100){
  $dir=Split-Path -Parent $Path
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  [IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path),($Obj|ConvertTo-Json -Depth $Depth),$utf8)
}
function QuotePs($Value){
  return "'" + ([string]$Value).Replace("'","''") + "'"
}
if($TargetAccepted -lt 1){ throw 'TARGET_ACCEPTED_MUST_BE_POSITIVE' }
if($BatchSize -lt 1 -or $BatchSize -gt 100){ throw 'BATCH_SIZE_MUST_BE_1_TO_100' }
if(-not (Test-Path $CampaignPack)){ throw "CAMPAIGN_PACK_MISSING:$CampaignPack" }
if(-not (Test-Path $TopicsPlan)){ throw "TOPICS_PLAN_MISSING:$TopicsPlan" }
$manifestPath=[IO.Path]::ChangeExtension($CampaignPack,'.manifest.json')
if(-not (Test-Path $manifestPath)){ throw "CAMPAIGN_PACK_MANIFEST_MISSING:$manifestPath" }
$manifest=Get-Content $manifestPath -Raw | ConvertFrom-Json
$seedLines=@(Get-Content $CampaignPack | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if($seedLines.Count -lt 1){ throw 'CAMPAIGN_PACK_EMPTY' }
$seedIds=@{}
foreach($line in $seedLines){
  $seed=$line | ConvertFrom-Json
  if([string]::IsNullOrWhiteSpace([string]$seed.seed_id)){ throw 'CAMPAIGN_PACK_SEED_ID_EMPTY' }
  if($seedIds.ContainsKey([string]$seed.seed_id)){ throw "CAMPAIGN_PACK_DUPLICATE_SEED_ID:$($seed.seed_id)" }
  $seedIds[[string]$seed.seed_id]=$true
  if(-not (Test-Path ([string]$seed.source_path))){ throw "CAMPAIGN_PACK_SOURCE_PATH_MISSING:$($seed.seed_id):$($seed.source_path)" }
}
$factoryScript='operations/school/curriculum/candidate_factory/generate_codex_curriculum_candidate_factory_run_v1.ps1'
$content=Get-Content $factoryScript -Raw
$forbiddenPatterns=@('codex\s+(exec|run|apply|review|resume)', 'openai\s+', 'curl\s+', 'Invoke-WebRequest', 'Invoke-RestMethod')
$forbiddenHits=@($forbiddenPatterns | Where-Object { $content -match $_ })
if($forbiddenHits.Count -gt 0){ throw "FORBIDDEN_EXTERNAL_OR_CODEX_CLI_CALL_IN_FACTORY: $($forbiddenHits -join ',')" }
$pwshCommand=Get-Command pwsh -ErrorAction SilentlyContinue
$powershellRunner=if($pwshCommand){ $pwshCommand.Source } else { 'powershell' }
if([string]::IsNullOrWhiteSpace($RunId)){
  $RunId='campaign_pack_validation_' + $TargetAccepted + '_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
}
$factoryCommand="& $(QuotePs $factoryScript) -TargetAccepted $TargetAccepted -RunKind Test -BatchSize $BatchSize -RunId $(QuotePs $RunId) -TopicsPlan $(QuotePs $TopicsPlan) -CampaignPack $(QuotePs $CampaignPack)"
$factoryOut=@(& $powershellRunner -NoProfile -ExecutionPolicy Bypass -Command $factoryCommand *>&1 | ForEach-Object { [string]$_ })
$factoryExit=$LASTEXITCODE
$factoryOut | ForEach-Object { Write-Host $_ }
if($factoryExit -ne 0){ throw "FACTORY_PROCESS_FAILED_EXIT_$factoryExit" }
$factoryStatus=($factoryOut | Where-Object { $_ -match '^FACTORY_STATUS=' } | Select-Object -Last 1) -replace '^FACTORY_STATUS=',''
if($factoryStatus -ne 'PASS_CODEX_CANDIDATE_FACTORY_GENERATION_V1'){ throw "FACTORY_NOT_PASS:$factoryStatus" }
$run=Get-Content operations/reports/CODEX_CANDIDATE_FACTORY_RUN_V1.json -Raw | ConvertFrom-Json
$candidateLines=@(Get-Content $run.all_candidates_path | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$seedBacked=0
$fallback=0
$missingCampaignFields=@()
$missingSourcePaths=@()
$duplicateLearningKeys=@()
$seenLearningKeys=@{}
$lineNo=0
foreach($line in $candidateLines){
  $lineNo++
  $c=$line | ConvertFrom-Json
  $isFallback=($c.fallback_template -eq $true -or [string]$c.seed_id -eq 'fallback_template')
  if($isFallback){
    $fallback++
    continue
  }
  $seedBacked++
  foreach($field in @('campaign_id','seed_id','source_path','source_summary')){
    if(-not ($c.PSObject.Properties.Name -contains $field) -or [string]::IsNullOrWhiteSpace([string]$c.$field)){
      $missingCampaignFields += [pscustomObject]@{line=$lineNo; candidate_id=$c.candidate_id; missing=$field}
    }
  }
  if(-not (Test-Path ([string]$c.source_path))){
    $missingSourcePaths += [pscustomObject]@{line=$lineNo; candidate_id=$c.candidate_id; source_path=$c.source_path}
  }
  $lk=[string]$c.learning_key
  if([string]::IsNullOrWhiteSpace($lk)){
    $duplicateLearningKeys += [pscustomObject]@{line=$lineNo; candidate_id=$c.candidate_id; learning_key='EMPTY'}
  } elseif($seenLearningKeys.ContainsKey($lk)){
    $duplicateLearningKeys += [pscustomObject]@{line=$lineNo; candidate_id=$c.candidate_id; learning_key=$lk}
  } else {
    $seenLearningKeys[$lk]=$true
  }
}
$seedBackedPercent=if($candidateLines.Count -gt 0){ [Math]::Round((100.0*$seedBacked/$candidateLines.Count),2) } else { 0 }
$fallbackPercent=if($candidateLines.Count -gt 0){ [Math]::Round((100.0*$fallback/$candidateLines.Count),2) } else { 0 }
& operations/school/curriculum/codex_contract/validate_codex_curriculum_contract_consistency_v1.ps1 -RunDir $run.run_dir | Out-Host
$consistency=Get-Content operations/reports/CODEX_CURRICULUM_CONTRACT_CONSISTENCY_V1.json -Raw | ConvertFrom-Json
$stream=$null
if($RunStreaming){
  & operations/school/curriculum/streaming_absorption/validate_codex_curriculum_streaming_absorption_v1.ps1 -RunDir $run.run_dir | Out-Host
  $stream=Get-Content operations/reports/STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1.json -Raw | ConvertFrom-Json
}
$streamOk=if($RunStreaming){ ($stream.status -eq 'PASS_STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1' -and [int]$stream.ready_atoms_total -eq $TargetAccepted -and [int]$stream.stream_quarantined_total -eq 0 -and $stream.active_memory_mutated -eq $false) } else { $true }
$ok=(
  [int]$run.candidates_created -eq $TargetAccepted -and
  $run.campaign_pack_status -eq 'CAMPAIGN_PACK_APPLIED' -and
  $seedBackedPercent -ge 90 -and
  $fallbackPercent -le 10 -and
  $missingCampaignFields.Count -eq 0 -and
  $missingSourcePaths.Count -eq 0 -and
  $duplicateLearningKeys.Count -eq 0 -and
  $consistency.status -eq 'PASS_CODEX_CURRICULUM_CONTRACT_CONSISTENCY_V1' -and
  [int]$consistency.aggregate.accepted -eq $TargetAccepted -and
  [int]$consistency.aggregate.rejected -eq 0 -and
  $streamOk -and
  $run.active_memory_mutated -eq $false
)
$status=if($ok){'PASS_CAMPAIGN_PACK_CANDIDATE_FACTORY_V1'}else{'FAIL_CAMPAIGN_PACK_CANDIDATE_FACTORY_V1'}
$report=[pscustomObject]@{
  schema='campaign_pack_candidate_factory_validator_v1'
  status=$status
  runtime_ready=$false
  target_accepted=$TargetAccepted
  batch_size=$BatchSize
  run_id=$run.run_id
  run_dir=$run.run_dir
  campaign_pack=$CampaignPack
  manifest_path=$manifestPath
  manifest_seed_count=$manifest.seed_count
  seed_lines=$seedLines.Count
  candidates_created=$run.candidates_created
  campaign_seeded_candidates=$seedBacked
  fallback_template_candidates=$fallback
  seed_backed_percent=$seedBackedPercent
  fallback_percent=$fallbackPercent
  missing_campaign_fields=@($missingCampaignFields)
  missing_source_paths=@($missingSourcePaths)
  duplicate_learning_keys=@($duplicateLearningKeys)
  contract_consistency_status=$consistency.status
  contract_accepted=$consistency.aggregate.accepted
  contract_rejected=$consistency.aggregate.rejected
  streaming_requested=[bool]$RunStreaming
  streaming_status=if($stream){$stream.status}else{'NOT_RUN'}
  stream_ready_atoms=if($stream){$stream.ready_atoms_total}else{0}
  stream_quarantined=if($stream){$stream.stream_quarantined_total}else{0}
  active_memory_mutated=$false
  forbidden_call_hits=@($forbiddenHits)
  boundary='Validates campaign-pack grounding for existing candidate_factory only. No Real run, no active promotion, no direct compact memory mutation.'
}
$reportPath='operations/school/curriculum/candidate_factory/reports/CAMPAIGN_PACK_CANDIDATE_FACTORY_VALIDATION_V1.json'
WriteJson $reportPath $report 100
$md=@(
  '# CAMPAIGN_PACK_CANDIDATE_FACTORY_VALIDATION_V1',
  '',
  "Status: $status",
  'Runtime ready: false',
  '',
  "TargetAccepted: $TargetAccepted",
  "Run id: $($run.run_id)",
  "Campaign pack: $CampaignPack",
  "Campaign seeds: $($seedLines.Count)",
  "Candidates created: $($run.candidates_created)",
  "Seed-backed percent: $seedBackedPercent",
  "Fallback percent: $fallbackPercent",
  "Contract consistency: $($consistency.status)",
  "Contract accepted: $($consistency.aggregate.accepted)",
  "Contract rejected: $($consistency.aggregate.rejected)",
  "Streaming: $(if($stream){$stream.status}else{'NOT_RUN'})",
  "Stream ready atoms: $(if($stream){$stream.ready_atoms_total}else{0})",
  "Stream quarantined: $(if($stream){$stream.stream_quarantined_total}else{0})",
  'Active memory mutated: false',
  '',
  'Boundary: campaign-pack grounding validation only; no active promotion.'
)
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/school/curriculum/candidate_factory/reports/CAMPAIGN_PACK_CANDIDATE_FACTORY_VALIDATION_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "CAMPAIGN_VALIDATION_STATUS=$status"
Write-Host "VALIDATOR_REPORT=$reportPath"
Write-Host "RUN_ID=$($run.run_id)"
Write-Host "RUN_DIR=$($run.run_dir)"
Write-Host "CAMPAIGN_PACK=$CampaignPack"
Write-Host "CAMPAIGN_SEEDS=$($seedLines.Count)"
Write-Host "CANDIDATES_CREATED=$($run.candidates_created)"
Write-Host "SEED_BACKED_PERCENT=$seedBackedPercent"
Write-Host "FALLBACK_PERCENT=$fallbackPercent"
Write-Host "CONTRACT_STATUS=$($consistency.status)"
Write-Host "CONTRACT_ACCEPTED=$($consistency.aggregate.accepted)"
Write-Host "CONTRACT_REJECTED=$($consistency.aggregate.rejected)"
Write-Host "STREAMING_STATUS=$(if($stream){$stream.status}else{'NOT_RUN'})"
Write-Host "STREAM_READY_ATOMS=$(if($stream){$stream.ready_atoms_total}else{0})"
Write-Host "STREAM_QUARANTINED=$(if($stream){$stream.stream_quarantined_total}else{0})"
Write-Host "ACTIVE_MEMORY_MUTATED=false"
Write-Host "RUNTIME_READY=false"
if(-not $ok){ exit 1 }
