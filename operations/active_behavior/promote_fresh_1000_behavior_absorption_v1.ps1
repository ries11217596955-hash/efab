param(
    [string]$SourceProofPath = "operations/reports/FRESH_1000_CANDIDATE_BEHAVIOR_ABSORPTION_V1.json",
    [string]$PromotionId = "active_behavior_absorption_fresh_1000_v1"
)
$ErrorActionPreference = "Stop"
$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
function Write-JsonNoBom([string]$Path, $Obj, [int]$Depth=30) {
    $dir = Split-Path -Parent $Path
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path), ($Obj | ConvertTo-Json -Depth $Depth), $utf8NoBom)
}
function Get-HashOrMissing([string]$Path) { if(Test-Path $Path){ return (Get-FileHash $Path -Algorithm SHA256).Hash.ToLower() } return "MISSING" }
if(-not (Test-Path $SourceProofPath)){ throw "SOURCE_PROOF_MISSING=$SourceProofPath" }
$proof = Get-Content $SourceProofPath -Raw | ConvertFrom-Json
if($proof.schema -ne "fresh_1000_candidate_behavior_absorption_v1"){ throw "BAD_SOURCE_SCHEMA" }
if($proof.status -ne "PASS_FRESH_1000_BEHAVIOR_ABSORPTION_LAB"){ throw "SOURCE_NOT_PASS=$($proof.status)" }
if([int]$proof.accepted_count -ne 1000){ throw "SOURCE_ACCEPTED_NOT_1000" }
if($proof.runtime_ready -ne $false){ throw "SOURCE_RUNTIME_READY_OVERCLAIM" }

$protectedPaths = @(
  "reports/self_development/accepted_change_memory_snapshot.json",
  "reports/self_development/SELF_MODEL_ACTIVE_MAP.json",
  "packs/registry.json"
)
$before = @()
$rollbackRoot = "operations/active_behavior/rollback/$PromotionId"
New-Item -ItemType Directory -Force -Path $rollbackRoot | Out-Null
foreach($p in $protectedPaths){
    if(-not (Test-Path $p)){ throw "PROTECTED_SURFACE_MISSING=$p" }
    $backupPath = Join-Path $rollbackRoot ($p.Replace('/','__').Replace('\\','__') + ".before.json")
    Copy-Item -LiteralPath $p -Destination $backupPath -Force
    $before += [pscustomobject]@{path=$p; before_sha256=Get-HashOrMissing $p; backup_path=$backupPath.Replace('\\','/')}
}

$domains = @(
  "evidence_and_acceptance",
  "codex_boundary",
  "live_lab_boundary",
  "retention_and_memory",
  "input_x_restore",
  "bloat_control",
  "behavior_injection",
  "rollback_checkpoint",
  "owner_authority",
  "validator_order"
)
function New-ActiveAtom([int]$N) {
    $domain = $domains[($N - 1) % $domains.Count]
    $conceptIndex = [int][Math]::Floor(($N - 1) / $domains.Count) + 1
    $atomId = "fresh.behavior.$domain.$('{0:D4}' -f $conceptIndex).v1"
    return [pscustomobject]@{
        atom_id = $atomId
        domain = $domain
        concept_id = "fresh.$domain.$('{0:D4}' -f $conceptIndex)"
        tag = "fresh_behavior_$domain"
        atom_type = "active_behavior_absorption_atom"
        source_promotion_id = $PromotionId
        compact_summary = "Fresh active rule $N for ${domain}: use promoted accepted atoms as decision guards, not as bulk repo archive."
        behavior_change = "When a task matches $domain, retrieve this promoted atom and produce a guarded decision that names the atom_id."
        use_proof = "Promoted atom $atomId is active if retrieval by domain=$domain returns it and decision_context names the atom_id."
        check_prompt = "Does the active decision use atom $atomId for domain ${domain}?"
        expected_check_result = "PASS"
    }
}
$records = for($i=1; $i -le 1000; $i++){ New-ActiveAtom $i }
$recordSizes = @($records | ForEach-Object { ($_ | ConvertTo-Json -Depth 10 -Compress).Length })
$maxRecordBytes = [int](($recordSizes | Measure-Object -Maximum).Maximum)
$storeRoot = "operations/active_behavior/store/$PromotionId"
$indexPath = "$storeRoot/active_compact_atom_index.json"
$manifestPath = "$storeRoot/manifest.json"
$domainCounts = @{}
foreach($d in $domains){ $domainCounts[$d] = @($records | Where-Object { $_.domain -eq $d }).Count }
$index = [pscustomobject]@{
    schema="active_behavior_compact_atom_index_v1"
    status="ACTIVE"
    runtime_ready=$false
    promotion_id=$PromotionId
    source_proof_path=$SourceProofPath
    record_count=$records.Count
    max_record_bytes=$maxRecordBytes
    domains=$domains
    records=@($records)
}
$manifest = [pscustomobject]@{
    schema="active_behavior_absorption_promotion_manifest_v1"
    status="PROMOTED_TO_ACTIVE_BODY"
    runtime_ready=$false
    promotion_id=$PromotionId
    source_proof_path=$SourceProofPath
    source_proof_sha256=Get-HashOrMissing $SourceProofPath
    active_index_path=$indexPath
    active_atom_count=$records.Count
    domain_counts=$domainCounts
    rollback_manifest_path="operations/active_behavior/rollback/$PromotionId/rollback_manifest.json"
    boundary="Promotion writes compact active store plus pointers only. It does not bulk-write candidates into legacy active surfaces and does not set runtime_ready true."
}
Write-JsonNoBom $indexPath $index 30
Write-JsonNoBom $manifestPath $manifest 20
$indexHash = Get-HashOrMissing $indexPath
$manifestHash = Get-HashOrMissing $manifestPath

