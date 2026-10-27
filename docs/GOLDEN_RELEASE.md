# Golden Release Manifest

> Fait partie du parcours de certification : vue d'ensemble dans [`CERTIFICATION.md`](CERTIFICATION.md).

Une workstation n'est considérée reproductible que si son état certifié peut être identifié précisément et relié à toute sa chaîne de validation.

Le bundle Golden ne peut être généré qu'en **GATE 3 bare-metal**, après import du compte rendu natif Live USB et qualification du système installé.

Après la certification bare-metal, `scripts/release/capture-golden-release.sh` produit un bundle sous `state/releases/` contenant :

```text
golden-release.json
rpm-nevra.tsv
flatpak-commits.tsv
gnome-extensions.tsv
runtime-stack.tsv
enabled-repositories.txt
hardware-ids.txt
fedora-media.lock
performance-runtime.policy
live-proof.json
MANIFEST.sha256
```

Le verrou du média de la release active (`installer/fedora45-media.lock` après promotion du profil 45) est copié dans le bundle sous le nom générique `fedora-media.lock`, inclus dans `MANIFEST.sha256`.

## Golden Release, ISO Fedora et sauvegarde : trois objets différents

| Objet | À quoi il sert | Ce qu'il n'est pas |
|---|---|---|
| **ISO Fedora signée** | installer le système d'exploitation de base | une workstation Golden déjà personnalisée |
| **Dépôt Git + profil promu** | décrire précisément la convergence prévue | une preuve que le matériel fonctionne |
| **Golden Release Manifest** | photographier les versions, identités et preuves d'un système **déjà certifié** | une sauvegarde complète des documents |
| **Borg sur SSD externe** | restaurer les jeux de données sélectionnés | un certificat du GPU ou de GNOME |

Le futur manifeste Fedora 45 ne doit être produit **qu'après** promotion du média final, tests logiciels au nouveau SHA et Gate 3 sur le véritable PC. Les exemples décrivent la cible sélectionnée ; ils ne permettent pas de générer un bundle avant la promotion et la qualification de la machine.

Pour suivre le schéma de fonctionnement : [ARCHITECTURE_PEDAGOGIQUE.md](ARCHITECTURE_PEDAGOGIQUE.md).


## Preuve Live embarquée

`live-proof.json` est la copie du JSON natif importé après installation. Il conserve le commit, le plan de modules, l’identité stable du PC et les résultats individuels des contrôles, avec `environment=live-usb` et `hardware_certification=PREINSTALL_ONLY`.

La capture vérifie cette preuve avant de créer le bundle ; elle la copie et l’inclut dans `MANIFEST.sha256`. La qualification du système installé est portée par les diagnostics et preuves Gate 3, liés à la configuration effective et au runtime final.

## Contenu du manifeste

`golden-release.json` lie notamment :

- version et commit du projet ;
- `effective_config_sha256` ;
- hash du plan de modules ;
- bloc `performance_runtime` avec `contract=PASS`, policy SHA-256 et politiques CPU/SCX/zram/NVMe ;
- `validation_gates.chain=PASS` ;
- SHA-256 de `live-proof.json` dans `validation_gates.live_proof_sha256` ;
- fingerprint hardware et runtime ;
- kernel courant ;
- politique kernel `rolling-n-nminus1` ;
- kernel N ;
- kernel N-1 ou `none` lors d'une première installation ;
- défaut GRUB ;
- nombre de versions du canal configuré installées et limite maximale `2` par canal ;
- BIOS et microcode AMD ;
- Arc B580 `8086:e20b`, `xe`, ReBAR, PCIe x8 et EDID certifié ;
- Fedora release/compose/ISO/SHA-256 ;
- hashes des inventaires RPM/Flatpak/extensions/repositories et des IDs PCI/USB/DRM réellement observés.

`runtime-stack.tsv` capture également N, N-1, le défaut GRUB et la valeur effective `installonly_limit` afin que l'état du boot soit reproductible et auditable.

Les inventaires détaillés conservent les NEVRA RPM, commits Flatpak et hashes d'extensions afin qu'une évolution externe ne soit pas confondue avec l'état certifié historique.

## Conditions de création

Le script refuse de produire une Golden release si l'une de ces conditions manque :

```text
runtime = baremetal
Live USB = preuve native actuelle, source et identités matérielles correspondantes
système = Fedora installé, hors session Live
baseline hardware = valide
B580 PCIe/ReBAR = valide
T705 SMART/PCIe = valide
kernel courant = N
GRUB default = N
versions kernel-core <= 2 ; aucun second canal
performance-doctor --certify = PASS
```

Le défaut Golden est Linux amont officiel, sans patch, dernière stable comparée à kernel.org. Seul le canal `kernel-core` est géré, avec deux versions au maximum après purge. Aucun fallback supplémentaire épinglé n'est exigé ; le retour aux paquets Fedora reste une récupération explicite ([ADR 0015](adr/0015-official-upstream-linux.md)).

La certification finale ajoute en plus les doctors, le cold-start Nautilus, les cycles suspend/resume et les autres preuves Golden.

## Ce que ce manifeste prouve

Il fournit une **attestation d'état** et de chaîne de validation, pas une promesse que les mirrors Fedora/Flathub permettront éternellement de reconstruire bit-for-bit le même poste. Pour une reconstruction historique totalement autonome, il faut en plus conserver les payloads RPM/Flatpak/ISO nécessaires.

Pour l'usage Golden personnel, la politique retenue est :

```text
source versionnée
  + CI logicielle au commit exact
  + relevé Live natif avant installation
  + média signé
  + inventaire exact
  + certification hardware/runtime bare-metal
```

Toute modification du commit ou du module plan invalide la preuve Live. Toute modification significative de la matrice bare-metal — notamment un nouveau kernel N — doit être validée puis capturée à nouveau.

## Archive historique longue durée

Après une certification finale `PASS`, le projet fournit un helper opt-in :

```bash
./control.sh cert archive /mnt/archive/golden-2026 \
  /chemin/Fedora-Workstation-Live-45.iso \
  /chemin/offline-rpm-flatpak-cache
```

`scripts/release/seal-golden-archive.sh` :

- lit le `golden_release_manifest` de la certification finale courante ;
- vérifie d'abord le `MANIFEST.sha256` du bundle Golden ;
- refuse une destination située dans le checkout Git ;
- copie le bundle certifié dans `release/` ;
- copie les payloads explicitement fournis dans `payloads/` ;
- écrit `ARCHIVE.txt` avec commit et configuration effective ;
- génère puis vérifie un nouveau `MANIFEST.sha256` couvrant l'archive complète.

Le helper **ne télécharge rien automatiquement**. Cette limite est volontaire : les médias Fedora/Rocky et les snapshots de dépôts/caches doivent provenir d'une source de confiance choisie par l'opérateur. Pour les RPM/Flatpak, on peut fournir un cache ou miroir offline préalablement constitué ; l'archive scellée conserve ensuite exactement ce qui lui a été remis.

L'archive doit être stockée hors machine ou sur un stockage dédié. Elle complète Borg et le bundle Golden ; elle ne remplace ni le backup courant ni la certification runtime.

Voir [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md) pour le protocole complet.

Le manifeste conserve `fedora-media.lock` pour la release sélectionnée et promue ; il ne copie jamais le média d’une autre release pour en attester la provenance.
