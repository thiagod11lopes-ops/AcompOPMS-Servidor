@echo off
chcp 65001 >nul
title Reparar Gateway HTTPS — AcompOPMS
:: Usa quando a etapa 11/12 diz: App local OK, mas HTTPS nao respondeu.
:: Nao reinstala o pacote — so reaplica host, firewall e sobe o gateway.

net session >nul 2>&1
if %errorlevel% neq 0 (
  echo Solicitando permissao de Administrador (UAC)...
  powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

cd /d "%~dp0"

set "SP=%~dp0Arquivos\Servidor\Gereal\AcompSolemp\servidor-portatil"
if not exist "%SP%\scripts\Iniciar-Gateway.ps1" (
  echo Nao achei servidor-portatil em:
  echo   %SP%
  echo Copie a pasta Servidor-final inteira.
  pause
  exit /b 1
)

cd /d "%SP%"

echo.
echo [1/4] Docker Desktop precisa estar Ready...
docker info >nul 2>&1
if errorlevel 1 (
  echo ERRO: Docker nao responde. Abra o Docker Desktop, espere ficar Ready e rode este arquivo de novo.
  pause
  exit /b 1
)
echo       Docker OK.

echo.
echo [2/4] Aplicando IP / config do host...
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Aplicar-Host.ps1"
if errorlevel 1 (
  echo AVISO: Aplicar-Host falhou. Continuando mesmo assim...
)

echo.
echo [3/4] Firewall (portas 80 e 443)...
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Instalar-Dns-Autostart.ps1"
if errorlevel 1 (
  echo AVISO: regra de firewall/DNS pode ter falhado. Continuando...
)

echo.
echo [4/4] Subindo gateway HTTPS (nginx :443)...
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\Iniciar-Gateway.ps1"
if errorlevel 1 (
  echo.
  echo ERRO ao subir o gateway.
  echo Verifique se as portas 80/443 nao estao em uso:
  echo   netstat -ano ^| findstr ":443 "
  echo   docker ps -a
  pause
  exit /b 1
)

echo.
echo Testando HTTPS local...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$cfg=@{}; Get-Content '.\config.env' | %%{ if($_ -match '^\s*SERVER_HOST=(.+)$'){ $cfg.Host=$Matches[1].Trim() } };" ^
  "$h= if($cfg.Host){$cfg.Host}else{'127.0.0.1'};" ^
  "$urls=@(\"https://$h/\",'https://127.0.0.1/');" ^
  "foreach($u in $urls){ try{ $c=& curl.exe -sk -o NUL -w '%%{http_code}' --max-time 6 $u 2>$null; Write-Host (\"  $u -> HTTP $c\") } catch { Write-Host (\"  $u -> falhou\") } }"

echo.
echo ============================================================
echo  Pronto. No Chrome deste PC tente:
echo    https://IP_DO_SERVIDOR/
echo  (o IP da etapa de instalacao, ex.: https://10.6.168.230/)
echo.
echo  Depois volte ao assistente e use "Tentar de novo" na etapa 11,
echo  ou abra o Dashboard e confira Gateway Online.
echo ============================================================
echo.
pause
exit /b 0
