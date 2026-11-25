# AcompOPMS — Pacote Servidor (offline)

Pacote completo para instalar o **servidor** AcompOPMS em outro PC Windows (Dashboard verde + frontend + Supabase), com instaladores offline.

## Como baixar

1. Abra **Releases** (lado direito desta página)
2. Baixe `AcompOPMS-Servidor-offline.zip` da release mais recente
3. Extraia no Desktop → pasta `Servidor-final`
4. Duplo clique em `Instalar-Servidor-AcompOPMS.cmd`
5. Senha: **Marinha**

## Conteúdo

- Docker Desktop, Node.js 22, VC++, WSL (instaladores)
- Frontend + `node_modules`
- Supabase self-hosted
- Scripts, Dashboard, HTTPS/mkcert

## Observações

- Instalação de programas Windows: **offline** (vêm no ZIP)
- Na **primeira** subida do Supabase, o Docker pode precisar baixar imagens uma vez (internet)
- Atualizações do app: pasta `atualização` (não substituir `Servidor-final` inteira)
- Após desligar o PC: Docker Ready → atalho **Servidor AcompOPMS** → Iniciar servidor

## App (código)

https://github.com/thiagod11lopes-ops/AcompSolemp
