@echo off
chcp 65001 >nul
cd /d "%~dp0"
if exist "%~dp0..\instaladores" (
  set "INS=%~dp0..\instaladores"
) else if exist "%~dp0instaladores" (
  set "INS=%~dp0instaladores"
) else if exist "D:\Servidor\instaladores" (
  set "INS=D:\Servidor\instaladores"
) else (
  echo Pasta instaladores nao encontrada.
  echo Coloque este arquivo junto da pasta instaladores no pen drive.
  pause
  exit /b 1
)

echo ============================================
echo  Instalacao offline - AcompOPMS Servidor
echo  Rode como Administrador se pedir.
echo  Pasta: %INS%
echo ============================================
echo.
echo IMPORTANTE: cada instalador vai ABRIR uma janela.
echo Clique em Next/Instalar/OK e espere terminar.
echo Depois volte nesta janela preta e aperte uma tecla.
echo.

echo [1/5] Visual C++ Redistributable
echo Abrindo instalador...
start "" "%INS%\vc_redist.x64.exe"
echo Quando o Visual C++ terminar, volte aqui e aperte uma tecla.
pause >nul

echo [2/5] WSL update
start "" "%INS%\wsl_update_x64.msi"
echo Quando o WSL terminar, volte aqui e aperte uma tecla.
pause >nul

echo [3/5] Docker Desktop
start "" "%INS%\Docker Desktop Installer.exe"
echo Quando o Docker terminar (pode pedir reiniciar), volte aqui e aperte uma tecla.
pause >nul

echo [4/5] Node.js
start "" "%INS%\node-v22.20.0-x64.msi"
echo Quando o Node terminar, volte aqui e aperte uma tecla.
pause >nul

echo [5/5] Cursor
if exist "%~dp0..\CursorUserSetup-x64-3.24.18.exe" (
  start "" "%~dp0..\CursorUserSetup-x64-3.24.18.exe"
) else if exist "%INS%\CursorUserSetup-x64-3.24.18.exe" (
  start "" "%INS%\CursorUserSetup-x64-3.24.18.exe"
) else if exist "D:\Servidor\CursorUserSetup-x64-3.24.18.exe" (
  start "" "D:\Servidor\CursorUserSetup-x64-3.24.18.exe"
) else (
  echo Instalador do Cursor nao encontrado. Instale manualmente da pasta do pen drive.
)
echo Quando o Cursor terminar, volte aqui e aperte uma tecla.
pause >nul

echo.
echo ============================================
echo Concluido.
echo - Se pediu reiniciar, reinicie o PC.
echo - Abra o Docker Desktop e espere ficar pronto.
echo - Depois siga o LEIA-ME.txt
echo ============================================
pause
