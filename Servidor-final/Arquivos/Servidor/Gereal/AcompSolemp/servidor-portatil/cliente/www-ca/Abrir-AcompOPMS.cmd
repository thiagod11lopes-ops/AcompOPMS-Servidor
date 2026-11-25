@echo off
setlocal
title AcompOPMS - Certificado
set "SERVER=192.168.1.202"
set "CA=%TEMP%\AcompOPMS-rootCA.pem"

net session >nul 2>&1
if errorlevel 1 (
  echo Solicitando Administrador...
  mshta "javascript:var s=new ActiveXObject('Shell.Application');s.ShellExecute('%~f0','','','runas',1);close();"
  exit /b
)

echo Baixando certificado...
curl.exe -fsSL --connect-timeout 5 --max-time 20 "http://%SERVER%/acomp-ca/AcompOPMS-rootCA.pem" -o "%CA%"
if errorlevel 1 (
  echo Falha ao baixar a CA. Servidor no ar?
  pause
  exit /b 1
)

echo Instalando certificado confiavel...
certutil.exe -addstore -f Root "%CA%"
if errorlevel 1 (
  echo Falha no certutil.
  pause
  exit /b 1
)

echo OK. Abrindo o sistema...
start "" "https://%SERVER%/"
exit /b 0