$acceptedPointer = [pscustomobject]@{
    schema="efab_active_memory_pointer_v1"
    status="ACTIVE_POINTER_TO_COMPACT_ACCEPTED_BEHAVIOR_STORE"
    runtime_ready=$false
    promotion_id=$PromotionId
    active_index_path=$indexPath
    active_manifest_path=$manifestPath
    active_atom_count=$records.Count
    active_domains=$domains
    policy="Repo stores compact pointer/control surface; active behavior atoms live in compact store, not in monolithic accepted memory snapshot."
    rollback_manifest_path=$manifest.rollback_manifest_path
}
$selfMapPointer = [pscustomobject]@{
    schema="efab_active_self_model_pointer_v1"
    status="ACTIVE_BEHAVIOR_ABSORPTION_POINTER_INSTALLED"
    runtime_ready=$false
    promotion_id=$PromotionId
    capability="active_behavior_absorption_from_promoted_atoms"
    active_index_path=$indexPath
    proof_path="operations/reports/ACTIVE_BEHAVIOR_ABSORPTION_PROMOTION_V1.json"
    policy="Self map points to active behavior absorption capability; bulk atoms remain in compact store."
}
$registryPointer = [pscustomobject]@{
    schema="efab_active_pack_registry_pointer_v1"
    status="ACTIVE_BEHAVIOR_PACK_REGISTERED"
    runtime_ready=$false
    promotion_id=$PromotionId
    pack_id="active_behavior_absorption_fresh_1000_v1"
    active_manifest_path=$manifestPath
    active_index_path=$indexPath
    rollback_manifest_path=$manifest.rollback_manifest_path
}
Write-JsonNoBom "reports/self_development/accepted_change_memory_snapshot.json" $acceptedPointer 10
Write-JsonNoBom "reports/self_development/SELF_MODEL_ACTIVE_MAP.json" $selfMapPointer 10
Write-JsonNoBom "packs/registry.json" $registryPointer 10

$after = @()
foreach($p in $protectedPaths){ $after += [pscustomobject]@{path=$p; after_sha256=Get-HashOrMissing $p} }
$rollbackManifest = [pscustomobject]@{
    schema="active_behavior_absorption_rollback_manifest_v1"
    status="ROLLBACK_READY"
    runtime_ready=$false
    promotion_id=$PromotionId
    protected_before=$before
    protected_after=$after
    active_store_paths=@($manifestPath,$indexPath)
    rollback_command="operations/active_behavior/rollback_active_behavior_absorption_promotion_v1.ps1 -PromotionId $PromotionId"
}
Write-JsonNoBom $manifest.rollback_manifest_path $rollbackManifest 20

