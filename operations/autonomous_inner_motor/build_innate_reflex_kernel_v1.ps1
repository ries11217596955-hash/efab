
param(
    [string]$ManifestPath = 'operations/autonomous_inner_motor/innate_reflex_kernel_v1.json',
    [string]$BodyOrganKnowledgePath = 'operations/autonomous_inner_motor/organ_knowledge/BODY_SELF_INSPECTION_CIRCUIT_V1_KNOWLEDGE.json',
    [string]$OutputPath
)
$ErrorActionPreference = 'Stop'
function Write-CleanJson($Path, $Data, [int]$Depth = 80) {
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $json = ($Data | ConvertTo-Json -Depth $Depth) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path), $json.TrimEnd() + "`n", (New-Object System.Text.UTF8Encoding($false)))
}
$wakeDefaultIds=@('body_audit_reflex','repo_reality_reflex','process_scan_reflex','runtime_pressure_reflex','active_memory_read_reflex')
if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) { throw "innate reflex manifest missing: $ManifestPath" }
if (-not (Test-Path -LiteralPath $BodyOrganKnowledgePath -PathType Leaf)) { throw "body organ knowledge missing: $BodyOrganKnowledgePath" }
$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
$bodyKnowledge = Get-Content -Raw -LiteralPath $BodyOrganKnowledgePath | ConvertFrom-Json
$reflexes = @($manifest.reflexes)
if ($reflexes.Count -lt 25) { throw "expected at least 25 reflex slots, got $($reflexes.Count)" }
foreach($id in $wakeDefaultIds) {
    $r=@($reflexes | Where-Object { $_.reflex_id -eq $id } | Select-Object -First 1)[0]
    if($null -eq $r){ throw "wake_default_reflex_missing:$id" }
    if($r.built_in -ne $true){ throw "wake_default_not_builtin:$id" }
    if($r.callable -ne $true){ throw "wake_default_not_callable:$id" }
    if($r.wake_default -ne $true){ throw "wake_default_flag_missing:$id" }
    if($r.requires_owner_permission -ne $false){ throw "wake_default_requires_owner_permission:$id" }
    if($r.trigger_required -ne $false){ throw "wake_default_trigger_required:$id" }
}
$body = @($reflexes | Where-Object { $_.reflex_id -eq 'body_audit_reflex' } | Select-Object -First 1)[0]
if ($body.status -ne 'DEFAULT_WAKE_OBSERVE') { throw "body_audit_reflex status mismatch: $($body.status)" }
if ($body.organ_id -ne 'BODY_SELF_INSPECTION_CIRCUIT_V1') { throw "body_audit_reflex organ mismatch: $($body.organ_id)" }
if ($body.can_hear_body -ne $true) { throw 'body_audit_reflex can_hear_body must be true' }
if ($bodyKnowledge.organ_id -ne 'BODY_SELF_INSPECTION_CIRCUIT_V1') { throw 'body organ knowledge organ mismatch' }
foreach ($r in @($reflexes | Where-Object { $wakeDefaultIds -notcontains $_.reflex_id })) {
    if ($r.built_in -ne $true) { throw "reserved reflex is not built_in=true: $($r.reflex_id)" }
    if ($r.callable -ne $false) { throw "reserved reflex should not be callable yet: $($r.reflex_id)" }
    if ($r.status -ne 'RESERVED_NOT_BUILT') { throw "reserved reflex status mismatch: $($r.reflex_id)=$($r.status)" }
    if ($r.maturity -ne 'RESERVED_SLOT') { throw "reserved reflex maturity mismatch: $($r.reflex_id)=$($r.maturity)" }
}
$runtime = [ordered]@{
    schema = 'callable_innate_reflex_kernel_runtime_v1'
    status = 'PASS_CALLABLE_INNATE_REFLEX_KERNEL_V1_SLICE_A'
    source = $ManifestPath
    body_organ_knowledge = $BodyOrganKnowledgePath
    reflex_count = $reflexes.Count
    callable_count = @($reflexes | Where-Object { $_.callable -eq $true }).Count
    wake_default_count = @($reflexes | Where-Object { $_.wake_default -eq $true }).Count
    available_not_wired_count = @($reflexes | Where-Object { $_.status -eq 'AVAILABLE_NOT_WIRED' }).Count
    reserved_count = @($reflexes | Where-Object { $_.status -eq 'RESERVED_NOT_BUILT' }).Count
    wake_default_ids = $wakeDefaultIds
    body_audit_reflex = [ordered]@{
        reflex_id = $body.reflex_id; built_in = [bool]$body.built_in; callable = [bool]$body.callable; status = $body.status
        invocation_policy = $body.invocation_policy; wake_default = [bool]$body.wake_default; requires_owner_permission = [bool]$body.requires_owner_permission; trigger_required = [bool]$body.trigger_required
        organ_id = $body.organ_id; organ_status = $body.organ_status; entrypoint = $body.entrypoint; can_hear_body = [bool]$body.can_hear_body
        invoked_this_cycle = [bool]$body.invoked_this_cycle; body_inspection_invoked = [bool]$body.body_inspection_invoked
    }
    boundary = [ordered]@{ manifest_only = $true; body_inspection_invoked = $false; active_memory_mutated = $false; live_process_touched = $false; repair_executed = $false; legacy_launch_used = $false; runner_integrated = $true; wake_default_reflex_ready = $true }
}
if ($OutputPath) { Write-CleanJson $OutputPath $runtime 80 }
return $runtime
