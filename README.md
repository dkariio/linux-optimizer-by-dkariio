# 🛠️ Linux Optimizer — by @dkariio

**ES 🇪🇸 | EN 🇬🇧**

Un optimizador y herramienta de mantenimiento prudente para distribuciones Linux con **systemd**. Incluye una interfaz de terminal, diagnóstico, ajustes conservadores de memoria, límites de registros, limpieza de cachés de paquetes y restauración de configuraciones.

A conservative optimizer and maintenance utility for **systemd-based Linux distributions**. It provides a terminal menu, system diagnostics, cautious memory tuning, journal limits, package-cache cleanup and configuration restore.

> ⚠️ **No existe una herramienta universal que sea segura en absolutamente todas las distribuciones y configuraciones.** Linux Optimizer admite las principales familias Linux con systemd, pero no macOS/BSD, Alpine/OpenRC, NixOS, SteamOS ni sistemas inmutables/atómicos.
>
> ⚠️ **There is no single optimizer that can safely support every distribution and setup.** Linux Optimizer targets major systemd-based Linux families. It does not support macOS/BSD, Alpine/OpenRC, NixOS, SteamOS or immutable/atomic systems.

---

## 🌍 Compatibilidad / Compatibility

| Distribución / Distribution | Gestor / Package manager | Estado / Status |
|---|---|---|
| Debian, Ubuntu, Linux Mint, Pop!_OS, Zorin OS, Kali | APT | ✅ Compatible |
| Fedora, RHEL, Rocky Linux, AlmaLinux, Amazon Linux | DNF / YUM | ✅ Compatible |
| Arch Linux, Manjaro, EndeavourOS, Garuda | Pacman | ✅ Compatible |
| openSUSE Leap, Tumbleweed, SUSE Linux Enterprise | Zypper | ✅ Compatible |
| Alpine Linux | APK / OpenRC | ❌ No compatible |
| NixOS, SteamOS, VanillaOS, blendOS | Declarativo / inmutable | ❌ No compatible |
| Fedora Silverblue/Kinoite y sistemas OSTree | rpm-ostree | ❌ No compatible |
| macOS / BSD | — | ❌ No compatible |

**Requisitos / Requirements**

- Linux with a running `systemd` instance.
- Bash 4 or newer.
- Root privileges for the interactive menu: `sudo`.
- Common system utilities such as `free`, `df`, `findmnt`, `systemctl` and `journalctl`.
- APT, DNF/YUM, Pacman or Zypper for package-cache cleanup. The diagnostic and system-maintenance functions can still run when no supported package manager is detected, but package-cache cleanup will be unavailable.

The script detects the distribution family from `/etc/os-release` first, then checks for its package manager. This avoids choosing an unrelated package manager just because it happens to be installed.

---

## ✨ Funciones / Features

- 📊 **Panel de estado / System dashboard:** OS, kernel, CPU, RAM, root filesystem, storage devices, swap and ZRAM.
- 🩺 **Diagnóstico / Diagnostics:** disk space, package database checks where supported, failed systemd units, recent kernel errors and boot-time information.
- 🧠 **Memoria / Memory:** conservative `vm.swappiness` and `vm.vfs_cache_pressure` settings.
- 🚀 **ZRAM:** detects existing ZRAM and avoids installing a second implementation. Optional automatic setup with `zram-tools` is currently limited to APT-based distributions; other distributions keep their native ZRAM configuration.
- 📚 **System journal:** optional moderate size/retention limits and an explicit action to remove journal entries older than 30 days.
- 🧹 **Package cache:** uses the native package manager. On Arch-based systems it uses `paccache -rk2` only when `paccache` is already installed; it does not install extra tools automatically.
- ♻️ **Backups and restore:** backs up configuration files before changing them and offers restoration of the latest snapshot.
- 🧾 **Activity log:** records optimizer actions in `/var/log/linux-optimizer.log`.
- 🔒 **Conservative by design:** no automatic TRIM, partition changes, GRUB/bootloader changes, `fstab` edits, service disabling, update disabling, swap disabling or removal of personal files/apps.

---

## 🚀 Uso / Usage

### 1. Download / Descargar

Download `linux-optimizer-by-dkariio.sh` from the GitHub repository.

### 2. Review the script / Revisa el script

Before running any administrator script, read it and make sure you trust its source:

```bash
less linux-optimizer-by-dkariio.sh
```

### 3. Run / Ejecutar

From the directory where the file was downloaded:

```bash
sudo bash ./linux-optimizer-by-dkariio.sh
```

The script asks for confirmation before applying changes or cleaning caches. Choosing **No** or pressing Enter skips an optional action.

El script pide confirmación antes de aplicar cambios o limpiar cachés. Responder **No** o pulsar Intro omite la acción opcional.

### 4. Help / Ayuda

```bash
bash ./linux-optimizer-by-dkariio.sh --help
bash ./linux-optimizer-by-dkariio.sh --version
```

---

## 🛡️ Safety notes / Notas de seguridad

1. **Make a backup of important data before system maintenance.** The built-in snapshots back up only the configuration files that this script edits; they are not a full-system backup.
2. The restore option restores configuration files. It does **not** uninstall packages that may have been installed (for example `zram-tools`) and does not guarantee that service enablement or every external side effect is reversed.
3. TRIM is never run or enabled automatically. USB flash drives are not assumed to support TRIM just because Linux reports them as non-rotational.
4. ZRAM setup is automated only on APT-based systems. On Fedora, Arch and openSUSE, existing native ZRAM configuration is detected where possible and left untouched.
5. Memory and journal settings are conservative starting points, not guaranteed performance improvements for every workload. Benchmark your own system and revert the settings if they do not help.
6. Do not use this tool on production servers without first testing it in a safe environment.

---

## 📁 Files / Archivos

- `linux-optimizer-by-dkariio.sh` — main application.
- `README.md` — documentation in Spanish and English.
- `LICENSE` — MIT License.
- `CHANGELOG.md` — version history.

---

## 🧪 Validation / Validación

The release script has been checked with `bash -n` and its `--help` and `--version` options. It has **not** been tested on every listed distribution or hardware configuration. Contributions and testing reports from users are welcome.

El script se ha comprobado con `bash -n` y se han probado las opciones `--help` y `--version`. **No** se ha probado en todas las distribuciones ni configuraciones de hardware de la tabla. Se agradecen contribuciones e informes de pruebas.

---

## 🤝 Contributions / Contribuciones

Issues, bug reports, compatibility reports and pull requests are welcome. Please include:

- Distribution name and version.
- Kernel version.
- Package manager.
- Relevant terminal output (remove usernames, hostnames and other private information).
- Whether the system is installed on an internal drive, external SSD or USB flash drive.

Se agradecen incidencias, informes de errores, pruebas de compatibilidad y pull requests. Incluye la distribución y versión, kernel, gestor de paquetes y salida relevante del terminal, ocultando datos privados.

---

## 📚 References / Referencias

- [DNF command reference](https://dnf.readthedocs.io/en/latest/command_ref.html)
- [Arch Linux `paccache` manual](https://man.archlinux.org/man/paccache.8)
- [openSUSE Zypper documentation](https://doc.opensuse.org/documentation/tumbleweed/zypper/)
- [systemd documentation](https://www.freedesktop.org/wiki/Software/systemd/)

---

## ❤️ Credits

Created and maintained by **@dkariio** on Instagram

