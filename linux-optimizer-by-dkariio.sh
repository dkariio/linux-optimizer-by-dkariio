#!/usr/bin/env bash
# ============================================================================
#  LINUX OPTIMIZER 4.0
#  Conservative maintenance for systemd-based Linux distributions
#  Hecho por / Made by @dkariio
# ============================================================================
#  Supported package families (when available):
#   - Debian / Ubuntu / Linux Mint / Pop!_OS / Zorin / Kali (APT)
#   - Fedora / RHEL / Rocky / AlmaLinux (DNF or YUM)
#   - Arch / Manjaro / EndeavourOS (Pacman)
#   - openSUSE (Zypper)
#
#  Requirements: Bash 4+, systemd, systemctl, sysctl (for memory tuning).
#  This is not a universal optimizer for every Unix/Linux variant.
#  Non-systemd, immutable/atomic and declarative systems are not supported.
#
#  Safety principles:
#   - Diagnosis before changes; ask before maintenance actions.
#   - Back up every configuration file before changing it.
#   - Never change partitions, GRUB, fstab, bootloader or mount options.
#   - Never disable services, updates, firewall, swap or security features.
#   - Never run TRIM automatically; USB devices are treated cautiously.
#   - Never remove installed applications or personal files.
# ============================================================================

set -Eeuo pipefail
IFS=$'\n\t'

VERSION="4.0"
APP="Linux Optimizer"
AUTHOR="@dkariio"
BACKUP_ROOT="/var/backups/linux-optimizer"
LOG="/var/log/linux-optimizer.log"
SYSCTL_FILE="/etc/sysctl.d/99-linux-optimizer.conf"
JOURNAL_DIR="/etc/systemd/journald.conf.d"
JOURNAL_FILE="$JOURNAL_DIR/99-linux-optimizer.conf"
ZRAM_FILE="/etc/default/zramswap"
PACKAGE_MANAGER="unknown"
SNAPSHOT_DIR=""

# Colors are disabled in non-interactive output and when NO_COLOR is set.
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
    C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'; C_MAGENTA=$'\033[35m'
else
    C_RESET=''; C_BOLD=''; C_DIM=''; C_RED=''; C_GREEN=''; C_YELLOW=''
    C_BLUE=''; C_CYAN=''; C_MAGENTA=''
fi

now() { date '+%Y-%m-%d %H:%M:%S'; }

log_line() {
    local level="$1"; shift
    local message="$*"
    if [[ -w "$(dirname "$LOG")" || -w "$LOG" ]]; then
        printf '[%s] [%s] %s\n' "$(now)" "$level" "$message" >> "$LOG" 2>/dev/null || true
    fi
}

msg()   { printf '%b\n' "${C_BLUE}[*]${C_RESET} $*"; log_line INFO "$*"; }
ok()    { printf '%b\n' "${C_GREEN}[OK]${C_RESET} $*"; log_line OK "$*"; }
warn()  { printf '%b\n' "${C_YELLOW}[!]${C_RESET} $*"; log_line WARN "$*"; }
error() { printf '%b\n' "${C_RED}[ERROR]${C_RESET} $*" >&2; log_line ERROR "$*"; }

pause() {
    printf '\n%b' "${C_DIM}Pulsa INTRO para continuar...${C_RESET}"
    read -r _ || true
}

ask_yes_no() {
    local prompt="$1" answer
    while true; do
        printf '%b' "${C_YELLOW}?${C_RESET} ${prompt} [s/N]: "
        read -r answer || return 1
        case "${answer,,}" in
            s|si|sí|y|yes) return 0 ;;
            n|no|'') return 1 ;;
            *) printf '%s\n' 'Responde s/si o n/no (answer yes or no).' ;;
        esac
    done
}

hr() {
    printf '%b' "$C_DIM"
    printf '%s\n' '----------------------------------------------------------------------------'
    printf '%b' "$C_RESET"
}

header() {
    [[ -t 1 ]] && clear || true
    printf '%b\n' "${C_CYAN}${C_BOLD}"
    cat <<'BANNER'
  _      _____ _   _ _   _ __  __   ____  ____ _____ ___ __  __ ___ _______ 
 | |    |_   _| \ | | | | |  \/  | / __ \|  _ \_   _|_ _|  \/  |_ _|__   __|
 | |      | | |  \| | | | | |\/| || |  | | |_) || |  | || |\/| || |  | |   
 | |___   | | | |\  | |_| | |  | || |__| |  __/ | |  | || |  | || |  | |   
 |_____|  |_| |_| \_|\___/|_|  |_| \____/|_|    |_| |___|_|  |_|___| |_|   
