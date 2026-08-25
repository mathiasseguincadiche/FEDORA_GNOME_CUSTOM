# Crash forensics

La 0.8.0 conserve les preuves nécessaires pour différencier crash kernel, reset GPU, erreur RAS/MCE/EDAC, PCIe/AER, timeout NVMe, OOM, watchdog, crash userspace et reboot propre/brutal.

Le journal systemd est persistant et limité, les coredumps sont stockés de façon externe et bornée, `rasdaemon` reste actif et pstore est exploité lorsqu'il existe. `kexec-tools` est installé pour rendre kdump disponible, mais kdump n'est pas activé automatiquement tant que la réservation crashkernel n'a pas été validée sur la workstation.

Utiliser :

```bash
diagnostics/crash-doctor
diagnostics/last-boot-doctor
```
