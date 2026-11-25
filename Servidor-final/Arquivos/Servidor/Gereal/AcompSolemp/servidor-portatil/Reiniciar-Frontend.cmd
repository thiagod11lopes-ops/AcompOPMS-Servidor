@echo off
chcp 65001 >nul
title AcompOPMS - Reiniciar Frontend (Vite)
cd /d "%~dp0scripts"
echo.
echo === Reiniciando Frontend (Vite) ===
echo Aguarde. A janela mostra o erro se falhar.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Start-Vite.ps1" -ShowWindow
set ERR=%ERRORLEVEL%
echo.
if %ERR%==0 (
  echo SUCESSO: Vite no ar. Volte ao Dashboard e clique em Atualizar.
) else (
  echo FALHOU. Abra o arquivo de log:
  echo   %~dp0logs\vite.err.log
  echo   %~dp0logs\vite.status.txt
)
echo.
pause
exit /b %ERR%
