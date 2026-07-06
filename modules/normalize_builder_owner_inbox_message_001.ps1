function Get-Phase161B1InboxObjectProperty {
  param([object]$Object, [string[]]$Names, [object]$Default = $null)
  if ($null -eq $Object) {
    return $Default
  }
  foreach ($name in $Names) {
    if ($Object -is [System.Collections.IDictionary] -and $Object.Contains($name)) {
      return $Object[$name]
    }
    if ($Object.PSObject.Properties.Name -contains $name) {
      return $Object.$name
    }
  }
  return $Default
}

function Get-Phase161B1InboxStringProperty {
  param([object]$Object, [string[]]$Names, [string]$Default = "")
  $value = Get-Phase161B1InboxObjectProperty -Object $Object -Names $Names -Default $Default
  if ($null -eq $value) {
    return $Default
  }
  return [string]$value
}

function Get-Phase161B1InboxContentHash {
  param([string]$Content)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
    return ([System.BitConverter]::ToString($sha.ComputeHash($bytes)) -replace "-", "").ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function ConvertTo-Phase161B1InboxSafeLeaf {
  param([string]$Value, [int]$MaxLength = 80)
  $leaf = if ([string]::IsNullOrWhiteSpace($Value)) { "UNKNOWN" } else { $Value }
  $leaf = $leaf -replace '[^A-Za-z0-9_.-]', '_'
  if ($leaf.Length -gt $MaxLength) {
    $leaf = $leaf.Substring(0, $MaxLength)
  }
  return $leaf
}

function ConvertTo-Phase161B1OwnerInboxMessageNormalized {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path
  )

  $file = Get-Item -LiteralPath $Path
  $rawText = Get-Content -LiteralPath $file.FullName -Raw
  $contentHash = Get-Phase161B1InboxContentHash -Content $rawText
  $message = $null
  $parseError = ""
  try {
    $message = $rawText | ConvertFrom-Json
  } catch {
    $parseError = $_.Exception.Message
  }

  $explicitMessageType = ""
  $messageType = "unknown"
  $payload = $message
  if ($null -ne $message) {
    $explicitMessageType = (Get-Phase161B1InboxStringProperty -Object $message -Names @("message_type", "type") -Default "").Trim().ToLowerInvariant()
    if (-not [string]::IsNullOrWhiteSpace($explicitMessageType)) {
      $messageType = $explicitMessageType
    } elseif (-not [string]::IsNullOrWhiteSpace((Get-Phase161B1InboxStringProperty -Object $message -Names @("owner_goal") -Default ""))) {
      $messageType = "owner_task"
    } elseif (
      -not [string]::IsNullOrWhiteSpace((Get-Phase161B1InboxStringProperty -Object $message -Names @("curriculum_id") -Default "")) -and
      @((Get-Phase161B1InboxObjectProperty -Object $message -Names @("lessons") -Default @())).Count -gt 0
    ) {
      $messageType = "curriculum_pack"
    }

    if ($messageType -eq "curriculum_pack") {
      $candidatePayload = Get-Phase161B1InboxObjectProperty -Object $message -Names @("curriculum_pack", "pack") -Default $null
      if ($null -ne $candidatePayload) {
        $payload = $candidatePayload
      }
    }
  }

  $curriculumId = if ($messageType -eq "curriculum_pack" -and $null -ne $payload) { Get-Phase161B1InboxStringProperty -Object $payload -Names @("curriculum_id") -Default "NONE" } else { "NONE" }
  $ownerTaskId = if ($messageType -eq "owner_task" -and $null -ne $message) { Get-Phase161B1InboxStringProperty -Object $message -Names @("task_id", "id", "taskId") -Default "NONE" } else { "NONE" }
  $instructionTarget = if ($messageType -eq "instruction" -and $null -ne $message) { Get-Phase161B1InboxStringProperty -Object $message -Names @("target") -Default "general" } else { "NONE" }
  $messageIdSeed = switch ($messageType) {
    "curriculum_pack" { $curriculumId }
    "owner_task" { $ownerTaskId }
    "instruction" { Get-Phase161B1InboxStringProperty -Object $message -Names @("instruction_id", "id") -Default "INSTRUCTION" }
    "stop" { "STOP" }
    "pause" { "PAUSE" }
    default { "MESSAGE" }
  }
  $hashFragment = if ($contentHash.Length -ge 12) { $contentHash.Substring(0, 12) } else { "nohash" }
  $messageId = "{0}_{1}" -f (ConvertTo-Phase161B1InboxSafeLeaf -Value $messageIdSeed -MaxLength 64), $hashFragment

  return [pscustomobject][ordered]@{
    message_id = $messageId
    original_file = $file.Name
    original_full_path = $file.FullName
    raw_text = $rawText
    content_hash = $contentHash
    parse_error = $parseError
    parsed_message = $message
    explicit_message_type = $explicitMessageType
    inferred_message_type = $messageType
    payload = $payload
    curriculum_id = $curriculumId
    owner_task_id = $ownerTaskId
    instruction_target = $instructionTarget
    created_at = $file.LastWriteTimeUtc.ToUniversalTime().ToString("o")
  }
}
