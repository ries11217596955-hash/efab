param(
  [string]$EpisodeId = '',
  [Parameter(Mandatory=$true)][string]$Topic,
  [Parameter(Mandatory=$true)][string]$Situation,
  [Parameter(Mandatory=$true)][string]$Hypothesis,
  [Parameter(Mandatory=$true)][string]$ActionTaken,
  [Parameter(Mandatory=$true)][string]$Result,
  [string]$FailureReason = '',
  [string]$Correction = '',
  [Parameter(Mandatory=$true)][string]$ReuseHint,
  [Parameter(Mandatory=$true)][ValidateSet('HYPOTHESIS_OPEN','HYPOTHESIS_FAILED','HYPOTHESIS_SUPPORTED','PROVEN_LAB','PROVEN_LIVE','REUSABLE_LESSON','DO_NOT_REPEAT')][string]$Status,
  [Parameter(Mandatory=$true)][ValidateSet('low','medium','high')][string]$Confidence,
  [Parameter(Mandatory=$true)][string[]]$ProofRefs,
  [string[]]$Tags = @(),
  [string]$OutputRoot = '.runtime/episodic_memory_v1/cells',
  [int]$MaxCellBytes = 12000
)
$ErrorActionPreference='Stop'
function New-SafeSlug([string]$Value) {
  if([string]::IsNullOrWhiteSpace($Value)) { return 'unknown' }
  $slug = ($Value.ToLowerInvariant() -replace '[^a-z0-9_\-]+','_').Trim('_')
  if([string]::IsNullOrWhiteSpace($slug)) { return 'unknown' }
  if($slug.Length -gt 80) { $slug = $slug.Substring(0,80).Trim('_') }
  return $slug
}
function Assert-NonEmpty([string]$Value,[string]$Name){ if([string]::IsNullOrWhiteSpace($Value)){ throw "EPISODE_FIELD_EMPTY:$Name" } }
function Assert-NoRawDump([string]$Value,[string]$Name){
  $bad=@('stdout_preview','stderr_preview','stdout_tail','stderr_tail','managed_run-','CommandLine=','System.Management.Automation',' at line:','CategoryInfo','FullyQualifiedErrorId')
  foreach($marker in $bad){ if($Value -like "*$marker*"){ throw "RAW_DUMP_MARKER_IN_FIELD:${Name}:${marker}" } }
  if($Value.Length -gt 1600){ throw "EPISODE_FIELD_TOO_LONG:$Name" }
}
Assert-NonEmpty $Topic 'topic'
Assert-NonEmpty $Situation 'situation'
Assert-NonEmpty $Hypothesis 'hypothesis'
Assert-NonEmpty $ActionTaken 'action_taken'
Assert-NonEmpty $Result 'result'
Assert-NonEmpty $ReuseHint 'reuse_hint'
foreach($pair in @(@('topic',$Topic),@('situation',$Situation),@('hypothesis',$Hypothesis),@('action_taken',$ActionTaken),@('result',$Result),@('failure_reason',$FailureReason),@('correction',$Correction),@('reuse_hint',$ReuseHint))){ Assert-NoRawDump $pair[1] $pair[0] }
if($Status -eq 'HYPOTHESIS_FAILED' -and [string]::IsNullOrWhiteSpace($FailureReason)){ throw 'FAILED_EPISODE_REQUIRES_FAILURE_REASON' }
if($Status -in @('PROVEN_LIVE','REUSABLE_LESSON') -and @($ProofRefs).Count -lt 1){ throw 'PROVEN_EPISODE_REQUIRES_PROOF_REF' }
$proofObjects=@()
foreach($ref in @($ProofRefs)){
  if([string]::IsNullOrWhiteSpace($ref)){ throw 'EMPTY_PROOF_REF' }
  if(-not (Test-Path $ref)){ throw "PROOF_REF_MISSING:$ref" }
  $item=Get-Item $ref
  if($item.Length -gt 2MB){ throw "PROOF_REF_TOO_LARGE:$ref" }
  $proofObjects += [ordered]@{ path=$ref; exists=$true; sha256=(Get-FileHash -Algorithm SHA256 -Path $ref).Hash; bytes=$item.Length }
}
if([string]::IsNullOrWhiteSpace($EpisodeId)){ $EpisodeId = (New-SafeSlug $Topic) + '_' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ') }
$cell=[ordered]@{
  schema='episodic_memory_cell_v1'
  memory_type='episodic'
  episode_id=$EpisodeId
  topic=$Topic
  tags=@($Tags)
  situation=$Situation
  hypothesis=$Hypothesis
  action_taken=$ActionTaken
  result=$Result
  failure_reason=$FailureReason
  correction=$Correction
  reuse_hint=$ReuseHint
  status=$Status
  confidence=$Confidence
  proof_refs=@($proofObjects)
  raw_trace_included=$false
  compact_rule='episode digest only; no raw stdout/stderr/archive dump'
  created_at=(Get-Date).ToString('o')
}
$json=$cell | ConvertTo-Json -Depth 30
$bytes=[System.Text.Encoding]::UTF8.GetByteCount($json)
if($bytes -gt $MaxCellBytes){ throw "EPISODE_CELL_TOO_LARGE:$bytes" }
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$outPath=Join-Path $OutputRoot ((New-SafeSlug $EpisodeId)+'.json')
$json | Set-Content -Path $outPath -Encoding UTF8
$verify=Get-Content $outPath -Raw | ConvertFrom-Json
if($verify.schema -ne 'episodic_memory_cell_v1'){ throw 'EPISODE_CELL_WRITE_VERIFY_FAILED' }
Write-Output 'EPISODE_CELL_STATUS=PASS_EPISODIC_MEMORY_CELL_V1'
Write-Output ('EPISODE_CELL_PATH='+$outPath)
Write-Output ('EPISODE_CELL_BYTES='+$bytes)
Write-Output 'RAW_TRACE_INCLUDED=false'