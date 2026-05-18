#!/bin/bash

# Script: Proxmox_Wake-On-Lan.sh
# Descripción: Configura Wake-on-LAN en una interfaz de red y crea un servicio systemd

set -e  # Salir si hay algún error crítico

# =======================================================================================
# 🎨 COLORES Y FUNCIONES DE SALIDA
# =======================================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
ORANGE='\033[38;2;255;140;0m'
BOLD='\033[1m'
NC='\033[0m'

print_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
print_warn()  { echo -e "${YELLOW}[AVISO]${NC}  $1"; }
print_error() { echo -e "${ORAANGE}[ERROR]${NC} $1"; exit 1; }
print_step()  { echo -e "${BLUE}[👉]${NC}  $1"; }
print_aviso() { echo -e "${MAGENTA}[AVISO]${NC}  $1"; }
print_ok()    { echo -e "${GREEN}[✓]${NC}  $1"; }
print_fail()  { echo -e "${RED}[✗]${NC}  $1"; }

# =======================================================================================
# INICIO DEL SCRIPT
# =======================================================================================
trap 'echo -e "\n${RED}❌ Proceso Cancelado por el Usuario.${NC}"; exit 1' INT TERM
if [[ $EUID -ne 0 ]]; then print_error "Este script debe ejecutarse como root o con sudo."; fi

clear
echo -e "${ORANGE}${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${ORANGE}${BOLD}║                                                              ║${NC}"
echo -e "${ORANGE}${BOLD}║           CONFIGURACIÓN WAKE-ON-LAN EN PROXMOX               ║${NC}"
echo -e "${ORANGE}${BOLD}║                                                              ║${NC}"
echo -e "${ORANGE}${BOLD}║       https://github.com/AmIBeingObtuse/Youtubestacks/       ║${NC}"
echo -e "${ORANGE}${BOLD}║                                                              ║${NC}"
echo -e "${ORANGE}${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"


echo -e "${CYAN}=======================================================${NC}"
echo -e "${CYAN}🔍 ACTUALIZAR EL SISTEMA                     ${NC}"
echo -e "${CYAN}=======================================================${NC}"

echo ""
print_step "1. Actualizando el sistema..."
if apt update && apt full-upgrade -y && apt autoremove -y && apt autoclean -y; then
    print_ok "Sistema actualizado correctamente"
else
    print_error "Falló la actualización del sistema"
fi

echo -e "${CYAN}=======================================================${NC}"
echo -e "${CYAN}📦 INSTALAR DEPENDECIA       ${NC}"
echo -e "${CYAN}=======================================================${NC}"

echo ""
print_step "2. Instalando ethtool..."
if apt install ethtool -y; then
    print_ok "ethtool instalado correctamente"
else
    print_error "Falló la instalación de ethtool"
fi

echo -e "${CYAN}=======================================================${NC}"
echo -e "${CYAN}🌐 INDENTIFICAR INTERFACES DE RED                            ${NC}"
echo -e "${CYAN}=======================================================${NC}"
# 3. Identificar la interfaz de red activa
echo ""
print_step "3. Identificando interfaces de red activas..."
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
ip addr
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Obtener lista de interfaces con IP (excluyendo loopback)
mapfile -t interfaces < <(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | grep -v "^veth" | grep -v "^vmbr" | grep -v "^tap" | grep -v "vlan")

