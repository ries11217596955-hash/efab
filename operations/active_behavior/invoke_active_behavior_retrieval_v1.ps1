param(
    [string]$Domain = "behavior_injection",
    [int]$Limit = 5
)
$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$pointerPath="reports/self_development/accepted_change_memory_snapshot.json"
if(-not(Test-Path $pointerPath)){ throw "ACTIVE_POINTER_MISSING" }
$pointer=Get-Content $pointerPath -Raw | ConvertFrom-Json
if($pointer.schema -ne "efab_active_memory_pointer_v1"){ throw "ACTIVE_POINTER_BAD_SCHEMA" }
if($pointer.status -ne "ACTIVE_POINTER_TO_COMPACT_ACCEPTED_BEHAVIOR_STORE"){ throw "ACTIVE_POINTER_NOT_ACTIVE" }
$index=Get-Content $pointer.active_index_path -Raw | ConvertFrom-Json
$records=@($index.records | Where-Object { $_.domain -eq $Domain } | Select-Object -First $Limit)
$result=[pscustomobject]@{
  schema="active_behavior_retrieval_result_v1"
  status= if($records.Count -gt 0){"PASS"}else{"NO_MATCH"}
  runtime_ready=$false
  domain=$Domain
  requested_limit=$Limit
  returned_count=$records.Count
  promotion_id=$pointer.promotion_id
  records=@($records)
}
$result | ConvertTo-Json -Depth 20