<#
.SYNOPSIS
  Stages realistic "good" and "bad" dismissals before the session so the audit demo has content.
.DESCRIPTION
  Run AFTER the first CodeQL analysis and Dependabot scan have produced alerts.
  - BAD : hard-coded JWT key in src/auth.js dismissed as "won't fix" with a lazy comment (a real true positive)
  - GOOD: hard-coded key in test/auth.test.js dismissed as "used in tests" with evidence
  - BAD : minimatch (dev dependency) dismissed as tolerable risk with a 2-word comment
  Use -Reset to reopen everything this script touched.
.EXAMPLE
  ./tools/seed-dismissals.ps1 -Repo qkfang/ghas-training
  ./tools/seed-dismissals.ps1 -Reset
#>
param(
  [string]$Repo = (gh repo view --json nameWithOwner -q .nameWithOwner),
  [switch]$Reset
)
$ErrorActionPreference = 'Stop'

function Get-Alerts([string]$Path) {
  $raw = gh api --paginate "repos/$Repo/$Path"
  return @(($raw -join "`n") -replace '\]\s*\[', ',' | ConvertFrom-Json)
}

function Update-CodeAlert($alert, [string]$reason, [string]$comment) {
  if ($Reset) {
    gh api -X PATCH "repos/$Repo/code-scanning/alerts/$($alert.number)" -f state=open | Out-Null
    Write-Host "  reopened code #$($alert.number)"
    return
  }
  gh api -X PATCH "repos/$Repo/code-scanning/alerts/$($alert.number)" `
    -f state=dismissed -f "dismissed_reason=$reason" -f "dismissed_comment=$comment" | Out-Null
  Write-Host "  dismissed code #$($alert.number) ($($alert.rule.id)) as '$reason'"
}

function Update-DependabotAlert($alert, [string]$reason, [string]$comment) {
  if ($Reset) {
    gh api -X PATCH "repos/$Repo/dependabot/alerts/$($alert.number)" -f state=open | Out-Null
    Write-Host "  reopened dependabot #$($alert.number)"
    return
  }
  gh api -X PATCH "repos/$Repo/dependabot/alerts/$($alert.number)" `
    -f state=dismissed -f "dismissed_reason=$reason" -f "dismissed_comment=$comment" | Out-Null
  Write-Host "  dismissed dependabot #$($alert.number) ($($alert.dependency.package.name)) as '$reason'"
}

$code = Get-Alerts 'code-scanning/alerts?per_page=100'
$deps = Get-Alerts 'dependabot/alerts?per_page=100'
$targetState = $Reset ? 'dismissed' : 'open'

$creds = $code | Where-Object { $_.rule.id -eq 'js/hardcoded-credentials' -and $_.state -eq $targetState }
$prodCred = $creds | Where-Object { $_.most_recent_instance.location.path -like 'demo-app/src/*' } | Select-Object -First 1
$testCred = $creds | Where-Object { $_.most_recent_instance.location.path -like 'demo-app/test/*' } | Select-Object -First 1

if ($prodCred) { Update-CodeAlert $prodCred "won't fix" 'not an issue' }
else { Write-Warning 'No js/hardcoded-credentials alert found in demo-app/src - has CodeQL (security-extended) run?' }

if ($testCred) {
  Update-CodeAlert $testCred 'used in tests' 'TEST: key only signs tokens inside node:test unit tests; never loaded by src/. Verified no import from src. Ticket SEC-101'
}

$mm = $deps | Where-Object { $_.dependency.package.name -eq 'minimatch' -and $_.state -eq $targetState } | Select-Object -First 1
if ($mm) { Update-DependabotAlert $mm 'tolerable_risk' 'dev only' }
else { Write-Warning 'No open minimatch Dependabot alert found (auto-triage preset may have dismissed it already).' }

Write-Host "`nDone. Run ./tools/alert-report.ps1 -DismissedOnly to see the audit view." -ForegroundColor Cyan