if [ ${#interfaces[@]} -eq 0 ]; then
    print_error "No se encontraron interfaces de red."
elif [ ${#interfaces[@]} -eq 1 ]; then
    INTERFACE_LAN="${interfaces[0]}"
    print_info "Interfaz detectada automáticamente: ${CYAN}$INTERFACE_LAN${NC}"
else
    print_aviso "Se detectaron múltiples interfaces:"
    echo ""
    for i in "${!interfaces[@]}"; do
        echo -e "  ${GREEN}$((i+1))${NC}) ${CYAN}${interfaces[$i]}${NC}"
    done
    echo ""
    read -p "$(echo -e ${MAGENTA}"Selecciona el número de la interfaz LAN: "${NC})" seleccion
    if [[ "$seleccion" =~ ^[0-9]+$ ]] && [ "$seleccion" -ge 1 ] && [ "$seleccion" -le ${#interfaces[@]} ]; then
        INTERFACE_LAN="${interfaces[$((seleccion-1))]}"
        print_info "Interfaz seleccionada: ${CYAN}$INTERFACE_LAN${NC}"
    else
        print_error "Selección inválida."
    fi
fi

# 4. Ejecutar ethtool para activar Wake-on-LAN (modo g)
echo ""
print_step "4. Activando Wake-on-LAN en ${CYAN}$INTERFACE_LAN${NC}..."
if ethtool -s "$INTERFACE_LAN" wol g; then
    print_ok "Wake-on-LAN activado correctamente"
else
    print_error "Falló la activación de Wake-on-LAN"
fi

# 5. Verificar configuración (corregido para capturar correctamente el valor)
echo ""
print_step "Verificando configuración Wake-on-LAN..."

# Mostrar la configuración actual completa de Wake-on-LAN
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
ethtool "$INTERFACE_LAN" | grep -E "Wake-on|Supports"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Extraer correctamente el valor de Wake-on (la línea que contiene "Wake-on:" seguido de un carácter)
WOL_STATUS=$(ethtool "$INTERFACE_LAN" 2>/dev/null | grep "Wake-on:" | grep -o "[g|d|p|u|m|b|a|s]$" | head -1)

if [ "$WOL_STATUS" = "g" ]; then
    print_ok "Configuración correcta: Wake-on = ${GREEN}$WOL_STATUS${NC} (Magic Packet)"
else
    print_warn "Configuración actual: Wake-on = ${YELLOW}$WOL_STATUS${NC} (se esperaba 'g')"
fi

# 6. Crear servicio systemd
echo ""
print_step "6. Creando servicio systemd..."
SERVICE_FILE="/etc/systemd/system/wol.service"

cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Enable Wake-on-LAN
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/sbin/ethtool -s $INTERFACE_LAN wol g

[Install]
WantedBy=multi-user.target
EOF

if [ -f "$SERVICE_FILE" ]; then
    print_ok "Servicio creado en: ${CYAN}$SERVICE_FILE${NC}"
else
    print_error "Falló la creación del servicio"
fi

# 7. Habilitar e iniciar el servicio
echo ""
print_step "Recargando systemd..."
systemctl daemon-reload

echo ""
print_step "Habilitando el servicio..."
if systemctl enable wol.service; then
    print_ok "Servicio habilitado correctamente"
else
    print_error "Falló al habilitar el servicio"
fi

echo ""
print_step "Iniciando el servicio..."
if systemctl start wol.service; then
    print_ok "Servicio iniciado correctamente"
else
    print_error "Falló al iniciar el servicio"
fi

# =======================================================================================
# RESUMEN FINAL
# =======================================================================================
echo ""
echo -e "${CYAN}=========================================${NC}"
echo -e "${CYAN} Configuración completada con éxito ✓${NC}"
echo -e "${CYAN}=========================================${NC}"
echo -e "${GREEN}🛠️ Interfaz configurada:${NC} $INTERFACE_LAN"
echo ""
echo -e "${YELLOW}📝 Para verificar la configuración en el futuro:${NC}"
echo -e "${GREEN}ethtool $INTERFACE_LAN | grep 'Wake-on:'${NC}"
echo ""
echo -e "${ORANGE}${BOLD}💡 Notas:${NC}"
echo -e "${ORANGE}${BOLD}- Verifica que la tarjeta de red soporte WOL (Wake-On-LAN)${NC}"
echo -e "${ORANGE}${BOLD}- Asegúrate de que Wake-on-LAN esté también habilitado en la BIOS${NC}"
echo ""