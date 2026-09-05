# Guide d'installation — Fedora 44 GNOME 50 Golden Workstation

Le portail documentaire est [`README.md`](README.md). Ce guide décrit le chemin **bare-metal de production** ; les validations WSL2/VirtualBox ne déverrouillent jamais l'APPLY réel.

## 1. Vérifier le média Fedora 44

La source approuvée est versionnée dans :

```text
installer/fedora44-media.lock
```

Conserver ensemble l'ISO Fedora Workstation, le fichier CHECKSUM officiel et un keyring Fedora obtenu par un canal de confiance, puis :

```bash
installer/verify-fedora44-media.sh \
  --iso Fedora-Workstation-Live-44-1.7.x86_64.iso \
  --checksum Fedora-Workstation-44-1.7-x86_64-CHECKSUM \
  --keyring /chemin/vers/fedora-gpg-keyring.gpg
```

La vérification exige la signature du CHECKSUM et le SHA-256 verrouillé. Ne pas installer depuis un ISO de même nom mais de hash différent.

## 2. Générer le Kickstart depuis le commit exact

```bash
installer/generate-fedora44-kickstart.sh --disk /dev/nvme0n1
```

Le générateur :

- montre modèle/serial/taille du disque ;
- exige la phrase destructive exacte ;
- incorpore le SHA Git du checkout ;
- incorpore le média Fedora approuvé ;
- efface uniquement le NVMe explicitement choisi ;
- installe Btrfs **sans LUKS** ;
- laisse Secure Boot hors du contrat Golden ;
- clone exactement le commit incorporé ;
- ne lance jamais l'APPLY automatiquement.

## 3. Préparer le second T705

Le second Crucial T705 est dédié à KVM. Le dépôt **ne partitionne et ne formate jamais ce disque**.

Le préparer manuellement en EXT4 et le monter sur `/data`, puis :

```bash
findmnt /data
lsblk -f
```

Le root et `/data` doivent être deux NVMe physiques distincts.

## 4. Configuration locale

```bash
cp config/local.conf.example config/local.conf
$EDITOR config/local.conf
```

Conserver :

```text
REAL_MACHINE_APPROVED=false
```

jusqu'à la fin des contrôles.

La configuration effective inclut les fichiers versionnés **et `config/local.conf`**. Une modification de l'overlay local après le dry-run rend la preuve obsolète.

## 5. Baseline hardware

```bash
./diagnostics/baseline-doctor snapshot
./diagnostics/baseline-doctor run-memory-test 5600
```

Configurer ensuite 6000 MT/s dans le BIOS, redémarrer et lancer :

```bash
./diagnostics/baseline-doctor run-memory-test 6000
./diagnostics/baseline-doctor run-nvme-test root
./diagnostics/baseline-doctor run-nvme-test data
./diagnostics/baseline-doctor certify
```

La certification vérifie notamment :

- Ryzen 7 7700 ;
- DDR5 testée à 5600 puis 6000 MT/s ;
- Arc B580 `8086:e20b` sur `xe` ;
- ReBAR actif ;
- lien B580 x8 avec capacité ≥ PCIe 4.0 ;
- deux T705 distincts, SMART strict et lien x4 avec capacité PCIe 5.0 ;
- EDID du moniteur connecté **à la B580** ;
- absence de signaux kernel critiques.

Le profil EDID certifié est écrit dans :

```text
~/.config/fedora-gnome-custom/display-certified.env
```

## 6. Full dry-run

```bash
./install.sh --dry-run
```

Le dry-run est non mutant et produit une preuve liée à :

```text
commit Git
configuration effective
plan des modules
fingerprint hardware
```

Toute modification d'un de ces éléments impose de refaire le dry-run.

## 7. Backup pré-APPLY

```bash
./prepare-preapply-backup.sh
```

Le chemin est fail-closed :

```text
cible externe/off-machine
      ↓
Restic snapshot
      ↓
restic check
      ↓
restore canary
      ↓
marker lié au même état que le dry-run
```

Au moment de l'APPLY, le projet **rouvre réellement le repository Restic** et vérifie que le snapshot exact existe toujours avec le tag attendu. La seule présence du marker local ne suffit pas.

