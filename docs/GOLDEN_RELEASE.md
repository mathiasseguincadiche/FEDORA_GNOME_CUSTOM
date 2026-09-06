# Golden Release Manifest

Une workstation n'est considérée reproductible que si son état certifié peut être identifié précisément.

Après la certification bare-metal, `scripts/release/capture-golden-release.sh` produit un bundle sous `state/releases/` contenant :

```text
golden-release.json
rpm-nevra.tsv
flatpak-commits.tsv
gnome-extensions.tsv
runtime-stack.tsv
enabled-repositories.txt
hardware-ids.txt
fedora44-media.lock
```

## Contenu du manifeste

`golden-release.json` lie notamment :

- version et commit du projet ;
- `effective_config_sha256` ;
- hash du plan de modules ;
- fingerprint hardware et runtime ;
- kernel courant ;
- kernel Fedora fallback ;
- BIOS et microcode AMD ;
- Arc B580 `8086:e20b`, `xe` et EDID certifié ;
- Fedora release/compose/ISO/SHA-256 ;
- hashes des inventaires RPM/Flatpak/extensions/repositories et des IDs PCI/USB/DRM réellement observés.

Les inventaires détaillés conservent les NEVRA RPM, commits Flatpak et hashes d'extensions afin qu'une évolution externe ne soit pas confondue avec l'état certifié historique.

## Ce que ce manifeste prouve

Il fournit une **attestation d'état**, pas une promesse que les mirrors Fedora/Flathub permettront éternellement de reconstruire bit-for-bit le même poste. Pour une reconstruction historique totalement autonome, il faudrait en plus archiver les payloads RPM/Flatpak/ISO eux-mêmes.

Pour l'usage Golden personnel, la politique retenue est :

```text
source versionnée + media signé + inventaire exact + certification hardware/runtime
```

Toute modification significative de la matrice doit être validée puis capturée à nouveau.
