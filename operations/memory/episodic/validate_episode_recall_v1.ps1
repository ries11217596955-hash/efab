$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$recall='operations/memory/episodic/get_episode_recall_v1.ps1'
$writer='operations/memory/episodic/write_episode_cell_v1.ps1'
Assert (Test-Path $recall) 'RECALL_HELPER_MISSING'
Assert (Test-Path $writer) 'EPISODE_WRITER_MISSING'
. (Resolve-Path $recall)
$outRoot='.runtime/episodic_memory_v1/recall_validator_cells'
Remove-Item $outRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$proofAimo='tests/live_start/AIMO_GROWTH_SELECTOR_HOTSWAP_V1_PROOF.json'
$proofSelector='tests/autonomous_inner_motor/GROWTH_DIRECTED_TASK_SELECTION_V1_PROOF.json'
& $writer -EpisodeId 'recall_real_aimo_selector_ordered_payload_lesson_v1' -Topic 'aimo selector ordered payload validator lesson' -Situation 'Live AIMO selector fallback exposed that lab validation missed ordered payload shape.' -Hypothesis 'Episodic recall should surface this lesson before future selector or memory routing changes.' -ActionTaken 'Stored a reusable episodic cell with proof references and reuse hint.' -Result 'Recall by selector, ordered payload, and live-shaped terms should find this episode.' -FailureReason 'Validator did not model the live-shaped ordered payload.' -Correction 'Add live-shaped payload fixtures before accepting routing code.' -ReuseHint 'Before editing selector or memory routing, test PSCustomObject and ordered payload shapes.' -Status 'REUSABLE_LESSON' -Confidence 'high' -ProofRefs @($proofAimo,$proofSelector) -Tags @('aimo','selector','ordered_payload','validator','memory_routing') -OutputRoot $outRoot | Out-Null
for($i=1;$i -le 50;$i++){
  & $writer -EpisodeId "recall_noise_$i" -Topic "unrelated synthetic topic $i" -Situation "Noise episode $i for recall volume validation." -Hypothesis 'Noise cells should not outrank the real selector memory.' -ActionTaken 'Wrote bounded noise cell.' -Result 'Noise cell created.' -ReuseHint 'No relevant routing lesson here.' -Status 'HYPOTHESIS_SUPPORTED' -Confidence 'medium' -ProofRefs @($proofSelector) -Tags @('noise','volume') -OutputRoot $outRoot | Out-Null
}
Set-Content -Path (Join-Path $outRoot 'malformed.json') -Value '{ not valid json' -Encoding UTF8
$rec=Get-EpisodicMemoryRecall -QueryTerms @('selector ordered payload live-shaped validator memory routing') -MemoryRoots @($outRoot) -MaxMatches 3
Assert ($rec.available -eq $true) 'RECALL_NOT_AVAILABLE_FOR_REAL_TERMS'
Assert ($rec.status -eq 'EPISODIC_RECALL_AVAILABLE') 'RECALL_STATUS_BAD'
Assert (@($rec.selected).Count -ge 1) 'RECALL_SELECTED_EMPTY'
Assert ($rec.selected[0].episode_id -eq 'recall_real_aimo_selector_ordered_payload_lesson_v1') 'RECALL_TOP_MATCH_NOT_REAL_EPISODE'
Assert (($rec.reuse_hints -join ' ') -like '*ordered payload*') 'RECALL_REUSE_HINT_MISSING_ORDERED_PAYLOAD'
Assert ($rec.scanned_count -ge 52) 'RECALL_VOLUME_SCAN_COUNT_BAD'
Assert ($rec.skipped_count -ge 1) 'RECALL_MALFORMED_SKIP_NOT_RECORDED'
$none=Get-EpisodicMemoryRecall -QueryTerms @('galaxy banana pineapple') -MemoryRoots @($outRoot)
Assert ($none.available -eq $false) 'UNRELATED_RECALL_SHOULD_NOT_MATCH'
Assert ($none.status -eq 'NO_RELEVANT_EPISODIC_MEMORY') 'UNRELATED_RECALL_STATUS_BAD'
$empty=Get-EpisodicMemoryRecall -QueryTerms @('') -MemoryRoots @($outRoot)
Assert ($empty.status -eq 'NO_QUERY_TERMS') 'EMPTY_QUERY_STATUS_BAD'
# AIMO wiring static check.
$aimo='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$aimoText=Get-Content $aimo -Raw
Assert ($aimoText -match 'Get-EpisodicMemoryRecall') 'AIMO_RECALL_CALL_MISSING'
Assert ($aimoText -match 'episodic_recall_trace') 'AIMO_RECALL_TRACE_MISSING'
Assert (($aimoText -match 'current_task_query_with_episodic_decision') -or ($aimoText -match 'episodic_reuse_hint')) 'AIMO_QUERY_AUGMENT_OR_DECISION_REWRITE_MISSING'
$proof=[ordered]@{
  schema='episodic_recall_validation_v1'
  status='PASS_EPISODIC_RECALL_V1'
  tests=@(
    [ordered]@{name='recall_real_selector_episode_by_terms';status='PASS';top_episode=$rec.selected[0].episode_id},
    [ordered]@{name='unrelated_query_returns_no_recall';status='PASS'},
    [ordered]@{name='empty_query_rejected';status='PASS'},
    [ordered]@{name='volume_50_plus_real_cells_scanned';status='PASS';scanned_count=$rec.scanned_count},
    [ordered]@{name='malformed_cell_skipped';status='PASS';skipped_count=$rec.skipped_count},
    [ordered]@{name='aimo_wiring_static_check';status='PASS'}
  )
  real_recall=[ordered]@{ available=$rec.available; status=$rec.status; top_episode=$rec.selected[0].episode_id; reuse_hints=@($rec.reuse_hints); scanned_count=$rec.scanned_count; skipped_count=$rec.skipped_count }
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/memory/episodic/EPISODIC_RECALL_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofPath -Parent) | Out-Null
$proof | ConvertTo-Json -Depth 40 | Set-Content -Path $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_EPISODIC_RECALL_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('TOP_EPISODE='+$rec.selected[0].episode_id)
Write-Host 'LIVE_PROCESS_TOUCHED=false'


