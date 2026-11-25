# Instalador unico — pasta "Servidor-final" (programas + pacote).
# Senha do assistente: Marinha

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$desk = [Environment]::GetFolderPath('Desktop')

Add-Type -AssemblyName System.Windows.Forms | Out-Null

function Find-PacoteServidor {
  $candidates = @(
    (Join-Path $root 'Arquivos\Servidor'),
    (Join-Path $root 'Servidor'),
    (Join-Path $desk 'Servidor-final\Arquivos\Servidor'),
    (Join-Path $desk 'Servidor final\Arquivos\Servidor'),
    (Join-Path $desk 'Arquivos\Servidor'),
    (Join-Path $desk 'Iniciar Servidor'),
    (Join-Path $desk 'Transferir Servidor')
  )
  foreach ($c in $candidates) {
    if (-not (Test-Path -LiteralPath $c)) { continue }
    $vbs = Join-Path $c 'Instalar Servidor.vbs'
    $dash = Join-Path $c 'Gereal\AcompSolemp\servidor-portatil\Dashboard.vbs'
    $ps1 = Join-Path $c 'Gereal\AcompSolemp\servidor-portatil\scripts\Instalar-Pacote-Servidor.ps1'
    if ((Test-Path -LiteralPath $vbs) -or (Test-Path -LiteralPath $dash) -or (Test-Path -LiteralPath $ps1)) {
      return (Resolve-Path -LiteralPath $c).Path
    }
  }
  return $null
}

function Find-InstaladoresDir {
  $candidates = @(
    (Join-Path $root 'instaladores'),
    (Join-Path $root 'Arquivos\Servidor\Gereal\instaladores'),
    (Join-Path $root 'Arquivos\Servidor\instaladores'),
    (Join-Path $desk 'instaladores'),
    (Join-Path $desk 'Servidor-final\instaladores'),
    (Join-Path $desk 'Servidor final\instaladores')
  )
  foreach ($c in $candidates) {
    if (-not (Test-Path -LiteralPath $c)) { continue }
    $docker = Get-ChildItem -LiteralPath $c -Filter 'Docker*Installer*.exe' -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($docker) { return (Resolve-Path -LiteralPath $c).Path }
  }
  return $null
}

function New-DesktopShortcut([string]$Name, [string]$Target, [string]$WorkDir = '', [string]$Args = '') {
  $ws = New-Object -ComObject WScript.Shell
  $path = Join-Path $desk ($Name + '.lnk')
  $lnk = $ws.CreateShortcut($path)
  $lnk.TargetPath = $Target
  if ($Args) { $lnk.Arguments = $Args }
  if ($WorkDir) { $lnk.WorkingDirectory = $WorkDir } else { $lnk.WorkingDirectory = Split-Path -Parent $Target }
  $lnk.Description = $Name
  $lnk.Save()
  return $path
}

Write-Host ''
Write-Host '========================================'
Write-Host '  Servidor-final — AcompOPMS'
  Write-Host '  (programas + pacote nesta pasta)'
  Write-Host '========================================'
Write-Host ''

$pack = Find-PacoteServidor
if (-not $pack) {
  [Windows.Forms.MessageBox]::Show(
    "Nao achei o pacote do servidor dentro desta pasta.`n`nEsperado:`n$root\Arquivos\Servidor`n(com a pasta Gereal dentro)",
    'Servidor-final — AcompOPMS',
    'OK',
    'Error'
  ) | Out-Null
  exit 1
}

$instDir = Find-InstaladoresDir
Write-Host "Pacote: $pack"
Write-Host ("Instaladores: {0}" -f ($(if ($instDir) { $instDir } else { '(nao encontrados — ok se Docker/Node ja estiverem instalados)' })))

# Garantir que o assistente ache os instaladores relativos ao pacote
if ($instDir) {
  $gerealInst = Join-Path $pack 'Gereal\instaladores'
  if (-not (Test-Path -LiteralPath $gerealInst)) {
    New-Item -ItemType Directory -Force -Path $gerealInst | Out-Null
  }
  foreach ($pat in @('Docker*Installer*.exe', 'node-*.msi', 'vc_redist*.exe', 'wsl_update*.msi')) {
    Get-ChildItem -LiteralPath $instDir -Filter $pat -File -ErrorAction SilentlyContinue | ForEach-Object {
      $dest = Join-Path $gerealInst $_.Name
      if (-not (Test-Path -LiteralPath $dest)) {
        Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
      }
    }
  }
}

$dashVbs = Join-Path $pack 'Gereal\AcompSolemp\servidor-portatil\Dashboard.vbs'
if (-not (Test-Path -LiteralPath $dashVbs)) {
  $dashVbs = Join-Path $pack 'Dashboard.vbs'
}
$viteCmd = Join-Path $pack 'Gereal\AcompSolemp\servidor-portatil\Reiniciar-Frontend.cmd'
if (-not (Test-Path -LiteralPath $viteCmd)) {
  $viteCmd = Join-Path $pack 'Gereal\AcompSolemp\servidor-portatil\scripts\Start-Vite.ps1'
}

if (Test-Path -LiteralPath $dashVbs) {
  $p1 = New-DesktopShortcut 'Servidor AcompOPMS' $dashVbs
  Write-Host "Atalho: $p1"
}

if (Test-Path -LiteralPath $viteCmd) {
  if ($viteCmd.ToLower().EndsWith('.ps1')) {
    $p2 = New-DesktopShortcut 'Reiniciar Frontend AcompOPMS' 'powershell.exe' (Split-Path $viteCmd) (
      "-NoProfile -ExecutionPolicy Bypass -File `"$viteCmd`" -ShowWindow"
    )
  } else {
    $p2 = New-DesktopShortcut 'Reiniciar Frontend AcompOPMS' $viteCmd
  }
  Write-Host "Atalho: $p2"
}

$selfCmd = Join-Path $root 'Instalar-Servidor-AcompOPMS.cmd'
if (Test-Path -LiteralPath $selfCmd) {
  New-DesktopShortcut 'Instalar Servidor AcompOPMS' $selfCmd | Out-Null
}

$instalarVbs = Join-Path $pack 'Instalar Servidor.vbs'
$instalarPs1 = Join-Path $pack 'Gereal\AcompSolemp\servidor-portatil\scripts\Instalar-Pacote-Servidor.ps1'

Write-Host ''
Write-Host 'Abrindo o assistente de instalacao...'
Write-Host 'Senha: Marinha'
Write-Host ''

if (Test-Path -LiteralPath $instalarVbs) {
  $p = Start-Process -FilePath 'wscript.exe' -ArgumentList "`"$instalarVbs`"" -Wait -PassThru
  $code = $p.ExitCode
} elseif (Test-Path -LiteralPath $instalarPs1) {
  $p = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', $instalarPs1
  ) -Wait -PassThru
  $code = $p.ExitCode
} else {
  [Windows.Forms.MessageBox]::Show(
    "Pacote encontrado, mas sem Instalar Servidor.vbs / Instalar-Pacote-Servidor.ps1.`n`n$pack",
    'Servidor-final — AcompOPMS',
    'OK',
    'Error'
  ) | Out-Null
  exit 1
}

Write-Host ''
Write-Host 'Assistente encerrado.'
Write-Host 'Use o atalho "Servidor AcompOPMS" e clique em Iniciar servidor.'
Write-Host ''

if ($code -ne 0 -and $null -ne $code) { exit $code }
exit 0
