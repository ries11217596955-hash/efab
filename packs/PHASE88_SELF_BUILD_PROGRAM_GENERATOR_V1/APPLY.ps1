$ErrorActionPreference = "Stop"

Write-Output "PHASE88_APPLY_START"

& "modules/self_development/write_self_build_program_generator_report.ps1"

$QueuePath = "TASK_QUEUE.json"
$Queue = Get-Content $QueuePath -Raw | ConvertFrom-Json
$Queue.active_task_id = "NONE"

$tasks = @($Queue.tasks)
for ($i = 0; $i -lt $tasks.Count; $i++) {
  if ($tasks[$i].task_id -eq "TASK_SELF_BUILD_PROGRAM_GENERATOR_V1_001") {
    $tasks[$i].status = "COMPLETED"
    $tasks[$i] | Add-Member -NotePropertyName completed_at -NotePropertyValue ((Get-Date).ToUniversalTime().ToString("o")) -Force
  }
}
$Queue.tasks = $tasks
$Queue | ConvertTo-Json -Depth 50 | Set-Content $QueuePath -Encoding UTF8

$RoadmapPath = "CAPABILITY_ROADMAP.json"
$Roadmap = Get-Content $RoadmapPath -Raw | ConvertFrom-Json
$Roadmap | Add-Member -NotePropertyName phase88_self_build_program_generator_v1 -NotePropertyValue "COMPLETED" -Force
$Roadmap | ConvertTo-Json -Depth 50 | Set-Content $RoadmapPath -Encoding UTF8

$GenesisPath = "GENESIS_STATE.json"
$Genesis = Get-Content $GenesisPath -Raw | ConvertFrom-Json
$Genesis | Add-Member -NotePropertyName self_build_program_generator_v1 -NotePropertyValue "PROVEN" -Force
$Genesis | ConvertTo-Json -Depth 50 | Set-Content $GenesisPath -Encoding UTF8

Write-Output "TASK_QUEUE_RETURNED_TO_NONE"
Write-Output "PHASE88_APPLY_COMPLETE"

# PHASE165F_DYNAMIC_SELF_BUILD_PROGRAM_GENERATION_PATCH_START
try {
  $__phase165fGenerator = "self_build_programs/generator/GENERATE_DYNAMIC_SELF_BUILD_PROGRAM_V1.ps1"
  if (Test-Path $__phase165fGenerator) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $__phase165fGenerator | Out-Null
  }
} catch {
  Write-Warning ("PHASE165F dynamic self-build program generation failed: " + $_.Exception.Message)
}
# PHASE165F_DYNAMIC_SELF_BUILD_PROGRAM_GENERATION_PATCH_END
