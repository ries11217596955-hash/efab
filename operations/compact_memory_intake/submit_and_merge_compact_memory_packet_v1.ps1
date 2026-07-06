param(
  [Parameter(Mandatory=$true)][string]$PacketPath,
  [switch]$Merge,
  [string]$PolicyPath = "operations/compact_memory_intake/multi_source_compact_memory_intake_policy.json"
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/compact_memory_intake/submit_compact_memory_packet_v1.ps1 -PacketPath $PacketPath -PolicyPath $PolicyPath *>&1 | ForEach-Object{[string]$_})
$out|ForEach-Object{Write-Host $_}
$status=($out|Where-Object{$_ -match '^INTAKE_STATUS='}|Select-Object -Last 1) -replace '^INTAKE_STATUS=',''
$q=($out|Where-Object{$_ -match '^INTAKE_QUEUE_PATH='}|Select-Object -Last 1) -replace '^INTAKE_QUEUE_PATH=',''
if($status -ne 'PASS_MULTI_SOURCE_COMPACT_MEMORY_INTAKE_SUBMIT_V1'){ throw "INTAKE_SUBMIT_NOT_PASS:$status" }
Write-Host "SUBMIT_AND_MERGE_INTAKE_QUEUE_PATH=$q"
if($Merge){
  if(-not (Test-Path $q)){ throw "QUEUE_PACKET_MISSING_FOR_MERGE:$q" }
  $mergeOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/compact_memory_intake/merge_compact_memory_intake_queue_v1.ps1 -PacketPath $q -ProcessLimit 1 -PolicyPath $PolicyPath *>&1 | ForEach-Object{[string]$_})
  $mergeOut|ForEach-Object{Write-Host $_}
  $mergeStatus=($mergeOut|Where-Object{$_ -match '^MERGE_QUEUE_STATUS='}|Select-Object -Last 1) -replace '^MERGE_QUEUE_STATUS=',''
  if($mergeStatus -ne 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1'){ throw "MERGE_QUEUE_NOT_PASS:$mergeStatus" }
  Write-Host "SUBMIT_AND_MERGE_STATUS=PASS_SUBMIT_AND_MERGE_COMPACT_MEMORY_PACKET_V1"
} else {
  Write-Host "SUBMIT_AND_MERGE_STATUS=PASS_SUBMIT_ONLY_COMPACT_MEMORY_PACKET_V1"
}