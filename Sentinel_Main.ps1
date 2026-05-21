# G:\Mi unidad\1. PROYECTOS\SENTINEL RETURNS\Sentinel_Main.ps1
# MASTER SCRIPT: Orquestador central de Sentinel Returns (UTF-8 GLOBAL BLINDAJE)
param([switch]$Listen)

# FORZAR ENCODING UTF-8 GLOBAL EN LA CONSOLA DE WINDOWS Y POWERSHELL
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Forzar protocolo seguro para conexiones externas
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Cargar módulos funcionales de forma relativa
$CurrentDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$CurrentDir\Sentinel_Data.ps1"
. "$CurrentDir\Sentinel_Brain.ps1"
. "$CurrentDir\Sentinel_Telegram.ps1"

# Cargar .env si existe (ejecución local — GitHub Actions inyecta desde Secrets)
$EnvFile = Join-Path $CurrentDir ".env"
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | Where-Object { $_ -match '^\s*([^#=]+?)\s*=\s*(.+?)\s*$' } | ForEach-Object {
        $n = $Matches[1]; $v = $Matches[2].Trim('"').Trim("'")
        if (-not [Environment]::GetEnvironmentVariable($n, "Process")) {
            [Environment]::SetEnvironmentVariable($n, $v, "Process")
        }
    }
}

function Start-SentinelPipeline {
    Write-Host "`n🛡️ === ARRANCANDO PIPELINE: SENTINEL RETURNS (UTF-8 SECURE) ===" -ForegroundColor White -BackgroundColor DarkBlue

    # Recuperar variables esenciales de entorno
    $OllamaKey    = $env:SENTINEL_OLLAMA_KEY
    $TgToken      = $env:SENTINEL_TG_TOKEN
    $TgChatId     = $env:SENTINEL_TG_CHATID
    $CoinCapKey   = $env:SENTINEL_COINCAP_KEY

    if (-not $OllamaKey)  { Write-Error "❌ [MASTER] Error: `$env:SENTINEL_OLLAMA_KEY está vacía."; return }
    if (-not $TgToken)    { Write-Error "❌ [MASTER] Error: `$env:SENTINEL_TG_TOKEN está vacía."; return }
    if (-not $TgChatId)   { Write-Error "❌ [MASTER] Error: `$env:SENTINEL_TG_CHATID está vacía."; return }
    if (-not $CoinCapKey) { Write-Error "❌ [MASTER] Error: `$env:SENTINEL_COINCAP_KEY está vacía."; return }

    # 1. Extraer precios en tiempo real (CoinGecko)
    $MarketData = Get-SentinelMarketData
    if ($MarketData.BTC -eq 0.0) {
        Write-Host "⚠️ [MASTER] Alerta: Datos de mercado caídos. Cancelando ejecución." -ForegroundColor Red
        return
    }

    # 2. Procesar análisis con deepseek-v4-flash en Ollama Cloud
    $ReporteMarkdown = Get-SentinelAnalysis -MarketData $MarketData -ApiKey $OllamaKey

    if (@($ReporteMarkdown)[0] -like "ERROR:*") {
        Write-Host "⚠️ [MASTER] Alerta: El análisis falló. Abortando envío." -ForegroundColor Red
        return
    }

    # 3. Despachar a tu móvil por Telegram (2 mensajes)
    $TodosEnviados = $true
    foreach ($Msg in $ReporteMarkdown) {
        $Ok = Send-SentinelTelegramMessage -MessageText $Msg -Token $TgToken -ChatId $TgChatId
        if (-not $Ok) { $TodosEnviados = $false }
        Start-Sleep -Milliseconds 800
    }

    if ($TodosEnviados) {
        Write-Host "🏁 [MASTER] Pipeline completado. ¡Reporte limpio enviado con éxito!" -ForegroundColor Green
    } else {
        Write-Host "⚠️ [MASTER] El reporte se generó pero falló algún envío por Telegram." -ForegroundColor Yellow
    }
}