BANNER
    printf '%b\n' "$C_RESET"
    printf '%b\n' "${C_BOLD}       OPTIMIZADOR PRUDENTE PARA LINUX  ·  CONSERVATIVE LINUX MAINTENANCE${C_RESET}"
    printf '                         v%s  ·  Hecho por %b%s%b\n' "$VERSION" "$C_MAGENTA" "$AUTHOR" "$C_RESET"
    hr
}

section() {
    printf '\n%b\n' "${C_BOLD}${C_CYAN}  $*${C_RESET}"
    hr
}

# ---------------------------------------------------------------------------
# Platform checks and initialization
# ---------------------------------------------------------------------------

check_arguments() {
    case "${1:-}" in
        --version|-v) printf '%s %s\n' "$APP" "$VERSION"; exit 0 ;;
        --help|-h)
            cat <<HELP
$APP $VERSION — Hecho por $AUTHOR

Uso / Usage:
  sudo bash $0           Abrir la interfaz interactiva / Open the menu
  bash $0 --help         Mostrar esta ayuda / Show this help
  bash $0 --version      Mostrar la versión / Show version

Sistemas previstos / Intended systems:
  Distribuciones Linux con systemd y gestor APT, DNF/YUM, Pacman o Zypper.

No compatible con / Not supported:
  macOS, BSD, Alpine/OpenRC, sistemas inmutables/atómicos y NixOS.
HELP
            exit 0
            ;;
    esac
}

check_platform() {
    [[ "$(uname -s)" == "Linux" ]] || { error 'Este programa solo funciona en Linux.'; exit 1; }
    [[ -r /etc/os-release ]] || { error 'No se encuentra /etc/os-release.'; exit 1; }
    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "${ID:-}" =~ ^(nixos|steamos|vanilla|vanillaos|blendos|guix|opensuse-microos|opensuse-aeon|opensuse-kalpa)$ || -e /run/ostree-booted ]]; then
        error 'Sistema declarativo/inmutable detectado (NixOS, OSTree, SteamOS u otro). No se modificarán archivos del sistema.'
        error 'Declarative/immutable system detected (NixOS, OSTree, SteamOS or similar). No system files will be modified.'
        exit 1
    fi
    if ! command -v systemctl >/dev/null 2>&1 || [[ ! -d /run/systemd/system ]]; then
        error 'Se necesita systemd en ejecución. No se admiten OpenRC ni otros init.'
        error 'A running systemd instance is required; OpenRC and other init systems are unsupported.'
        exit 1
    fi

    # Prefer the distribution identity over incidental package-manager binaries.
    # Some users install foreign package tools for compatibility or containers.
    local distro_id="${ID:-}" distro_like="${ID_LIKE:-}"
    if [[ "$distro_id" =~ ^(debian|ubuntu|linuxmint|pop|zorin|kali|elementary|neon|raspbian)$ || "$distro_like" == *debian* || "$distro_like" == *ubuntu* ]]; then
        command -v apt-get >/dev/null 2>&1 && PACKAGE_MANAGER="apt"
    elif [[ "$distro_id" =~ ^(fedora|rhel|centos|rocky|almalinux|ol|amzn)$ || "$distro_like" == *fedora* || "$distro_like" == *rhel* ]]; then
        if command -v dnf >/dev/null 2>&1; then PACKAGE_MANAGER="dnf"
        elif command -v yum >/dev/null 2>&1; then PACKAGE_MANAGER="yum"; fi
    elif [[ "$distro_id" =~ ^(arch|manjaro|endeavouros|garuda)$ || "$distro_like" == *arch* ]]; then
        command -v pacman >/dev/null 2>&1 && PACKAGE_MANAGER="pacman"
    elif [[ "$distro_id" =~ ^(opensuse|opensuse-leap|opensuse-tumbleweed|sles|sled)$ || "$distro_like" == *suse* ]]; then
        command -v zypper >/dev/null 2>&1 && PACKAGE_MANAGER="zypper"
    fi

    # Fallback for compatible derivatives whose os-release metadata is unusual.
    if [[ "$PACKAGE_MANAGER" == "unknown" ]]; then
        if command -v apt-get >/dev/null 2>&1; then PACKAGE_MANAGER="apt"
        elif command -v dnf >/dev/null 2>&1; then PACKAGE_MANAGER="dnf"
        elif command -v yum >/dev/null 2>&1; then PACKAGE_MANAGER="yum"
        elif command -v pacman >/dev/null 2>&1; then PACKAGE_MANAGER="pacman"
        elif command -v zypper >/dev/null 2>&1; then PACKAGE_MANAGER="zypper"
        fi
    fi

    if [[ "$PACKAGE_MANAGER" == "unknown" ]]; then
        warn 'No se reconoce APT, DNF, YUM, Pacman ni Zypper. El diagnóstico seguirá disponible; la limpieza de paquetes quedará desactivada.'
    fi
}

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        printf '%b\n' "${C_RED}Se necesitan permisos de administrador / Administrator privileges are required.${C_RESET}"
        printf 'Ejecuta / Run: sudo bash %q\n' "$0"
        exit 1
    fi
}

