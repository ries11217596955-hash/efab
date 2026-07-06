param(
  [string]$PolicyPath='operations/school/curriculum/source_router/template_filter/school_source_template_filter_policy.json',
  [string]$MetricsPath,
  [string]$NeedPath,
  [string]$RunId = "template_filter_$(Get-Date -Format yyyyMMdd_HHmmss)"
)
$ErrorActionPreference='Stop'
Set-Location (git rev-parse --show-toplevel).Trim()
if(-not(Test-Path $PolicyPath)){ throw "POLICY_MISSING:$PolicyPath" }
$p=Get-Content $PolicyPath -Raw | ConvertFrom-Json
$m=[ordered]@{duplicate_rate=0.0;novelty_score=0.8;validator_pass_rate=1.0;quarantine_rate=0.0;external_required=$false;codex_required=$false;codex_available=$true;topic='school_candidate_material'}
if($MetricsPath){ $mj=Get-Content $MetricsPath -Raw|ConvertFrom-Json; foreach($prop in $mj.PSObject.Properties){ $m[$prop.Name]=$prop.Value } }
$n=[ordered]@{goal='produce school candidate material';source_need='official_docs';freshness_need='stable';preferred_domains=@();topic=$m.topic}
if($NeedPath){ $nj=Get-Content $NeedPath -Raw|ConvertFrom-Json; foreach($prop in $nj.PSObject.Properties){ $n[$prop.Name]=$prop.Value } }
$selected='InternalFactory'; $reason='internal_factory_healthy'; $status='PASS_USE_INTERNAL_FACTORY'
if([bool]$m.external_required -or ([bool]$m.codex_required -and -not [bool]$m.codex_available)){
  $selected='ExternalWorldSourcePort'; $reason='external_required_or_codex_unavailable'; $status='PASS_ESCALATE_TO_EXTERNAL_WORLD'
} elseif(([double]$m.duplicate_rate -ge 0.50 -or [double]$m.novelty_score -le 0.35) -and [bool]$m.codex_available -and -not [bool]$m.external_required){
  $selected='CodexSourcePort'; $reason='internal_factory_stale_codex_available'; $status='PASS_ESCALATE_TO_CODEX'
}
$sourceNeed=[string]$n.source_need
$ladder=@($p.source_ladder)
$preferredTier=@($ladder|Where-Object{$_.tier -eq $sourceNeed}|Select-Object -First 1)
if(-not $preferredTier){ $preferredTier=@($ladder|Where-Object{$_.tier -eq 'official_docs'}|Select-Object -First 1) }
$queryTemplate=[ordered]@{
  goal=$n.goal
  topic=$n.topic
  source_need=$sourceNeed
  freshness_need=$n.freshness_need
  preferred_domains=@($n.preferred_domains)
  blocked_result_types=@($p.blocked_result_types)
  minimum_authority_score=[double]$p.query_template_defaults.minimum_authority_score
  reject_ads_sponsored=$true
  cross_check_required=[bool]$p.query_template_defaults.cross_check_required
}
$result=[ordered]@{
  schema='school_source_template_filter_decision_v1'
  status=$status
  run_id=$RunId
  selected_source=$selected
  reason=$reason
  metrics=$m
  need=$n
  query_template=$queryTemplate
  authority_tier=[ordered]@{tier=$preferredTier.tier;authority_score=[double]$preferredTier.authority_score;action=$preferredTier.action}
  fallback_chain=@('InternalFactory','CodexSourcePort','ExternalWorldSourcePort')
  quarantine_rules=@('reject sponsored/ad','reject seo/content farm','quarantine low authority','cross-check non-official risky claims')
  boundary='Decision selects source route and query template only; it does not accept external material or write memory.'
  created_at=(Get-Date).ToString('o')
}
$proof=".runtime/school_source_template_filter/$RunId/SCHOOL_SOURCE_TEMPLATE_FILTER_DECISION_V1.json"
New-Item -ItemType Directory -Force -Path (Split-Path $proof -Parent) | Out-Null
$result|ConvertTo-Json -Depth 80|Set-Content -LiteralPath $proof -Encoding UTF8
Write-Host "TEMPLATE_FILTER_STATUS=$status"
Write-Host "TEMPLATE_FILTER_SELECTED_SOURCE=$selected"
Write-Host "TEMPLATE_FILTER_REASON=$reason"
Write-Host "TEMPLATE_FILTER_PROOF=$proof"
