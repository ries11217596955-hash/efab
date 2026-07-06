param(
  [Parameter(Mandatory=$true)]
  [string]$PolicyRoot,

  [string]$OutputRoot = ""
)

$ErrorActionPreference = "Stop"

function Read-Json {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-Json {
  param([string]$Path, [object]$Object)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $Object | ConvertTo-Json -Depth 80 | Set-Content -Path $Path -Encoding UTF8
}

function Explain-Reason {
  param([string]$Code)

  switch ($Code) {
    "next_cycle_improvement_proven_for_accept_false" {
      return [ordered]@{
        code = $Code
        category = "usefulness"
        severity = "BLOCKS_FINAL_ACCEPT"
        meaning = "Sandbox next-cycle improvement is partial, but not enough for final absorb."
        repair_action = "run bounded absorb rehearsal and measure improvement after sandbox absorb"
      }
    }
    "live_task_success_delta_not_proven" {
      return [ordered]@{
        code = $Code
        category = "performance"
        severity = "BLOCKS_FINAL_ACCEPT"
        meaning = "No live-like task success delta has been proven yet."
        repair_action = "measure before/after success delta in bounded daemon trial"
      }
    }
    "live_daemon_autonomous_absorb_not_proven" {
      return [ordered]@{
        code = $Code
        category = "autonomy"
        severity = "BLOCKS_FINAL_ACCEPT"
        meaning = "Builder has not yet proven autonomous absorb inside a bounded live-like loop."
        repair_action = "run bounded live daemon absorb trial in sandbox"
      }
    }
    "controlled_absorb_rehearsal_missing" {
      return [ordered]@{
        code = $Code
        category = "absorb"
        severity = "BLOCKS_FINAL_ACCEPT"
        meaning = "Absorb has not been rehearsed under safety contracts."
        repair_action = "create sandbox absorb overlay and prove rollback/no accepted core mutation"
      }
    }
    default {
      return [ordered]@{
        code = $Code
        category = "unknown_or_generic"
        severity = "BLOCKS_FINAL_ACCEPT"
        meaning = "Policy gate reported this condition as missing for final accept."
        repair_action = "inspect upstream policy evidence and add a specific repair rule"
      }
    }
  }
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
  $OutputRoot = Join-Path (Split-Path -Parent $PolicyRoot) "PHASE162_POLICY_GATE_DECISION_EXPLANATION_$stamp"
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

$policy = Read-Json (Join-Path $PolicyRoot "autonomous_accept_policy_gate_result.json")
$policyValidation = Read-Json (Join-Path $PolicyRoot "autonomous_accept_policy_gate_validation.json")

$inputOk = (
  ([string]$policyValidation.status -eq "PASS") -and
  ([string]$policy.status -eq "PASS")
)

$missing = @($policy.missing_for_final_accept | ForEach-Object { [string]$_ })
if ($missing.Count -eq 0 -and ([bool]$policy.policy_granted_for_final_accept -eq $false)) {
  $missing = @("final_accept_blocked_without_explicit_reason")
}

$reasonObjects = @($missing | ForEach-Object { Explain-Reason -Code $_ })

$decisionCode = "DENY_FINAL_ACCEPT"
$decisionKind = "BLOCK_FINAL_ACCEPT"

if ([bool]$policy.policy_granted_for_bounded_absorb_trial -eq $true -and [bool]$policy.policy_granted_for_final_accept -eq $false) {
  $decisionCode = "ALLOW_BOUNDED_ABSORB_TRIAL_DENY_FINAL_ACCEPT"
  $decisionKind = "ALLOW_SANDBOX_REHEARSAL_ONLY"
}

if ([bool]$policy.policy_granted_for_final_accept -eq $true) {
  $decisionCode = "FINAL_ACCEPT_READY"
  $decisionKind = "ALLOW_FINAL_ACCEPT"
}

$shortSummary = if ($decisionCode -eq "ALLOW_BOUNDED_ABSORB_TRIAL_DENY_FINAL_ACCEPT") {
  "Policy allows only bounded sandbox absorb trial. Final absorb is blocked because live absorb proof, final next-cycle improvement proof, and live task delta are not proven."
} elseif ($decisionCode -eq "FINAL_ACCEPT_READY") {
  "Policy allows final accept."
} else {
  "Policy blocks final accept and does not grant bounded absorb trial. Repair policy inputs first."
}

$explanation = [ordered]@{
  schema = "PHASE162_POLICY_GATE_DECISION_EXPLANATION_V1"
  status = if ($inputOk) { "PASS" } else { "BLOCKED_INPUT_NOT_READY" }
  created_at = (Get-Date -Format o)
  policy_root = $PolicyRoot
  decision_code = $decisionCode
  decision_kind = $decisionKind
  decision_summary = $shortSummary
  machine_decision = [string]$policy.machine_decision
  next_machine_action = [string]$policy.next_machine_action
  allow_bounded_absorb_trial = [bool]$policy.policy_granted_for_bounded_absorb_trial
  allow_final_accept = [bool]$policy.policy_granted_for_final_accept
  accept_ready = [bool]$policy.accept_ready
  why_not_final_accept = $missing
  reason_codes = $reasonObjects
  next_repair_action = if ($decisionCode -eq "ALLOW_BOUNDED_ABSORB_TRIAL_DENY_FINAL_ACCEPT") {
    "BUILD_BOUNDED_LIVE_DAEMON_ABSORB_TRIAL_SANDBOX"
  } else {
    "REPAIR_POLICY_INPUTS"
  }
  agent_readable = [ordered]@{
    decision_code = $decisionCode
    allowed_action = [string]$policy.next_machine_action
    denied_action = "FINAL_ACCEPT"
    blocked_because = $missing
  }
  human_readable_short = $shortSummary
  accepted_atom_claimed = $false
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}

Write-Json -Path (Join-Path $OutputRoot "policy_gate_decision_explanation.json") -Object $explanation

@"
# PHASE162 Policy Gate Decision Explanation Report

## Decision

- decision_code: $decisionCode
- decision_kind: $decisionKind
- allow_bounded_absorb_trial: $($explanation.allow_bounded_absorb_trial)
- allow_final_accept: $($explanation.allow_final_accept)
- next_machine_action: $($explanation.next_machine_action)
- accept_ready: $($explanation.accept_ready)

## Short Explanation

$shortSummary

## Why Final Accept Is Blocked

$($missing | ForEach-Object { "- $_" } | Out-String)

## Next Repair Action

$($explanation.next_repair_action)

## Boundary

No accepted core write happened.
"@ | Set-Content -Path (Join-Path $OutputRoot "PHASE162_POLICY_GATE_DECISION_EXPLANATION_REPORT.md") -Encoding UTF8

[pscustomobject]@{
  status = $explanation.status
  output_root = $OutputRoot
  decision_code = $decisionCode
  allow_bounded_absorb_trial = [bool]$explanation.allow_bounded_absorb_trial
  allow_final_accept = [bool]$explanation.allow_final_accept
  next_machine_action = [string]$explanation.next_machine_action
  reason_count = $missing.Count
  accepted_state_mutated = $false
  accepted_memory_mutated = $false
  accepted_self_model_mutated = $false
}
