<#
.SYNOPSIS
Script para limpeza pós-migração V2V (VMware para Proxmox).

.DESCRIPTION
Este script exibe e possibilita a remoção de "dispositivos ocultos" (Ghost Devices)
de rede, facilitando a reutilização do endereço IP estático antigo em novas interfaces de rede (VirtIO).
#>

Write-Host "=== Limpeza de Rede de Hardware Fantasma (Pos-Migracao) ===" -ForegroundColor Cyan
Write-Host "Configurando sistema para exibir dispositivos ocultos de hardware..." -ForegroundColor Green

# Define variável de ambiente para sessão e máquina
[Environment]::SetEnvironmentVariable("devmgr_show_nonpresent_devices", "1", "Process")
[Environment]::SetEnvironmentVariable("devmgr_show_nonpresent_devices", "1", "Machine")

Write-Host "Variavel devmgr_show_nonpresent_devices=1 aplicada com sucesso." -ForegroundColor Green
Write-Host ""
Write-Host "DICA: O Gerenciador de Dispositivos sera aberto agora." -ForegroundColor Yellow
Write-Host "Siga os passos manuais:"
Write-Host " 1. No menu superior clique em 'Exibir' (View) -> 'Mostrar dispositivos ocultos' (Show hidden devices)."
Write-Host " 2. Expanda a categoria 'Adaptadores de rede' (Network adapters)."
Write-Host " 3. Desinstale os adaptadores antigos e esmaecidos (Ex: Intel E1000, VMware VMXNET3)."
Write-Host " 4. Somente apos isso, configure seu IP estatico no adaptador ativo atualizado (VirtIO Red Hat)." -ForegroundColor Yellow
Write-Host ""
Write-Host "Pressione qualquer tecla para abrir o Gerenciador de Dispositivos (devmgmt.msc)..."
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null

# Inicia o Gerenciador de Dispositivos (com elevação se o terminal for admin)
Start-Process "devmgmt.msc"

Write-Host "Ao terminar a configuração, pode fechar a janela." -ForegroundColor Green
