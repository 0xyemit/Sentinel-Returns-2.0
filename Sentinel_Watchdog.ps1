# Sentinel_Watchdog.ps1
# Guarda el listener activo 24/7: lo reinicia si muere.
# Ejecutado por Windows Task Scheduler al arrancar sesion.

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$CurrentDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$MainScript  = Join-Path $CurrentDir "Sentinel_Main.ps1"
$LogFile     = Join-Path $CurrentDir "sentinel_watchdog.log"

function Write-Log {
    param([string]$Message)
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $Message"
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    Write-Host $line
}

# Rotar log si supera 1 MB
if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt 1MB) {
    Rename-Item $LogFile "$LogFile.bak" -Force
}

Write-Log "=== WATCHDOG ARRANCADO ==="

while ($true) {
    Write-Log "Iniciando Sentinel_Main.ps1 -Listen..."

    $Proc = Start-Process -FilePath "powershell.exe" `
        -ArgumentList "-ExecutionPolicy Bypass -File `"$MainScript`" -Listen" `
        -PassThru -NoNewWindow

    Write-Log "PID $($Proc.Id) en marcha."

    # Esperar a que el proceso termine
    $Proc.WaitForExit()

    $ExitCode = $Proc.ExitCode
    Write-Log "Proceso terminado. ExitCode=$ExitCode. Reiniciando en 10s..."
    Start-Sleep -Seconds 10
}
