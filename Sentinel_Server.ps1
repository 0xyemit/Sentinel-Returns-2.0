# Sentinel_Server.ps1
# Servidor HTTP webhook para Google Cloud Run.
# Recibe updates de Telegram via POST, procesa comandos, responde via Bot API.

function Start-SentinelWebhookServer {
    $OllamaKey  = $env:SENTINEL_OLLAMA_KEY
    $TgToken    = $env:SENTINEL_TG_TOKEN
    $TgChatId   = $env:SENTINEL_TG_CHATID
    $Port       = if ($env:PORT) { $env:PORT } else { "8080" }

    if (-not $OllamaKey)  { Write-Error "[SERVER] SENTINEL_OLLAMA_KEY vacia."; exit 1 }
    if (-not $TgToken)    { Write-Error "[SERVER] SENTINEL_TG_TOKEN vacia."; exit 1 }
    if (-not $TgChatId)   { Write-Error "[SERVER] SENTINEL_TG_CHATID vacia."; exit 1 }

    $ValidCoins = @("BTC","ETH","SOL","ONDO","HBAR","XRP","TAO")

    $Listener = [System.Net.HttpListener]::new()
    $Listener.Prefixes.Add("http://+:$Port/")
    $Listener.Start()

    Write-Host "🌐 [SERVER] Escuchando en :$Port — listo para webhooks de Telegram." -ForegroundColor Cyan

    while ($true) {
        try {
            $Context  = $Listener.GetContext()
            $Request  = $Context.Request
            $Response = $Context.Response

            # Health check (GET /) — usado por Cloud Run para liveness
            if ($Request.HttpMethod -eq "GET") {
                $Bytes = [System.Text.Encoding]::UTF8.GetBytes("OK")
                $Response.StatusCode = 200
                $Response.ContentLength64 = $Bytes.Length
                $Response.OutputStream.Write($Bytes, 0, $Bytes.Length)
                $Response.Close()
                continue
            }

            # Leer body del POST de Telegram
            $Reader = [System.IO.StreamReader]::new($Request.InputStream, [System.Text.Encoding]::UTF8)
            $Body   = $Reader.ReadToEnd()
            $Reader.Dispose()

            # Parsear JSON
            $Update  = $null
            $MsgText = $null
            $ChatId  = $null
            try {
                $Update  = $Body | ConvertFrom-Json
                $MsgText = $Update.message.text
                $ChatId  = [string]$Update.message.chat.id
            } catch {
                Write-Host "⚠️ [SERVER] JSON invalido — ignorando." -ForegroundColor Yellow
            }

            # Devolver 200 a Telegram ANTES de procesar (evita reintentos)
            # NOTA: el procesamiento continua en el mismo hilo despues del Close()
            $OkBytes = [System.Text.Encoding]::UTF8.GetBytes("OK")
            $Response.StatusCode = 200
            $Response.ContentLength64 = $OkBytes.Length
            $Response.OutputStream.Write($OkBytes, 0, $OkBytes.Length)
            $Response.Close()

            if (-not $MsgText -or -not $ChatId) { continue }

            Write-Host "📩 [SERVER] [$ChatId] $MsgText" -ForegroundColor DarkCyan

            # --- COMANDOS ---

            if ($MsgText -match '^/help') {
                $Msg = "🛡️ <b>SENTINEL — Comandos</b>`n`n/analisis — Reporte completo (7 activos)`n/analisis BTC — Un activo (BTC ETH SOL ONDO HBAR XRP TAO)`n/status — Precios sin IA`n/help — Esta ayuda"
                Send-SentinelTelegramMessage -MessageText $Msg -Token $TgToken -ChatId $ChatId | Out-Null
            }
            elseif ($MsgText -match '^/status') {
                Write-Host "⚡ [SERVER] /status — obteniendo precios..." -ForegroundColor Yellow
                $MD = Get-SentinelMarketData
                $Msg = "⚡ <b>PRECIOS EN TIEMPO REAL</b>`n📅 $($MD.Timestamp)`n`n₿ BTC  <code>`$$($MD.BTC)</code>`nΞ ETH  <code>`$$($MD.ETH)</code>`n◎ SOL  <code>`$$($MD.SOL)</code>`n💧 XRP  <code>`$$($MD.XRP)</code>`n💠 ONDO <code>`$$($MD.ONDO)</code>`n🔷 HBAR <code>`$$($MD.HBAR)</code>`n🧠 TAO  <code>`$$($MD.TAO)</code>`n`n😐 F&amp;G: $($MD.FnGValue) — $($MD.FnGStatus)"
                Send-SentinelTelegramMessage -MessageText $Msg -Token $TgToken -ChatId $ChatId | Out-Null
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

        } catch {
            Write-Host "❌ [SERVER] Error en request loop: $_" -ForegroundColor Red
            try { $Response.StatusCode = 200; $Response.Close() } catch {}
        }
    }
}
