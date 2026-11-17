# Changelog / Registro de cambios

## [4.0] — 2026-11-17

### Added / Añadido
- Support for APT, DNF, YUM, Pacman and Zypper package-manager families.
- Distribution-aware package-manager detection using `/etc/os-release`.
- Bilingual Spanish/English interface labels and help text.
- Generic package-cache cleanup adapted to the detected package manager.
- Expanded diagnostics for disk space, package health, failed services, kernel errors, virtualization and boot timing.
- Explicit support boundaries for systemd-based distributions.

### Improved / Mejorado
- Changed project identity from Mint-only to Linux Optimizer for broader distribution support.
- Kept ZRAM auto-installation limited to APT-based systems; other distributions retain their native configuration.
- Avoided automatic TRIM and improved caution around USB storage.
- More explicit backup/restore information and safety warnings.
- Added `--help` and `--version` options.

### Safety / Seguridad
- No partition, GRUB, bootloader, fstab or mount-option modifications.
- No disabling of essential services, updates, swap or security features.
- No removal of installed applications or personal files.
