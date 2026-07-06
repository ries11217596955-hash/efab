$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
& operations/school/curriculum/run_curriculum_school_v1.ps1 -MaxLessons 12 -IncludeNegative | Out-Host
$r=Get-Content operations/reports/CURRICULUM_SCHOOL_V1.json -Raw | ConvertFrom-Json
$cp=Get-Content operations/school/curriculum/store/active_curriculum_school_v1/active_curriculum_checkpoint.json -Raw | ConvertFrom-Json
$hasNegativeReject=@($r.rejected_lessons | Where-Object {$_.lesson_id -eq "curriculum.lesson.bad_negative.v1"}).Count -eq 1
$ok=($r.status -eq "PASS_CURRICULUM_SCHOOL_V1_CANARY" -and [int]$r.accepted_count -gt 0 -and [int]$r.directed_count -gt 0 -and [int]$r.experience_count -gt 0 -and [int]$r.behavior_use_pass_count -eq [int]$r.accepted_count -and [int]$r.rejected_count -ge 1 -and $hasNegativeReject -and $cp.no_magic_n -eq $true)
$status=if($ok){"PASS_CURRICULUM_SCHOOL_V1"}else{"FAIL_CURRICULUM_SCHOOL_V1"}
$v=[pscustomobject]@{schema="curriculum_school_v1_validator"; status=$status; runtime_ready=$false; accepted_count=$r.accepted_count; rejected_count=$r.rejected_count; directed_count=$r.directed_count; experience_count=$r.experience_count; behavior_use_pass_count=$r.behavior_use_pass_count; has_negative_rejection=$hasNegativeReject; no_magic_n=$cp.no_magic_n; boundary="Directive curriculum school canary with negative rejection and behavior-use proof."}
$utf8=New-Object System.Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path (Get-Location).Path "operations/reports/CURRICULUM_SCHOOL_V1_VALIDATION.json"),($v|ConvertTo-Json -Depth 30),$utf8)
Write-Host "VALIDATION_STATUS=$status"
Write-Host "ACCEPTED=$($r.accepted_count)"
Write-Host "REJECTED=$($r.rejected_count)"
Write-Host "DIRECTED=$($r.directed_count)"
Write-Host "EXPERIENCE=$($r.experience_count)"
Write-Host "BEHAVIOR_USE_PASS=$($r.behavior_use_pass_count)"
Write-Host "NEGATIVE_REJECTION=$hasNegativeReject"
Write-Host "RUNTIME_READY=false"
if(-not $ok){exit 1}