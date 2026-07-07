param(
  [Parameter(Mandatory=$true)][string]$PacketPath,
  [string]$PolicyPath = "operations/compact_memory_intake/multi_source_compact_memory_intake_policy.json"
)
$ErrorActionPreference = 'Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot
function WriteJson($Path,$Obj,$Depth=50){
  $dir=Split-Path $Path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $Obj | ConvertTo-Json -Depth $Depth | Set-Content -LiteralPath $Path -Encoding UTF8
}
function Convert-ToGrowthSignalSlug([string]$Value) {
  if([string]::IsNullOrWhiteSpace($Value)) { return 'growth_signal_specificity_gap' }
  $slug = ($Value.ToLowerInvariant() -replace '[^a-z0-9_\-]+','_').Trim('_','-')
  if([string]::IsNullOrWhiteSpace($slug)) { return 'growth_signal_specificity_gap' }
  foreach($prefix in @('validate_guardrails_before_','follow_growth_signal_')) {
    while($slug.StartsWith($prefix) -and $slug.Length -gt $prefix.Length) { $slug=$slug.Substring($prefix.Length).Trim('_','-') }
  }
  if($slug -in @('active_growth_signal','aimo_sandbox_test_life','agentlife_cycle_learning','follow','follow_gr','follow_growth','growth_signal','validate_guardrails')) { return 'growth_signal_specificity_gap' }
  if($slug.Length -gt 80) { $slug=$slug.Substring(0,80).Trim('_','-') }
  if([string]::IsNullOrWhiteSpace($slug)) { return 'growth_signal_specificity_gap' }
  return $slug
}
function Get-PacketInfluenceField($Packet,[string]$Name,$Default=$null) {
  if($Packet -and $Packet.influence -and $Packet.influence.PSObject.Properties[$Name]) { return $Packet.influence.PSObject.Properties[$Name].Value }
  return $Default
}
function Convert-ToBoundedList($Value) {
  $out=New-Object System.Collections.Generic.List[string]
  foreach($v in @($Value)) {
    if(-not [string]::IsNullOrWhiteSpace([string]$v)) {
      $s=[string]$v
      if($s.Length -gt 260){$s=$s.Substring(0,260)}
      if(-not $out.Contains($s)){ $out.Add($s)|Out-Null }
    }
  }
  return @($out.ToArray())
}
if(-not (Test-Path $PacketPath)){ throw "PACKET_MISSING:$PacketPath" }
$policy=Get-Content $PolicyPath -Raw | ConvertFrom-Json
$packet=Get-Content $PacketPath -Raw | ConvertFrom-Json
$validationOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/compact_memory_intake/validate_compact_memory_packet_v1.ps1 -PacketPath $PacketPath -PolicyPath $PolicyPath *>&1 | ForEach-Object {[string]$_})
$validationOut | ForEach-Object { Write-Host $_ }
$validationStatus=($validationOut|Where-Object{$_ -match '^PACKET_VALIDATION_STATUS='}|Select-Object -Last 1) -replace '^PACKET_VALIDATION_STATUS=',''
if($validationStatus -ne 'PASS_COMPACT_MEMORY_KNOWLEDGE_PACKET_V1'){ throw "PACKET_VALIDATION_NOT_PASS:$validationStatus" }
$atoms=@($packet.atoms)
$declaredAtomCount=if($packet.quality_summary -and $packet.quality_summary.atom_count){[int]$packet.quality_summary.atom_count}else{$atoms.Count}
$topics=@($atoms|ForEach-Object{[string]$_.topic}|Select-Object -Unique)
$queueRoot=[string]$policy.runtime_queue_root
New-Item -ItemType Directory -Force -Path $queueRoot | Out-Null
$packetId="{0}_{1}_{2}" -f $packet.source_kind,($packet.source_id -replace '[^A-Za-z0-9_.-]','_'),(Get-Date -Format 'yyyyMMdd_HHmmss')
$queuePath=Join-Path $queueRoot ("$packetId.json")
Copy-Item -LiteralPath $PacketPath -Destination $queuePath -Force
$maturityDelta=0
if($packet.influence -and $null -ne $packet.influence.maturity_delta){ $maturityDelta=[double]$packet.influence.maturity_delta } else { $maturityDelta=[Math]::Min(5,[Math]::Max(0.1,($declaredAtomCount/100000.0))) }
$supportPolicy=if($packet.influence -and $packet.influence.memory_support_policy){[string]$packet.influence.memory_support_policy}else{'CHECK_FRESH_MEMORY_AGAINST_SELECTED_PATH_BEFORE_EXECUTION'}
$rawFocusBoosts=if($packet.influence -and $packet.influence.focus_boosts){@($packet.influence.focus_boosts)}else{@($topics)}
$rawTopicsWereGeneric = $true
foreach($rawTopicForQuality in @($topics)) { if((Convert-ToGrowthSignalSlug ([string]$rawTopicForQuality)) -ne 'growth_signal_specificity_gap') { $rawTopicsWereGeneric = $false } }
$actionableTopics=@($topics | ForEach-Object { Convert-ToGrowthSignalSlug ([string]$_) } | Select-Object -Unique)
if(@($actionableTopics).Count -lt 1){ $actionableTopics=@('growth_signal_specificity_gap') }
$primaryTopic=[string]@($actionableTopics)[0]
$specificGap=[string](Get-PacketInfluenceField $packet 'specific_gap' $null)
if([string]::IsNullOrWhiteSpace($specificGap)){
  if($primaryTopic -eq 'growth_signal_specificity_gap') { $specificGap='growth_signal_topic_is_too_generic_for_useful_task_selection' }
  else { $specificGap="validated_memory_topic_requires_bounded_next_action:$primaryTopic" }
}
$specificGapSlug=Convert-ToGrowthSignalSlug $specificGap
if($primaryTopic -eq 'growth_signal_specificity_gap' -and $specificGapSlug -ne 'growth_signal_specificity_gap') { $actionableTopics=@($specificGapSlug) }
$nextActionCandidate=[string](Get-PacketInfluenceField $packet 'next_action_candidate' $null)
if([string]::IsNullOrWhiteSpace($nextActionCandidate)){
  if($specificGap -like '*too_generic*') { $nextActionCandidate='derive_specific_growth_topic_from_latest_agentlife_or_school_memory_delta' }
  elseif($primaryTopic -eq 'growth_signal_specificity_gap') { $nextActionCandidate='replace_generic_growth_signal_with_source_specific_gap_and_validator_hint' }
  else { $nextActionCandidate="inspect_$primaryTopic`_and_return_one_bounded_next_action_candidate" }
}
$validatorHint=[string](Get-PacketInfluenceField $packet 'validator_hint' $null)
if([string]::IsNullOrWhiteSpace($validatorHint)){
  if($nextActionCandidate -like '*growth_topic*' -or $specificGap -like '*too_generic*') { $validatorHint='validate growth signal has specific_gap, next_action_candidate, proof_needed, validator_hint, and non-generated semantic topic' }
  else { $validatorHint='validate proposed action against real packet shape, negative generic-topic case, and proof refs before live use' }
}
$proofNeeded=Convert-ToBoundedList (Get-PacketInfluenceField $packet 'proof_needed' @())
if(@($proofNeeded).Count -lt 1){ $proofNeeded=@('producer proof JSON','negative generic-topic validator','live or lab observation showing AIMO selected a bounded action from the signal') }
$signalQuality=if($primaryTopic -eq 'growth_signal_specificity_gap' -or $specificGap -like '*too_generic*'){'NEEDS_SPECIFICITY'}else{'ACTIONABLE'}
$focusBoosts=Convert-ToBoundedList (@($rawFocusBoosts) + @($specificGapSlug,$nextActionCandidate,'proof_needed','validator_hint'))
$growthSignal=[ordered]@{
  schema='compact_memory_growth_signal_v1'
  status='ACTIVE_GROWTH_SIGNAL'
  created_at=(Get-Date).ToString('o')
  source_kind=$packet.source_kind
  source_id=$packet.source_id
  packet_id=$packetId
  packet_path=$queuePath
  declared_atom_count=$declaredAtomCount
  packet_atoms=$atoms.Count
  topics=@($actionableTopics)
  maturity_delta=$maturityDelta
  memory_support_policy=$supportPolicy
  focus_boosts=@($focusBoosts)
  behavior_rule='Autonomous life must inspect this signal after path selection and before execution; validated knowledge supports the selected path when topics match, but must not override path selection.'
  specific_gap=$specificGap
  next_action_candidate=$nextActionCandidate
  proof_needed=@($proofNeeded)
  validator_hint=$validatorHint
  signal_quality=$signalQuality
  actionable_contract=[ordered]@{ specific_gap_required=$true; next_action_candidate_required=$true; proof_needed_required=$true; validator_hint_required=$true; generated_task_name_as_topic_allowed=$false }
  active_memory_mutated_by_intake=$false
}
if([bool]$policy.growth_signal_enabled){ WriteJson ([string]$policy.active_growth_signal_path) $growthSignal 40 }
$report=[ordered]@{
  schema='compact_memory_intake_submission_result_v1'
  status='PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1'
  packet_path=$PacketPath
  queue_path=$queuePath
  growth_signal_path=[string]$policy.active_growth_signal_path
  source_kind=$packet.source_kind
  source_id=$packet.source_id
  declared_atom_count=$declaredAtomCount
  packet_atoms=$atoms.Count
  topics=@($actionableTopics)
  maturity_delta=$maturityDelta
  active_memory_mutated=$false
  submitted_at=(Get-Date).ToString('o')
}
$reportRoot=[string]$policy.runtime_report_root
New-Item -ItemType Directory -Force -Path $reportRoot | Out-Null
$reportPath=Join-Path $reportRoot ("COMPACT_MEMORY_INTAKE_SUBMISSION_$packetId.json")
WriteJson $reportPath $report 40
Write-Host "INTAKE_STATUS=$($report.status)"
Write-Host "INTAKE_QUEUE_PATH=$queuePath"
Write-Host "GROWTH_SIGNAL_PATH=$($report.growth_signal_path)"
Write-Host "GROWTH_MATURITY_DELTA=$maturityDelta"
Write-Host "GROWTH_MEMORY_SUPPORT_POLICY=$supportPolicy"