init_runtime() {
    mkdir -p "$BACKUP_ROOT"
    touch "$LOG"
    chmod 700 "$BACKUP_ROOT"
}

on_error() {
    local code=$?
    error "Error (código ${code}) cerca de la línea ${1:-?}. Consulta $LOG."
    exit "$code"
}
trap 'on_error "$LINENO"' ERR

# ---------------------------------------------------------------------------
# Reversible configuration snapshots
# ---------------------------------------------------------------------------

start_snapshot() {
    [[ -n "$SNAPSHOT_DIR" ]] && return 0
    SNAPSHOT_DIR="$BACKUP_ROOT/$(date '+%Y%m%d-%H%M%S')-$$"
    mkdir -p "$SNAPSHOT_DIR/files"
    : > "$SNAPSHOT_DIR/manifest.txt"
    chmod 700 "$SNAPSHOT_DIR" "$SNAPSHOT_DIR/files"
    msg "Copia de seguridad / Backup: $SNAPSHOT_DIR"
}

backup_file() {
    local file="$1" state="absent" destination
    start_snapshot
    if grep -Fq "|$file" "$SNAPSHOT_DIR/manifest.txt" 2>/dev/null; then return 0; fi
    destination="$SNAPSHOT_DIR/files/${file#/}"
    if [[ -e "$file" || -L "$file" ]]; then
        state="present"
        mkdir -p "$(dirname "$destination")"
        cp -a -- "$file" "$destination"
    fi
    printf '%s|%s\n' "$state" "$file" >> "$SNAPSHOT_DIR/manifest.txt"
}

latest_snapshot() {
    find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name '20*' -printf '%f\n' 2>/dev/null | sort | tail -n 1
}

restore_snapshot() {
    local snapshot="$1" manifest="$BACKUP_ROOT/$1/manifest.txt" state file source
    [[ -r "$manifest" ]] || { error 'La copia seleccionada no tiene manifiesto / Backup manifest is missing.'; return 1; }
    section 'RESTAURAR CONFIGURACIÓN / RESTORE CONFIGURATION'
    printf 'Se restaurarán los archivos guardados en / Files will be restored from:\n  %s\n' "$BACKUP_ROOT/$snapshot"
    warn 'Esto no desinstala paquetes ni revierte estados de servicios / This does not uninstall packages or revert service states.'
    ask_yes_no '¿Continuar? / Continue?' || { msg 'Restauración cancelada / Restore cancelled.'; return 0; }
    while IFS='|' read -r state file; do
        [[ -n "$state" && -n "$file" ]] || continue
        case "$state" in
            present)
                source="$BACKUP_ROOT/$snapshot/files/${file#/}"
                if [[ -e "$source" || -L "$source" ]]; then
                    mkdir -p "$(dirname "$file")"
                    cp -a --remove-destination "$source" "$file"
                    ok "Restaurado / Restored: $file"
                else
                    warn "No se encuentra la copia / Backup not found: $file"
                fi
                ;;
            absent)
                rm -f -- "$file"
                ok "Retirado archivo creado por el optimizador / Removed optimizer-created file: $file"
                ;;
            *) warn "Entrada desconocida / Unknown entry: $state|$file" ;;
        esac
    done < "$manifest"
    command -v sysctl >/dev/null 2>&1 && sysctl --system >/dev/null 2>&1 || true
    systemctl try-restart systemd-journald.service >/dev/null 2>&1 || true
    if systemctl list-unit-files zramswap.service --no-legend 2>/dev/null | grep -q zramswap; then
        systemctl try-restart zramswap.service >/dev/null 2>&1 || true
    fi
    ok 'Restauración terminada / Restore complete. Reinicia si algún ajuste no se refleja / Reboot if needed.'
    log_line INFO "Restored configuration from $snapshot"
}

