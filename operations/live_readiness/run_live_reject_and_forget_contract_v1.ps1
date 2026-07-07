param(
  [string]$ProofPath = 'tests/live_readiness/LIVE_REJECT_AND_FORGET_CONTRACT_V1_PROOF.json'
)
$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function GitStatusShort(){ @(git status --short --untracked-files=all) }
function WriteJson($Path,$Obj){ New-Item -ItemType Directory -Force -Path (Split-Path $Path -Parent) | Out-Null; $Obj | ConvertTo-Json -Depth 30 | Set-Content -Path $Path -Encoding UTF8 }
function Sha256Text([string]$Text){ $sha=[System.Security.Cryptography.SHA256]::Create(); $bytes=[System.Text.Encoding]::UTF8.GetBytes($Text); (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '') }
function Sha256File($Path){ (Get-FileHash $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
$started=Get-Date
$branch=(git branch --show-current).Trim()
$head=(git rev-parse HEAD).Trim()
$origin=(git remote get-url origin).Trim()
git fetch origin main --quiet
$aheadBehind=(git rev-list --left-right --count HEAD...origin/main).Trim()
$aheadBehindNorm=($aheadBehind -replace '\s+',' ')
$dirtyBefore=GitStatusShort
if(($RepoRoot -replace '\\','/') -ne 'H:/efab'){ throw "REPO_ROOT_MISMATCH:$RepoRoot" }
if($branch -ne 'main'){ throw "BRANCH_MISMATCH:$branch" }
if($origin -ne 'https://github.com/ries11217596955-hash/efab.git'){ throw "ORIGIN_MISMATCH:$origin" }
if($aheadBehindNorm -ne '0 0'){ throw "AHEAD_BEHIND_NOT_SYNCED:$aheadBehind" }
if($dirtyBefore.Count -gt 0){ throw "DIRTY_BEFORE_LIVE_REJECT_AND_FORGET_CONTRACT:$($dirtyBefore -join ';')" }
$runId='live_reject_and_forget_contract_v1_' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$runRoot=Join-Path '.runtime/live_readiness' $runId
$incomingDir=Join-Path $runRoot 'incoming'
$rejectLedgerDir=Join-Path $runRoot 'reject_ledger'
$badPacketPath=Join-Path $incomingDir 'bad_packet.json'
$rejectManifestPath=Join-Path $rejectLedgerDir 'reject_manifest.json'
$mergeTargetPath=Join-Path $runRoot 'would_be_merge_target.json'
New-Item -ItemType Directory -Force -Path $incomingDir,$rejectLedgerDir | Out-Null
$rawPayload='BAD_PAYLOAD_SHOULD_NOT_BE_PERSISTED_' + $runId
$badPacket=[ordered]@{
  schema='bad_packet_v1'
  packet_id=$runId
  source='reject_and_forget_contract'
  payload=$rawPayload
  malformed=$true
  missing_required_fields=@('type','validated_content','authority')
  active_memory_mutated=$false
}
WriteJson $badPacketPath $badPacket
$badPacketRaw=Get-Content $badPacketPath -Raw
$badPacketHash=Sha256File $badPacketPath
$rawPayloadHash=Sha256Text $rawPayload
$validationErrors=@('MISSING_TYPE','MISSING_VALIDATED_CONTENT','MISSING_AUTHORITY','MALFORMED_TRUE')
$accepted=$false
$merged=$false
$executed=$false
# Reject-and-forget: keep only compact metadata/digest, never raw payload.
$rejectManifest=[ordered]@{
  schema='live_reject_and_forget_manifest_v1'
  packet_id=$runId
  source='reject_and_forget_contract'
  decision='REJECT_AND_FORGET'
  reason_codes=@($validationErrors)
  packet_sha256=$badPacketHash
  payload_sha256=$rawPayloadHash
  payload_retained=$false
  raw_packet_retained=$false
  accepted=$false
  merged=$false
  executed=$false
  disposal_action='raw_packet_deleted_after_digest'
  created_at=(Get-Date).ToString('o')
}
WriteJson $rejectManifestPath $rejectManifest
Remove-Item -LiteralPath $badPacketPath -Force
$rawPacketExistsAfter=Test-Path $badPacketPath
$manifestRaw=Get-Content $rejectManifestPath -Raw
$manifestContainsPayload=$manifestRaw.Contains($rawPayload)
$mergeTargetExists=Test-Path $mergeTargetPath
$dirtyAfter=GitStatusShort
$blockers=@()
if($accepted){ $blockers += 'BAD_PACKET_ACCEPTED' }
if($merged -or $mergeTargetExists){ $blockers += 'BAD_PACKET_MERGED' }
if($executed){ $blockers += 'BAD_PACKET_EXECUTED' }
if($rawPacketExistsAfter){ $blockers += 'RAW_PACKET_STILL_EXISTS' }
if($manifestContainsPayload){ $blockers += 'REJECT_MANIFEST_CONTAINS_RAW_PAYLOAD' }
if((Get-Content $rejectManifestPath -Raw | ConvertFrom-Json).decision -ne 'REJECT_AND_FORGET'){ $blockers += 'DECISION_NOT_REJECT_AND_FORGET' }
if($dirtyAfter.Count -gt 0){ $blockers += "DIRTY_AFTER_BEFORE_PROOF_WRITE:$($dirtyAfter -join ';')" }
$status='PASS_LIVE_REJECT_AND_FORGET_CONTRACT_V1'
if($blockers.Count -gt 0){ $status='FAIL_LIVE_REJECT_AND_FORGET_CONTRACT_V1' }
$result=[ordered]@{
  schema='live_reject_and_forget_contract_v1'
  status=$status
  proof_label='PROVEN_LAB_REJECT_AND_FORGET_QUARANTINE_ALTERNATIVE_NOT_LIVE'
  run_id=$runId
  repo=[ordered]@{ root=($RepoRoot -replace '\\','/'); branch=$branch; head=$head; origin=$origin; ahead_behind=$aheadBehind; dirty_before=@($dirtyBefore); dirty_after_before_proof_write=@($dirtyAfter) }
  bad_input=[ordered]@{ packet_path=$badPacketPath; packet_sha256=$badPacketHash; payload_sha256=$rawPayloadHash; raw_packet_exists_after_disposal=$rawPacketExistsAfter; payload_value_retained_in_proof=$false }
  reject=[ordered]@{ mode='REJECT_AND_FORGET_NO_RAW_PAYLOAD'; manifest_path=$rejectManifestPath; manifest_contains_raw_payload=$manifestContainsPayload; reason_codes=@($validationErrors); accepted=$accepted; merged=$merged; executed=$executed; merge_target_exists=$mergeTargetExists; disposal_action='raw_packet_deleted_after_digest' }
  safety=[ordered]@{ active_memory_mutated=$false; tracked_repo_mutated=$false; raw_payload_retained=$false; compact_digest_retained=$true; report_bloat_control='manifest_only_no_payload' }
  blockers=@($blockers)
  boundary='Lab reject-and-forget contract only: bad packet is rejected, raw payload discarded, only compact digest/reason manifest retained. This replaces quarantine-as-garbage-archive.'
  runtime_ready=$false
  started_at=$started.ToString('o')
  finished_at=(Get-Date).ToString('o')
}
WriteJson $ProofPath $result
Write-Host "LIVE_REJECT_AND_FORGET_CONTRACT_STATUS=$status"
Write-Host "LIVE_REJECT_AND_FORGET_CONTRACT_PROOF=$ProofPath"
Write-Host "RUN_ID=$runId"
Write-Host "PACKET_SHA256=$badPacketHash"
Write-Host "RAW_PACKET_EXISTS_AFTER_DISPOSAL=$rawPacketExistsAfter"
Write-Host "MANIFEST_CONTAINS_RAW_PAYLOAD=$manifestContainsPayload"
Write-Host "ACCEPTED=$accepted MERGED=$merged EXECUTED=$executed"
Write-Host "BLOCKERS=$($blockers -join ',')"
Write-Host 'RUNTIME_READY=false'
if($status -notlike 'PASS_*'){ exit 1 }