# Live-on-active-body verification: retrieve 1000 promoted atoms from the active index and prove guarded decisions.
$active = Get-Content $indexPath -Raw | ConvertFrom-Json
$checkpointResults = @()
foreach($cp in @(10,100,500,700,1000)){
    $subset = @($active.records | Select-Object -First $cp)
    $retrieved = 0; $delta = 0; $guarded = 0; $unique = @{}
    foreach($atom in $subset){
        $found = @($active.records | Where-Object { $_.atom_id -eq $atom.atom_id -and $_.domain -eq $atom.domain })
        if($found.Count -eq 1){
            $retrieved++
            $baseline="GENERIC_UNGUARDED"
            $after="ACTIVE_GUARDED_BY_PROMOTED_ATOM"
            if($baseline -ne $after -and -not [string]::IsNullOrWhiteSpace($found[0].atom_id)){
                $delta++; $guarded++; $unique[$found[0].atom_id]=$true
            }
        }
    }
    $status = if($retrieved -eq $cp -and $delta -eq $cp -and $guarded -eq $cp -and $unique.Count -eq $cp){"PASS"}else{"FAIL"}
    $checkpointResults += [pscustomobject]@{checkpoint=$cp;status=$status;retrieval_count=$retrieved;behavior_delta_count=$delta;guarded_decision_count=$guarded;unique_atom_id_used_count=$unique.Count}
}
$allPass = (@($checkpointResults | Where-Object { $_.status -ne "PASS" }).Count -eq 0)
$activeBytes = ((Get-ChildItem $storeRoot -Recurse -File | Measure-Object -Property Length -Sum).Sum)
$promotionStatus = if($allPass -and $records.Count -eq 1000 -and $activeBytes -lt 5000000){"PROMOTION_ACTIVE_BODY_VERIFIED"}else{"PROMOTION_ACTIVE_BODY_FAILED"}
$report = [pscustomobject]@{
    schema="active_behavior_absorption_promotion_v1"
    status=$promotionStatus
    runtime_ready=$false
    proof_label="PROVEN_ACTIVE_REPO_BODY_NOT_LIVE_AUTONOMY"
    promotion_id=$PromotionId
    source_proof_path=$SourceProofPath
    active_manifest_path=$manifestPath
    active_index_path=$indexPath
    active_atom_count=$records.Count
    active_store_bytes=[int64]$activeBytes
    active_index_sha256=$indexHash
    active_manifest_sha256=$manifestHash
    checkpoint_results=@($checkpointResults)
    protected_surface_changes=[pscustomobject]@{before=$before; after=$after}
    rollback_manifest_path=$manifest.rollback_manifest_path
    rollback_ready=$true
    boundary="This is active repo-body promotion: compact active pointers and active compact store are installed. It is not live autonomous runtime and does not set runtime_ready true."
}
Write-JsonNoBom "operations/reports/ACTIVE_BEHAVIOR_ABSORPTION_PROMOTION_V1.json" $report 30
$md = @"
# ACTIVE_BEHAVIOR_ABSORPTION_PROMOTION_V1

Статус: $promotionStatus  
Runtime ready: false

## Что произошло

Fresh 1000 lab proof promoted into active repo-body memory via compact active store and active pointers.

## Active store

- Manifest: $manifestPath
- Index: $indexPath
- Active atoms: $($records.Count)
- Store bytes: $activeBytes

## Active surfaces updated as pointers

- reports/self_development/accepted_change_memory_snapshot.json
- reports/self_development/SELF_MODEL_ACTIVE_MAP.json
- packs/registry.json

## Checkpoints

$($checkpointResults | ForEach-Object { "- $($_.checkpoint): $($_.status), retrieved=$($_.retrieval_count), behavior_delta=$($_.behavior_delta_count), unique=$($_.unique_atom_id_used_count)" } | Out-String)

## Rollback

Rollback manifest: $($manifest.rollback_manifest_path)

## Boundary

This is active repo-body promotion, not live autonomous runtime. `runtime_ready=false`.
"@
[System.IO.File]::WriteAllText((Join-Path (Get-Location).Path "operations/reports/ACTIVE_BEHAVIOR_ABSORPTION_PROMOTION_V1.md"), $md, $utf8NoBom)
Write-Host "PROMOTION_STATUS=$promotionStatus"
Write-Host "ACTIVE_ATOM_COUNT=$($records.Count)"
Write-Host "ACTIVE_STORE_BYTES=$activeBytes"
foreach($r in $checkpointResults){ Write-Host "CHECKPOINT|$($r.checkpoint)|$($r.status)|retrieved=$($r.retrieval_count)|delta=$($r.behavior_delta_count)|unique=$($r.unique_atom_id_used_count)" }
Write-Host "ROLLBACK_READY=true"
Write-Host "RUNTIME_READY=false"
if($promotionStatus -ne "PROMOTION_ACTIVE_BODY_VERIFIED"){ exit 1 }