# Instalacao direta do PC SISTEMA/cliente — sem hub Servidor.
# Uso: .\Instalar-Pacote-Sistema.ps1
#      ..\Instalar Sistema.vbs (na pasta transferivel Sistema)

$ErrorActionPreference = 'Stop'

$candidates = @(
  (Join-Path $PSScriptRoot 'Assistente-Instalacao-Cliente.ps1')
)
$assistente = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $assistente) { throw 'Assistente-Instalacao-Cliente.ps1 nao encontrado neste pacote.' }

$assistente = (Resolve-Path -LiteralPath $assistente).Path
$qAssist = if ($assistente -match '[\s"]') { '"' + ($assistente.Replace('"', '\"')) + '"' } else { $assistente }
Start-Process -FilePath 'powershell.exe' -ArgumentList @(
  '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass',
  '-File', $qAssist, '-CreateDesktopShortcut'
) -WorkingDirectory (Split-Path $assistente -Parent) -Wait