# ---------------------------------------------------------------------------
# Hardware and read-only status
# ---------------------------------------------------------------------------

ram_total_gb() { awk '/MemTotal/ {printf "%.1f", $2/1024/1024}' /proc/meminfo; }

cpu_name() {
    if command -v lscpu >/dev/null 2>&1; then
        lscpu 2>/dev/null | awk -F: '/Model name/ {sub(/^[ \t]+/, "", $2); print $2; exit}'
    else
        awk -F: '/model name/ {sub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo
    fi
}

root_source() { findmnt -n -o SOURCE / 2>/dev/null || printf 'desconocido'; }

root_transport() {
    local src
    src="$(root_source)"
    if [[ "$src" == /dev/* ]] && command -v lsblk >/dev/null 2>&1; then
        lsblk -s -n -o TRAN "$src" 2>/dev/null | sed '/^$/d' | sort -u | paste -sd, - || true
    fi
}

zram_active() {
    [[ -r /sys/block/zram0/disksize ]] && [[ "$(cat /sys/block/zram0/disksize 2>/dev/null || echo 0)" != 0 ]]
}

show_dashboard() {
    header
    section 'RESUMEN DEL EQUIPO / SYSTEM OVERVIEW'
    printf '  Sistema / OS : %s\n' "${PRETTY_NAME:-Linux}"
    printf '  Kernel       : %s\n' "$(uname -r)"
    printf '  Gestor       : %s\n' "$PACKAGE_MANAGER"
    printf '  CPU          : %s\n' "$(cpu_name)"
    printf '  RAM          : %s GB\n' "$(ram_total_gb)"
    printf '  Raíz / Root  : %s\n' "$(root_source)"
    printf '  Transporte   : %s\n' "$(root_transport | grep -v '^$' || echo 'no identificado / unknown')"
    printf '\n%b\n' "${C_BOLD}  Memoria / Memory${C_RESET}"
    free -h | sed 's/^/  /'
    printf '\n%b\n' "${C_BOLD}  Almacenamiento / Storage${C_RESET}"
    df -hT / 2>/dev/null | sed 's/^/  /'
    df -i / 2>/dev/null | sed 's/^/  Inodos /'
    if command -v lsblk >/dev/null 2>&1; then
        printf '\n%b\n' "${C_BOLD}  Dispositivos / Devices${C_RESET}"
        lsblk -o NAME,SIZE,TYPE,TRAN,RM,ROTA,FSTYPE,MOUNTPOINT 2>/dev/null | sed 's/^/  /' || true
    fi
    printf '\n%b\n' "${C_BOLD}  ZRAM y SWAP${C_RESET}"
    if command -v zramctl >/dev/null 2>&1; then zramctl 2>/dev/null | sed 's/^/  /' || true; else printf '  zramctl no instalado / not installed\n'; fi
    swapon --show 2>/dev/null | sed 's/^/  /' || true
    printf '\n  Swappiness          : %s\n' "$(sysctl -n vm.swappiness 2>/dev/null || echo '?')"
    printf '  VFS cache pressure  : %s\n' "$(sysctl -n vm.vfs_cache_pressure 2>/dev/null || echo '?')"
    printf '  Journal             : %s\n' "$(journalctl --disk-usage 2>/dev/null | sed 's/^.*: //' || echo 'no disponible / unavailable')"
    printf '\n'
    if zram_active; then ok 'ZRAM activa / ZRAM active.'; else warn 'No se detecta ZRAM activa / No active ZRAM detected.'; fi
    if grep -qE '\b(vmx|svm)\b' /proc/cpuinfo; then ok 'CPU compatible con virtualización / Hardware virtualization detected.'; else warn 'No se detecta VT-x/AMD-V (puede estar desactivado en BIOS/UEFI) / Not detected (may be disabled in firmware).'; fi
    pause
}

package_health_check() {
    case "$PACKAGE_MANAGER" in
        apt)
            printf '\n  [2/8] Estado de paquetes / Package audit\n'
            local audit
            audit="$(dpkg --audit 2>&1 || true)"
            [[ -n "$audit" ]] && printf '%s\n' "$audit" | sed 's/^/        /' || ok 'dpkg no detecta paquetes pendientes / No unfinished dpkg packages.'
            printf '\n  [3/8] Dependencias APT\n'
            if apt-get check; then ok 'Dependencias APT correctas / APT dependencies look OK.'; else warn 'APT informa de posibles problemas / APT reported issues.'; fi
            ;;
        dnf)
            printf '\n  [2/8] Verificación DNF\n'
            if dnf check; then ok 'DNF check finalizado sin errores / DNF check completed.'; else warn 'DNF informa de posibles problemas / DNF reported issues.'; fi
            ;;
        yum)
            printf '\n  [2/8] Verificación YUM\n'
            if yum check; then ok 'YUM check finalizado / YUM check completed.'; else warn 'YUM informa de posibles problemas / YUM reported issues.'; fi
            ;;
        pacman)
            printf '\n  [2/8] Base de datos Pacman\n'
            if pacman -Dk; then ok 'Comprobación de dependencias completada / Dependency check completed.'; else warn 'Pacman informa de posibles problemas / Pacman reported issues.'; fi
            ;;
        zypper)
            printf '\n  [2/8] Gestor Zypper\n'
            zypper --version | sed 's/^/        /'
            msg 'La verificación de dependencias de Zypper no se ejecuta automáticamente.'
            ;;
        *)
            printf '\n  [2/8] Gestor de paquetes\n'
            warn 'No se admite una comprobación automática para este gestor.'
            ;;
    esac
}

run_diagnostics() {
    header
    section 'DIAGNÓSTICO / SYSTEM CHECKS'
    printf '  [1/8] Espacio libre / Free space\n'
    df -h / | tail -n 1 | sed 's/^/        /'
    package_health_check
    printf '\n  [4/8] Servicios fallidos / Failed services\n'
    local failed
    failed="$(systemctl --failed --no-legend 2>/dev/null || true)"
    [[ -n "$failed" ]] && printf '%s\n' "$failed" | sed 's/^/        /' || ok 'No hay servicios fallidos / No failed services.'
    printf '\n  [5/8] Errores recientes del kernel / Recent kernel errors\n'
    if command -v journalctl >/dev/null 2>&1; then
        journalctl -k -p err -n 10 --no-pager 2>/dev/null | tail -n 10 | sed 's/^/        /' || true
    else
        printf '        journalctl no disponible / unavailable\n'
    fi
    printf '\n  [6/8] Virtualización / Virtualization\n'
    if grep -qE '\b(vmx|svm)\b' /proc/cpuinfo; then ok 'VT-x/AMD-V detectado / detected.'; else warn 'VT-x/AMD-V no detectado / not detected.'; fi
    command -v VBoxManage >/dev/null 2>&1 && printf '        VirtualBox: instalado / installed\n' || printf '        VirtualBox: no detectado / not detected\n'
    command -v virsh >/dev/null 2>&1 && printf '        libvirt: instalado / installed\n' || printf '        libvirt: no detectado / not detected\n'
    printf '\n  [7/8] Arranque / Boot analysis (solo lectura / read-only)\n'
    if command -v systemd-analyze >/dev/null 2>&1; then
        systemd-analyze time 2>/dev/null | sed 's/^/        /' || true
        systemd-analyze blame 2>/dev/null | head -n 8 | sed 's/^/        /' || true
    else
        printf '        systemd-analyze no disponible / unavailable\n'
    fi
    printf '\n  [8/8] Almacenamiento y TRIM / Storage and TRIM (sin ejecutar / not run)\n'
    local transport
    transport="$(root_transport)"
    if [[ "$transport" == *usb* ]]; then
        warn 'La raíz parece estar en USB. TRIM no se ejecutará / Root appears to be USB; TRIM will not be run.'
    else
        msg 'No se ejecuta TRIM. Comprueba la compatibilidad del dispositivo / TRIM was not run; verify device support first.'
    fi
    if command -v smartctl >/dev/null 2>&1; then
        msg 'smartctl está disponible; no se inicia una prueba SMART automática.'
    else
        msg 'smartmontools no está instalado; la comprobación SMART queda omitida.'
    fi
    pause
}

# ---------------------------------------------------------------------------
# Safe tuning
# ---------------------------------------------------------------------------

set_config_key() {
    local file="$1" key="$2" value="$3"
    if grep -qE "^[[:space:]]*#?[[:space:]]*${key}=" "$file"; then
        sed -i -E "s|^[[:space:]]*#?[[:space:]]*${key}=.*|${key}=${value}|" "$file"
    else
        printf '%s=%s\n' "$key" "$value" >> "$file"
    fi
}

configure_zram() {
    if zram_active; then
        ok 'ZRAM ya está activa; se conserva / ZRAM is active; keeping current setup.'
        return 0
    fi
    if systemctl is-active --quiet zramswap.service 2>/dev/null; then
        ok 'El servicio zramswap ya está activo / zramswap service already active.'
        return 0
    fi
    if [[ -e /etc/systemd/zram-generator.conf || -e /usr/lib/systemd/zram-generator.conf || -e /usr/local/lib/systemd/zram-generator.conf ]]; then
        warn 'Se detectó zram-generator. No se instalará una segunda implementación / zram-generator found; no duplicate will be installed.'
        return 0
    fi
    if (( $(awk '/MemTotal/ {print $2}' /proc/meminfo) < 2048 )); then
        warn 'Menos de 2 GB de RAM: se omite ZRAM automática / Less than 2 GB RAM; skipping automatic ZRAM.'
        return 0
    fi
    if [[ "$PACKAGE_MANAGER" != "apt" ]]; then
        warn 'La configuración automática de ZRAM solo está preparada para APT (Debian/Ubuntu/Mint). En otras distribuciones se respeta la herramienta nativa / Automatic ZRAM setup is currently APT-only; other distros keep their native setup.'
        return 0
    fi
    if [[ -e "$ZRAM_FILE" ]]; then
        warn "$ZRAM_FILE ya existe; no se sobrescribirá / already exists; it will not be overwritten automatically."
        return 0
    fi
    if ! ask_yes_no 'No hay ZRAM activa. ¿Instalar zram-tools? / No active ZRAM. Install zram-tools?'; then
        msg 'Se omite ZRAM / Skipping ZRAM.'
        return 0
    fi
    msg 'Instalando zram-tools desde los repositorios APT / Installing zram-tools from APT repositories...'
    backup_file "$ZRAM_FILE"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y zram-tools
    if [[ ! -e "$ZRAM_FILE" ]]; then
        warn 'El paquete no creó /etc/default/zramswap; no se aplican ajustes / Package did not create expected config.'
        return 0
    fi
    set_config_key "$ZRAM_FILE" ALGO lz4
    set_config_key "$ZRAM_FILE" PERCENT 25
    set_config_key "$ZRAM_FILE" PRIORITY 100
    systemctl enable --now zramswap.service
    ok 'ZRAM configurada: LZ4, hasta 25 % RAM, prioridad 100 / ZRAM configured.'
}

apply_sysctl_tuning() {
    if ! command -v sysctl >/dev/null 2>&1; then
        warn 'sysctl no está disponible; se omiten ajustes de memoria / sysctl not found; skipping memory tuning.'
        return 0
    fi
    local swap_value=10
    zram_active && swap_value=80
    backup_file "$SYSCTL_FILE"
    cat > "$SYSCTL_FILE" <<SYSCTL
# Linux Optimizer ${VERSION} - ajustes prudentes de memoria / conservative memory tuning
# Gestionado por ${AUTHOR}; restaurable desde el menú / managed by ${AUTHOR}; restorable from menu.
vm.swappiness = ${swap_value}
vm.vfs_cache_pressure = 75
SYSCTL
    chmod 644 "$SYSCTL_FILE"
    sysctl --load="$SYSCTL_FILE" >/dev/null
    ok "Memoria ajustada / Memory tuned: swappiness=${swap_value}, vfs_cache_pressure=75."
}

apply_journal_limits() {
    if ! command -v journalctl >/dev/null 2>&1 || ! systemctl list-unit-files systemd-journald.service --no-legend 2>/dev/null | grep -q systemd-journald; then
        warn 'systemd-journald no está disponible; se omiten límites / journald unavailable; skipping limits.'
        return 0
    fi
    mkdir -p "$JOURNAL_DIR"
    backup_file "$JOURNAL_FILE"
    cat > "$JOURNAL_FILE" <<JOURNAL
# Linux Optimizer ${VERSION} - límites moderados del diario / moderate journal limits
# Gestionado por ${AUTHOR}; restaurable desde el menú / managed by ${AUTHOR}; restorable from menu.
[Journal]
SystemMaxUse=100M
RuntimeMaxUse=50M
SystemMaxFileSize=20M
RuntimeMaxFileSize=10M
MaxRetentionSec=1month
JOURNAL
    chmod 644 "$JOURNAL_FILE"
    systemctl try-restart systemd-journald.service >/dev/null 2>&1 || true
    ok 'Límites de registros configurados / Journal limits applied.'
}

apply_optimizations() {
    header
    section 'OPTIMIZACIÓN RECOMENDADA / RECOMMENDED TUNING'
    printf 'Se proponen estos cambios / Proposed changes:\n'
    printf '  • ZRAM: APT only, optional, if no existing setup is detected.\n'
    printf '  • Ajustes moderados de memoria / Moderate memory settings.\n'
    printf '  • Límites prudentes de journald / Sensible journald limits.\n'
    printf '  • Copia previa de cada configuración / Backup before every config change.\n\n'
    warn 'No se tocarán particiones, GRUB, fstab, servicios esenciales ni actualizaciones / No partitions, bootloader, fstab, essential services or updates will be changed.'
    ask_yes_no '¿Aplicar estos ajustes? / Apply these settings?' || { msg 'Operación cancelada / Cancelled.'; pause; return 0; }
    start_snapshot
    configure_zram
    apply_sysctl_tuning
    apply_journal_limits
    section 'OPTIMIZACIÓN FINALIZADA / OPTIMIZATION COMPLETE'
    ok "Copia / Backup: $SNAPSHOT_DIR"
    ok "Registro / Log: $LOG"
    msg 'No es obligatorio reiniciar / A reboot is not normally required.'
    pause
}

# ---------------------------------------------------------------------------
# Package cache cleanup by package manager
# ---------------------------------------------------------------------------

safe_cleanup() {
    header
    section 'LIMPIEZA DE CACHÉ / PACKAGE CACHE CLEANUP'
    case "$PACKAGE_MANAGER" in
        apt)
            printf 'Se ejecutará / Will run: apt-get clean y apt-get autoclean.\n'
            printf 'No elimina aplicaciones instaladas ni documentos / Does not remove installed apps or personal files.\n\n'
            ask_yes_no '¿Limpiar la caché APT? / Clean APT cache?' || { msg 'Cancelado / Cancelled.'; pause; return 0; }
            apt-get clean
            apt-get autoclean -y
            ;;
        dnf)
            printf 'Se ejecutará / Will run: dnf clean packages.\n\n'
            ask_yes_no '¿Limpiar paquetes descargados? / Clean cached packages?' || { msg 'Cancelado / Cancelled.'; pause; return 0; }
            dnf clean packages
            ;;
        yum)
            printf 'Se ejecutará / Will run: yum clean packages.\n\n'
            ask_yes_no '¿Limpiar paquetes descargados? / Clean cached packages?' || { msg 'Cancelado / Cancelled.'; pause; return 0; }
            yum clean packages
            ;;
        pacman)
            if command -v paccache >/dev/null 2>&1; then
                printf 'Se conservarán las dos versiones más recientes de cada paquete / Keeps the two newest cached versions.\n\n'
                ask_yes_no '¿Ejecutar paccache -rk2? / Run paccache -rk2?' || { msg 'Cancelado / Cancelled.'; pause; return 0; }
                paccache -rk2
            else
                warn 'No se encuentra paccache (paquete pacman-contrib). No se borrará la caché automáticamente.'
                msg 'Instala pacman-contrib y vuelve a intentarlo / Install pacman-contrib and retry.'
                pause
                return 0
            fi
            ;;
        zypper)
            printf 'Se ejecutará / Will run: zypper clean --packages.\n\n'
            ask_yes_no '¿Limpiar paquetes descargados? / Clean cached packages?' || { msg 'Cancelado / Cancelled.'; pause; return 0; }
            zypper clean --packages
            ;;
        *)
            warn 'Gestor no compatible; no se ejecuta ninguna limpieza / Unsupported package manager; nothing was cleaned.'
            pause
            return 0
            ;;
    esac
    ok 'Limpieza de caché completada / Cache cleanup completed.'
    printf '\nEspacio disponible / Available space:\n'
    df -h / | sed 's/^/  /'
    pause
}

vacuum_old_journals() {
    header
    section 'LIMPIEZA DE REGISTROS / JOURNAL CLEANUP'
    if ! command -v journalctl >/dev/null 2>&1; then
        warn 'journalctl no está disponible / journalctl unavailable.'
        pause
        return 0
    fi
    printf 'Se eliminarán solo registros systemd con más de 30 días / Only systemd journal entries older than 30 days will be removed.\n'
    printf 'Uso actual / Current usage: %s\n\n' "$(journalctl --disk-usage 2>/dev/null | sed 's/^.*: //' || echo 'no disponible')"
    warn 'Los registros eliminados no servirán para diagnosticar problemas antiguos / Deleted logs cannot help diagnose older issues.'
    ask_yes_no '¿Continuar? / Continue?' || { msg 'Cancelado / Cancelled.'; pause; return 0; }
    journalctl --vacuum-time=30d
    ok 'Limpieza de registros completada / Journal cleanup completed.'
    journalctl --disk-usage 2>/dev/null || true
    pause
}

view_log() {
    header
    section 'REGISTRO / ACTIVITY LOG'
    if [[ -s "$LOG" ]]; then tail -n 100 "$LOG"; else printf 'Todavía no hay entradas / No log entries yet.\n'; fi
    printf '\nArchivo / File: %s\n' "$LOG"
    pause
}

show_backups() {
    section 'COPIAS DE SEGURIDAD / BACKUPS'
    local found=0 item
    while IFS= read -r item; do
        [[ -n "$item" ]] || continue
        printf '  • %s\n' "$item"
        found=1
    done < <(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name '20*' -printf '%f\n' 2>/dev/null | sort -r)
    (( found == 1 )) || printf '  Todavía no hay copias / No backups yet.\n'
}

restore_menu() {
    header
    show_backups
    local latest
    latest="$(latest_snapshot)"
    if [[ -z "$latest" ]]; then pause; return 0; fi
    printf '\nSe restaurará la copia más reciente / Latest backup: %s\n' "$latest"
    restore_snapshot "$latest"
    pause
}

# ---------------------------------------------------------------------------
# Main menu
# ---------------------------------------------------------------------------

main_menu() {
    while true; do
        header
        printf '\n  %b1)%b  Panel de estado / System dashboard\n' "$C_GREEN" "$C_RESET"
        printf '  %b2)%b  Aplicar optimización / Apply recommended tuning\n' "$C_GREEN" "$C_RESET"
        printf '  %b3)%b  Limpiar caché de paquetes / Clean package cache\n' "$C_GREEN" "$C_RESET"
        printf '  %b4)%b  Diagnóstico / Diagnostics\n' "$C_GREEN" "$C_RESET"
        printf '  %b5)%b  Limpiar registros >30 días / Vacuum journal older than 30 days\n' "$C_GREEN" "$C_RESET"
        printf '  %b6)%b  Ver registro / View activity log\n' "$C_GREEN" "$C_RESET"
        printf '  %b7)%b  Restaurar configuración / Restore configuration\n' "$C_GREEN" "$C_RESET"
        printf '  %b8)%b  Salir / Exit\n' "$C_GREEN" "$C_RESET"
        printf '\n'
        hr
        printf '%bSelecciona una opción [1-8] / Choose an option [1-8]: %b' "$C_BOLD" "$C_RESET"
        local choice
        read -r choice || choice=8
        case "$choice" in
            1) show_dashboard ;;
            2) apply_optimizations ;;
            3) safe_cleanup ;;
            4) run_diagnostics ;;
            5) vacuum_old_journals ;;
            6) view_log ;;
            7) restore_menu ;;
            8) printf '\n%b¡Hasta luego! / Goodbye!%b  Hecho por / Made by %s\n\n' "$C_CYAN" "$C_RESET" "$AUTHOR"; exit 0 ;;
            *) warn 'Opción no válida / Invalid option.'; sleep 1 ;;
        esac
    done
}

main() {
    check_arguments "${1:-}"
    check_platform
    check_root
    init_runtime
    main_menu
}

main "${1:-}"
