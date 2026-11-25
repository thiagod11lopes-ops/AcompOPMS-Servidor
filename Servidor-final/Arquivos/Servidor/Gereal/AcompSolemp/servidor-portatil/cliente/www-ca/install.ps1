$ErrorActionPreference = 'Stop'
$Server = '192.168.1.202'
$cmd = Join-Path $env:TEMP 'acomp-install.cmd'
Invoke-WebRequest -Uri "http://$Server/acomp-ca/install.cmd" -OutFile $cmd -UseBasicParsing
Start-Process -FilePath $cmd -Wait
