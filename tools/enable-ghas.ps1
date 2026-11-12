<#
.SYNOPSIS
  Enables the GHAS features used by the triage demo on a repository.
.EXAMPLE
  ./tools/enable-ghas.ps1 -Repo qkfang/ghas-training
#>
param(
  [string]$Repo = (gh repo view --json nameWithOwner -q .nameWithOwner),
  [switch]$EnableDependabotSecurityUpdates
)
$ErrorActionPreference = 'Stop'
Write-Host "Configuring GHAS features on $Repo" -ForegroundColor Cyan

gh api -X PUT "repos/$Repo/vulnerability-alerts" | Out-Null
Write-Host '  [x] Dependabot alerts'

$body = @{
  security_and_analysis = @{
    secret_scanning                 = @{ status = 'enabled' }
    secret_scanning_push_protection = @{ status = 'enabled' }
  }
} | ConvertTo-Json -Depth 5
$body | gh api -X PATCH "repos/$Repo" --input - | Out-Null
Write-Host '  [x] Secret scanning + push protection'

if ($EnableDependabotSecurityUpdates) {
  gh api -X PUT "repos/$Repo/automated-security-fixes" | Out-Null
  Write-Host '  [x] Dependabot security updates (PRs)'
}

$default = gh api "repos/$Repo/code-scanning/default-setup" 2>$null | ConvertFrom-Json
if ($default.state -eq 'configured') {
  Write-Warning 'CodeQL default setup is ON. Disable it (Settings > Code security) so the advanced workflow in .github/workflows/codeql.yml can upload results.'
} else {
  Write-Host '  [x] CodeQL default setup is off - advanced workflow will be used'
}

Write-Host "`nManual steps (UI only):" -ForegroundColor Yellow
Write-Host '  1. Settings > Advanced Security > Secret scanning > Custom patterns > New pattern'
Write-Host '       Name: ACME API key   Pattern: acme_(live|test)_[A-Za-z0-9]{24}'
Write-Host '  2. Settings > Advanced Security > Dependabot rules: review GitHub presets (dev-scoped low impact)'
Write-Host "  3. Run the CodeQL workflow:  gh workflow run codeql.yml -R $Repo"
