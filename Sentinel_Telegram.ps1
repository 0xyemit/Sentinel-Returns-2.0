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
        parse_mode = "Markdown"
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
