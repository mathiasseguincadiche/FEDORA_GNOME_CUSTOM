# Vitals — télémétrie de la Golden Workstation

> Vue d’ensemble : [GNOME.md](GNOME.md). Le nom de module `gnome.telemetry` et les clés `RESOURCE_MONITOR_*` sont conservés comme interface de configuration.

Fedora 45 / GNOME 51 utilise **Vitals v85, review 74743**, UUID `Vitals@CoreCoding.com`, schéma `org.gnome.shell.extensions.vitals`. L’archive exacte, son URL et son SHA-256 sont dans `config/gnome-extensions.lock`. `scripts/gnome/install-resource-monitor.sh` vérifie ce verrou, les métadonnées et la provenance ; la production reste bloquée si le profil est `pending`.

## Réglages appliqués

| Réglage Vitals | Valeur du profil |
|---|---|
| `update-time` | 2 secondes |
| `position-in-panel` | 2, zone droite |
| `show-processor`, `show-memory`, `show-network` | true |
| `show-temperature` | selon l’option correspondante |
| `show-gpu` | false par défaut : mesure de charge `xe` non qualifiée |
| `hot-sensors` | CPU utilisé, RAM utilisée, débit descendant maximal, débit montant maximal |

Les identifiants stables sont `_processor_usage_`, `_memory_usage_`, `__network-rx_max__` et `__network-tx_max__`. Le module applique et relit ces valeurs. Les anciennes clés GSettings de Resource Monitor v28 ne sont pas utilisées pour Vitals.

Les températures dépendent des identifiants hwmon réellement découverts : les épingler depuis le menu Vitals sur le poste. Vitals ne garantit pas l’affichage de la charge Intel Arc B580 dans le panneau. Les détails propres aux interfaces réseau et aux capteurs doivent être contrôlés visuellement sur le matériel après installation, en Gate 3.

## Contrôles matériels indépendants

`diagnostics/resource-monitor-doctor` et le module conservent la détection du capteur Ryzen `k10temp` / `zenpower` (label `Tctl` préféré) et de la B580 PCI `8086:e20b`. La température GPU DRM hwmon est signalée lorsqu’elle existe.

La charge GPU reste **optionnelle et non mesurée** tant qu’aucun backend Intel `xe` n’a été qualifié. Son absence ne bloque ni la convergence du bureau ni la Gate 3 ; elle n’est jamais affichée comme un faux 0 %. Les attributs de charge d’autres pilotes ne sont pas requis pour la B580. Les mesures CPU, RAM et réseau restent attendues.

```bash
bash diagnostics/resource-monitor-doctor
./diagnostics/gnome-doctor
```

La CI vérifie les vrais schémas et préférences Vitals dans Fedora 45, et son activation dans la VM GNOME 51. Les conteneurs et laboratoires QEMU ne certifient pas les capteurs physiques. La Gate 3 exige le doctor sans KO.