function Start-SentinelListener {
    $OllamaKey  = $env:SENTINEL_OLLAMA_KEY
    $TgToken    = $env:SENTINEL_TG_TOKEN
    $TgChatId   = $env:SENTINEL_TG_CHATID
    $CoinCapKey = $env:SENTINEL_COINCAP_KEY

    if (-not $OllamaKey)  { Write-Error "❌ [LISTENER] SENTINEL_OLLAMA_KEY vacía."; return }
    if (-not $TgToken)    { Write-Error "❌ [LISTENER] SENTINEL_TG_TOKEN vacía."; return }
    if (-not $TgChatId)   { Write-Error "❌ [LISTENER] SENTINEL_TG_CHATID vacía."; return }
    if (-not $CoinCapKey) { Write-Error "❌ [LISTENER] SENTINEL_COINCAP_KEY vacía."; return }

    $ValidCoins = @("BTC","ETH","SOL","ONDO","HBAR","XRP","TAO")
    $Offset     = 0L

    Clear-TelegramWebhook -Token $TgToken

    Write-Host "`n🎧 [LISTENER] Escuchando comandos de Telegram. Ctrl+C para salir." -ForegroundColor Cyan

    while ($true) {
        $Updates = @(Get-TelegramUpdates -Token $TgToken -Offset $Offset -LongPollTimeout 5)

        foreach ($Update in $Updates) {
            $Offset  = [long]$Update.update_id + 1L
            $MsgText = $Update.message.text
            $ChatId  = [string]$Update.message.chat.id
            if (-not $MsgText) { continue }

            Write-Host "📩 [LISTENER] [$ChatId] $MsgText" -ForegroundColor DarkCyan

            if ($MsgText -match '^/help') {
                $HelpMsg = "🛡️ <b>SENTINEL — Comandos</b>`n`n/analisis — Reporte completo (7 activos)`n/analisis BTC — Un activo (BTC ETH SOL ONDO HBAR XRP TAO)`n/status — Precios sin IA`n/help — Esta ayuda"
                Send-SentinelTelegramMessage -MessageText $HelpMsg -Token $TgToken -ChatId $ChatId | Out-Null
            }
            elseif ($MsgText -match '^/status') {
                Write-Host "⚡ [LISTENER] Obteniendo precios..." -ForegroundColor Yellow
                $MD = Get-SentinelMarketData
                $StatusMsg = "⚡ <b>PRECIOS EN TIEMPO REAL</b>`n📅 $($MD.Timestamp)`n`n₿ BTC  <code>`$$($MD.BTC)</code>`nΞ ETH  <code>`$$($MD.ETH)</code>`n◎ SOL  <code>`$$($MD.SOL)</code>`n💧 XRP  <code>`$$($MD.XRP)</code>`n💠 ONDO <code>`$$($MD.ONDO)</code>`n🔷 HBAR <code>`$$($MD.HBAR)</code>`n🧠 TAO  <code>`$$($MD.TAO)</code>`n`n😐 F&amp;G: $($MD.FnGValue) — $($MD.FnGStatus)"
                Send-SentinelTelegramMessage -MessageText $StatusMsg -Token $TgToken -ChatId $ChatId | Out-Null
            }
            elseif ($MsgText -match '^/analisis(?:\s+(\w+))?') {
                $RequestedCoin = if ($Matches[1]) { $Matches[1].ToUpper() } else { $null }

                if ($RequestedCoin -and $RequestedCoin -notin $ValidCoins) {
                    Send-SentinelTelegramMessage -MessageText "❌ Moneda no reconocida: <code>$RequestedCoin</code>`nUsa: BTC ETH SOL ONDO HBAR XRP TAO" -Token $TgToken -ChatId $ChatId | Out-Null
                    continue
                }

                $WaitMsg = if ($RequestedCoin) { "⏳ Analizando <b>$RequestedCoin</b>..." } else { "⏳ Generando reporte completo..." }
                Send-SentinelTelegramMessage -MessageText $WaitMsg -Token $TgToken -ChatId $ChatId | Out-Null

                $MD = Get-SentinelMarketData
                if ($MD.BTC -eq 0.0) {
                    Send-SentinelTelegramMessage -MessageText "❌ Error obteniendo datos de mercado." -Token $TgToken -ChatId $ChatId | Out-Null
                    continue
                }

                $Params = @{ MarketData = $MD; ApiKey = $OllamaKey }
                if ($RequestedCoin) { $Params['FilterCoin'] = $RequestedCoin }

                $Msgs = Get-SentinelAnalysis @Params
                if (@($Msgs)[0] -like "ERROR:*") {
                    Send-SentinelTelegramMessage -MessageText "❌ $(@($Msgs)[0])" -Token $TgToken -ChatId $ChatId | Out-Null
                    continue
                }

                foreach ($Msg in $Msgs) {
                    Send-SentinelTelegramMessage -MessageText $Msg -Token $TgToken -ChatId $ChatId | Out-Null
                    Start-Sleep -Milliseconds 800
                }
            }
        }

        if ($Updates.Count -eq 0) { Start-Sleep -Seconds 2 }
    }
}

if ($Listen) { Start-SentinelListener } else { Start-SentinelPipeline }
