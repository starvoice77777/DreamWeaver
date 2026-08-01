# Smoke: health → dev login → home → favorite → settings → private save
# Requires: API on http://127.0.0.1:8000 and Postgres up.
# Usage: .\scripts\smoke_remote_auth.ps1

$ErrorActionPreference = "Stop"
$Base = if ($env:DW_API_BASE) { $env:DW_API_BASE.TrimEnd("/") } else { "http://127.0.0.1:8000" }

function Invoke-Json {
    param(
        [string]$Method,
        [string]$Path,
        [object]$Body = $null,
        [string]$Token = $null
    )
    $headers = @{ "Accept" = "application/json" }
    if ($Token) { $headers["Authorization"] = "Bearer $Token" }
    $uri = "$Base$Path"
    if ($null -ne $Body) {
        $json = $Body | ConvertTo-Json -Compress -Depth 8
        return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($json))
    }
    return Invoke-RestMethod -Method $Method -Uri $uri -Headers $headers
}

Write-Host "== health =="
$health = Invoke-Json GET "/health"
if ($health.status -ne "ok") { throw "health failed: $($health | ConvertTo-Json -Compress)" }
Write-Host "ok"

Write-Host "== auth apple (dev:) =="
$auth = Invoke-Json POST "/v1/auth/apple" @{
    identity_token = "dev:smoke-user"
    nickname       = "Smoke"
}
$token = $auth.access_token
if (-not $token) { throw "no access_token" }
Write-Host "user_id=$($auth.user_id)"

Write-Host "== home =="
$homePayload = Invoke-Json GET "/v1/home" -Token $token
Write-Host "recommended=$($homePayload.recommended.Count) favorites=$($homePayload.favorites.Count) private=$($homePayload.private_scenes.Count)"

Write-Host "== scenes =="
$scenes = Invoke-Json GET "/v1/scenes"
if ($scenes.Count -lt 1) { throw "no scenes" }
$sceneId = $scenes[0].id
Write-Host "scene=$sceneId"

Write-Host "== favorite patch =="
$state = Invoke-Json PATCH "/v1/users/me/scene-states/$sceneId" @{ is_favorite = $true; mark_opened = $true } -Token $token
Write-Host "is_favorite=$($state.is_favorite)"

Write-Host "== settings put =="
$settings = Invoke-Json PUT "/v1/users/me/settings" @{
    auto_play_enabled = $true
    audio_quality     = "标准"
} -Token $token
Write-Host "audio_quality=$($settings.audio_quality)"

Write-Host "== private scene create + save =="
$created = Invoke-Json POST "/v1/users/me/scenes" @{
    name        = "Smoke Mix"
    subtitle    = "script"
    description = ""
    category    = "personal"
    tags        = @("smoke")
    visual_style = "warmLamp"
    sources     = @(
        @{
            name         = "rain"
            symbolName   = "cloud.rain"
            layer        = "environment"
            volume       = 0.7
            position     = @{ angle = 0.0; radius = 0.5 }
            resourceName = "rain_soft"
            isEnabled    = $true
        }
    )
} -Token $token
$saved = Invoke-Json POST "/v1/users/me/scenes/$($created.id)/save" -Token $token
Write-Host "saved version=$($saved.saved_version) id=$($saved.id)"

Write-Host "SMOKE_OK"
