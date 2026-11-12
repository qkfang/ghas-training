<#
.SYNOPSIS
  Prioritised view of open GHAS alerts plus an audit of dismissed/closed alerts.
.DESCRIPTION
  Pulls code scanning, Dependabot and secret scanning alerts via the GitHub REST API,
  assigns a starting priority (P0-P3) using the rules in sessions/01-alert-triage/03-triage-playbook.md,
  and flags dismissals that need review (weak justification, stale, or contradictory).
  The priority is a starting point - humans adjust it for exposure and business context.
.EXAMPLE
  ./tools/alert-report.ps1 -Repo qkfang/ghas-training
  ./tools/alert-report.ps1 -DismissedOnly
#>
param(
  [string]$Repo = (gh repo view --json nameWithOwner -q .nameWithOwner),
  [switch]$DismissedOnly,
  [int]$MinCommentLength = 20,
  [int]$ReviewAfterDays = 180
)
$ErrorActionPreference = 'Stop'

function Get-Alerts([string]$Path) {
  $raw = gh api --paginate "repos/$Repo/$Path" 2>$null
  if (-not $? -or -not $raw) { return @() }   # feature disabled / no access
  # --paginate concatenates JSON arrays; normalise to one array
  return @(($raw -join "`n") -replace '\]\s*\[', ',' | ConvertFrom-Json)
}

function Step-Priority([int]$p, [int]$delta) { [Math]::Min(3, [Math]::Max(0, $p + $delta)) }
$sevRank = @{ critical = 0; high = 1; medium = 2; moderate = 2; low = 3; error = 1; warning = 2; note = 3 }

function Get-Epss($advisory) {
  $e = $advisory.epss
  if ($e -is [array]) { $e = $e | Select-Object -First 1 }
  if ($e) { return [double]$e.percentage } else { return $null }
}

$cs = Get-Alerts 'code-scanning/alerts?per_page=100'
$db = Get-Alerts 'dependabot/alerts?per_page=100'
$ss = Get-Alerts 'secret-scanning/alerts?per_page=100'

if (-not $DismissedOnly) {
  $open = @()

  foreach ($a in $cs | Where-Object state -eq 'open') {
    $sev = $a.rule.security_severity_level ?? $a.rule.severity
    $p = $sevRank[$sev] ?? 3
    $path = $a.most_recent_instance.location.path
    $isTest = ($a.most_recent_instance.classifications -contains 'test') -or ($path -match '(^|/)(test|tests|__tests__)/')
    if ($isTest) { $p = Step-Priority $p 2 }
    $open += [pscustomobject]@{
      P = "P$p"; Type = 'code'; '#' = $a.number; Severity = $sev
      Finding = $a.rule.id; Where = $path + ($isTest ? ' (test)' : ''); Signal = ''
    }
  }

  foreach ($a in $db | Where-Object state -eq 'open') {
    $sev = $a.security_advisory.severity
    $p = $sevRank[$sev] ?? 3
    $epss = Get-Epss $a.security_advisory
    $signal = @()
    if ($a.dependency.scope -eq 'development') { $p = Step-Priority $p 2; $signal += 'dev-scope' }
    if ($null -ne $epss) {
      $signal += ('EPSS {0:P1}' -f $epss)
      if ($epss -ge 0.10) { $p = Step-Priority $p -1 }
    }
    if ($a.security_vulnerability.first_patched_version) { $signal += 'patch available' }
    $open += [pscustomobject]@{
      P = "P$p"; Type = 'dependabot'; '#' = $a.number; Severity = $sev
      Finding = "$($a.dependency.package.name) $($a.security_advisory.ghsa_id)"
      Where = $a.dependency.manifest_path; Signal = $signal -join ', '
    }
  }

  foreach ($a in $ss | Where-Object state -eq 'open') {
    $validity = $a.validity ?? 'unknown'
    $p = if ($validity -eq 'inactive') { 2 } else { 0 }   # unknown is treated as live
    $open += [pscustomobject]@{
      P = "P$p"; Type = 'secret'; '#' = $a.number; Severity = 'n/a'
      Finding = $a.secret_type_display_name; Where = $a.first_location_detected.path; Signal = "validity: $validity"
    }
  }

  Write-Host "`n=== OPEN ALERTS by starting priority ($Repo) ===" -ForegroundColor Cyan
  $open | Sort-Object P, Type, '#' | Format-Table -AutoSize -Wrap
}

