# Guide d'installation neuve — Fedora 45 Workstation / GNOME 51

Ce guide suit le parcours direct sur le PC : **Live USB → installation neuve → configuration personnalisée → qualification du système installé**. Le portail documentaire est [docs/README.md](README.md). Les tests logiciels de la CI Linux restent automatiques et ne constituent aucune étape à exécuter dans une VM avant l’installation.

## Cible Fedora 45 et statut pending

La référence unique de cette procédure est **Fedora 45 Workstation / GNOME 51**, installée directement. La configuration centrale sélectionne `HOST_RELEASE="45"` ; aucune installation préalable de Fedora 44 ni migration n’est nécessaire.

Le profil de production reste `pending` jusqu’à la promotion du média final signé et des composants revus. Le contrôle Live ne promeut pas ce profil. La configuration et le dry-run restent consultables pendant la préparation ; l’APPLY et la génération du Kickstart de production refusent un profil non promu. Les scripts historiques Fedora 44 sont décrits séparément dans [HISTORICAL_FEDORA44.md](HISTORICAL_FEDORA44.md).

## Avant de commencer

**Public :** opérateur qui prépare ou installe la workstation physique cible.

**Objectif :** passer d'un matériel identifié à une Fedora installée, convergée, redémarrée puis certifiée par Gate 3, sans contourner les garde-fous Golden.

### Préconditions

Avant toute mutation réelle, vous devez disposer :

- du matériel cible identifié ;
- d'un média final Fedora 45 authentifié et de son CHECKSUM signé ;
- du dépôt sur un commit propre et audité ;
- d'un second T705 identifié sans ambiguïté pour `/data` ;
- d'une cible Borg externe/off-machine disponible pour le backup pré-APPLY (ext4, non chiffrée) ;
- de Secure Boot désactivé et vérifiable comme tel.

Si le modèle mental du projet, les statuts `CODE-READY` / `Golden runtime-certified` ou le rôle des Gates ne sont pas clairs, lire d'abord [`README.md`](README.md).

### Le parcours

| Phase | Sections | Résultat attendu |
| --- | --- | --- |
| Préinstaller | 1 et 2 | Média final signé, observations Live réussies et compte rendu exporté |
| Installer Fedora | 2 | Installation neuve sur le SSD système, redémarrage et import du compte rendu Live |
| Préparer la configuration | 3 à 5 | Outils, configuration locale, `/data` et baseline prêts |
| Appliquer | 6 à 10 | Configuration définitive → dry-run final → sauvegarde vérifiée → APPLY → redémarrage |
| Qualifier | 11 à 14 | Host vérifié, Rocky qualifié, essais physiques et Gate 3 PASS |
| Exploiter | 15 à 17 | Mises à jour, sauvegardes et récupération |

### Règle d'arrêt

**Ne continuez pas** lorsqu'une précondition ou un doctor obligatoire échoue. Le chemin est fail-closed : corriger la cause, puis relancer la validation correspondante.

En particulier, ne pas poursuivre vers APPLY si :

- le profil Fedora 45 est pending ou le média n'est pas authentifié ;
- `/data` pointe vers un disque ambigu ou incorrect ;
- la baseline n'est pas valide ;
- le dry-run est périmé ;
- le backup pré-APPLY n'est plus vérifiable ;
- Secure Boot est actif ou indéterminé ;
- Git est dirty.

Le résultat final recherché est explicite : **la workstation n'est `Golden runtime-certified` qu'après Gate 3 PASS sur la vraie machine**.

---

## 1. Vérifier le média Fedora 45 final

**But :** authentifier l'ISO Workstation Fedora 45 final et son CHECKSUM signé, jamais une Beta ou une RC.

Le fichier `installer/fedora45-media.lock` n'existe qu'après promotion officielle du profil. Lorsque `profiles/fedora45/profile.json` est `pending`, cette étape reste **BLOCKED**.

