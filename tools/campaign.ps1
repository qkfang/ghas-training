<#
.SYNOPSIS
  Plans, creates and monitors GHAS security campaigns via the REST API (Session 3 demo).
.DESCRIPTION
  Security campaigns are an ORGANIZATION feature: the caller must be an org owner or security manager,
  and the API only sees PUBLISHED campaigns (drafts are UI-only).
    -Plan    Scope check: open code scanning alerts in the org matching -Rule / -Severity / -Repository / -Property,
             grouped by repo, rule and severity. Checks the 1000-alert campaign limit and (with -WeeklyCapacity)
             suggests a realistic end date.
    -Create  Same scope, then POST /orgs/{org}/campaigns (published immediately).
    default  Progress report for campaigns: burn-down vs time elapsed, status (ON-TRACK / AT-RISK / OVERDUE / ...)
             and governance flags.
.EXAMPLE
  ./tools/campaign.ps1 -Org my-demo-org
  ./tools/campaign.ps1 -Org my-demo-org -All
  ./tools/campaign.ps1 -Org my-demo-org -Plan -Rule js/sql-injection,js/reflected-xss,js/command-line-injection -Property tier=1 -WeeklyCapacity 5
  ./tools/campaign.ps1 -Org my-demo-org -Create -Name 'Injection in tier-1 apps' -Description 'Fix SQLi, XSS and command injection. Guidance: https://...' `
      -Rule js/sql-injection,js/reflected-xss,js/command-line-injection -Property tier=1 -EndsAt 2027-02-28 -Manager sec-lead `
      -ContactLink https://github.com/orgs/my-demo-org/discussions/1 -GenerateIssues
#>
[CmdletBinding(DefaultParameterSetName = 'Report')]
param(
  [Parameter(Mandatory)][string]$Org,

  [Parameter(ParameterSetName = 'Report')][switch]$All,
  [Parameter(ParameterSetName = 'Report')][int]$AtRiskMargin = 15,

  [Parameter(ParameterSetName = 'Plan', Mandatory)][switch]$Plan,
  [Parameter(ParameterSetName = 'Create', Mandatory)][switch]$Create,

  [Parameter(ParameterSetName = 'Plan')][Parameter(ParameterSetName = 'Create')][string[]]$Rule,
  [Parameter(ParameterSetName = 'Plan')][Parameter(ParameterSetName = 'Create')][ValidateSet('critical', 'high', 'medium', 'low')][string[]]$Severity,
  [Parameter(ParameterSetName = 'Plan')][Parameter(ParameterSetName = 'Create')][string[]]$Repository,
  [Parameter(ParameterSetName = 'Plan')][Parameter(ParameterSetName = 'Create')][string[]]$Property,
  [Parameter(ParameterSetName = 'Plan')][int]$WeeklyCapacity,

  [Parameter(ParameterSetName = 'Create', Mandatory)][string]$Name,
  [Parameter(ParameterSetName = 'Create', Mandatory)][string]$Description,
  [Parameter(ParameterSetName = 'Create', Mandatory)][datetime]$EndsAt,
  [Parameter(ParameterSetName = 'Create')][string]$Manager,
  [Parameter(ParameterSetName = 'Create')][string[]]$TeamManager,
  [Parameter(ParameterSetName = 'Create')][string]$ContactLink,
  [Parameter(ParameterSetName = 'Create')][switch]$GenerateIssues
)
$ErrorActionPreference = 'Stop'
$MaxAlerts = 1000

function Get-Paged([string]$Path) {
  $raw = gh api --paginate $Path
  if ($LASTEXITCODE -ne 0) { throw "GET $Path failed. Campaigns need an organization and the org owner or security manager role." }
  if (-not $raw) { return @() }
  return @(($raw -join "`n") -replace '\]\s*\[', ',' | ConvertFrom-Json)
}

