' Instalar Servidor
Option Explicit
Dim sh, fso, root, ps1, i, candidates
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
ps1 = ""
candidates = Array( _
  root & "\Gereal\AcompSolemp\servidor-portatil\scripts\Instalar-Pacote-Servidor.ps1", _
  root & "\Gereal\AcompSolemp\servidor-portatil\scripts\Hub-Instalacao-AcompOPMS.ps1" _
)
For i = 0 To UBound(candidates)
  If fso.FileExists(candidates(i)) Then ps1 = fso.GetAbsolutePathName(candidates(i)) : Exit For
Next
If ps1 = "" Then
  MsgBox "Nao achei o instalador.`n`nCopie a pasta INTEIRA." & vbCrLf & root, vbCritical, "Instalar Servidor"
  WScript.Quit 1
End If
sh.CurrentDirectory = fso.GetParentFolderName(ps1)
' Janela visivel: se der erro, o usuario ve a mensagem (Hidden parecia que "nao abria").
sh.Run "powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File " & Chr(34) & ps1 & Chr(34), 1, True