Après authentification et promotion du média final :

```bash
installer/verify-fedora-media.sh --release 45 \
  --iso /chemin/Fedora-Workstation-Live-45-COMPOSE.x86_64.iso \
  --checksum /chemin/Fedora-Workstation-45-COMPOSE-x86_64-CHECKSUM \
  --keyring /chemin/fedora.gpg
```

`COMPOSE` est à remplacer par le numéro réel du média promu. Le vérificateur exige signature GPG et SHA-256 exacts.

**Checkpoint :** ne pas continuer si le profil est pending, si la signature est invalide ou si l'ISO ne correspond pas au verrou.

## 2. Vérifier le PC en Live, puis installer Fedora

### Depuis « Try Fedora »

Démarrer la clé Fedora 45 finale authentifiée et choisir **Try Fedora**. Ne pas encore ouvrir l’installateur. Suivre [FEDORA45_LIVE_PREFLIGHT.md](FEDORA45_LIVE_PREFLIGHT.md), qui détaille les 16 points, les réponses humaines et les critères de décision.

Depuis une copie propre du dépôt positionnée au commit audité :

```bash
git rev-parse HEAD
./control.sh validate live plan
./control.sh validate live run
```

Les six points requis doivent réussir et aucun point ne doit échouer. Les essais complémentaires non effectués restent `NOT_TESTED`. Un GO Live prouve uniquement les observations de préinstallation ; il ne certifie ni la configuration personnalisée ni les services du système installé.

**Avant de quitter le Live**, exporter le JSON et son fichier SHA-256 vers un support externe accessible en écriture :

```bash
./control.sh validate export live /chemin/du/support-externe/preinstallation
```

Conserver aussi le SHA du commit. Le HOME du Live est temporaire ; la clé de démarrage peut être en lecture seule. Vérifier que les deux fichiers exportés sont réellement sur le support externe. Ne pas utiliser le futur SSD système ou le SSD `/data` comme destination de transfert.

### Installation graphique neuve

Lancer ensuite l’installateur Fedora depuis la session Live. Identifier le **T705 système par son numéro de série**, puis relire le récapitulatif des changements de stockage avant confirmation. L’installation doit cibler ce SSD : Btrfs, sans LUKS, conformément au choix du projet. Préserver le second T705 prévu pour `/data` ; le dépôt ne le partitionne et ne le formate pas automatiquement. Ne pas déduire le rôle d’un disque de son nom `/dev/nvme0n1`, qui peut changer.

Le projet demande Secure Boot désactivé. Une installation Fedora manuelle ne lance pas `install.sh --apply` : la préparation et les preuves décrites ci-dessous ont lieu après son premier redémarrage.

