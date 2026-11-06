<#
.SYNOPSIS
    Deploy the `github-app` Edge Function that brokers GitHub App tokens.

.DESCRIPTION
    Fill in `scripts/github-app.local.json` (copy the .example first), then run:

        .\scripts\setup-github-app.ps1

    The script stores the four secrets, deploys the function with
    `--no-verify-jwt`, and verifies that the endpoint answers.
    Parameters override the JSON file; when neither is given it asks.

    Nothing is written to disk: the .pem stays where it is and is only read.

.PARAMETER ConfigPath
    JSON file with { projectRef, appId, appSlug, privateKeyPath, webhookSecret,
    clientId, clientSecret }.

.PARAMETER DryRun
    Print the commands instead of running them (no secrets are sent).
#>
[CmdletBinding()]
param(
    [string] $ConfigPath = '',
    [string] $ProjectRef = '',
    [string] $AppId = '',
    [string] $AppSlug = '',
    [string] $PrivateKeyPath = '',
    [string] $WebhookSecret = '',
    [string] $ClientId = '',
    [string] $ClientSecret = '',
    [switch] $Yes,
    [switch] $DryRun
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

function Write-Step($text) { Write-Host "`n=== $text ===" -ForegroundColor Cyan }
function Write-Ok($text) { Write-Host "  [ok] $text" -ForegroundColor Green }
function Write-Warn($text) { Write-Host "  [!]  $text" -ForegroundColor Yellow }

function Read-Value($prompt) {
    try {
        return (Read-Host $prompt).Trim()
    } catch {
        throw "Missing value: cannot prompt in this shell. Pass it as a parameter or put it in '$ConfigPath'."
    }
}

# --- configuration ---------------------------------------------------------

if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot 'github-app.local.json' }

if (Test-Path $ConfigPath) {
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    # "<paste App ID>"-style placeholders count as empty.
    $fromConfig = {
        param($value)
        if (-not $value) { return '' }
        $text = "$value".Trim()
        if ($text -match '^<.*>$') { return '' }
        return $text
    }
    if (-not $ProjectRef) { $ProjectRef = & $fromConfig $config.projectRef }
    if (-not $AppId) { $AppId = & $fromConfig $config.appId }
    if (-not $AppSlug) { $AppSlug = & $fromConfig $config.appSlug }
    if (-not $PrivateKeyPath) { $PrivateKeyPath = & $fromConfig $config.privateKeyPath }
    if (-not $WebhookSecret) { $WebhookSecret = & $fromConfig $config.webhookSecret }
    if (-not $ClientId) { $ClientId = & $fromConfig $config.clientId }
    if (-not $ClientSecret) { $ClientSecret = & $fromConfig $config.clientSecret }
    Write-Ok "config: $ConfigPath"
} else {
    Write-Warn "no config file at $ConfigPath (copy github-app.local.example.json)"
}

if (-not $ProjectRef) { $ProjectRef = 'ifrpswaclrrsshspdmzd' }
$host_ = "https://$ProjectRef.supabase.co"

Write-Step 'GitHub App - values to paste in the browser'
Write-Host @"
  GitHub App name ......... 6DX (must be unique; the slug is used in the install URL)
  Homepage URL ............ https://6dx.app   (any URL you own)
  Callback URL ............ $host_/functions/v1/github-app   (ADD it - do not remove an existing one)
  Supabase auth callback .. $host_/auth/v1/callback           (the separate identity OAuth app)
  Setup URL ............... $host_/functions/v1/github-app      (Redirect on update: OFF)
  Webhook URL ............. $host_/functions/v1/github-app/webhook
  Webhook secret .......... the value in webhookSecret below (32+ random chars)
  Permissions ............. Metadata: Read | Contents: Read | Issues: Read & write |
                            Pull requests: Read & write
  Organization permissions  Members: Read   (proves org-admin ownership)
  Subscribe to events ..... Pull request
  Install scope ........... Only on this account (switch to Any account later)
  Request user auth during installation: LEAVE OFF. With it on, GitHub redirects
  straight to the callback URL and drops our signed `state`, so the function can
  no longer tell which workspace the installation belongs to. The function runs
  the OAuth step itself (setup URL -> authorize -> callback) and keeps the state.
"@