$audit = @()
$now = Get-Date

foreach ($a in $cs | Where-Object state -eq 'dismissed') {
  $audit += [pscustomobject]@{
    Type = 'code'; '#' = $a.number; Finding = $a.rule.id; Reason = $a.dismissed_reason
    Comment = $a.dismissed_comment; By = $a.dismissed_by.login; At = [datetime]$a.dismissed_at
    Path = $a.most_recent_instance.location.path; Validity = $null
  }
}
foreach ($a in $db | Where-Object state -in 'dismissed', 'auto_dismissed') {
  $audit += [pscustomobject]@{
    Type = 'dependabot'; '#' = $a.number; Finding = $a.dependency.package.name
    Reason = ($a.state -eq 'auto_dismissed') ? 'auto-dismissed (rule)' : $a.dismissed_reason
    Comment = $a.dismissed_comment; By = $a.dismissed_by.login
    At = [datetime]($a.dismissed_at ?? $a.auto_dismissed_at); Path = $a.dependency.manifest_path; Validity = $null
  }
}
foreach ($a in $ss | Where-Object { $_.state -eq 'resolved' -and $_.resolution -ne 'revoked' }) {
  $audit += [pscustomobject]@{
    Type = 'secret'; '#' = $a.number; Finding = $a.secret_type_display_name; Reason = $a.resolution
    Comment = $a.resolution_comment; By = $a.resolved_by.login; At = [datetime]$a.resolved_at
    Path = $a.first_location_detected.path; Validity = $a.validity
  }
}

$audit = $audit | ForEach-Object {
  $flags = @()
  if ($_.Reason -ne 'auto-dismissed (rule)' -and ([string]$_.Comment).Trim().Length -lt $MinCommentLength) { $flags += 'WEAK-JUSTIFICATION' }
  if (($now - $_.At).TotalDays -gt $ReviewAfterDays) { $flags += 'REVIEW-DUE' }
  if ($_.Type -eq 'secret' -and $_.Validity -eq 'active') { $flags += 'SECRET-STILL-ACTIVE' }
  if ($_.Type -eq 'code' -and $_.Reason -eq 'used in tests' -and $_.Path -notmatch '(^|/)(test|tests|__tests__|spec)/') { $flags += 'NOT-A-TEST-PATH' }
  if ($_.Type -eq 'code' -and $_.Reason -eq "won't fix" -and $_.Comment -notmatch '(?i)approv|review|ticket|[A-Z]+-\d+') { $flags += 'NO-APPROVAL-OR-REVIEW-DATE' }
  $_ | Add-Member -NotePropertyName Flags -NotePropertyValue ($flags -join ' ') -PassThru
}

Write-Host "`n=== DISMISSED / CLOSED ALERT AUDIT ($Repo) ===" -ForegroundColor Cyan
if (-not $audit) { Write-Host 'No dismissed alerts.'; return }
$audit | Sort-Object { -not $_.Flags }, Type | Select-Object Type, '#', Finding, Reason, By, @{n = 'Age(d)'; e = { [int]($now - $_.At).TotalDays } }, Comment, Flags |
  Format-Table -AutoSize -Wrap

$flagged = @($audit | Where-Object Flags).Count
Write-Host ("{0} of {1} dismissals need review." -f $flagged, @($audit).Count) -ForegroundColor ($flagged ? 'Yellow' : 'Green')