Le [Kickstart optionnel](#option-avancée--kickstart) est une alternative pour une installation automatisée préparée et relue ; il n’est pas requis pour le parcours graphique.

### Premier démarrage sur le SSD

Retirer le média de démarrage au moment approprié puis ouvrir la session GNOME du système installé. Si Git manque sur cette installation neuve, l’installer avec `sudo dnf install git`. Reprendre **le même commit** que celui testé en Live :

```bash
git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
cd FEDORA_GNOME_CUSTOM
git switch --detach SHA_DU_COMMIT_AUDITE
./control.sh validate import /chemin/du/support-externe/preinstallation/live-COMMIT.json
./control.sh validate status
```

Remplacer les SHA et chemins par ceux réellement conservés. L’import contrôle le commit, le plan des modules et les identités physiques du PC. Il ne demande pas que le noyau Live soit identique au noyau installé. Le contrôle de ce dernier appartient à la qualification du système installé.

**Checkpoint :** compte rendu Live importé pour ce PC et ce commit, démarrage depuis le SSD système, second T705 préservé. Aucune VM n’est nécessaire avant cette étape.

## 3. Outils et configuration locale

Avant l’enrôlement et les mesures, préparer explicitement les outils nécessaires :

```bash
./control.sh install prepare-tools
```

Cette commande installe les paquets de baseline, dont `smartmontools`, sans mesurer ni certifier le matériel. Le Kickstart généré inclut le même manifeste ; cette étape prépare aussi une installation Fedora effectuée manuellement. Les consultations d’état restent sans installation de paquets.

```bash
test -e config/local.conf || cp config/local.conf.example config/local.conf
$EDITOR config/local.conf
```

Conserver le fichier existant si Kickstart a déjà écrit `HOST_RELEASE="45"`. Pour une installation manuelle, l’exemple sélectionne également Fedora 45. Pendant la revue initiale, conserver :

```text
REAL_MACHINE_APPROVED=false
```

jusqu’à la fin des contrôles préparatoires. Renseigner aussi le dépôt Borg externe et les réglages retenus avant de mesurer la baseline.

La configuration effective inclut les fichiers versionnés **et `config/local.conf`**. Une modification de l'overlay local après le dry-run rend la preuve obsolète.

## 4. Préparer le second T705 — stockage persistant + KVM

Le second Crucial T705 est le disque **persistant** de la workstation. Il ne sert plus uniquement à KVM : il protège les données de travail, la bibliothèque ISO et la bibliothèque de jeux d'une réinstallation ou d'une perte du disque système Btrfs. Le dépôt **ne partitionne et ne formate jamais ce disque**.

S’il contient déjà les données à conserver, réutiliser son filesystem EXT4 **sans le reformater**. Pour un disque neuf seulement, préparer manuellement EXT4 après vérification du numéro de série et des sauvegardes. Le monter durablement sur `/data` (de préférence par UUID dans `/etc/fstab`), puis :

```bash
findmnt /data
./diagnostics/baseline-doctor storage-identity
./diagnostics/baseline-doctor enroll-data NUMERO_DE_SERIE_DU_T705_DATA
lsblk -f
```

Le root et `/data` doivent être deux T705 physiques distincts. Recopier le numéro de série de la cible `/data` observé dans `storage-identity` pour l’approuver ; ne pas deviner ce numéro. L’enrôlement enregistre les modèles, numéros de série, WWN et UUID. Un changement de montage ou de disque invalide ensuite la baseline et bloque les écritures et sauvegardes sur `/data`.

L'APPLY crée ou normalise ensuite cette structure **sans supprimer le contenu existant** :

```text
/data/
├── Documents/          # documents utilisateur persistants ; XDG Documents pointe ici
├── Projets/            # projets de travail persistants
├── ISO/                # bibliothèque ISO persistante, hors backup automatique par défaut
├── Jeux/               # bibliothèque de jeux persistante, hors backup automatique par défaut
├── IA/Openclaw/        # projets et sources Openclaw IA ; protégés par Borg
└── libvirt/
    ├── images/         # pool devops-data / disques qcow2
    ├── iso/
    ├── cloud-init/
    ├── nvram/
    ├── snapshots/
    └── exports/
```

`Documents`, `Projets`, `ISO`, `Jeux` et `IA/Openclaw` restent des répertoires utilisateur séparés de `/data/libvirt`. Une réinstallation du premier T705 doit **réutiliser le second T705 sans le reformater**.

**Checkpoint :** `findmnt` et `lsblk` doivent prouver que `/` et `/data` résident sur deux T705 physiques distincts avant de continuer.

## 5. Baseline hardware

**But :** démontrer que le matériel réel correspond au profil Golden avant toute convergence.

```bash
./diagnostics/baseline-doctor enroll-wifi
./diagnostics/baseline-doctor enroll-bluetooth
./diagnostics/baseline-doctor list-cooling
# Identifier physiquement pompe, ventilateur CPU et ventilateur boîtier.
./diagnostics/baseline-doctor enroll-cooling fanN fanM fanP
./diagnostics/baseline-doctor snapshot
./diagnostics/baseline-doctor run-memory-test 5600
```

Configurer ensuite 6000 MT/s dans le BIOS, redémarrer et lancer :

```bash
./diagnostics/baseline-doctor run-memory-test 6000
./diagnostics/baseline-doctor run-cpu-soak
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
~/.local/state/fedora-gnome-custom/display-profile.env
```

**Checkpoint :** la baseline doit être certifiée. Un échec hardware est un critère d'arrêt.

## 6. Full dry-run

Après revue du matériel, de `/data` et de tous les réglages, fixer **avant ce dry-run final** dans `config/local.conf` :

```text
HOST_RELEASE="45"
REAL_MACHINE_APPROVED=true
```

La configuration est désormais définitive : **configuration définitive → dry-run final → sauvegarde vérifiée → APPLY → redémarrage → qualification matérielle Gate 3**. Toute retouche, y compris du drapeau d’approbation, impose de refaire le dry-run puis le backup. Le profil Fedora 45 doit déjà être promu ; ce drapeau ne contourne aucun verrou.

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

**Checkpoint :** la preuve doit correspondre au commit, à la configuration et au fingerprint qui seront utilisés pour APPLY.

## 7. Backup pré-APPLY

```bash
./prepare-preapply-backup.sh
```

Le chemin est fail-closed :

```text
cible externe/off-machine
      ↓
archive Borg fgc-preapply-…
      ↓
borg check --verify-data
      ↓
restore canary
      ↓
marker lié au même état que le dry-run
```

Au moment de l'APPLY, le projet **rouvre réellement le dépôt Borg** et vérifie que l'archive exacte (nom et identifiant) existe toujours avec le type pré-APPLY attendu. La seule présence du marker local ne suffit pas.

**Checkpoint :** ne continuer que si le snapshot exact est encore accessible et restaurable.

## 8. APPLY protégé

**Point de mutation principal :** cette étape modifie réellement la workstation.

La configuration approuvée à l’étape 6 ne doit plus changer après la création des preuves. Exécuter :

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

Le module kernel installe **le dernier Linux amont officiel stable, après comparaison à kernel.org**, définit ce noyau comme défaut GRUB, conserve au maximum le noyau amont immédiatement précédent et garde un noyau Fedora signé comme entrée GRUB de secours (`installonly_limit=4`).

Le module de données persistantes vérifie que `/data` est bien le second T705 EXT4, crée idempotemment `/data/Documents`, `/data/Projets`, `/data/ISO`, `/data/Jeux` et `/data/IA/Openclaw`, applique leurs droits/labels SELinux, puis configure XDG Documents vers `/data/Documents`. Aucun contenu préexistant n'est supprimé.

**Checkpoint :** APPLY doit terminer sans garde-fou contourné. Un refus impose de corriger la précondition qui l'a déclenché.

## 9. Premier boot sur Linux amont stable N

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

Le kernel doit notamment passer les vrais smoke tests VA-API et OpenCL sur la B580. `kernel-doctor` vérifie aussi `installonly_limit=4`, le nombre de kernels amont installés, N/N-1, le secours Fedora et le défaut GRUB. `data-storage-doctor` vérifie le second T705, les répertoires persistants dont `IA/Openclaw`, leurs droits/labels et le mapping XDG Documents.

**Checkpoint :** le runtime actif doit réellement être N et les doctors bare-metal doivent être conformes avant la certification finale.

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

## 11. Préparer et qualifier Rocky après les contrôles du host

Le Live USB et l’installation neuve n’exigent aucune VM. À présent que Fedora est installé, configuré, redémarré et que les contrôles de base du host ont réussi, vérifier le socle KVM :

```bash
./diagnostics/virtualization-doctor
./diagnostics/kvm-io-doctor benchmark
```

Créer ensuite explicitement le profil **Rocky DevOps**, puis le qualifier avec le [KVM Quickstart](KVM_QUICKSTART.md). Le projet ne crée aucune VM automatiquement pendant APPLY. La qualification de l’invité et les essais Nautilus/SFTP doivent précéder la certification Golden complète lorsque KVM est activé.

```bash
bash scripts/kvm/runtime_certification.sh
```

Les exports des VM relèvent d’une gestion personnelle manuelle. Les images et données `/data/libvirt` ne font pas partie des sauvegardes Borg automatiques : voir [KVM_QUICKSTART.md](KVM_QUICKSTART.md) et [BACKUP_RESTORE.md](BACKUP_RESTORE.md).

Ne désactiver ni SELinux, ni firewalld, ni le guard nftables pour contourner un défaut. Pour le détail : [VIRTUALIZATION.md](VIRTUALIZATION.md), [KVM_NETWORK.md](KVM_NETWORK.md), [VIRTUALIZATION.md](VIRTUALIZATION.md#profil-rocky-devops).

## 12. Cinq cycles veille/réveil

Effectuer cinq vrais cycles physiques. Après chaque reprise :

```bash
./diagnostics/final-certification record-suspend
```

Chaque preuve est unique et liée au fingerprint courant. Les erreurs critiques xe/PCIe/NVMe/xHCI après resume rendent le cycle invalide.

**Checkpoint :** cinq preuves physiques distinctes et valides sont requises ; ne pas simuler ce résultat.

## 13. Certification Golden

Terminer les essais du système installé décrits dans la [checklist physique](PHYSICAL_QUALIFICATION_CHECKLIST.md) et le [protocole de fiabilité](QUALIFICATION.md) : réseau, audio, affichage, GPU, usage réel des applications et du bureau, sauvegarde/restauration, veille et Rocky. Le contrôle court du Live ne remplace pas ces preuves de fonctionnement après configuration.

Quand toutes les preuves sont présentes :

```bash
./control.sh validate gate3 certify
```

La certification finale :

1. exécute tous les doctors obligatoires ;
2. certifie la matrice logicielle réellement démarrée ;
3. génère un `golden-release.json` et ses inventaires ;
4. lie la preuve au kernel/runtime courant.

Le diagnostic desktop bare-metal inclut le contrat de données persistantes ; une Golden ne doit donc pas être considérée conforme si `/data/Documents`, `/data/Projets`, `/data/ISO`, `/data/Jeux` ou `/data/IA/Openclaw` dérivent de leur contrat.

Le nouveau kernel n'attend plus cette certification pour devenir le noyau normal. En revanche, une mise à jour kernel peut rendre l'ancienne Golden `STALE` jusqu'à une nouvelle certification.

**Résultat attendu :** Gate 3 PASS et artefacts de certification liés au runtime physique courant.

## 14. Vérifier l'état certifié

```bash
./control.sh cert status
./diagnostics/software-matrix-doctor status
./diagnostics/software-matrix-doctor diff
```

`diff` montre exactement ce qui a changé depuis la matrice known-good.

À ce stade seulement, si Gate 3 a réellement réussi, la workstation peut être décrite comme **Golden runtime-certified**.

## 15. Mises à jour quotidiennes

Préparer une mise à jour complète :

```bash
./control.sh update all
```

Le chemin complet effectue le backup, résout le dernier Linux amont stable et refuse un RPM en retard sur kernel.org, impose `installonly_limit=4` et prépare la transaction RPM DNF5 offline. S’il existe une transaction RPM offline, vérifier l’état puis déclencher son redémarrage :

```bash
./control.sh update status
./control.sh update reboot
```

Après le redémarrage :

```bash
./control.sh update finalize
```

La finalisation relit le journal DNF5 offline, exécute `dnf5 check`, vérifie que le nouveau kernel N est installé, démarré et défaut GRUB, puis retire les noyaux amont plus anciens que N-1. Il reste N, N-1 et le noyau Fedora de secours, sous réserve de la protection du noyau actuellement démarré. Ensuite viennent Flatpak en mode complet, consultation firmware et diagnostic global.

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

Si aucun changement RPM n’est nécessaire, le parcours complet traite quand même les mises à jour Flatpak ; aucun redémarrage offline n’est alors à déclencher. Aucun firmware n’est flashé automatiquement.

## 16. Backup et récupération des données persistantes

La sauvegarde quotidienne Borg protège les dossiers XDG habituels ; `DOCUMENTS` se résout désormais vers `/data/Documents`. `/data/Projets` et `/data/IA/Openclaw` sont également ajoutés explicitement aux sources quotidiennes. `/data/ISO` et `/data/Jeux` ne sont pas sauvegardés automatiquement par défaut afin d'éviter de dupliquer de gros payloads reproductibles ou retéléchargeables.

Le second T705 protège contre la perte/réinstallation du **disque système**, mais il ne remplace pas un backup externe : une panne physique du second T705 reste possible. Les données importantes conservent donc la protection Borg externe.

## 17. Recovery

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

Si ni N ni N-1 ne démarrent : maintenir **Maj** ou appuyer sur **Échap** au démarrage pour afficher GRUB, puis choisir l'entrée Fedora sans `vanilla`. Une fois démarré, rendre ce secours durable sans rien supprimer :

```bash
./control.sh kernel fallback
```

Retour d'urgence aux paquets Fedora :

```bash
scripts/kernel/rollback-to-fedora.sh
```

Ce dernier chemin désactive les COPR noyau et remet les paquets Fedora par
défaut. Cette récupération explicite remplace le suivi amont ; aucun troisième noyau n'est épinglé.

Voir [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) avant toute restauration et [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) avant tout contournement.


---

## Option avancée — Kickstart

Pour remplacer l’installation graphique par une installation automatisée préparée, après la qualification Live et l’export du compte rendu :

```bash
ls -l /dev/disk/by-id/nvme-*
# Choisir l'identifiant du T705 système, vérifié par son numéro de série.
installer/generate-fedora-kickstart.sh --release 45 --disk /dev/disk/by-id/nvme-IDENTIFIANT_SYSTEME
```

**Média requis :** Fedora n’accepte pas de Kickstart depuis une image Live (« Try Fedora » / Workstation Live). Démarrer l’ISO **Fedora 45 Everything netinstall** avec `inst.ks=` pointant vers le fichier généré (clé USB ou URL locale). Les paquets proviennent alors des miroirs Fedora officiels (`fedora` et `updates`) déclarés dans le Kickstart ; l’ISO Workstation Live vérifiée à l’étape 1 reste la référence pour les observations Live.

Le générateur :

- montre modèle/serial/taille du disque ;
- exige la phrase destructive exacte ;
- incorpore le SHA Git du checkout ;
- incorpore le média Fedora approuvé ;
- efface uniquement le NVMe explicitement choisi ;
- installe Btrfs **sans LUKS** ;
- ne change pas Secure Boot ; le projet exige de le désactiver explicitement ;
- clone exactement le commit incorporé ;
- ne lance jamais l'APPLY automatiquement.

**Checkpoint :** le disque système et le SHA Git incorporé doivent être ceux que vous avez réellement audités.

Le commit incorporé doit être celui testé en Live. Après installation, reprendre l’import du compte rendu Live et la préparation à la section 3. Le Kickstart ne remplace ni les observations Live, ni la baseline, ni la sauvegarde, ni la qualification finale.

## Après ce guide

- exploitation quotidienne : [`CONTROL_CENTER.md`](CONTROL_CENTER.md) ;
- sauvegarde / restauration : [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md) ;
- symptômes : [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md) ;
- KVM : [`KVM_QUICKSTART.md`](KVM_QUICKSTART.md) ;
- preuve et reproductibilité : [`QUALIFICATION.md`](QUALIFICATION.md).
