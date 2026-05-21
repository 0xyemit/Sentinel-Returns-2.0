# G:\Mi unidad\1. PROYECTOS\SENTINEL RETURNS\Sentinel_Telegram.ps1
# MÓDULO 3: Despacho de notificaciones a través del Bot de Telegram

function Send-SentinelTelegramMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$MessageText,
        
        [Parameter(Mandatory = $true)]
        [string]$Token,
        
        [Parameter(Mandatory = $true)]
        [string]$ChatId
    )

    Write-Host "📡 [TELEGRAM] Preparando el despacho de la alerta al terminal móvil..." -ForegroundColor Cyan

    $Uri = "https://api.telegram.org/bot$Token/sendMessage"

    $Body = @{
        chat_id    = $ChatId
        text       = $MessageText
        parse_mode = "HTML"
    }

    $BodyJson = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json))

    try {
        $Response = Invoke-RestMethod -Uri $Uri -Method Post -ContentType "application/json; charset=utf-8" -Body $BodyJson -TimeoutSec 15
        
        if ($Response.ok -eq $true) {
            Write-Host "🚀 [TELEGRAM] ¡Reporte enviado con éxito!" -ForegroundColor Green
            return $true
        } else {
            Write-Host "❌ [TELEGRAM] El servidor respondió negativamente." -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "❌ [TELEGRAM] Error crítico en la petición: $_" -ForegroundColor Red
        return $false
    }
}

function Clear-TelegramWebhook {
    param([string]$Token)
    try {
        $R = Invoke-RestMethod -Uri "https://api.telegram.org/bot$Token/deleteWebhook?drop_pending_updates=false" -Method Post -TimeoutSec 10
        if ($R.ok) { Write-Host "✅ [TELEGRAM] Webhook eliminado. Polling activo." -ForegroundColor Green }
        else        { Write-Host "⚠️ [TELEGRAM] deleteWebhook respondió ok=false." -ForegroundColor Yellow }
    } catch {
        Write-Host "⚠️ [TELEGRAM] deleteWebhook falló: $_" -ForegroundColor Yellow
    }
}

function Set-TelegramWebhook {
    param(
        [string]$Token,
        [string]$Url
    )
    try {
        $Body = @{ url = $Url } | ConvertTo-Json
        $R = Invoke-RestMethod -Uri "https://api.telegram.org/bot$Token/setWebhook" -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($Body)) -ContentType "application/json; charset=utf-8" -TimeoutSec 15
        if ($R.ok) { Write-Host "✅ [TELEGRAM] Webhook registrado: $Url" -ForegroundColor Green }
        else        { Write-Host "⚠️ [TELEGRAM] setWebhook ok=false: $($R.description)" -ForegroundColor Yellow }
        return $R.ok
    } catch {
        Write-Host "❌ [TELEGRAM] setWebhook falló: $_" -ForegroundColor Red
        return $false
    }
}

function Get-TelegramUpdates {
    param(
        [string]$Token,
        [long]$Offset = 0,
        [int]$LongPollTimeout = 5
    )
    $Uri = "https://api.telegram.org/bot$Token/getUpdates?offset=$Offset&timeout=$LongPollTimeout&allowed_updates=%5B%22message%22%5D"
    try {
        $R = Invoke-RestMethod -Uri $Uri -Method Get -TimeoutSec ($LongPollTimeout + 10)
        if ($R.ok) { return $R.result }
    } catch {
        Write-Host "⚠️ [TELEGRAM] getUpdates falló: $_" -ForegroundColor DarkYellow
    }
    return @()
}