function Get-Scope {
  $alerts = Get-Paged "orgs/$Org/code-scanning/alerts?state=open&per_page=100"
  if ($Rule) { $alerts = $alerts | Where-Object { $_.rule.id -in $Rule } }
  if ($Severity) { $alerts = $alerts | Where-Object { $_.rule.security_severity_level -in $Severity } }
  if ($Repository) { $alerts = $alerts | Where-Object { $_.repository.name -in $Repository -or $_.repository.full_name -in $Repository } }
  if ($Property) {
    # Repository custom properties (e.g. tier=1, exposure=internet) encode asset criticality once, org-wide.
    $props = Get-Paged "orgs/$Org/properties/values?per_page=100"
    $repoIds = foreach ($r in $props) {
      $match = $true
      foreach ($p in $Property) {
        $k, $v = $p -split '=', 2
        $actual = ($r.properties | Where-Object property_name -eq $k).value
        if (@($actual) -notcontains $v) { $match = $false }
      }
      if ($match) { $r.repository_id }
    }
    $alerts = $alerts | Where-Object { $_.repository.id -in $repoIds }
  }
  return @($alerts)
}

function Show-Scope($alerts) {
  Write-Host "`n=== CAMPAIGN SCOPE ($Org) — $($alerts.Count) open code scanning alerts ===" -ForegroundColor Cyan
  if (-not $alerts) { Write-Warning 'No alerts match. Widen -Rule / -Severity / -Repository / -Property.'; return }
  $alerts | Group-Object { $_.repository.full_name } | Sort-Object Count -Descending |
    Select-Object @{n = 'Repository'; e = { $_.Name } }, Count | Format-Table -AutoSize
  $alerts | Group-Object { $_.rule.id } | Sort-Object Count -Descending |
    Select-Object @{n = 'Rule'; e = { $_.Name } }, Count | Format-Table -AutoSize
  $alerts | Group-Object { $_.rule.security_severity_level ?? $_.rule.severity } | Sort-Object Count -Descending |
    Select-Object @{n = 'Severity'; e = { $_.Name } }, Count | Format-Table -AutoSize

  if ($alerts.Count -gt $MaxAlerts) {
    Write-Warning "A campaign can include at most $MaxAlerts alerts. Narrow the scope or split into several campaigns."
  }
  $repos = @($alerts.repository.id | Sort-Object -Unique).Count
  Write-Host ("{0} repositories → expect one tracking issue each with -GenerateIssues." -f $repos)
  if ($WeeklyCapacity -gt 0) {
    $weeks = [Math]::Ceiling($alerts.Count / $WeeklyCapacity) + 1   # +1 week buffer for review/merge
    Write-Host ("Capacity {0} alerts/week → ~{1} weeks. Suggested -EndsAt {2:yyyy-MM-dd}." -f $WeeklyCapacity, $weeks, (Get-Date).AddDays(7 * $weeks)) -ForegroundColor Yellow
  }
}

if ($Plan) { Show-Scope (Get-Scope); return }

if ($Create) {
  if (-not $Manager -and -not $TeamManager) { throw 'A campaign needs a manager: pass -Manager <login> and/or -TeamManager <team-slug> (org owner or security manager).' }
  if ($EndsAt -le (Get-Date)) { throw '-EndsAt must be in the future.' }
  $alerts = Get-Scope
  Show-Scope $alerts
  if (-not $alerts) { return }
  if ($alerts.Count -gt $MaxAlerts) { throw "Scope has $($alerts.Count) alerts; the limit is $MaxAlerts." }

  $body = [ordered]@{
    name                 = $Name
    description          = $Description
    ends_at              = ($EndsAt.TimeOfDay -eq [timespan]::Zero ? $EndsAt.ToString('yyyy-MM-dd') + 'T23:59:59Z' : $EndsAt.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))
    generate_issues      = [bool]$GenerateIssues
    code_scanning_alerts = @($alerts | Group-Object { $_.repository.id } | ForEach-Object {
        [ordered]@{ repository_id = [long]$_.Name; alert_numbers = @($_.Group.number | Sort-Object) }
      })
  }
  if ($Manager) { $body.managers = @($Manager) }        # the API currently accepts a single user manager
  if ($TeamManager) { $body.team_managers = @($TeamManager) }
  if ($ContactLink) { $body.contact_link = $ContactLink }

  $c = $body | ConvertTo-Json -Depth 6 | gh api -X POST "orgs/$Org/campaigns" --input - | ConvertFrom-Json
  if ($LASTEXITCODE -ne 0) { throw 'Campaign creation failed (see gh output above).' }
  Write-Host ("`nCreated campaign #{0} '{1}' — due {2:yyyy-MM-dd}, {3} alerts." -f $c.number, $c.name, [datetime]$c.ends_at, $alerts.Count) -ForegroundColor Green
  Write-Host "Track it: https://github.com/orgs/$Org/security/campaigns/$($c.number)  or  ./tools/campaign.ps1 -Org $Org"
  return
}

