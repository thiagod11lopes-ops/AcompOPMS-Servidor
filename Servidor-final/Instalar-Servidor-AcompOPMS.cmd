@echo off
chcp 65001 >nul
title Servidor-final — AcompOPMS
cd /d "%~dp0"
echo.
echo  Servidor-final — AcompOPMS
echo  (programas + pacote nesta pasta)
echo  Senha do assistente: Marinha
echo.
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0Instalar-Servidor-AcompOPMS.ps1"
set ERR=%ERRORLEVEL%
echo.
if not %ERR%==0 (
  echo Instalacao terminou com codigo %ERR%.
) else (
  echo Assistente encerrado. Use o atalho "Servidor AcompOPMS" e Iniciar servidor.
)
echo.
pause
exit /b %ERR%
