param(
  [Parameter(Mandatory=$true)][int]$TargetAccepted,
  [Parameter(Mandatory=$true)][ValidateSet('Test','Real')][string]$RunKind,
  [int]$BatchSize = 100,
  [Parameter(Mandatory=$true)][string]$RunId,
  [int]$OrdinalOffset = 0,
  [Parameter(Mandatory=$true)][string]$TopicsPlan,
  [ValidateSet('Auto','InternalFactory','CodexSourcePort','ExternalWorldSourcePort')][string]$SourceMode = 'Auto',
  [string]$PolicyPath = 'operations/school/curriculum/source_router/school_source_router_policy.json',
  [string]$TemplateMetricsPath,
  [string]$TemplateNeedPath
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=80){ $d=Split-Path $Path -Parent; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
if(-not (Test-Path $PolicyPath)){ throw "SCHOOL_SOURCE_ROUTER_POLICY_MISSING:$PolicyPath" }
if(-not (Test-Path $TopicsPlan)){ throw "TOPICS_PLAN_MISSING:$TopicsPlan" }
$policy=Get-Content $PolicyPath -Raw|ConvertFrom-Json
$selected=$SourceMode
$selectionReason='explicit_source_mode'
$skipped=@()
$templateFilterStatus=$null
$templateFilterProof=$null
$templateFilterReason=$null
if($SourceMode -eq 'Auto'){
  if($policy.template_filter -and [bool]$policy.template_filter.enabled){
    $filterScript=[string]$policy.template_filter.script
    $filterPolicy=[string]$policy.template_filter.policy
    if([string]::IsNullOrWhiteSpace($filterScript) -or -not (Test-Path $filterScript)){ throw "TEMPLATE_FILTER_SCRIPT_MISSING:$filterScript" }
    $filterArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$filterScript,'-PolicyPath',$filterPolicy,'-RunId',("school_source_router_filter_$RunId"))
    if($TemplateMetricsPath){ $filterArgs += @('-MetricsPath',$TemplateMetricsPath) }
    if($TemplateNeedPath){ $filterArgs += @('-NeedPath',$TemplateNeedPath) }
    $filterOut=@(& powershell @filterArgs *>&1 | ForEach-Object{[string]$_})
    $templateFilterStatus=($filterOut|Where-Object{$_ -match '^TEMPLATE_FILTER_STATUS='}|Select-Object -Last 1) -replace '^TEMPLATE_FILTER_STATUS=',''
    $selected=($filterOut|Where-Object{$_ -match '^TEMPLATE_FILTER_SELECTED_SOURCE='}|Select-Object -Last 1) -replace '^TEMPLATE_FILTER_SELECTED_SOURCE=',''
    $templateFilterReason=($filterOut|Where-Object{$_ -match '^TEMPLATE_FILTER_REASON='}|Select-Object -Last 1) -replace '^TEMPLATE_FILTER_REASON=',''
    $templateFilterProof=($filterOut|Where-Object{$_ -match '^TEMPLATE_FILTER_PROOF='}|Select-Object -Last 1) -replace '^TEMPLATE_FILTER_PROOF=',''
    $selectionReason='template_filter_decision'
  } else {
    $selected=$null
    foreach($candidate in @($policy.selection_order)){
      if(@($policy.enabled_sources) -contains $candidate){ $selected=$candidate; $selectionReason='first_enabled_source_in_policy_order'; break }
      else { $skipped += [ordered]@{source=$candidate; reason='SOURCE_NOT_ENABLED'} }
    }
  }
}
if([string]::IsNullOrWhiteSpace($selected)){ throw 'NO_ENABLED_SCHOOL_SOURCE_AVAILABLE' }
if(@($policy.enabled_sources) -notcontains $selected){ throw "SELECTED_SOURCE_NOT_ENABLED:$selected" }
$codexPortStatus=$null
$codexPortProof=$null
$externalWorldPortStatus=$null
$externalWorldPortProof=$null
$sourceMaterialStatus='INTERNAL_FACTORY_ONLY'
if($selected -eq 'CodexSourcePort'){
  $codexScript=[string]$policy.codex_source_port.script
  if([string]::IsNullOrWhiteSpace($codexScript) -or -not (Test-Path $codexScript)){ throw "CODEX_SOURCE_PORT_SCRIPT_MISSING:$codexScript" }
  $codexOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $codexScript -TargetAccepted $TargetAccepted -RunId $RunId -TopicsPlan $TopicsPlan *>&1 | ForEach-Object{[string]$_})
  $codexPortStatus=($codexOut|Where-Object{$_ -match '^SCHOOL_CODEX_SOURCE_PORT_STATUS='}|Select-Object -Last 1) -replace '^SCHOOL_CODEX_SOURCE_PORT_STATUS=',''
  $codexPortProof=($codexOut|Where-Object{$_ -match '^SCHOOL_CODEX_SOURCE_PORT_PROOF='}|Select-Object -Last 1) -replace '^SCHOOL_CODEX_SOURCE_PORT_PROOF=',''
  if($codexPortStatus -ne 'PASS_SCHOOL_CODEX_SOURCE_PORT_V1'){ throw "CODEX_SOURCE_PORT_NOT_PASS:$codexPortStatus" }
  $sourceMaterialStatus='CODEX_DRAFT_VALIDATED_THEN_INTERNAL_FACTORY_NORMALIZED'
} elseif($selected -eq 'ExternalWorldSourcePort'){
  $externalScript=[string]$policy.external_world_source_port.script
  if([string]::IsNullOrWhiteSpace($externalScript) -or -not (Test-Path $externalScript)){ throw "EXTERNAL_WORLD_SOURCE_PORT_SCRIPT_MISSING:$externalScript" }
  $externalArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File',$externalScript,'-TargetAccepted',$TargetAccepted,'-RunId',$RunId,'-TopicsPlan',$TopicsPlan)
  if($policy.external_world_source_port.seed_material_path){ $externalArgs += @('-SeedMaterialPath',[string]$policy.external_world_source_port.seed_material_path) }
  if($policy.external_world_source_port.fetch_urls){ foreach($u in @($policy.external_world_source_port.fetch_urls)){ $externalArgs += @('-FetchUrls',[string]$u) } }
  $externalOut=@(& powershell @externalArgs *>&1 | ForEach-Object{[string]$_})
  $externalWorldPortStatus=($externalOut|Where-Object{$_ -match '^SCHOOL_EXTERNAL_WORLD_SOURCE_PORT_STATUS='}|Select-Object -Last 1) -replace '^SCHOOL_EXTERNAL_WORLD_SOURCE_PORT_STATUS=',''
  $externalWorldPortProof=($externalOut|Where-Object{$_ -match '^SCHOOL_EXTERNAL_WORLD_SOURCE_PORT_PROOF='}|Select-Object -Last 1) -replace '^SCHOOL_EXTERNAL_WORLD_SOURCE_PORT_PROOF=',''
  if($externalWorldPortStatus -ne 'PASS_SCHOOL_EXTERNAL_WORLD_SOURCE_PORT_V1'){ throw "EXTERNAL_WORLD_SOURCE_PORT_NOT_PASS:$externalWorldPortStatus" }
  $sourceMaterialStatus='EXTERNAL_MATERIAL_CANDIDATE_VALIDATED_THEN_INTERNAL_FACTORY_NORMALIZED'
} elseif($selected -ne 'InternalFactory'){
  throw "SCHOOL_SOURCE_NOT_IMPLEMENTED_IN_V1:$selected"
}
$factoryScript=[string]$policy.internal_factory.script
if(-not (Test-Path $factoryScript)){ throw "INTERNAL_FACTORY_SCRIPT_MISSING:$factoryScript" }
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $factoryScript -TargetAccepted $TargetAccepted -RunKind $RunKind -BatchSize $BatchSize -RunId $RunId -OrdinalOffset $OrdinalOffset -TopicsPlan $TopicsPlan *>&1 | ForEach-Object{[string]$_})
$out | ForEach-Object { Write-Host $_ }
$factoryStatus=($out|Where-Object{$_ -match '^FACTORY_STATUS='}|Select-Object -Last 1) -replace '^FACTORY_STATUS=',''
$factoryProof=($out|Where-Object{$_ -match '^FACTORY_PROOF_PATH='}|Select-Object -Last 1) -replace '^FACTORY_PROOF_PATH=',''
$factoryReportPath='operations/reports/CODEX_CANDIDATE_FACTORY_RUN_V1.json'
$factoryReport=$null
if(Test-Path $factoryReportPath){ $factoryReport=Get-Content $factoryReportPath -Raw|ConvertFrom-Json }
$status=if($factoryStatus -eq 'PASS_CODEX_CANDIDATE_FACTORY_GENERATION_V1'){'PASS_SCHOOL_SOURCE_ROUTER_V1'}else{'FAIL_SCHOOL_SOURCE_ROUTER_V1'}
$proof=[ordered]@{
  schema='school_source_router_selection_v1'
  status=$status
  run_id=$RunId
  source_mode=$SourceMode
  selected_source=$selected
  selection_reason=$selectionReason
  template_filter_status=$templateFilterStatus
  template_filter_reason=$templateFilterReason
  template_filter_proof=$templateFilterProof
  skipped_sources=@($skipped)
  target_accepted=$TargetAccepted
  run_kind=$RunKind
  batch_size=$BatchSize
  ordinal_offset=$OrdinalOffset
  topics_plan=$TopicsPlan
  factory_status=$factoryStatus
  factory_proof_path=$factoryProof
  factory_report_path=$factoryReportPath
  candidates_created=if($factoryReport){[int]$factoryReport.candidates_created}else{0}
  ready_source_material_kind='curriculum_candidate_atoms'
  source_authority_boundary='Source router selects bounded material supplier only; selected source cannot write compact memory and cannot decide school route.'
  codex_source_port_status=if($codexPortStatus){$codexPortStatus}else{$policy.codex_source_port.status}
  codex_source_port_proof=$codexPortProof
  source_material_status=$sourceMaterialStatus
  external_world_source_port_status=if($externalWorldPortStatus){$externalWorldPortStatus}else{$policy.external_world_source_port.status}
  external_world_source_port_proof=$externalWorldPortProof
  created_at=(Get-Date).ToString('o')
}
$proofPath='operations/reports/SCHOOL_SOURCE_ROUTER_SELECTION_V1.json'
WriteJson $proofPath $proof 80
Write-Host "SCHOOL_SOURCE_ROUTER_STATUS=$status"
Write-Host "SCHOOL_SOURCE_SELECTED=$selected"
Write-Host "SCHOOL_SOURCE_ROUTER_PROOF=$proofPath"
if($status -ne 'PASS_SCHOOL_SOURCE_ROUTER_V1'){ exit 1 }
