param(
  [string]$CandidateDir = "",
  [string]$SessionRoot = "",
  [string]$RunId = "",
  [string]$SandboxRoot = ""
)

$ErrorActionPreference = "Stop"

function Normalize-Phase160HMaterializationFullPath {
  param([string]$Path)
  return [System.IO.Path]::GetFullPath($Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
}

function Resolve-Phase160HMaterializationRepoRoot {
  $scriptRootCandidate = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($PSCommandPath)) {
    $scriptRootCandidate = Split-Path -Path $PSCommandPath -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate) -and -not [string]::IsNullOrWhiteSpace($MyInvocation.MyCommand.Path)) {
    $scriptRootCandidate = Split-Path -Path $MyInvocation.MyCommand.Path -Parent
  }
  if ([string]::IsNullOrWhiteSpace($scriptRootCandidate)) {
    throw "PHASE160H_MATERIALIZATION_SCRIPT_ROOT_UNAVAILABLE"
  }
  return Normalize-Phase160HMaterializationFullPath -Path (Join-Path $scriptRootCandidate "..")
}

function Resolve-Phase160HMaterializationPath {
  param([string]$RepoRoot, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Assert-Phase160HMaterializationPathInside {
  param([string]$Root, [string]$FullPath, [string]$Label)
  $normalizedRoot = Normalize-Phase160HMaterializationFullPath -Path $Root
  $normalizedPath = Normalize-Phase160HMaterializationFullPath -Path $FullPath
  if (-not ($normalizedPath -eq $normalizedRoot -or $normalizedPath.StartsWith($normalizedRoot + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))) {
    throw "PHASE160H_MATERIALIZATION_PATH_OUTSIDE_$Label=$FullPath"
  }
  return $normalizedPath
}

function ConvertTo-Phase160HMaterializationRelativePath {
  param([string]$RepoRoot, [string]$FullPath)
  $root = Normalize-Phase160HMaterializationFullPath -Path $RepoRoot
  $full = Normalize-Phase160HMaterializationFullPath -Path $FullPath
  if ($full -eq $root) {
    return "."
  }
  if (-not $full.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "PHASE160H_MATERIALIZATION_PATH_OUTSIDE_REPO=$FullPath"
  }
  return ($full.Substring($root.Length + 1) -replace "\\", "/")
}

function ConvertTo-Phase160HMaterializationDotNetFileSystemPath {
  param([string]$Path)
  $full = [System.IO.Path]::GetFullPath($Path)
  if ([System.IO.Path]::DirectorySeparatorChar -ne '\') {
    return $full
  }
  if ($full.StartsWith('\\?\', [System.StringComparison]::Ordinal)) {
    return $full
  }
  if ($full.StartsWith('\\', [System.StringComparison]::Ordinal)) {
    return '\\?\UNC\' + $full.Substring(2)
  }
  return '\\?\' + $full
}

function Test-Phase160HMaterializationFileExists {
  param([string]$Path)
  return [System.IO.File]::Exists((ConvertTo-Phase160HMaterializationDotNetFileSystemPath -Path $Path))
}

function Test-Phase160HMaterializationDirectoryExists {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $true
  }
  return [System.IO.Directory]::Exists((ConvertTo-Phase160HMaterializationDotNetFileSystemPath -Path $Path))
}

function New-Phase160HMaterializationDirectory {
  param([string]$Path)
  if (-not [string]::IsNullOrWhiteSpace($Path)) {
    [System.IO.Directory]::CreateDirectory((ConvertTo-Phase160HMaterializationDotNetFileSystemPath -Path $Path)) | Out-Null
  }
}

function Remove-Phase160HMaterializationDirectory {
  param([string]$Path)
  if (-not [string]::IsNullOrWhiteSpace($Path) -and (Test-Phase160HMaterializationDirectoryExists -Path $Path)) {
    [System.IO.Directory]::Delete((ConvertTo-Phase160HMaterializationDotNetFileSystemPath -Path $Path), $true)
  }
}

function Read-Phase160HMaterializationTextFile {
  param([string]$Path)
  return [System.IO.File]::ReadAllText((ConvertTo-Phase160HMaterializationDotNetFileSystemPath -Path $Path), [System.Text.UTF8Encoding]::new($false))
}

function Write-Phase160HMaterializationTextFile {
  param([string]$Path, [string]$Text)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Phase160HMaterializationDirectoryExists -Path $directory)) {
    New-Phase160HMaterializationDirectory -Path $directory
  }
  [System.IO.File]::WriteAllText((ConvertTo-Phase160HMaterializationDotNetFileSystemPath -Path $Path), $Text, [System.Text.UTF8Encoding]::new($false))
}

