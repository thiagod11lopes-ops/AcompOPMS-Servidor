# Sobe (ou reinicia) o frontend Vite e espera responder em /login.
# Uso:
#   .\Start-Vite.ps1
#   .\Start-Vite.ps1 -ShowWindow

param(
  [int]$Port = 0,
  [switch]$ShowWindow
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_common.ps1"

$cfg = Import-ServidorConfig
$frontendDir = $cfg.FRONTEND_DIR
if (-not $frontendDir -or -not (Test-Path -LiteralPath $frontendDir)) {
  throw "FRONTEND_DIR invalido: $frontendDir"
}
if ($Port -le 0) {
  try { $Port = [int]$cfg.APP_PORT } catch { $Port = 5173 }
}
if ($Port -le 0) { $Port = 5173 }

$logDir = Join-Path (Get-ServidorRoot) 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$outLog = Join-Path $logDir 'vite.out.log'
$errLog = Join-Path $logDir 'vite.err.log'
$pidFile = Join-Path $logDir 'vite.pid'
$statusFile = Join-Path $logDir 'vite.status.txt'

function Write-ViteStatus([string]$Text) {
  $line = ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Text)
  Add-Content -LiteralPath $statusFile -Value $line -Encoding UTF8
  Write-Host $line
}

function Test-ViteUp([int]$P) {
  try {
    $code = & curl.exe -s -o NUL -w '%{http_code}' --max-time 3 "http://127.0.0.1:$P/login" 2>$null
    if (-not $code) { $code = '0' }
    return ($code -eq '200' -or $code -eq '304' -or $code -eq '301' -or $code -eq '302')
  } catch {
    return $false
  }
}

Set-Content -LiteralPath $statusFile -Value '' -Encoding UTF8
Write-ViteStatus "FRONTEND_DIR=$frontendDir"
Write-ViteStatus "PORT=$Port"

if (Test-ViteUp $Port) {
  Write-ViteStatus "Vite ja estava no ar em http://127.0.0.1:$Port/login"
  exit 0
}

Write-ViteStatus 'Encerrando o que estiver na porta...'
try {
  $owners = @(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty OwningProcess -Unique)
  foreach ($pidOwn in $owners) {
    if ($pidOwn -and $pidOwn -gt 8) {
      Write-ViteStatus "Stop-Process PID $pidOwn"
      Stop-Process -Id $pidOwn -Force -ErrorAction SilentlyContinue
    }
  }
} catch {
  Write-ViteStatus ("Aviso ao liberar porta: {0}" -f $_.Exception.Message)
}

if (Test-Path $pidFile) {
  $old = Get-Content $pidFile -ErrorAction SilentlyContinue
  if ($old) {
    try { Stop-Process -Id ([int]$old) -Force -ErrorAction SilentlyContinue } catch { }
  }
  Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 1

function Test-FrontendDepsOk {
  $need = @(
    (Join-Path $frontendDir 'node_modules\vite\dist\node\cli.js'),
    (Join-Path $frontendDir 'node_modules\@rolldown\pluginutils\dist\index.mjs')
  )
  foreach ($p in $need) {
    if (-not (Test-Path -LiteralPath $p)) { return $false }
  }
  return $true
}

$needNpm = -not (Test-Path (Join-Path $frontendDir 'node_modules'))
if (-not $needNpm -and -not (Test-FrontendDepsOk)) {
  Write-ViteStatus 'Dependencias incompletas (vite/rolldown) — reinstalando node_modules...'
  $needNpm = $true
  Remove-Item -Recurse -Force (Join-Path $frontendDir 'node_modules') -ErrorAction SilentlyContinue
}
if ($needNpm) {
  Write-ViteStatus 'Rodando npm install no frontend...'
  Push-Location $frontendDir
  try {
    cmd.exe /c "npm.cmd install --no-audit --no-fund"
    if ($LASTEXITCODE -ne 0) { throw "npm install falhou (codigo $LASTEXITCODE)" }
  } finally {
    Pop-Location
  }
  if (-not (Test-FrontendDepsOk)) {
    throw 'Dependencias do frontend ainda incompletas apos npm install (vite/rolldown).'
  }
}

$npmCmd = $null
$npm = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
if ($npm) { $npmCmd = $npm.Source }
if (-not $npmCmd) {
  $npm = Get-Command 'npm' -ErrorAction SilentlyContinue
  if ($npm) { $npmCmd = $npm.Source }
}
if (-not $npmCmd) { throw 'npm nao encontrado no PATH. Reinstale o Node.js e abra um novo PowerShell.' }
Write-ViteStatus "npm=$npmCmd"

Set-Content -LiteralPath $outLog -Value '' -Encoding UTF8
Set-Content -LiteralPath $errLog -Value '' -Encoding UTF8

# Importante: no Windows, Start-Process + Redirect NAO funciona bem com .cmd.
# Sempre usa cmd.exe /c para o modo oculto.
$inner = "`"$npmCmd`" run dev -- --host 0.0.0.0 --port $Port"
Write-ViteStatus "Iniciando: cmd /c $inner"

if ($ShowWindow) {
  $p = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/k', $inner) `
    -WorkingDirectory $frontendDir -PassThru -WindowStyle Normal
} else {
  $p = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', $inner) `
    -WorkingDirectory $frontendDir -PassThru -WindowStyle Hidden `
    -RedirectStandardOutput $outLog -RedirectStandardError $errLog
}

if (-not $p) { throw 'Start-Process cmd/npm falhou (processo nulo).' }
Set-Content -LiteralPath $pidFile -Value $p.Id -Encoding ASCII
Write-ViteStatus "PID=$($p.Id)"

$ready = $false
for ($i = 1; $i -le 60; $i++) {
  if (Test-ViteUp $Port) { $ready = $true; break }
  if (-not $ShowWindow -and $p.HasExited) {
    Write-ViteStatus "cmd/vite encerrou cedo (ExitCode=$($p.ExitCode))"
    break
  }
  Start-Sleep -Seconds 2
}

if (-not $ready) {
  $tailErr = ''
  $tailOut = ''
  if (Test-Path $errLog) {
    $tailErr = ((Get-Content -LiteralPath $errLog -Tail 40 -ErrorAction SilentlyContinue) -join "`n")
  }
  if (Test-Path $outLog) {
    $tailOut = ((Get-Content -LiteralPath $outLog -Tail 40 -ErrorAction SilentlyContinue) -join "`n")
  }
  Write-ViteStatus 'FALHA — Vite nao respondeu em /login'
  if ($tailErr) { Write-ViteStatus "STDERR:`n$tailErr" }
  if ($tailOut) { Write-ViteStatus "STDOUT:`n$tailOut" }
  throw @"
Vite nao respondeu em http://127.0.0.1:$Port/login

Veja:
$errLog
$statusFile

Trecho:
$tailErr
"@
}

Write-ViteStatus "OK http://127.0.0.1:$Port/login"
exit 0
