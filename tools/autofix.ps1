<#
.SYNOPSIS
  Generates Copilot Autofix suggestions for code scanning alerts via the REST API and, optionally,
  commits them to a branch and opens a draft PR (Session 2 demo).
.DESCRIPTION
  For each alert number:
    1. POST  /code-scanning/alerts/{n}/autofix          (202 = generating, 200 = already exists)
    2. GET   /code-scanning/alerts/{n}/autofix          poll until status is success | error | outdated
    3. POST  /code-scanning/alerts/{n}/autofix/commits  (with -Commit / -CreatePR) to an existing branch
    4. gh pr create --draft                              (with -CreatePR)
  Without -Branch each alert gets its own branch autofix/alert-<n> (avoids conflicts between fixes).
  Autofixes are generated for alerts on the default branch only. Every PR still needs human review.
.EXAMPLE
  ./tools/autofix.ps1 -Alert 2                    # generate and print the suggestion status/explanation
  ./tools/autofix.ps1 -Alert 2 -StatusOnly        # read-only: show the existing autofix, if any
  ./tools/autofix.ps1 -Alert 2,10 -CreatePR       # one draft PR per alert
  ./tools/autofix.ps1 -Alert 1,2 -Branch autofix/products -CreatePR   # both fixes on one branch / PR
#>
param(
  [string]$Repo = (gh repo view --json nameWithOwner -q .nameWithOwner),
  [Parameter(Mandatory)][int[]]$Alert,
  [string]$Branch,
  [switch]$StatusOnly,
  [switch]$Commit,
  [switch]$CreatePR,
  [int]$TimeoutSec = 300
)
$ErrorActionPreference = 'Stop'
if ($CreatePR) { $Commit = $true }

function Invoke-Gh([string[]]$ArgList) {
  $out = gh api @ArgList 2>&1
  $ok = $LASTEXITCODE -eq 0
  $stdout = $out | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
  [pscustomobject]@{ Ok = $ok; Text = (($ok ? $stdout : $out) -join "`n") }
}

function Get-Autofix([int]$n) {
  $r = Invoke-Gh @("repos/$Repo/code-scanning/alerts/$n/autofix")
  if ($r.Ok) { return $r.Text | ConvertFrom-Json }
  if ($r.Text -match 'Not Found|404') { return $null }
  throw "Autofix status for alert #${n} failed: $($r.Text)"
}

function Wait-Autofix([int]$n) {
  $deadline = (Get-Date).AddSeconds($TimeoutSec)
  do {
    $fix = Get-Autofix $n
    if ($fix -and $fix.status -ne 'pending') { return $fix }
    Start-Sleep -Seconds 5
    Write-Host '.' -NoNewline
  } while ((Get-Date) -lt $deadline)
  Write-Host ''
  throw "Timed out after ${TimeoutSec}s waiting for the autofix on alert #$n."
}

function Confirm-Branch([string]$name, [string]$base) {
  $exists = Invoke-Gh @("repos/$Repo/git/ref/heads/$name")
  if ($exists.Ok) { return }
  $sha = gh api "repos/$Repo/git/ref/heads/$base" --jq .object.sha
  gh api -X POST "repos/$Repo/git/refs" -f "ref=refs/heads/$name" -f "sha=$sha" | Out-Null
  Write-Host "  created branch $name from $base"
}

$defaultBranch = gh api "repos/$Repo" --jq .default_branch
$prBranches = [ordered]@{}

foreach ($n in $Alert) {
  $ar = Invoke-Gh @("repos/$Repo/code-scanning/alerts/$n")
  if (-not $ar.Ok) { Write-Warning "Alert #$n not found or not accessible: $($ar.Text)"; continue }
  $a = $ar.Text | ConvertFrom-Json
  $where = "$($a.most_recent_instance.location.path):$($a.most_recent_instance.location.start_line)"
  Write-Host "`n#$n $($a.rule.id) [$($a.rule.security_severity_level ?? $a.rule.severity)] $where ($($a.state))" -ForegroundColor Cyan

  if ($StatusOnly) {
    $fix = Get-Autofix $n
  } else {
    if ($a.state -ne 'open') { Write-Warning "Alert #$n is $($a.state) - skipping."; continue }
    $req = Invoke-Gh @('-X', 'POST', "repos/$Repo/code-scanning/alerts/$n/autofix")
    if (-not $req.Ok) { Write-Warning "Autofix request failed (unsupported alert, Autofix disabled, or no access): $($req.Text)"; continue }
    Write-Host '  autofix requested, waiting' -NoNewline
    $fix = Wait-Autofix $n
    Write-Host ''
  }

  if (-not $fix) { Write-Host '  no autofix exists for this alert yet'; continue }
  $color = @{ success = 'Green'; error = 'Red'; outdated = 'Yellow'; pending = 'Gray' }[$fix.status]
  Write-Host "  status: $($fix.status)" -ForegroundColor $color
  if ($fix.description) { Write-Host ($fix.description -replace '(?m)^', '  | ') }

  if (-not $Commit -or $StatusOnly) { continue }
  if ($fix.status -ne 'success') { Write-Warning "No usable autofix for #$n ($($fix.status)) - not committing."; continue }

  $target = $Branch ? $Branch : "autofix/alert-$n"
  Confirm-Branch $target $defaultBranch
  $msg = "Fix code scanning alert #${n}: $($a.rule.id) (Copilot Autofix)"
  $c = Invoke-Gh @('-X', 'POST', "repos/$Repo/code-scanning/alerts/$n/autofix/commits", '-f', "target_ref=refs/heads/$target", '-f', "message=$msg")
  if (-not $c.Ok) { Write-Warning "Commit to $target failed (e.g. conflict with an earlier fix on the same branch): $($c.Text)"; continue }
  Write-Host "  committed $(($c.Text | ConvertFrom-Json).sha.Substring(0, 7)) to $target"
  if (-not $prBranches.Contains($target)) { $prBranches[$target] = @() }
  $prBranches[$target] += $a
}

if (-not $CreatePR) { return }

foreach ($target in $prBranches.Keys) {
  $existing = gh pr list -R $Repo --head $target --state open --json url --jq '.[0].url'
  if ($existing) { Write-Host "`nPR already open for ${target}: $existing"; continue }
  $alerts = $prBranches[$target]
  $title = ($alerts.Count -eq 1) ? "Fix code scanning alert #$($alerts[0].number): $($alerts[0].rule.id)" : "Fix code scanning alerts $(($alerts | ForEach-Object { "#$($_.number)" }) -join ', ')"
  $body = @(
    'Copilot Autofix suggestion(s) generated via the REST API. **Review before merging.**', ''
    ($alerts | ForEach-Object { "- $($_.html_url) — ``$($_.rule.id)``" })
    '', '### Reviewer checklist (sessions/02-copilot-remediation/03-remediation-playbook.md)'
    '- [ ] Root cause removed (safe API, not a blocklist)'
    '- [ ] CodeQL check shows the alert fixed and no new alerts'
    '- [ ] Tests pass; regression test added'
    '- [ ] Behaviour preserved; no unexpected dependency'
  ) -join "`n"
  $url = gh pr create -R $Repo --draft --base $defaultBranch --head $target --title $title --body $body
  Write-Host "`nDraft PR: $url" -ForegroundColor Green
}
