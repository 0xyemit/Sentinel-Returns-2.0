# deploy.ps1
# Despliega Sentinel en Google Cloud Run y registra el webhook de Telegram.
# Requisito: gcloud CLI autenticado (gcloud auth login)
# Uso: .\deploy.ps1

$ErrorActionPreference = "Stop"
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# --- 1. Leer variables del .env local ---
$EnvFile = Join-Path $ProjectDir ".env"
if (-not (Test-Path $EnvFile)) {
    Write-Error "No se encontro .env en $ProjectDir"
    exit 1
}

$Vars = @{}
Get-Content $EnvFile | Where-Object { $_ -match '^\s*([^#=]+?)\s*=\s*(.+?)\s*$' } | ForEach-Object {
    $Vars[$Matches[1]] = $Matches[2].Trim('"').Trim("'")
}

$OllamaKey  = $Vars["SENTINEL_OLLAMA_KEY"]
$TgToken    = $Vars["SENTINEL_TG_TOKEN"]
$TgChatId   = $Vars["SENTINEL_TG_CHATID"]

if (-not $OllamaKey -or -not $TgToken -or -not $TgChatId) {
    Write-Error "Faltan variables en .env. Revisa SENTINEL_OLLAMA_KEY, SENTINEL_TG_TOKEN, SENTINEL_TG_CHATID"
    exit 1
}

# --- 2. Configuracion del servicio ---
$ServiceName = "sentinel-bot"
$Region      = "europe-west1"

$EnvVarsStr = "SENTINEL_OLLAMA_KEY=$OllamaKey,SENTINEL_TG_TOKEN=$TgToken,SENTINEL_TG_CHATID=$TgChatId"

Write-Host "`n[DEPLOY] Desplegando $ServiceName en Cloud Run ($Region)..." -ForegroundColor Cyan

# --- 3. Deploy ---
gcloud run deploy $ServiceName `
    --source $ProjectDir `
    --region $Region `
    --platform managed `
    --allow-unauthenticated `
    --memory 512Mi `
    --cpu 1 `
    --timeout 120 `
    --min-instances 0 `
    --max-instances 3 `
    --set-env-vars $EnvVarsStr `
    --no-cpu-throttling `
    --quiet

if ($LASTEXITCODE -ne 0) {
    Write-Error "gcloud deploy fallo. Revisa los logs."
    exit 1
}

# --- 4. Obtener URL del servicio ---
$ServiceUrl = (gcloud run services describe $ServiceName --region $Region --format "value(status.url)") 2>$null
Write-Host "`n[OK] Servicio activo: $ServiceUrl" -ForegroundColor Green

# --- 5. Registrar webhook de Telegram ---
Write-Host "`n[WEBHOOK] Registrando en Telegram..." -ForegroundColor Cyan
$WebhookUri = "https://api.telegram.org/bot$TgToken/setWebhook"
$Body = @{ url = "$ServiceUrl/" } | ConvertTo-Json
$R = Invoke-RestMethod -Uri $WebhookUri -Method Post -Body $Body -ContentType "application/json" -TimeoutSec 15

if ($R.ok) {
    Write-Host "[OK] Webhook registrado: $ServiceUrl/" -ForegroundColor Green
} else {
    Write-Host "[WARN] setWebhook respondio ok=false: $($R.description)" -ForegroundColor Yellow
}

Write-Host "`n[!] IMPORTANTE: Deshabilita el watchdog local para evitar conflicto:" -ForegroundColor Yellow
Write-Host "    Disable-ScheduledTask -TaskName 'SentinelReturns-Listener'" -ForegroundColor DarkYellow
Write-Host "`n[DONE] Deploy completado. Prueba enviando /status en Telegram.`n" -ForegroundColor Green