# --- Progress report -----------------------------------------------------------------------------
$now = Get-Date
$campaigns = Get-Paged ("orgs/$Org/campaigns?per_page=100&sort=ends_at&direction=asc" + ($All ? '' : '&state=open'))
if (-not $campaigns) { Write-Host "No $($All ? '' : 'open ')published campaigns in $Org."; return }

$rows = foreach ($c in $campaigns) {
  $s = $c.alert_stats
  $open, $inProg, $closed = [int]$s.open_count, [int]$s.in_progress_count, [int]$s.closed_count
  $total = $open + $inProg + $closed
  $start = [datetime]($c.published_at ?? $c.created_at)
  $end = [datetime]$c.ends_at
  $span = ($end - $start).TotalDays
  $elapsedPct = $span -gt 0 ? [Math]::Min(100, [Math]::Max(0, 100 * ($now - $start).TotalDays / $span)) : 100
  $closedPct = $total ? 100 * $closed / $total : 100

  $status = if ($c.state -eq 'closed') { 'CLOSED' }
  elseif ($open + $inProg -eq 0) { 'COMPLETE' }
  elseif ($now -gt $end) { 'OVERDUE' }
  elseif ($closedPct + $AtRiskMargin -lt $elapsedPct) { 'AT-RISK' }
  else { 'ON-TRACK' }

  $flags = @()
  if ($c.state -eq 'open' -and $elapsedPct -ge 25 -and $closed + $inProg -eq 0) { $flags += 'NOT-STARTED' }
  if (-not $c.contact_link) { $flags += 'NO-CONTACT-LINK' }
  if (-not $c.managers -and -not $c.team_managers) { $flags += 'NO-MANAGER' }
  if ($span -gt 120) { $flags += 'LONG-RUNNING' }
  if ($c.state -eq 'closed' -and $open + $inProg -gt 0) { $flags += 'CLOSED-WITH-OPEN-ALERTS' }

  [pscustomobject]@{
    '#' = $c.number; Name = $c.name; Due = $end.ToString('yyyy-MM-dd')
    'Days left' = [int][Math]::Ceiling(($end - $now).TotalDays)
    Open = $open; 'In progress' = $inProg; Closed = $closed
    'Closed %' = [int]$closedPct; 'Time %' = [int]$elapsedPct
    Status = $status; Manager = (@($c.managers.login) + @($c.team_managers.slug) | Where-Object { $_ }) -join ','
    Flags = $flags -join ' '
  }
}

Write-Host "`n=== SECURITY CAMPAIGN PROGRESS ($Org) ===" -ForegroundColor Cyan
$rows | Select-Object '#', Name, Due, 'Days left', Open, 'In progress', Closed, 'Closed %', 'Time %', Status, Manager | Format-Table -AutoSize -Wrap
$attention = @($rows | Where-Object { $_.Status -in 'AT-RISK', 'OVERDUE' -or $_.Flags })
foreach ($r in $attention) {
  Write-Host ("  #{0} {1}: {2} {3}" -f $r.'#', $r.Name, $r.Status, $r.Flags) -ForegroundColor Yellow
}
Write-Host ("{0} of {1} campaigns need attention. 'Closed' includes dismissed alerts — audit them with tools/alert-report.ps1 -DismissedOnly." -f $attention.Count, @($rows).Count) -ForegroundColor ($attention ? 'Yellow' : 'Green')
