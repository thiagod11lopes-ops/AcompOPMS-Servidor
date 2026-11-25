# Garante a CA AcompOPMS no armazenamento Raiz confiavel deste PC.
# Uso:
#   .\Ensure-Certificado-Confianca.ps1
#   .\Ensure-Certificado-Confianca.ps1 -ServerHost 10.6.167.66 -OpenBrowser
#   .\Ensure-Certificado-Confianca.ps1 -CaPath C:\...\AcompOPMS-rootCA.pem

param(
  [string]$ServerHost = '',
  [string]$CaPath = '',
  [switch]$OpenBrowser,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$logDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'logs'
if (-not (Test-Path -LiteralPath $logDir)) {
  New-Item -ItemType Directory -Force -Path $logDir | Out-Null
}
$logFile = Join-Path $logDir 'ensure-cert.log'

function Write-Info([string]$Message) {
  $line = ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message)
  try { Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8 } catch { }
  if (-not $Quiet) { Write-Host $Message }
}

function Test-IsAdmin {
  return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
    IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-PemSha1([string]$Path) {
  $dump = & certutil.exe -dump $Path 2>&1 | Out-String
  # EN: Cert Hash(sha1):   PT-BR: Hash Cert(sha1):
  if ($dump -match '(?i)(?:Cert Hash|Hash Cert)\(sha1\):\s*([a-fA-F0-9 ]+)') {
    return (($Matches[1] -replace '\s', '').ToUpperInvariant())
  }
  return $null
}

function Test-CaTrusted([string]$Path) {
  $hash = Get-PemSha1 $Path
  if (-not $hash) {
    Write-Info 'Aviso: nao foi possivel ler SHA1 da CA (certutil dump).'
    return $false
  }
  Write-Info ("SHA1 CA: {0}" -f $hash)
  $store = & certutil.exe -store Root 2>&1 | Out-String
  $ok = $store.ToUpperInvariant().Contains($hash)
  Write-Info ("CA ja na loja Root: {0}" -f $ok)
  return $ok
}

function Convert-PemToCer([string]$PemPath) {
  $raw = Get-Content -LiteralPath $PemPath -Raw -ErrorAction Stop
  if ($raw -notmatch '-----BEGIN CERTIFICATE-----') { return $PemPath }
  $cer = Join-Path $env:TEMP ('AcompOPMS-rootCA-{0}.cer' -f ([Guid]::NewGuid().ToString('N').Substring(0, 8)))
  & certutil.exe -decode $PemPath $cer | Out-Null
  if ((Test-Path -LiteralPath $cer) -and ((Get-Item -LiteralPath $cer).Length -gt 0)) {
    return $cer
  }
  return $PemPath
}

function Resolve-CaPath {
  if ($CaPath -and (Test-Path -LiteralPath $CaPath)) { return (Resolve-Path -LiteralPath $CaPath).Path }

  $root = Split-Path $PSScriptRoot -Parent
  $candidates = @(
    (Join-Path $root 'cliente\AcompOPMS-rootCA.pem'),
    (Join-Path $root 'cliente\www-ca\AcompOPMS-rootCA.pem'),
    (Join-Path $PSScriptRoot '..\cliente\AcompOPMS-rootCA.pem')
  )
  foreach ($c in $candidates) {
    if (Test-Path -LiteralPath $c) { return (Resolve-Path -LiteralPath $c).Path }
  }

  $hostName = $ServerHost.Trim()
  if (-not $hostName) {
    try {
      . "$PSScriptRoot\_common.ps1"
      $cfg = Import-ServidorConfig
      $hostName = [string]$cfg.SERVER_HOST
      if (-not $hostName) { $hostName = Get-PreferredLanIPv4 }
    } catch { }
  }
  if (-not $hostName) {
    throw 'CA nao encontrada e ServerHost nao informado para baixar.'
  }

  $url = "http://{0}/acomp-ca/AcompOPMS-rootCA.pem" -f $hostName.TrimEnd('/')
  $dest = Join-Path $env:TEMP 'AcompOPMS-rootCA.pem'
  Write-Info ("Baixando CA: {0}" -f $url)
  & curl.exe -fsSL --connect-timeout 5 --max-time 20 $url -o $dest
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $dest)) {
    throw "Falha ao baixar a CA em $url"
  }
  return $dest
}

try {
  $ca = Resolve-CaPath
  Write-Info ("CA: {0}" -f $ca)

  if (Test-CaTrusted $ca) {
    Write-Info 'Certificado ja confiado neste PC.'
  } else {
    if (-not (Test-IsAdmin)) {
      Write-Info 'Solicitando Administrador para instalar o certificado...'
      # Start-Process nao coloca aspas: path com espaco ("Servidor final") quebra -File.
      $q = {
        param([string]$v)
        if ([string]::IsNullOrEmpty($v)) { return '""' }
        if ($v -match '[\s"]') { return '"' + ($v.Replace('"', '\"')) + '"' }
        return $v
      }
      $argList = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', (& $q $PSCommandPath),
        '-CaPath', (& $q $ca)
      )
      if ($ServerHost) { $argList += @('-ServerHost', (& $q $ServerHost)) }
      if ($OpenBrowser) { $argList += '-OpenBrowser' }
      if ($Quiet) { $argList += '-Quiet' }
      $p = Start-Process -FilePath 'powershell.exe' -ArgumentList $argList -Verb RunAs -Wait -PassThru
      if ($null -eq $p -or $p.ExitCode -ne 0) {
        $code = if ($null -eq $p) { 'null' } else { $p.ExitCode }
        throw "Instalacao do certificado cancelada ou falhou (codigo $code). Aceite o UAC e tente de novo."
      }
      if (-not (Test-CaTrusted $ca)) {
        throw 'UAC concluiu, mas a CA ainda nao aparece na loja Raiz. Tente de novo como Administrador.'
      }
    } else {
      Write-Info 'Instalando CA na loja Raiz (ROOT)...'
      $toAdd = Convert-PemToCer $ca
      Write-Info ("Arquivo para certutil: {0}" -f $toAdd)
      $out = & certutil.exe -addstore -f 'Root' $toAdd 2>&1 | Out-String
      Write-Info $out.Trim()
      if ($LASTEXITCODE -ne 0) { throw 'certutil falhou ao instalar a CA.' }
      if (-not (Test-CaTrusted $ca)) {
        throw 'certutil retornou OK, mas a CA nao foi encontrada na loja Raiz.'
      }
      Write-Info 'CA instalada com sucesso.'
      if ($toAdd -ne $ca -and (Test-Path -LiteralPath $toAdd)) {
        Remove-Item -LiteralPath $toAdd -Force -ErrorAction SilentlyContinue
      }
    }
  }

  if ($OpenBrowser) {
    $hostName = $ServerHost.Trim()
    if (-not $hostName) {
      try {
        . "$PSScriptRoot\_common.ps1"
        $cfg = Import-ServidorConfig
        $hostName = [string]$cfg.SERVER_HOST
        if (-not $hostName) { $hostName = Get-PreferredLanIPv4 }
      } catch { }
    }
    if ($hostName) {
      $url = "https://{0}/" -f $hostName.TrimEnd('/')
      Write-Info ("Abrindo {0}" -f $url)
      Start-Process $url | Out-Null
    }
  }

  exit 0
} catch {
  Write-Info ("ERRO: {0}" -f $_.Exception.Message)
  throw
}