function Write-Phase160HMaterializationJsonFile {
  param([string]$Path, [object]$Object, [int]$Depth = 100)
  $directory = Split-Path -Path $Path -Parent
  if ($directory -and -not (Test-Phase160HMaterializationDirectoryExists -Path $directory)) {
    New-Phase160HMaterializationDirectory -Path $directory
  }
  $json = ($Object | ConvertTo-Json -Depth $Depth) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  Write-Phase160HMaterializationTextFile -Path $Path -Text $json
}

function Read-Phase160HMaterializationJsonSafe {
  param([string]$Path)
  try {
    if (-not (Test-Phase160HMaterializationFileExists -Path $Path)) {
      return $null
    }
    return Read-Phase160HMaterializationTextFile -Path $Path | ConvertFrom-Json
  } catch {
    return $null
  }
}

function Get-Phase160HMaterializationProperty {
  param([object]$Object, [string]$Name, [object]$Default = $null)
  if ($null -eq $Object) {
    return $Default
  }
  if ($Object.PSObject.Properties.Name -contains $Name) {
    return $Object.$Name
  }
  return $Default
}

function Test-Phase160HMaterializationRelativePathSafe {
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path)) {
    return $false
  }
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $false
  }
  $parts = @($Path -split "[\\/]+" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  return (@($parts | Where-Object { $_ -eq ".." }).Count -eq 0)
}

function Test-Phase160HMaterializationPowerShellParse {
  param([string]$Path)
  $tokens = $null
  $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile((ConvertTo-Phase160HMaterializationDotNetFileSystemPath -Path $Path), [ref]$tokens, [ref]$parseErrors) | Out-Null
  if ($parseErrors.Count -gt 0) {
    return [pscustomobject][ordered]@{
      parser_checks_pass = $false
      parser_error_count = $parseErrors.Count
      parser_error_message = [string]$parseErrors[0].Message
    }
  }
  return [pscustomobject][ordered]@{
    parser_checks_pass = $true
    parser_error_count = 0
    parser_error_message = "NONE"
  }
}

$RepoRoot = Resolve-Phase160HMaterializationRepoRoot
$Pushed = $false

