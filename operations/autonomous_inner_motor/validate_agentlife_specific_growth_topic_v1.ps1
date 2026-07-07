$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$script='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$text=Get-Content $script -Raw
function Import-FunctionFromText([string]$Name,[string]$SourceText){
  $m=[regex]::Match($SourceText,"(?m)^function\s+$Name\b")
  Assert $m.Success "FUNCTION_NOT_FOUND:$Name"
  $start=$m.Index
  $brace=$SourceText.IndexOf('{',$start)
  Assert ($brace -ge 0) "FUNCTION_BRACE_NOT_FOUND:$Name"
  $depth=0
  for($i=$brace;$i -lt $SourceText.Length;$i++){
    if($SourceText[$i] -eq '{'){ $depth++ }
    elseif($SourceText[$i] -eq '}'){
      $depth--
      if($depth -eq 0){
        $fn=$SourceText.Substring($start,$i-$start+1)
        . ([scriptblock]::Create($fn))
        $cmd=Get-Command $Name -CommandType Function -ErrorAction Stop
        Set-Item -Path ("function:global:$Name") -Value $cmd.ScriptBlock
        return
      }
    }
  }
  throw "FUNCTION_END_NOT_FOUND:$Name"
}
function Get-SelectorField($Object,[string]$Name,$Default=$null) {
  if($null -eq $Object) { return $Default }
  if($Object -is [System.Collections.IDictionary] -and $Object.Contains($Name)) { return $Object[$Name] }
  if($Object.PSObject.Properties[$Name]) { return $Object.PSObject.Properties[$Name].Value }
  return $Default
}
foreach($name in @('Normalize-GrowthSignalTopicForTask','Test-GenericAgentLifeGrowthTopic','Select-AgentLifePacketTopic')){ Import-FunctionFromText $name $text }
$genericSelector=[pscustomobject]@{
  normalized_topic='growth_signal_topic_is_too_generic_for_useful_task'
  specific_gap='validated_memory_topic_requires_bounded_next_action:growth_signal_topic_is_too_generic_for_useful_task'
  next_action_candidate='derive_specific_growth_topic_from_latest_agentlife_or_school_memory_delta'
  validator_hint='validate growth signal has specific_gap, next_action_candidate, proof_needed, validator_hint, and non-generated semantic topic'
  proof_needed=@('producer proof JSON','negative generic-topic validator')
}
$genericEvent=[pscustomobject]@{current_task='validate_guardrails_before_follow_growth_signal_growth_signal_topic_is_too_generic_for_useful_task'}
$d=Select-AgentLifePacketTopic $genericSelector $genericEvent
Assert ($d.topic -eq 'derive_specific_growth_topic_from_latest_agentlife_or_school_memory_delta') 'GENERIC_SELECTOR_DID_NOT_PROMOTE_NEXT_ACTION_TOPIC'
Assert ($d.topic_source -eq 'selector_next_action_candidate') 'GENERIC_SELECTOR_TOPIC_SOURCE_BAD'
Assert (-not (Test-GenericAgentLifeGrowthTopic $d.topic)) 'PROMOTED_TOPIC_STILL_GENERIC'
Assert ($d.specific_gap -like 'validated_memory_topic_requires_bounded_next_action*') 'SPECIFIC_GAP_NOT_PRESERVED'
Assert ($d.next_action_candidate -eq 'derive_specific_growth_topic_from_latest_agentlife_or_school_memory_delta') 'NEXT_ACTION_NOT_PRESERVED'
Assert (@($d.proof_needed).Count -eq 2) 'PROOF_NEEDED_NOT_PRESERVED'
$actionSelector=[pscustomobject]@{
  normalized_topic='selector_validator_missing_live_payload_shape'
  specific_gap='selector_validator_missing_live_payload_shape'
  next_action_candidate='add_ordered_payload_negative_case_to_selector_validator'
  validator_hint='validate ordered dictionary and PSCustomObject selector inputs'
  proof_needed=@('selector validator PASS')
}
$d2=Select-AgentLifePacketTopic $actionSelector $null
Assert ($d2.topic -eq 'add_ordered_payload_negative_case_to_selector_validator') 'ACTIONABLE_SELECTOR_DID_NOT_PREFER_NEXT_ACTION'
Assert ($d2.topic_source -eq 'selector_next_action_candidate') 'ACTIONABLE_SELECTOR_TOPIC_SOURCE_BAD'
Assert (-not (Test-GenericAgentLifeGrowthTopic $d2.topic)) 'ACTIONABLE_TOPIC_FLAGGED_GENERIC'
$noSelectorEvent=[pscustomobject]@{current_task='validate_guardrails_before_follow_growth_signal_follow_gr'}
$d3=Select-AgentLifePacketTopic $null $noSelectorEvent
Assert ($d3.topic -eq 'derive_specific_growth_topic_from_latest_agentlife_or_school_memory_delta') 'NO_SELECTOR_FALLBACK_NOT_SPECIFIC_DERIVATION'
Assert ($d3.topic_source -eq 'fallback_specificity_derivation_action') 'NO_SELECTOR_FALLBACK_SOURCE_BAD'
Assert (@($d3.proof_needed).Count -ge 3) 'NO_SELECTOR_FALLBACK_PROOF_NEEDED_BAD'
Assert ($text -match 'AGENTLIFE_ACTIONABLE_RUNTIME_SUMMARY_ATOM') 'AGENTLIFE_PACKET_CLASSIFIER_NOT_UPDATED'
Assert ($text -match 'specific_gap=\$specificGap') 'AGENTLIFE_PACKET_SPECIFIC_GAP_NOT_WRITTEN'
Assert ($text -match 'next_action_candidate=\$nextAction') 'AGENTLIFE_PACKET_NEXT_ACTION_NOT_WRITTEN'
Assert ($text -match 'proof_needed=@\(\$proofNeeded\)') 'AGENTLIFE_PACKET_PROOF_NEEDED_NOT_WRITTEN'
Assert ($text -match 'validator_hint=\$validatorHint') 'AGENTLIFE_PACKET_VALIDATOR_HINT_NOT_WRITTEN'
$proof=[ordered]@{
  schema='agentlife_specific_growth_topic_validation_v1'
  status='PASS_AGENTLIFE_SPECIFIC_GROWTH_TOPIC_V1'
  tests=@(
    [ordered]@{name='generic_selector_promotes_next_action_topic';status='PASS';topic=$d.topic;source=$d.topic_source},
    [ordered]@{name='actionable_selector_prefers_next_action';status='PASS';topic=$d2.topic;source=$d2.topic_source},
    [ordered]@{name='no_selector_falls_back_to_specific_derivation_action';status='PASS';topic=$d3.topic;source=$d3.topic_source},
    [ordered]@{name='agentlife_packet_writes_contract_fields';status='PASS'}
  )
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/autonomous_inner_motor/AGENTLIFE_SPECIFIC_GROWTH_TOPIC_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofPath -Parent)|Out-Null
$proof|ConvertTo-Json -Depth 40|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_AGENTLIFE_SPECIFIC_GROWTH_TOPIC_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'


