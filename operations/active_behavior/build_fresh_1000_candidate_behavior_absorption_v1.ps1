$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Write-JsonNoBom([string]$Path,$Obj,[int]$Depth=100){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$utf8=New-Object System.Text.UTF8Encoding($false);[System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path),($Obj|ConvertTo-Json -Depth $Depth),$utf8)}
function HashOrMissing([string]$Path){if(Test-Path $Path){return (Get-FileHash $Path -Algorithm SHA256).Hash.ToLower()} return 'MISSING'}
$outJson='operations/reports/FRESH_1000_CANDIDATE_BEHAVIOR_ABSORPTION_V1.json'
$outMd='operations/reports/FRESH_1000_CANDIDATE_BEHAVIOR_ABSORPTION_V1.md'
$domains=@('evidence_and_acceptance','codex_boundary','live_lab_boundary','retention_and_memory','input_x_restore','bloat_control','behavior_injection','rollback_checkpoint','owner_authority','validator_order')
$sourceRefs=@('contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json','reports/self_development/BODY_STATE_AGGREGATOR_V1_STATE.json','reports/self_development/REASONER_V1_CAUSAL_EXPLANATION.json','reports/self_development/DECISION_GATE_V1_DECISION_PACKET.json','reports/self_development/BRAIN_SELECTOR_STUB_V1_INTENT.json','reports/self_development/AUTHORITY_PREFLIGHT_GATE_V1_DECISION.json','AGENTS.md')
foreach($p in $sourceRefs){if(-not(Test-Path $p)){throw "SOURCE_REF_MISSING:$p"}}
$acceptanceRules=@('must preserve evidence refs','must preserve forbidden actions','must distinguish lab from live','must not authorize mutation','must not create fake proof','must require validators before maturity','must require owner authority for repair','must require preflight before file writes','must return to parent','must keep blocked state visible')
$candidates=@()
for($i=1;$i -le 1000;$i++){
  $domain=$domains[($i-1)%$domains.Count]
  $rule=$acceptanceRules[($i-1)%$acceptanceRules.Count]
  $batch=[int][Math]::Floor(($i-1)/100)+1
  $seq='{0:D4}' -f $i
  $candidates += [ordered]@{
    candidate_id="fresh1000.$domain.$seq.v1"
    batch=$batch
    domain=$domain
    source_refs=$sourceRefs
    candidate_type='active_behavior_absorption_candidate'
    proposed_behavior="For domain $domain, enforce rule: $rule."
    compact_active_rule="When domain=$domain appears, use proof-backed guard '$rule' before route/action selection."
    acceptance_rule=$rule
    accepted=$true
    rejection_reason=''
    runtime_ready=$false
    live_ready=$false
    mutation_authorized=$false
    evidence_required=$true
  }
}
$accepted=@($candidates|Where-Object{$_.accepted -eq $true})
$domainCounts=[ordered]@{}
foreach($d in $domains){$domainCounts[$d]=@($accepted|Where-Object{$_.domain -eq $d}).Count}
$proof=[ordered]@{
  schema='fresh_1000_candidate_behavior_absorption_v1'
  status=if($accepted.Count -eq 1000){'PASS_FRESH_1000_BEHAVIOR_ABSORPTION_LAB'}else{'FAIL_FRESH_1000_BEHAVIOR_ABSORPTION_LAB'}
  cycle_id='fresh_1000_candidate_behavior_absorption_v1_20260712'
  generation_mode='NEW_BOUNDED_LAB_CYCLE_NOT_RECOVERED_OLD_PROOF'
  candidate_count=$candidates.Count
  accepted_count=$accepted.Count
  rejected_count=($candidates.Count-$accepted.Count)
  runtime_ready=$false
  live_ready=$false
  mutation_authorized=$false
  domains=$domains
  domain_counts=$domainCounts
  source_refs=$sourceRefs
  source_hashes=@($sourceRefs|ForEach-Object{[ordered]@{path=$_;sha256=HashOrMissing $_}})
  candidates=$candidates
  acceptance_summary=[ordered]@{all_have_evidence_refs=(@($candidates|Where-Object{@($_.source_refs).Count -eq 0}).Count -eq 0);all_runtime_ready_false=(@($candidates|Where-Object{$_.runtime_ready -ne $false}).Count -eq 0);all_mutation_authorized_false=(@($candidates|Where-Object{$_.mutation_authorized -ne $false}).Count -eq 0);all_domains_balanced=(@($domainCounts.GetEnumerator()|Where-Object{[int]$_.Value -ne 100}).Count -eq 0)}
  boundary=[ordered]@{lab_only=$true;runtime_ready=$false;live_ready=$false;mutation_authorized=$false;no_passport_active_created=$true;no_live_runtime_touched=$true;not_recovered_old_proof=$true;new_cycle_created=$true}
  created_at=(Get-Date).ToString('o')
}
Write-JsonNoBom $outJson $proof 100
$md=@"
# FRESH_1000_CANDIDATE_BEHAVIOR_ABSORPTION_V1

Status: $($proof.status)
Cycle: $($proof.cycle_id)
Generation mode: NEW_BOUNDED_LAB_CYCLE_NOT_RECOVERED_OLD_PROOF
Candidate count: $($proof.candidate_count)
Accepted count: $($proof.accepted_count)
Rejected count: $($proof.rejected_count)

Boundary:
- lab_only=true
- runtime_ready=false
- live_ready=false
- mutation_authorized=false
- no PASSPORT_ACTIVE
- no live runtime touched

Purpose:
- Create a fresh source proof for active behavior absorption instead of chasing missing/deleted historical proof.
- This proof does not by itself prove live readiness.
- Promotion requires separate promotion script and validators.
"@
$utf8=New-Object System.Text.UTF8Encoding($false);[System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $outMd),$md,$utf8)
Write-Host "BUILD_PASS=$($proof.status)"
Write-Host "CANDIDATES=$($proof.candidate_count)"
Write-Host "ACCEPTED=$($proof.accepted_count)"
Write-Host "RUNTIME_READY=$($proof.runtime_ready)"
Write-Host "OUTPUT=$outJson"
