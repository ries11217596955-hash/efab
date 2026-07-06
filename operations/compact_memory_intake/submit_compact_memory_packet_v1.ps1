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
  topics=@($topics)
  maturity_delta=$maturityDelta
  memory_support_policy=$supportPolicy
  focus_boosts=@($(if($packet.influence -and $packet.influence.focus_boosts){@($packet.influence.focus_boosts)}else{@($topics)}))
  behavior_rule='Autonomous life must inspect this signal after path selection and before execution; validated knowledge supports the selected path when topics match, but must not override path selection.'
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
  topics=@($topics)
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