if (-not $PrivateKeyPath) {
    $candidates = @(Get-ChildItem -Path $PSScriptRoot, $repoRoot -Filter '*.private-key.pem' -File -ErrorAction SilentlyContinue)
    if ($candidates.Count -eq 1) {
        $PrivateKeyPath = $candidates[0].FullName
        Write-Ok "private key detected: $($candidates[0].Name)"
    } else {
        $PrivateKeyPath = Read-Value 'Path to the downloaded .pem (e.g. github-app.pem)'
    }
}

if (-not [System.IO.Path]::IsPathRooted($PrivateKeyPath)) {
    foreach ($base in @($PSScriptRoot, $repoRoot)) {
        $candidate = Join-Path $base $PrivateKeyPath
        if (Test-Path $candidate) { $PrivateKeyPath = $candidate; break }
    }
}
if (-not (Test-Path $PrivateKeyPath)) { throw "Private key not found: $PrivateKeyPath" }

# The downloaded file is named "<slug>.<date>.private-key.pem".
if (-not $AppSlug) {
    $derived = [System.IO.Path]::GetFileName($PrivateKeyPath) -replace '\.\d{4}-\d{2}-\d{2}\.private-key\.pem$', ''
    if ($derived -and $derived -ne [System.IO.Path]::GetFileName($PrivateKeyPath)) {
        $AppSlug = $derived
        Write-Ok "slug from the key filename: $AppSlug"
    }
}

# `GET /apps/{slug}` is public and returns the numeric App id, so the value does
# not have to be copied by hand.
if (-not $AppId -and $AppSlug) {
    try {
        $public = Invoke-RestMethod -Uri "https://api.github.com/apps/$AppSlug" `
            -Headers @{ 'Accept' = 'application/vnd.github+json'; 'User-Agent' = '6dx-setup' } `
            -TimeoutSec 15
        if ($public.id) {
            $AppId = "$($public.id)"
            Write-Ok "App ID resolved from GitHub: $AppId"
        }
    } catch {
        Write-Warn "could not read https://api.github.com/apps/$AppSlug ($($_.Exception.Message))"
    }
}

if (-not $AppSlug) {
    $AppSlug = Read-Value 'GitHub App slug (blank = 6dx)'
    if (-not $AppSlug) { $AppSlug = '6dx' }
}
if (-not $AppId) { $AppId = Read-Value 'GitHub App ID (App settings page)' }
if (-not $WebhookSecret) {
    $WebhookSecret = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 40 | ForEach-Object { [char]$_ })
}

if (-not $AppId) { throw 'appId is required (see https://github.com/settings/apps/<slug>).' }

if (-not $ClientId) { $ClientId = Read-Value 'OAuth client id of the App (App settings page)' }
if (-not $ClientSecret) { $ClientSecret = Read-Value 'OAuth client secret (App settings -> Generate a new client secret)' }
if (-not $ClientId -or -not $ClientSecret) {
    throw 'clientId and clientSecret are required: the install flow refuses to store an installation it cannot verify.'
}

Write-Step 'Where each value comes from'
Write-Host @"
  App ID ........... https://github.com/settings/apps/$AppSlug   -> "App ID" at the top
  App slug ......... the same URL - it is the last path segment
  Private key ...... same page -> "Private keys" -> Generate a private key
                     (downloads  <slug>.YYYY-MM-DD.private-key.pem)
  Webhook secret ... YOU invent it. Paste the value below into the same page,
                     section "Webhook" -> "Webhook secret" -> Save changes.
No App yet? Create it first: https://github.com/settings/apps/new
"@

Write-Step 'GitHub webhook secret'
Write-Host @" 
  This value does NOT come from GitHub - you invent it. It is used for two
  things: signing the install redirect (always required) and verifying GitHub
  webhooks (optional - skip the webhook section on GitHub if you do not want
  pull-request sync; the app still works).
"@
Write-Host "  Copy this into GitHub -> App settings -> Webhook -> Webhook secret:" -ForegroundColor Yellow
Write-Host "    $WebhookSecret" -ForegroundColor White
Write-Host "  (the same value is stored as GITHUB_WEBHOOK_SECRET)" -ForegroundColor Gray

