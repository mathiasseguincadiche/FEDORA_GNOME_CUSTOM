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

## 3. Préparer le second T705 — stockage persistant + KVM

Le second Crucial T705 est le disque **persistant** de la workstation. Il ne sert plus uniquement à KVM : il protège les données de travail, la bibliothèque ISO et la bibliothèque de jeux d'une réinstallation ou d'une perte du disque système Btrfs. Le dépôt **ne partitionne et ne formate jamais ce disque**.

Le préparer manuellement en EXT4 et le monter durablement sur `/data` (de préférence par UUID dans `/etc/fstab`), puis :

```bash
findmnt /data
lsblk -f
```

Le root et `/data` doivent être deux NVMe physiques distincts.

L'APPLY crée ou normalise ensuite cette structure **sans supprimer le contenu existant** :

```text
/data/
├── Documents/          # documents utilisateur persistants ; XDG Documents pointe ici
├── Projets/            # projets de travail persistants
├── ISO/                # bibliothèque ISO persistante, hors backup automatique par défaut
├── Jeux/               # bibliothèque de jeux persistante, hors backup automatique par défaut
└── libvirt/
    ├── images/         # pool devops-data / disques qcow2
    ├── iso/
    ├── cloud-init/
    ├── nvram/
    ├── snapshots/
    └── exports/
```

`Documents`, `Projets`, `ISO` et `Jeux` restent des répertoires utilisateur séparés de `/data/libvirt`. Une réinstallation du premier T705 doit **réutiliser le second T705 sans le reformater**.

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
- Secure Boot actif ou indéterminé.

Le module kernel installe **directement le dernier Kernel Vanilla stable**, applique `DNF installonly_limit=2`, définit ce noyau comme défaut GRUB et conserve au maximum le noyau immédiatement précédent.

Le module de données persistantes vérifie que `/data` est bien le second T705 EXT4, crée idempotemment `/data/Documents`, `/data/Projets`, `/data/ISO` et `/data/Jeux`, applique leurs droits/labels SELinux, puis configure XDG Documents vers `/data/Documents`. Aucun contenu préexistant n'est supprimé.

## 9. Premier boot sur le Kernel Vanilla N

Après APPLY :

```bash
./control.sh kernel status
sudo reboot
```

Le démarrage normal doit utiliser `N`, le dernier stable installé. Le noyau `N-1` reste disponible dans GRUB comme rollback. Il n'existe plus de boot `candidate` one-shot ni de promotion préalable.

Après démarrage sur N :

```bash
./diagnostics/kernel-doctor
./diagnostics/firmware-doctor
./diagnostics/storage-doctor
./diagnostics/data-storage-doctor
./diagnostics/graphics-doctor
./diagnostics/display-doctor
./diagnostics/media-doctor
./diagnostics/arc-compute-doctor
```

Le kernel doit notamment passer les vrais smoke tests VA-API et OpenCL sur la B580. `kernel-doctor` vérifie aussi `installonly_limit=2`, le nombre de kernels installés, N/N-1 et le défaut GRUB. `data-storage-doctor` vérifie le second T705, les quatre répertoires persistants, leurs droits/labels et le mapping XDG Documents.

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

Dans Nautilus et les boîtes de dialogue GNOME, « Documents » doit maintenant pointer vers `/data/Documents`.

## 11. Cinq cycles veille/réveil

Effectuer cinq vrais cycles physiques. Après chaque reprise :

```bash
./diagnostics/final-certification record-suspend
```

Chaque preuve est unique et liée au fingerprint courant. Les erreurs critiques xe/PCIe/NVMe/xHCI après resume rendent le cycle invalide.

## 12. Certification Golden

Quand toutes les preuves sont présentes :

```bash
./control.sh validate gate3 certify
```

La certification finale :

1. exécute tous les doctors obligatoires ;
2. certifie la matrice logicielle réellement démarrée ;
3. génère un `golden-release.json` et ses inventaires ;
4. lie la preuve au kernel/runtime courant.

Le diagnostic desktop bare-metal inclut le contrat de données persistantes ; une Golden ne doit donc pas être considérée conforme si `/data/Documents`, `/data/Projets`, `/data/ISO` ou `/data/Jeux` dérivent de leur contrat.

Le nouveau kernel n'attend plus cette certification pour devenir le noyau normal. En revanche, une mise à jour kernel peut rendre l'ancienne Golden `STALE` jusqu'à une nouvelle certification.

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

Le chemin complet effectue le backup, résout le dernier Kernel Vanilla stable, impose `installonly_limit=2` et prépare la transaction RPM DNF5 offline. Vérifier l'état puis déclencher le reboot offline :

```bash
./control.sh update status
./control.sh update reboot
```

Après le redémarrage :

```bash
./control.sh update finalize
```

La finalisation relit le journal DNF5 offline, exécute `dnf5 check`, vérifie que le nouveau kernel N est installé, démarré et défaut GRUB, puis exécute `dnf5 remove --oldinstallonly --limit=2`. Il ne reste donc que N et N-1. Ensuite viennent Flatpak en mode complet, consultation firmware et diagnostic global.

Exemple :

```text
7.2.2
  ↓ update all
7.2.3 = N
7.2.2 = N-1
  ↓ update all
7.2.4 = N
7.2.3 = N-1
7.2.2 supprimé
```

Aucun firmware n'est flashé automatiquement.

## 15. Backup et récupération des données persistantes

La sauvegarde quotidienne Restic protège les dossiers XDG habituels ; `DOCUMENTS` se résout désormais vers `/data/Documents`. `/data/Projets` est également ajouté explicitement aux sources quotidiennes. `/data/ISO` et `/data/Jeux` ne sont pas sauvegardés automatiquement par défaut afin d'éviter de dupliquer de gros payloads reproductibles ou retéléchargeables.

Le second T705 protège contre la perte/réinstallation du **disque système**, mais il ne remplace pas un backup externe : une panne physique du second T705 reste possible. Les données importantes conservent donc la protection Restic externe.

## 16. Recovery

Affichage :

```bash
./repair.sh display
```

Le repair refuse un écran arbitraire : il cible l'EDID certifié sur un connecteur de la B580.

Kernel N-1 :

```bash
./diagnostics/kernel-doctor
./control.sh kernel rollback
sudo reboot
```

`rollback` ne supprime pas N ; il sélectionne N-1 comme défaut GRUB. Pour revenir ensuite au dernier noyau installé :

```bash
./control.sh kernel install-latest
```

Retour d'urgence aux paquets Fedora :

```bash
scripts/kernel/rollback-to-fedora.sh
```

Ce dernier chemin est une récupération explicite, pas un fallback Fedora conservé en permanence.

Voir [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) avant toute restauration et [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) avant tout contournement.

## 17. KVM après certification HOST

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