try {
  Push-Location $RepoRoot
  $Pushed = $true

  foreach ($identityFile in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Resolve-Phase160HMaterializationPath -RepoRoot $RepoRoot -Path $identityFile))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing=$identityFile"
    }
  }

  if ([string]::IsNullOrWhiteSpace($CandidateDir)) {
    throw "PHASE160H_MATERIALIZATION_CANDIDATE_DIR_REQUIRED"
  }

  $CandidateDirFull = Resolve-Phase160HMaterializationPath -RepoRoot $RepoRoot -Path $CandidateDir
  $CandidateDirFull = Assert-Phase160HMaterializationPathInside -Root $RepoRoot -FullPath $CandidateDirFull -Label "REPO"
  if (-not (Test-Path -LiteralPath $CandidateDirFull)) {
    throw "PHASE160H_MATERIALIZATION_CANDIDATE_DIR_MISSING=$CandidateDir"
  }
  $CandidateDirRelative = ConvertTo-Phase160HMaterializationRelativePath -RepoRoot $RepoRoot -FullPath $CandidateDirFull

  $manifest = Read-Phase160HMaterializationJsonSafe -Path (Join-Path $CandidateDirFull "candidate_manifest.json")
  $proposedFiles = Read-Phase160HMaterializationJsonSafe -Path (Join-Path $CandidateDirFull "proposed_files.json")
  $candidateId = if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains "candidate_id") { [string]$manifest.candidate_id } else { Split-Path -Path $CandidateDirFull -Leaf }
  if ([string]::IsNullOrWhiteSpace($SandboxRoot)) {
    $SandboxRoot = Join-Path $CandidateDirFull "quality_gate/materialized_payloads"
  } else {
    $SandboxRoot = Resolve-Phase160HMaterializationPath -RepoRoot $RepoRoot -Path $SandboxRoot
  }
  $SandboxRoot = Assert-Phase160HMaterializationPathInside -Root $RepoRoot -FullPath $SandboxRoot -Label "REPO"
  Remove-Phase160HMaterializationDirectory -Path $SandboxRoot
  New-Phase160HMaterializationDirectory -Path $SandboxRoot

  $failures = @()
  $materializedFiles = @()
  $modulePayloadCount = 0
  $validatorPayloadCount = 0
  $parserChecksPass = $true
  $parserErrorCount = 0
  $parserErrors = @()

  if ($null -eq $proposedFiles) {
    $failures += "proposed_files.json missing or unreadable"
    $payloads = @()
  } else {
    $payloads = @(Get-Phase160HMaterializationProperty -Object $proposedFiles -Name "proposed_payloads" -Default @())
  }

  if ($payloads.Count -lt 1) {
    $failures += "proposed_payloads missing or empty"
  }

  foreach ($payload in $payloads) {
    $kind = [string](Get-Phase160HMaterializationProperty -Object $payload -Name "kind" -Default "unknown")
    $targetPath = [string](Get-Phase160HMaterializationProperty -Object $payload -Name "target_path" -Default "")
    $payloadPath = [string](Get-Phase160HMaterializationProperty -Object $payload -Name "payload_path" -Default "")
    if ($kind -eq "module") {
      $modulePayloadCount += 1
    }
    if ($kind -eq "validator") {
      $validatorPayloadCount += 1
    }
    if (-not (Test-Phase160HMaterializationRelativePathSafe -Path $targetPath)) {
      $failures += "unsafe or missing target_path for payload kind=$kind"
      continue
    }
    if (-not (Test-Phase160HMaterializationRelativePathSafe -Path $payloadPath)) {
      $failures += "unsafe or missing payload_path for payload kind=$kind target=$targetPath"
      continue
    }
    $payloadFullPath = [System.IO.Path]::GetFullPath((Join-Path $CandidateDirFull $payloadPath))
    $payloadFullPath = Assert-Phase160HMaterializationPathInside -Root $CandidateDirFull -FullPath $payloadFullPath -Label "CANDIDATE"
    if (-not (Test-Phase160HMaterializationFileExists -Path $payloadFullPath)) {
      $failures += "payload file missing kind=$kind path=$payloadPath"
      continue
    }
    $payloadText = Read-Phase160HMaterializationTextFile -Path $payloadFullPath
    if ([string]::IsNullOrWhiteSpace($payloadText)) {
      $failures += "payload file empty kind=$kind path=$payloadPath"
      continue
    }
    $materializedFullPath = [System.IO.Path]::GetFullPath((Join-Path $SandboxRoot $targetPath))
    $materializedFullPath = Assert-Phase160HMaterializationPathInside -Root $SandboxRoot -FullPath $materializedFullPath -Label "SANDBOX"
    $materializedDirectory = Split-Path -Path $materializedFullPath -Parent
    if ($materializedDirectory -and -not (Test-Phase160HMaterializationDirectoryExists -Path $materializedDirectory)) {
      New-Phase160HMaterializationDirectory -Path $materializedDirectory
    }
    Write-Phase160HMaterializationTextFile -Path $materializedFullPath -Text $payloadText
    $parseResult = [pscustomobject][ordered]@{
      parser_checks_pass = $true
      parser_error_count = 0
      parser_error_message = "NONE"
    }
    if ($targetPath -match "\.ps1$") {
      $parseResult = Test-Phase160HMaterializationPowerShellParse -Path $materializedFullPath
      if (-not $parseResult.parser_checks_pass) {
        $parserChecksPass = $false
        $parserErrorCount += [int]$parseResult.parser_error_count
        $parserErrors += [ordered]@{
          target_path = $targetPath
          message = [string]$parseResult.parser_error_message
        }
      }
    }
    $materializedFiles += [ordered]@{
      kind = $kind
      target_path = $targetPath
      payload_path = $payloadPath
      materialized_path = ConvertTo-Phase160HMaterializationRelativePath -RepoRoot $RepoRoot -FullPath $materializedFullPath
      parser_checks_pass = [bool]$parseResult.parser_checks_pass
      parser_error_count = [int]$parseResult.parser_error_count
    }
  }

  if ($modulePayloadCount -lt 1) {
    $failures += "proposed module payload missing"
  }
  if ($validatorPayloadCount -lt 1) {
    $failures += "proposed validator payload missing"
  }
  if (-not $parserChecksPass) {
    $failures += "PowerShell parser check failed for materialized payload"
  }

  $result = [ordered]@{
    status = if ($failures.Count -eq 0) { "PASS" } else { "FAIL" }
    candidate_id = $candidateId
    candidate_dir = $CandidateDirRelative
    session_root = if ([string]::IsNullOrWhiteSpace($SessionRoot)) { "NONE" } else { $SessionRoot }
    run_id = if ([string]::IsNullOrWhiteSpace($RunId)) { "NONE" } else { $RunId }
    sandbox_root = ConvertTo-Phase160HMaterializationRelativePath -RepoRoot $RepoRoot -FullPath $SandboxRoot
    proposed_payload_count = $payloads.Count
    materialized_payload_count = $materializedFiles.Count
    module_payload_count = $modulePayloadCount
    validator_payload_count = $validatorPayloadCount
    parser_checks_pass = $parserChecksPass
    parser_error_count = $parserErrorCount
    parser_errors = @($parserErrors)
    failures = @($failures)
    materialized_files = @($materializedFiles)
    accepted_code_written = $false
    repo_mutation_performed = $false
    commit_performed = $false
    push_performed = $false
    branch_switch_performed = $false
    protected_state_mutated = $false
    checked_at = (Get-Date).ToUniversalTime().ToString("o")
  }
  Write-Phase160HMaterializationJsonFile -Path (Join-Path $CandidateDirFull "quality_gate/materialization_result.json") -Object $result
  [pscustomobject]$result | ConvertTo-Json -Depth 100
} finally {
  if ($Pushed) {
    Pop-Location
  }
}