if (-not [System.IO.Path]::IsPathRooted($PrivateKeyPath)) {
    foreach ($base in @($PSScriptRoot, $repoRoot)) {
        $candidate = Join-Path $base $PrivateKeyPath
        if (Test-Path $candidate) { $PrivateKeyPath = $candidate; break }
    }
}
if (-not (Test-Path $PrivateKeyPath)) { throw "Private key not found: $PrivateKeyPath" }

$pem = [System.IO.File]::ReadAllText($PrivateKeyPath)
if ($pem -notmatch 'BEGIN (RSA )?PRIVATE KEY') {
    throw "That file does not look like a PEM private key: $PrivateKeyPath"
}
# The function turns the two-character sequence \n back into newlines, so the
# secret can travel as a single line.
$pemEscaped = ($pem -replace "`r`n", "`n").Trim() -replace "`n", '\n'
Write-Ok "private key: $([System.IO.Path]::GetFileName($PrivateKeyPath)) ($($pemEscaped.Length) chars, single line)"

Write-Step 'Preflight'
if (-not (Get-Command npx -ErrorAction SilentlyContinue)) {
    throw 'npx not found - install Node.js or use the Supabase CLI directly.'
}
Write-Ok 'npx available'

$supabase = @('--yes', 'supabase@latest')
# `--yes` tells the Supabase CLI to apply the hosted change without prompting;
# required for agent-driven runs.
$consent = if ($Yes) { @('--yes') } else { @() }
$secretsArgs = @(
    'secrets', 'set',
    "GITHUB_APP_ID=$AppId",
    "GITHUB_APP_SLUG=$AppSlug",
    "GITHUB_PRIVATE_KEY=$pemEscaped",
    "GITHUB_WEBHOOK_SECRET=$WebhookSecret",
    "GITHUB_CLIENT_ID=$ClientId",
    "GITHUB_CLIENT_SECRET=$ClientSecret",
    "--remote=$ProjectRef"
) + $consent
$deployArgs = @(
    'functions', 'deploy', 'github-app',
    '--no-verify-jwt',
    "--remote=$ProjectRef"
) + $consent

if ($DryRun) {
    Write-Warn 'dry run - nothing is sent'
    Write-Host "  npx supabase secrets set GITHUB_APP_ID=$AppId GITHUB_APP_SLUG=$AppSlug GITHUB_PRIVATE_KEY=<pem> GITHUB_WEBHOOK_SECRET=<secret> GITHUB_CLIENT_ID=<id> GITHUB_CLIENT_SECRET=<secret> --remote=$ProjectRef"
    Write-Host "  npx supabase functions deploy github-app --no-verify-jwt --remote=$ProjectRef"
    return
}

Write-Step 'Storing secrets'
# Native tools write warnings to stderr; with ErrorActionPreference=Stop that
# would abort the script. Judge by the exit code instead.
$ErrorActionPreference = 'Continue'
& npx @supabase @secretsArgs
if ($LASTEXITCODE -ne 0) { throw 'supabase secrets set failed - run "npx supabase login" first.' }
Write-Ok 'secrets stored'
$ErrorActionPreference = 'Stop'

Write-Step 'Deploying github-app (--no-verify-jwt)'
$ErrorActionPreference = 'Continue'
& npx @supabase @deployArgs
if ($LASTEXITCODE -ne 0) { throw 'supabase functions deploy failed - read the output above.' }
Write-Ok 'deployed'
$ErrorActionPreference = 'Stop'

Write-Step 'Verifying the endpoint'
$probe = "$host_/functions/v1/github-app"
$status = (& curl.exe -s -o NUL -w "%{http_code}" -X POST $probe -H 'Content-Type: application/json' -d '{"action":"installation"}') -join ''
if ($status.Trim() -eq '401') {
    Write-Ok "$probe -> 401 (deployed, unauthenticated callers rejected)"
} else {
    Write-Warn "$probe -> $($status.Trim()) (expected 401). Logs: npx supabase functions logs github-app"
}

Write-Step 'Remaining manual steps'
Write-Host @"
  1. Supabase dashboard -> Authentication -> URL Configuration
       Site URL + Redirect URLs = io.supabase.flutter://login-callback
  2. In the app: sign out and sign in again (drops the old 'repo' grant), then
       New project -> Link GitHub repository -> Install the app -> Refresh.
  3. Optional: revoke the old OAuth grant at github.com/settings/applications.
"@ -ForegroundColor Gray
