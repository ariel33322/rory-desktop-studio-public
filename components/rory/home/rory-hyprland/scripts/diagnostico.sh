#!/usr/bin/env bash
# Solo lectura. Ejecutar desde una terminal de la sesión Hyprland.
set -u
printf '\nVersiones\n'
qs --version
hyprctl version
printf '\nInstancias de Rory\n'
qs -p "$HOME/rory-hyprland/shell.qml" list
printf '\nNetworkManager\n'
nmcli general status
printf '\nBlueZ\n'
busctl --system status org.bluez --no-pager
printf '\nPipeWire y WirePlumber\n'
wpctl status
printf '\nPerfiles de energía\n'
powerprofilesctl list
printf '\nServicios de energía (consulta, sin cambios)\n'
systemctl is-active power-profiles-daemon.service tlp.service tuned.service auto-cpufreq.service
printf '\nMétricas de batería y sesión\n'
python3 "$(dirname -- "${BASH_SOURCE[0]}")/battery-metrics.py"
