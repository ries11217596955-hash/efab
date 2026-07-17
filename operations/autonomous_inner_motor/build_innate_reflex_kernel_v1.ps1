param(
    [string]$ManifestPath = 'operations/autonomous_inner_motor/innate_reflex_kernel_v1.json',
    [string]$BodyOrganKnowledgePath = 'operations/autonomous_inner_motor/organ_knowledge/BODY_SELF_INSPECTION_CIRCUIT_V1_KNOWLEDGE.json',
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
function Write-CleanJson($Path, $Data, [int]$Depth = 60) {
    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $json = ($Data | ConvertTo-Json -Depth $Depth) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path), $json.TrimEnd() + "`n", (New-Object System.Text.UTF8Encoding($false)))
}
if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) { throw "innate reflex manifest missing: $ManifestPath" }
if (-not (Test-Path -LiteralPath $BodyOrganKnowledgePath -PathType Leaf)) { throw "body organ knowledge missing: $BodyOrganKnowledgePath" }
$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
$bodyKnowledge = Get-Content -Raw -LiteralPath $BodyOrganKnowledgePath | ConvertFrom-Json
$reflexes = @($manifest.reflexes)
if ($reflexes.Count -lt 25) { throw "expected at least 25 reflex slots, got $($reflexes.Count)" }
$body = @($reflexes | Where-Object { $_.reflex_id -eq 'body_audit_reflex' } | Select-Object -First 1)[0]
if ($null -eq $body) { throw 'body_audit_reflex missing' }
if ($body.built_in -ne $true) { throw 'body_audit_reflex must be built_in=true' }
if ($body.callable -ne $true) { throw 'body_audit_reflex must be callable=true for wake-default observe-only sensing' }
if ($body.status -ne 'DEFAULT_WAKE_OBSERVE') { throw "body_audit_reflex status mismatch: $($body.status)" }
if ($body.organ_id -ne 'BODY_SELF_INSPECTION_CIRCUIT_V1') { throw "body_audit_reflex organ mismatch: $($body.organ_id)" }
if ($body.can_hear_body -ne $true) { throw 'body_audit_reflex can_hear_body must be true' }
if ($body.wake_default -ne $true) { throw 'body_audit_reflex wake_default must be true' }
if ($body.requires_owner_permission -ne $false) { throw 'body_audit_reflex must not require owner permission for wake observe' }
if ($body.trigger_required -ne $false) { throw 'body_audit_reflex must not require trigger for wake observe' }
if ($body.body_inspection_invoked -ne $false) { throw 'manifest must not claim body inspection already invoked' }
if ($bodyKnowledge.organ_id -ne 'BODY_SELF_INSPECTION_CIRCUIT_V1') { throw 'body organ knowledge organ mismatch' }
foreach ($r in @($reflexes | Where-Object { $_.reflex_id -ne 'body_audit_reflex' })) {
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
    wake_default_count = @($reflexes | Where-Object { $_.wake_default -eq $true -or $_.status -eq 'DEFAULT_WAKE_OBSERVE' }).Count
    available_not_wired_count = @($reflexes | Where-Object { $_.status -eq 'AVAILABLE_NOT_WIRED' }).Count
    reserved_count = @($reflexes | Where-Object { $_.status -eq 'RESERVED_NOT_BUILT' }).Count
    body_audit_reflex = [ordered]@{
        reflex_id = $body.reflex_id; built_in = [bool]$body.built_in; callable = [bool]$body.callable; status = $body.status
        invocation_policy = $body.invocation_policy; wake_default = [bool]$body.wake_default; requires_owner_permission = [bool]$body.requires_owner_permission; trigger_required = [bool]$body.trigger_required
        organ_id = $body.organ_id; organ_status = $body.organ_status; entrypoint = $body.entrypoint; can_hear_body = [bool]$body.can_hear_body
        invoked_this_cycle = [bool]$body.invoked_this_cycle; body_inspection_invoked = [bool]$body.body_inspection_invoked
    }
    boundary = [ordered]@{ manifest_only = $true; body_inspection_invoked = $false; active_memory_mutated = $false; live_process_touched = $false; repair_executed = $false; legacy_launch_used = $false; runner_integrated = $true; wake_default_reflex_ready = $true }
}
if ($OutputPath) { Write-CleanJson $OutputPath $runtime 60 }
return $runtime
