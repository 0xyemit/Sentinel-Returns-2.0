# G:\Mi unidad\1. PROYECTOS\SENTINEL RETURNS\Sentinel_Data.ps1
# MÓDULO 1: Extracción de datos de mercado en tiempo real (Bybit API)

function Get-SentinelMarketData {
    $Symbols = @("BTCUSDT", "ETHUSDT", "SOLUSDT", "ONDOUSDT", "HBARUSDT", "XRPUSDT", "TAOUSDT")
    $MarketPrices = @{}

    Write-Host "🔄 [DATA] Conectando con Bybit para extraer precios en tiempo real..." -ForegroundColor Cyan

    foreach ($Symbol in $Symbols) {
        try {
            $Uri = "https://api.bybit.com/v5/market/tickers?category=spot&symbol=$Symbol"
            $Response = Invoke-RestMethod -Uri $Uri -Method Get -TimeoutSec 10
            $PriceRaw = [double]$Response.result.list[0].lastPrice

            if ($PriceRaw -lt 2.0) {
                $MarketPrices[$Symbol] = [math]::Round($PriceRaw, 4)
            } else {
                $MarketPrices[$Symbol] = [math]::Round($PriceRaw, 2)
            }
        }
        catch {
            Write-Host "⚠️ [DATA] Error al extraer precio de $Symbol. Usando 0.0" -ForegroundColor Yellow
            $MarketPrices[$Symbol] = 0.0
        }
    }

    # Índice Fear & Greed
    try {
        $FngResponse = Invoke-RestMethod -Uri "https://api.alternative.me/fng/" -Method Get -TimeoutSec 10
        $FngValue  = $FngResponse.data[0].value
        $FngStatus = $FngResponse.data[0].value_classification
    }
    catch {
        $FngValue  = "50"
        $FngStatus = "Neutral"
    }

    return [PSCustomObject]@{
        Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        BTC       = $MarketPrices["BTCUSDT"]
        ETH       = $MarketPrices["ETHUSDT"]
        SOL       = $MarketPrices["SOLUSDT"]
        ONDO      = $MarketPrices["ONDOUSDT"]
        HBAR      = $MarketPrices["HBARUSDT"]
        XRP       = $MarketPrices["XRPUSDT"]
        TAO       = $MarketPrices["TAOUSDT"]
        FnGValue  = $FngValue
        FnGStatus = $FngStatus
    }
}