## 8. APPLY protégé

Après revue de la cible :

```text
REAL_MACHINE_APPROVED=true
```

puis :

```bash
./install.sh --apply
```

L'APPLY refuse notamment :

- une exécution non bare-metal ;
- un Git dirty ;
- un dry-run obsolète ;
- une baseline obsolète ;
- un snapshot pré-APPLY absent/inaccessible ;
- Secure Boot actif ou indéterminé ;
- un fallback Fedora absent.

Le module kernel **stage uniquement un candidat Kernel Vanilla**. Il ne change pas immédiatement le kernel Golden persistant.

## 9. Qualifier le kernel candidat

Après APPLY :

```bash
./control.sh kernel status
./control.sh kernel boot-candidate
```

Puis redémarrer.

Le boot est **one-shot** : en cas de problème, le défaut de boot persistant reste le kernel précédemment certifié/Fedora.

Après démarrage du candidat :

```bash
./diagnostics/kernel-doctor
./diagnostics/firmware-doctor
./diagnostics/storage-doctor
./diagnostics/graphics-doctor
./diagnostics/display-doctor
./diagnostics/media-doctor
./diagnostics/arc-compute-doctor
```

Le candidat doit notamment passer les vrais smoke tests VA-API et OpenCL sur la B580.

## 10. Premier login GNOME

Immédiatement après le login, avant d'utiliser Files :

```bash
./diagnostics/nautilus-coldstart-doctor
```

Puis contrôler :

```bash
./diagnostics/gnome-doctor
./diagnostics/nautilus-integration-doctor
./diagnostics/portal-doctor
./diagnostics/applications-doctor
```

## 11. Cinq cycles veille/réveil

Effectuer cinq vrais cycles physiques. Après chaque reprise :

```bash
./diagnostics/final-certification record-suspend
```

Chaque preuve est unique et liée au fingerprint courant. Les erreurs critiques xe/PCIe/NVMe/xHCI après resume rendent le cycle invalide.

## 12. Certifier le candidat

Quand toutes les preuves sont présentes :

```bash
./control.sh kernel certify
```

La certification finale :

1. exécute tous les doctors obligatoires ;
2. certifie la matrice logicielle ;
3. génère un `golden-release.json` et ses inventaires ;
4. enregistre le kernel comme Golden ;
5. le définit seulement alors comme défaut persistant.

Le **dernier kernel installé n'est jamais automatiquement Golden**.

## 13. Vérifier l'état certifié

```bash
./control.sh cert status
./diagnostics/software-matrix-doctor status
./diagnostics/software-matrix-doctor diff
```

`diff` montre exactement ce qui a changé depuis la matrice known-good.

## 14. Mises à jour quotidiennes

Préparer une mise à jour complète :

```bash
./control.sh update all
```

Cela effectue le backup et prépare la transaction RPM DNF5 offline. Ensuite :

```bash
sudo scripts/maintenance/update-system.sh --offline-reboot
```

Après le redémarrage :

```bash
scripts/maintenance/update-system.sh --post-offline
```

Aucun firmware n'est flashé automatiquement.

## 15. Recovery

Affichage :

```bash
./repair.sh display
```

Le repair refuse un écran arbitraire : il cible l'EDID certifié sur un connecteur de la B580.

Kernel :

```bash
./diagnostics/kernel-doctor
scripts/kernel/kernel-lifecycle.sh rollback
```

Retour complet aux paquets Fedora :

```bash
scripts/kernel/rollback-to-fedora.sh
```

Voir [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) avant toute restauration et [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) avant tout contournement.

## 16. KVM après certification HOST

Avant de créer les VM :

```bash
./diagnostics/virtualization-doctor
./diagnostics/kvm-io-doctor benchmark
```

Puis lire :

1. [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md) ;
2. [`VIRTUALIZATION.md`](VIRTUALIZATION.md) ;
3. [`KVM_NETWORK.md`](KVM_NETWORK.md) ;
4. [`VM_PROFILES.md`](VM_PROFILES.md).

Ne désactiver ni SELinux, ni firewalld, ni le guard nftables pour contourner une erreur.
