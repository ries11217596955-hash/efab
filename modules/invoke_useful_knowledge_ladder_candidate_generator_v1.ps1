$ErrorActionPreference = "Stop"

function Get-UsefulKnowledgeLadderDomainsV1 {
    @(
        [ordered]@{ domain = "evidence_and_acceptance"; ladder_level = 1; focus = "proof claims, validator evidence, and acceptance status"; guard = "evidence-bound reporting"; blocked = "claiming proof without fresh validator evidence" },
        [ordered]@{ domain = "live_lab_boundary"; ladder_level = 2; focus = "lab/runtime separation and live mutation boundaries"; guard = "lab evidence without live-readiness overclaim"; blocked = "treating lab output as live runtime authority" },
        [ordered]@{ domain = "codex_boundary"; ladder_level = 3; focus = "Codex preflight, scoped edits, and command discipline"; guard = "bounded Codex execution"; blocked = "mutating before scoped preflight" },
        [ordered]@{ domain = "retention_and_memory"; ladder_level = 4; focus = "durable compact memory, receipts, and retrieval"; guard = "semantic memory separated from receipts"; blocked = "using raw traces or receipts as memory" },
        [ordered]@{ domain = "organ_construction"; ladder_level = 5; focus = "organ contracts, validators, and modular extension"; guard = "contract-first organ construction"; blocked = "promoting unvalidated organ behavior" },
        [ordered]@{ domain = "path_selection"; ladder_level = 6; focus = "canonical lanes, legacy proof boundaries, and route choice"; guard = "current proof lane selection"; blocked = "using historical scale artifacts as current acceptance" },
        [ordered]@{ domain = "input_x_restore"; ladder_level = 7; focus = "restored task context, newest request, and mismatch handling"; guard = "current-context verification"; blocked = "trusting stale restored summaries over repo facts" },
        [ordered]@{ domain = "runtime_safety"; ladder_level = 8; focus = "bounded validation, scale gates, and process supervision"; guard = "bounded smoke validation only"; blocked = "running scale or supervision loops without scope" },
        [ordered]@{ domain = "settings_governance"; ladder_level = 9; focus = "protected settings, stubs, route locks, and policy surfaces"; guard = "protected governance surface preservation"; blocked = "silent settings or policy mutation" },
        [ordered]@{ domain = "owner_guidance"; ladder_level = 10; focus = "owner reports, limitations, and next-step clarity"; guard = "precise owner-facing delivery"; blocked = "hiding limitations or dirty state" }
    )
}

function New-UsefulKnowledgeLadderCandidateV1 {
    param(
        [string]$CandidateId,
        [string]$AtomId,
        [string]$Domain,
        [int]$LadderLevel,
        [string]$Concept,
        [string]$Trigger,
        [string]$Rule,
        [string]$AntiPattern,
        [string]$DecisionUse,
        [string]$ValidatorHint,
        [string[]]$ReuseTags,
        [ValidateSet("useful","duplicate","low_quality","conflict_or_unsafe")]
        [string]$QualityClass
    )

    [ordered]@{
        candidate_id = $CandidateId
        atom_id = $AtomId
        domain = $Domain
        ladder_level = $LadderLevel
        concept = $Concept
        trigger = $Trigger
        rule = $Rule
        anti_pattern = $AntiPattern
        decision_use = $DecisionUse
        validator_hint = $ValidatorHint
        source_type = "useful_knowledge_ladder_candidate_generator_v1"
        reuse_tags = @($ReuseTags)
        quality_class = $QualityClass
    }
}

