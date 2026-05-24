# Sentinel_Data.ps1
# MODULO 1: Extraccion de datos de mercado en tiempo real (Binance API)

function Get-SentinelMarketData {
    Write-Host "[DATA] Conectando con Binance para extraer precios en tiempo real..." -ForegroundColor Cyan

    $Prices = @{ BTC = 0.0; ETH = 0.0; SOL = 0.0; ONDO = 0.0; HBAR = 0.0; XRP = 0.0; TAO = 0.0 }

    try {
        $Symbols = '["BTCUSDT","ETHUSDT","SOLUSDT","ONDOUSDT","HBARUSDT","XRPUSDT","TAOUSDT"]'
        $Uri = "https://api.binance.com/api/v3/ticker/price?symbols=$([Uri]::EscapeDataString($Symbols))"
        $R = Invoke-RestMethod -Uri $Uri -Method Get -TimeoutSec 15

        foreach ($Item in $R) {
            switch ($Item.symbol) {
                "BTCUSDT"  { $Prices.BTC  = [math]::Round([double]$Item.price, 2) }
                "ETHUSDT"  { $Prices.ETH  = [math]::Round([double]$Item.price, 2) }
                "SOLUSDT"  { $Prices.SOL  = [math]::Round([double]$Item.price, 2) }
                "ONDOUSDT" { $Prices.ONDO = [math]::Round([double]$Item.price, 4) }
                "HBARUSDT" { $Prices.HBAR = [math]::Round([double]$Item.price, 4) }
                "XRPUSDT"  { $Prices.XRP  = [math]::Round([double]$Item.price, 4) }
                "TAOUSDT"  { $Prices.TAO  = [math]::Round([double]$Item.price, 2) }
            }
        }

        Write-Host "[DATA] Precios obtenidos. BTC: $($Prices.BTC)" -ForegroundColor Green
    }
    catch {
        Write-Host "[DATA] Error al extraer precios: $_" -ForegroundColor Red
    }

    # Indice Fear & Greed
    $FngValue  = "50"
    $FngStatus = "Neutral"
    try {
        $Fng       = Invoke-RestMethod -Uri "https://api.alternative.me/fng/" -Method Get -TimeoutSec 10
        $FngValue  = $Fng.data[0].value
        $FngStatus = $Fng.data[0].value_classification
    }
    catch {
        Write-Host "[DATA] Error al extraer Fear & Greed. Usando Neutral." -ForegroundColor Yellow
    }

    return [PSCustomObject]@{
        Timestamp = ([TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, [TimeZoneInfo]::FindSystemTimeZoneById("Europe/Madrid"))).ToString("yyyy-MM-dd HH:mm:ss")
        BTC       = $Prices.BTC
        ETH       = $Prices.ETH
        SOL       = $Prices.SOL
        ONDO      = $Prices.ONDO
        HBAR      = $Prices.HBAR
        XRP       = $Prices.XRP
        TAO       = $Prices.TAO
        FnGValue  = $FngValue
        FnGStatus = $FngStatus
    }
}