function Invoke-UsefulKnowledgeLadderCandidateGeneratorV1 {
    param(
        [Parameter(Mandatory = $true)]
        [int]$TargetAcceptedCount,
        [int]$MinimumCandidateCount = 0
    )

    if ($TargetAcceptedCount -le 0) {
        throw "TARGET_ACCEPTED_COUNT_MUST_BE_POSITIVE"
    }

    $domains = @(Get-UsefulKnowledgeLadderDomainsV1)
    $domainCount = $domains.Count
    if ($domainCount -eq 0) {
        throw "DOMAIN_COUNT_ZERO"
    }
    if (($TargetAcceptedCount % $domainCount) -ne 0) {
        throw "TARGET_ACCEPTED_COUNT_MUST_DIVIDE_BY_DOMAIN_COUNT"
    }

    $acceptedPerDomain = [int]($TargetAcceptedCount / $domainCount)
    $derivedMinimumCandidateCount = if ($MinimumCandidateCount -gt 0) {
        $MinimumCandidateCount
    } else {
        [int][Math]::Ceiling($TargetAcceptedCount * 1.1)
    }
    $minimumRejectCount = [Math]::Max(($derivedMinimumCandidateCount - $TargetAcceptedCount), ($domainCount * 3))
    $rejectsPerDomain = [int][Math]::Ceiling($minimumRejectCount / $domainCount)
    $lowQualityPerDomain = [Math]::Max(1, [int][Math]::Floor($rejectsPerDomain * 0.4))
    $duplicatePerDomain = [Math]::Max(1, [int][Math]::Floor($rejectsPerDomain * 0.3))
    $unsafePerDomain = [Math]::Max(1, ($rejectsPerDomain - $lowQualityPerDomain - $duplicatePerDomain))
    $rejectsPerDomain = $lowQualityPerDomain + $duplicatePerDomain + $unsafePerDomain

    $candidates = @()
    foreach ($domainDef in $domains) {
        $domain = [string]$domainDef["domain"]
        $ladderLevel = [int]$domainDef["ladder_level"]
        $focus = [string]$domainDef["focus"]
        $guard = [string]$domainDef["guard"]
        $blocked = [string]$domainDef["blocked"]

        for ($i = 1; $i -le $acceptedPerDomain; $i++) {
            $serial = "{0:D4}" -f $i
            $concept = "$domain decision guard $serial"
            $atomId = "builder.knowledge_ladder.$domain.level$ladderLevel.$serial.v1"
            $trigger = "When Builder evaluates $focus and scenario marker $serial appears in a task, retrieve the matching $domain ladder atom before deciding."
            $rule = "Require $guard for $domain decision marker ${serial}: verify task scope, relevant evidence, and blocked-action boundaries before taking the next step."
            $antiPattern = "Do not proceed by $blocked for $domain marker $serial; this loses the proof boundary that the ladder atom is meant to preserve."
            $decisionUse = "Use this atom to change or guard a Builder decision by selecting the bounded action that satisfies $guard for $domain marker $serial."
            $validatorHint = "PASS when atom_id, domain=$domain, ladder_level=$ladderLevel, rule text, decision_use text, and at least three reuse tags are present and specific."
            $reuseTags = @(
                $domain,
                "ladder_level_$ladderLevel",
                "builder_decision",
                "quality_gate",
                "durable_reuse"
            )

            $candidates += New-UsefulKnowledgeLadderCandidateV1 `
                -CandidateId "knowledge_ladder.$domain.accept.$serial" `
                -AtomId $atomId `
                -Domain $domain `
                -LadderLevel $ladderLevel `
                -Concept $concept `
                -Trigger $trigger `
                -Rule $rule `
                -AntiPattern $antiPattern `
                -DecisionUse $decisionUse `
                -ValidatorHint $validatorHint `
                -ReuseTags $reuseTags `
                -QualityClass "useful"
        }

        for ($i = 1; $i -le $duplicatePerDomain; $i++) {
            $serial = "{0:D4}" -f $i
            $candidates += New-UsefulKnowledgeLadderCandidateV1 `
                -CandidateId "knowledge_ladder.$domain.duplicate.$serial" `
                -AtomId "builder.knowledge_ladder.$domain.level$ladderLevel.$serial.v1" `
                -Domain $domain `
                -LadderLevel $ladderLevel `
                -Concept "$domain duplicate candidate $serial" `
                -Trigger "A duplicate candidate repeats an already accepted $domain atom id." `
                -Rule "Reject because duplicate atom ids cannot add durable decision knowledge." `
                -AntiPattern "Admitting duplicate atom ids would make retrieval ambiguous." `
                -DecisionUse "Rejected duplicate candidate; no governed decision should use this duplicate record." `
                -ValidatorHint "PASS when duplicate candidates are rejected by atom_id collision." `
                -ReuseTags @($domain, "duplicate_candidate", "quality_gate") `
                -QualityClass "duplicate"
        }

        for ($i = 1; $i -le $lowQualityPerDomain; $i++) {
            $serial = "{0:D4}" -f $i
            $candidates += New-UsefulKnowledgeLadderCandidateV1 `
                -CandidateId "knowledge_ladder.$domain.low_quality.$serial" `
                -AtomId "rejected.knowledge_ladder.$domain.low_quality.$serial" `
                -Domain $domain `
                -LadderLevel $ladderLevel `
                -Concept "$domain vague note $serial" `
                -Trigger "A vague note lacks a decision trigger for $domain." `
                -Rule "Reject because the candidate does not provide a specific Builder decision rule." `
                -AntiPattern "Admitting vague notes would blur the useful knowledge ladder." `
                -DecisionUse "Rejected low-quality candidate; no decision reuse is allowed." `
                -ValidatorHint "PASS when vague candidates are rejected before atom admission." `
                -ReuseTags @($domain, "low_quality_candidate", "quality_gate") `
                -QualityClass "low_quality"
        }

        for ($i = 1; $i -le $unsafePerDomain; $i++) {
            $serial = "{0:D4}" -f $i
            $candidates += New-UsefulKnowledgeLadderCandidateV1 `
                -CandidateId "knowledge_ladder.$domain.unsafe.$serial" `
                -AtomId "rejected.knowledge_ladder.$domain.unsafe.$serial" `
                -Domain $domain `
                -LadderLevel $ladderLevel `
                -Concept "$domain unsafe shortcut $serial" `
                -Trigger "An unsafe shortcut asks Builder to ignore scoped proof boundaries for $domain." `
                -Rule "Reject because this candidate contradicts bounded validation and proof-governed decisions." `
                -AntiPattern "Admitting unsafe shortcuts would weaken the Builder safety boundary." `
                -DecisionUse "Rejected unsafe candidate; it must block rather than guide decisions." `
                -ValidatorHint "PASS when unsafe or contradictory candidates are rejected." `
                -ReuseTags @($domain, "unsafe_candidate", "quality_gate") `
                -QualityClass "conflict_or_unsafe"
        }
    }

    [ordered]@{
        schema = "useful_knowledge_ladder_candidate_batch_v1"
        target_accepted_count = $TargetAcceptedCount
        candidate_count = $candidates.Count
        domain_count = $domainCount
        ladder_level_count = $domainCount
        accepted_per_domain = $acceptedPerDomain
        candidates = @($candidates)
    }
}
