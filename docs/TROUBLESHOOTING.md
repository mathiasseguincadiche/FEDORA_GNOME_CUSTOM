# Dépannage

> Mise à jour : 2026-11-06 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-06 — diagnostic de préinstallation relu contre `lib/live_validation.py` et `scripts/validation/live-usb.sh` ; routes du centre de contrôle contrôlées statiquement — matériel : non vérifié

Ce guide part d'un **symptôme**. Méthode : observer, diagnostiquer, corriger le minimum, puis revalider. Commencer par l'état réel :

```bash
./control.sh status
./control.sh doctor all
```

Chaque ligne `KO` nomme le contrôle en échec. Corriger le **premier** défaut réel, pas le dernier message.

**À ne jamais faire** : désactiver SELinux ou firewalld ; supprimer les règles nftables KVM ; ajouter `force_probe`, ou forcer ASPM, APST, C-States ou un mode de veille sans preuve ; reformater `/data` ; `chmod 777` ; éditer ou recréer un marqueur de preuve à la main ; modifier une configuration avant d'avoir conservé les journaux.

Sauf mention *(modifie le système)*, les commandes de cette page observent sans rien changer au poste ; certaines écrivent seulement un rapport ou une preuve dans le dépôt (`logs/`, `state/`, `reports/`). Une commande marquée change l'état du poste ; la lancer seulement une fois la cause confirmée.

## En urgence

Quand le PC ne démarre plus ou que des données semblent perdues, le but immédiat n'est pas de comprendre la panne : c'est de **retrouver un système démarrable sans rien détruire**. Les gestes ci-dessous n'effacent aucune donnée ; la section indiquée explique ensuite la cause.

| Situation | Gestes, dans l'ordre | Retour à la normale |
|---|---|---|
| Le PC ne démarre plus après un nouveau noyau | 1. Au démarrage, maintenir **Maj** ou appuyer sur **Échap** pour afficher GRUB. 2. Choisir le noyau amont précédent (N-1), sinon l'entrée Fedora sans `vanilla`. 3. Une fois connecté, conserver les journaux du démarrage raté : `./scripts/collect-boot-failure.sh`. 4. `./control.sh kernel rollback`, ou `./control.sh kernel fallback` si N-1 ne démarre pas non plus *(modifie le système)*. | `./control.sh kernel status` montre le noyau choisi par défaut ; suite dans [Noyau](#noyau) |
| Le système démarre, mais la session GNOME ne s'ouvre pas | 1. Ouvrir une console texte (**Ctrl+Alt+F3**) et se connecter. 2. `journalctl -b -p err --no-pager` pour lire les erreurs du démarrage en cours. 3. `./control.sh doctor all` pour trouver le premier défaut. | session GNOME ouverte, `doctor all` sans nouveau `KO` ; suite dans [GPU, écran et veille](#gpu-écran-et-veille) |
| `/data` a disparu | Ne rien formater ni recréer. `findmnt -n -T /data -o SOURCE,FSTYPE` et `lsblk -f`, puis remonter le disque existant. | `./control.sh doctor data` sans `KO` ; suite dans [Données `/data` et Gaming](#données-data-et-gaming) |
| Des fichiers ont été effacés ou écrasés | Cesser d'écrire dans le dossier concerné. Restaurer dans le staging avec `scripts/backup/restore.sh restore latest`, inspecter, puis recopier à la main. | fichiers relus dans le staging ; suite dans [sauvegardes](BACKUP_RESTORE.md#restaurer) |

**Pourquoi conserver les journaux d'abord ?** Un redémarrage ou une correction efface la trace qui explique la panne ; sans elle, le défaut reviendra au prochain noyau. Le piège classique est de tenir le problème pour réglé parce que le poste redémarre : une panne qui disparaît après un redémarrage ne prouve rien.

**Si aucun noyau ne démarre**, le poste se réinstalle depuis le [guide d'installation](INSTALLATION_GUIDE.md#le-parcours), section 2, en conservant le second T705 ; la [reprise après une perte totale](BACKUP_RESTORE.md#reprendre-après-une-perte-totale) décrit la remise en place des données. Après l'incident, consigner la cause et la correction dans la fiche d'incident ([Journaux et incidents](#journaux-et-incidents)).

## Par où commencer

| Symptôme | Première commande | Section |
|---|---|---|
| `install.sh --apply` ou la sauvegarde pré-APPLY refusés | `./install.sh --dry-run` | [Installation et APPLY](#installation-et-apply) |
| Gate 2 Live `NO-GO` ou `A_VERIFIER` | lire le TSV `state/validation/live-preflight.tsv` depuis la session Live | [Préinstallation Live](#préinstallation-live-usb) |
| Paquet, dépôt, Flatpak ou codec en échec | `dnf repolist`, `./diagnostics/media-doctor` | [Paquets et applications](#paquets-et-applications) |
| GPU, écran, couleurs ou veille | `./diagnostics/graphics-doctor`, `./diagnostics/display-doctor` | [GPU, écran et veille](#gpu-écran-et-veille) |
| Identité de la carte mère, CPU, mémoire, T705 | `./diagnostics/hardware-components-doctor` | [Carte mère, CPU, mémoire et stockage](#carte-mère-cpu-mémoire-et-stockage) |
| Démarrage sur le mauvais noyau, régression | `./control.sh kernel status` | [Noyau](#noyau) |
| `/data`, XDG Documents, Steam | `./control.sh doctor data` | [Données `/data` et Gaming](#données-data-et-gaming) |
| Sauvegarde refusée, restauration | `./diagnostics/backup-doctor --certify-status` | [Sauvegarde et restauration](#sauvegarde-et-restauration) |
| VM, réseau `devops-nat` | `./control.sh kvm guard-check` | [Dépannage KVM](KVM_QUICKSTART.md#dépannage) |
| Contrôle GitHub Actions rouge | page Actions, SHA exact | [Un contrôle GitHub Actions devient rouge](#un-contrôle-github-actions-devient-rouge) |

Les journaux et fiches d'incident sont décrits dans [Journaux et incidents](#journaux-et-incidents) ; ce qu'il faut joindre à une demande d'aide, dans [Avant de demander de l'aide](#avant-de-demander-de-laide).

## Pannes fréquentes

Une cause possible reste une hypothèse tant que la vérification ne l'a pas confirmée. Le détail de chaque cas est dans la section indiquée.

| Symptôme | Cause possible | Vérification sûre | Correction | Nouvelle validation |
|---|---|---|---|---|
| `install.sh --apply` refusé | dépôt modifié, dry-run absent ou d'un autre état, sauvegarde pré-APPLY absente, Secure Boot actif | `git status --short`, `./install.sh --dry-run` | corriger la cause nommée par le refus, refaire le dry-run puis la sauvegarde | l'APPLY passe ses gardes ([détail](#installation-et-apply)) |
| Arc B580 absente ou rendu instable | carte mal insérée, ReBAR désactivé, firmware manquant | `lspci -nnk -d 8086:e20b`, `./diagnostics/graphics-doctor` | vérifier slot et UEFI ; jamais de `force_probe` | `graphics-doctor` sans `KO` ([détail](#gpu-écran-et-veille)) |
| Affichage dégradé après une veille | mode d'écran perdu au réveil | `./diagnostics/display-doctor` | `./repair.sh display` *(modifie le système)* | `display-doctor` sans `KO` |
| Démarrage sur N-1 au lieu de N | entrée de démarrage par défaut | `./control.sh kernel status` | `./control.sh kernel install-latest` *(modifie le système)*, puis redémarrer | `kernel status` montre N démarré ([détail](#noyau)) |
| Régression après un nouveau noyau | défaut du noyau amont | `./control.sh kernel doctor`, `journalctl -k -b` | `./control.sh kernel rollback` *(modifie le système)* | doctors sans `KO` sur N-1, puis recertifier |
| `/data` absent | montage du second T705 perdu | `findmnt -n -T /data -o SOURCE,FSTYPE`, `lsblk -f` | remonter le disque existant, **sans formater** | `./control.sh doctor data` sans `KO` ([détail](#données-data-et-gaming)) |
| Label SELinux incorrect sous `/data` | fichiers copiés hors de leur contexte | `ls -Zd /data/*` | `sudo restorecon -RFv` sur les dossiers concernés *(modifie le système)* | `./control.sh doctor data` sans `KO` |
| Sauvegarde refusée | `/data` n'est pas le montage attendu, support externe absent | `./diagnostics/backup-doctor --certify-status` | rétablir le montage ou brancher le support | nouvelle sauvegarde, puis `./control.sh backup check` ([détail](#sauvegarde-et-restauration)) |
| VM sans Internet, garde en mode d'urgence | LAN en conflit avec `192.168.50.0/24`, changement de réseau | `./control.sh kvm guard-check`, `ip -4 route` | `./control.sh kvm guard-reconcile` *(modifie le système)* | `guard_mode=normal` ([détail](KVM_QUICKSTART.md#dépannage)) |

## Installation et APPLY

### Préinstallation Live USB

**Aucune installation n'a encore commencé : c'est le bon moment pour s'arrêter.** Si la Gate 2 retourne `NO-GO`, au moins un point a échoué ; si elle retourne `A_VERIFIER`, une observation obligatoire manque. Ne pas lancer l'installateur Fedora pour « voir si cela passe ».

1. Dans la session Live, examiner `state/validation/live-preflight.tsv` et noter les points `FAIL` ou `NOT_TESTED` ; ne jamais remplacer une absence d'essai par une réussite supposée.
2. Vérifier uniquement le composant ou la situation en cause : connexion réseau, réglage d'affichage, périphérique ou essai humain manquant.
3. Refaire les observations concernées avec le [guide Live USB](FEDORA45_LIVE_PREFLIGHT.md) et exporter un nouveau compte rendu si la décision devient `GO`.
4. Transmettre ce compte rendu à la revue du propriétaire. **Même un `GO` technique exige son autorisation avant installation.**

La Gate 3 ne s'exécute pas depuis la clé Live : elle qualifie Fedora **après** installation et configuration. Le [guide de qualification](QUALIFICATION.md) distingue ces preuves.

### APPLY refusé

**`install.sh --apply` refusé.** C'est une protection, pas une panne. Vérifier :

```bash
git status --short
./diagnostics/baseline-doctor status
./install.sh --dry-run
./prepare-preapply-backup.sh   # crée l'archive Borg pré-APPLY : écrit sur le support de sauvegarde
```

Causes courantes : exécution hors du PC physique (VM, conteneur, WSL), dépôt Git modifié, dry-run absent ou d'un autre état, baseline incomplète, sauvegarde pré-APPLY absente ou illisible, Secure Boot actif ou indéterminé, `REAL_MACHINE_APPROVED=true` absent de `config/local.conf`, phrase de confirmation incorrecte. Changer `config/local.conf` impose de refaire le dry-run puis la sauvegarde.

**Sauvegarde pré-APPLY refusée.** Elle exige un dry-run réussi au même état, une cible Borg externe prouvée, un dépôt non chiffré (un dépôt chiffré est refusé), de l'espace libre, `borg check --verify-data` et la restauration réelle d'un canari. Un `borg create` terminé ne suffit pas.

**Marqueur de sauvegarde présent mais archive absente.** L'APPLY reste bloqué : il relit l'archive exacte dans le dépôt. Refaire `./prepare-preapply-backup.sh`, et vérifier avec `borg list --glob-archives 'fgc-preapply-*' "$BACKUP_REPOSITORY"`.

## Paquets et applications

**DNF ou un dépôt échoue.** `dnf repolist`, `dnf check`, `dnf repoquery --available bash`. Pour VS Code ou Brave, vérifier le dépôt (`dnf repoquery --available code`, `brave-browser`) plutôt que de télécharger un RPM sur un site tiers. Une rupture côté éditeur peut être temporaire : la CI de préflight des paquets la verrait aussi.

**Application Flathub absente.** `flatpak remotes`, `flatpak list`, `flatpak remote-info flathub <APP_ID>`. Les mises à jour Flatpak sont manuelles (`flatpak update` ou `./control.sh update flatpak`) : aucun timer automatique, c'est normal.

**Codecs ou accélération vidéo.** `./diagnostics/media-doctor`, `vainfo`, `ffmpeg -decoders | grep -Ei 'h264|hevc|av1|vp9'`. Le pilote média Intel est choisi sur les capacités mesurées : si VA-API expose H.264/HEVC/AV1/VP9, garder le fournisseur courant même si un forum en conseille un autre.

**GNOME, portail ou Flatpak défaillant.** `./diagnostics/gnome-doctor`, `./diagnostics/portal-doctor`, `./diagnostics/applications-doctor`, `echo "$XDG_SESSION_TYPE"` (attendu `wayland`), `systemctl --user status xdg-desktop-portal.service xdg-desktop-portal-gnome.service`. Ne pas basculer sur X11 pour masquer un défaut Wayland ou GPU.

**Dock ou extensions incorrects.** `gnome-extensions list --enabled`, `./control.sh doctor polish`. Le profil attendu est décrit dans [GNOME](GNOME.md).

## GPU, écran et veille

**Arc B580 non détectée ou rendu instable.** Attendu : `8086:e20b` sur le pilote `xe`.

```bash
./diagnostics/kernel-doctor
./diagnostics/firmware-doctor
./diagnostics/graphics-doctor
./diagnostics/arc-compute-doctor
lspci -nnk -d 8086:e20b
journalctl -k -b | grep -Ei 'xe|drm|firmware|AER|PCIe'
```

Ne jamais ajouter `xe.force_probe` ou `i915.force_probe`.

**ReBAR absent.** `lspci -vv -d 8086:e20b | grep -A12 -i 'Resizable BAR'`. Activer *Above 4G Decoding* et *Resizable BAR* dans l'UEFI.

**B580 en x4 au lieu de x8.** `lspci -vv -d 8086:e20b | grep -E 'LnkCap:|LnkSta:'`. Attendu : capacité ≥ PCIe 4.0 et largeur x8 négociée ; une vitesse instantanée basse au repos n'est pas un défaut. Vérifier la carte, le slot CPU principal et l'UEFI avant Linux.

**Blanc grisâtre, image délavée.** Avant de soupçonner `xe`, comparer la plage RGB complète/limitée, la conversion HDR/SDR, l'éclairage nocturne et le profil ICC, un facteur à la fois. `./diagnostics/display-color-audit` donne un inventaire non intrusif ; un mode présent dans sysfs n'est pas forcément actif ([diagnostic des couleurs](DISPLAY_COLOR_DIAGNOSTIC.md)).

**Polices ou affichage dégradés après veille.** Ne pas toucher Fontconfig en premier. `./diagnostics/display-doctor`, puis `./repair.sh display` *(modifie le système)*, qui réapplique 2560×1440/~240 Hz, échelle 1.0, SDR et RGB complet, et seulement sur l'EDID certifié connecté à la B580.

**EDID attendu absent ou plusieurs écrans.** `./diagnostics/display-doctor`, `cat ~/.config/fedora-gnome-custom/display-certified.env`. Un écran réellement remplacé impose de refaire la baseline. La capture initiale exige un seul écran cible : débrancher les écrans secondaires pendant la certification.

**Réveil de veille incorrect.** `./diagnostics/suspend-doctor`, `./diagnostics/usb-resume-doctor`, `cat /sys/power/mem_sleep`, `journalctl -k -b | grep -Ei 'xe|drm|xhci|usb|nvme|AER|PCIe|ACPI'`. Ne forcer `deep`, `s2idle`, ASPM ou APST qu'après reproduction et analyse. Après correction, enregistrer de nouveaux cycles (`./control.sh validate gate3 record-suspend` *(modifie le système)*).

**Redémarrage inexpliqué ou crash.** Conserver les preuves avant tout changement de noyau ou de firmware :

```bash
./scripts/collect-boot-failure.sh
journalctl -b -1 -p warning..alert
journalctl -k -b -1 | grep -Ei 'panic|Oops|watchdog|MCE|EDAC|AER|PCIe|nvme|xe|drm|thermal'
coredumpctl list
```

## Carte mère, CPU, mémoire et stockage

**DMI / BIOS en KO.** `./diagnostics/hardware-components-doctor` et `cat /sys/class/dmi/id/{board_vendor,board_name,bios_version,bios_date}`. Attendu : MSI `MAG B850M MORTAR WIFI` (ou `MS-7E61`), BIOS AMI. Une mise à jour du BIOS change volontairement l'empreinte : refaire la baseline, ne jamais recopier un ancien marqueur.

**AMD P-State ou boost en KO.** `cat /sys/devices/system/cpu/cpufreq/policy0/scaling_driver /sys/devices/system/cpu/amd_pstate/status`. Attendu : `amd-pstate` ou `amd-pstate-epp`, statut `active`, `passive` ou `guided`, boost à 1. Si `acpi-cpufreq` apparaît, vérifier l'UEFI (CPPC) et la ligne de commande du noyau ; pas d'overclocking ni de réglage arbitraire.

**DDR5 retombée en vitesse après un reset du BIOS.** `sudo dmidecode --type 17 | grep -E 'Configured Memory Speed|Speed:'`. Refaire les tests mémoire 5600/6000 et la certification de la baseline.

**Wi-Fi identity lock en KO.** `lspci -Dnnk | grep -A4 -Ei 'Network controller|Wireless'`. Le verrou porte sur le PCI ID et le pilote, pas l'adresse PCI. Ne réenrôler (`./diagnostics/baseline-doctor enroll-wifi` *(modifie le système)*) qu'après avoir compris le changement.

**Ventilateurs ou capteurs (NCT6687D-R).** Seul le pilote Fedora `nct6683`, en lecture seule, est autorisé ; le BIOS garde le contrôle des ventilateurs. `lsmod | grep nct6683`, `sensors`. Si le pilote refuse la carte (`sudo dmesg | grep -i nct6683` signale un *customer ID* non supporté), et seulement dans ce cas : `HARDWARE_NCT6683_FORCE="true"` dans `config/local.conf`, puis `./control.sh install apply` *(modifie le système)*. Retour arrière : remettre `false`, supprimer `/etc/modprobe.d/fedora-gnome-custom-nct6683-force.conf` et recharger le module. `msi_fan_brute_force` et les modules tiers restent refusés. Sans tachymètre vivant, vérifier d'abord les branchements CPU_FAN/PUMP/SYS_FAN et les RPM dans le BIOS.

**T705 négocié en x2 ou sous PCIe 5.0.** `./diagnostics/storage-doctor`, `sudo nvme list`, `lspci -tv`. Attendu : x4 et ≥ 32 GT/s pour chacun. Vérifier le slot M.2, le partage de lignes PCIe et l'UEFI ; ne pas désactiver ASPM ou APST par réflexe.

**SMART T705 en KO.** `sudo nvme smart-log /dev/nvme0 -o json`, puis `journalctl -k -b | grep -Ei 'nvme|PCIe Bus Error|AER'`. Bloquants : `critical_warning` non nul, `media_errors` non nul, réserve sous le seuil, usure anormale, température critique, reset ou erreur I/O, erreur PCIe non corrigée. `num_err_log_entries` seul est historique : le corréler avec le journal courant.

## Noyau

État : `./control.sh kernel status` et `./control.sh kernel doctor`. Politique : [Linux amont](UPSTREAM_LINUX.md).

**Nouveau N installé mais démarrage sur N-1.** `./control.sh kernel install-latest` *(modifie le système)*, puis redémarrer. Pendant une mise à jour offline, `./control.sh update finalize` *(modifie le système)* remet N par défaut et demande un redémarrage si besoin. Aucun noyau n'est supprimé tant que N n'a pas démarré.

**Régression sur N.** `./control.sh kernel rollback` *(modifie le système)* choisit N-1 comme défaut sans supprimer N. Recertifier l'état retenu si la matrice a changé.

**Ni N ni N-1 ne démarrent.** Au démarrage, maintenir **Maj** ou appuyer sur **Échap** pour afficher GRUB (Fedora l'affiche aussi après un démarrage raté), puis choisir l'entrée Fedora sans `vanilla`. Une fois connecté : `./control.sh kernel fallback` *(modifie le système)* en fait le défaut sans rien supprimer. Retour au dernier amont : `./control.sh kernel install-latest` *(modifie le système)*. Retour complet aux paquets Fedora : `./control.sh kernel rollback-fedora` *(modifie le système)*.

**Trop de noyaux installés.** `rpm -q --qf '%{NAME}\t%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core | sort -V`. Attendu : au plus deux noyaux amont et un noyau Fedora de secours. `./control.sh kernel prune` *(modifie le système)* retire les versions exactes en trop ; le noyau démarré est protégé : redémarrer sur N puis relancer.

**Transaction DNF offline en attente.** `./control.sh update status`, puis `./control.sh update reboot` *(modifie le système)* et `./control.sh update finalize` *(modifie le système)* après le redémarrage.

**Certification `STALE`.** `./diagnostics/software-matrix-doctor diff` montre ce qui a changé. Lancer les doctors concernés, puis recertifier ; ne jamais recréer les marqueurs.

## Données `/data` et Gaming

Contrat : `/data` est l'EXT4 du second T705, avec `Documents`, `Projets`, `ISO`, `Jeux` et `IA/Openclaw` en `0750`, label `user_home_t`, et `libvirt` en `virt_image_t`. `Documents` est aussi le dossier XDG Documents. Le projet ne formate ni ne partitionne jamais ce disque.

**`/data` absent ou mauvais système de fichiers.** `findmnt -n -T /data -o SOURCE,FSTYPE`, `lsblk -f`, `./control.sh doctor data`. Restaurer le montage du disque existant, sans formater. Après une réinstallation : `./diagnostics/baseline-doctor storage-identity`, puis `enroll-data NUMERO_DE_SERIE` *(modifie le système)* ; deux partitions d'un même NVMe sont refusées.

**Dossier absent, propriétaire, mode ou label incorrect.** L'APPLY recrée les dossiers sans supprimer leur contenu. `stat -c '%U:%G %a %n' /data/*` et `ls -Zd /data/*`. Pour les labels, `sudo restorecon -RFv /data/Documents /data/Projets /data/IA/Openclaw /data/ISO /data/Jeux /data/libvirt` *(modifie le système)*. Jamais de `chown -R` aveugle, ni de lien vers `/data/libvirt`.

**XDG Documents incorrect.** `xdg-user-dir DOCUMENTS` doit répondre `/data/Documents`.

**La sauvegarde refuse `/data`.** Elle échoue volontairement si `/data` n'est pas le montage attendu (`./diagnostics/backup-doctor --certify-status`). `ISO` et `Jeux` ne sont pas sauvegardés : une donnée irremplaçable doit être ailleurs.

**Gaming doctor en KO.** `./control.sh doctor gaming`, `rpm -q steam gamemode mangohud goverlay gamescope steam-devices`, `vulkaninfo --summary` (attendu : B580 sur `xe`, Vulkan Mesa Intel). Le profil exige Gaming activé. Pas de Mesa git/COPR ni de noyau gaming pour masquer un `KO`.

**Steam n'utilise pas `/data/Jeux`.** Normal après installation : l'ajouter dans **Paramètres → Stockage** ; le projet ne modifie pas `libraryfolders.vdf`. Ne pas donner à Steam tout `/data`.

**Proton absent ou jeu instable.** Steam télécharge Proton à la demande. Préférer Proton, puis Proton Experimental, Proton-GE en exception par titre. Tester un jeu sans option, puis `gamemoderun %command%`, `mangohud %command%`, les deux ; Gamescope au cas par cas. Un problème d'anti-triche ou de DRM d'un jeu ne prouve pas un défaut du poste. Voir aussi [Gaming](GAMING.md).

## Sauvegarde et restauration

**Le moteur refuse une sauvegarde de VM.** Normal : les exports de VM sont manuels ; `--include-vms` et `BACKUP_VM_DISKS=true` sont refusés.

**Restaurer sans écraser le système.** `scripts/backup/restore.sh list`, `scripts/backup/restore.sh verify`, `scripts/backup/restore.sh restore latest` : la restauration va toujours dans un dossier de staging, à inspecter avant toute copie vers `/etc`, `/boot`, `$HOME` ou `/data`. Détails : [sauvegardes](BACKUP_RESTORE.md).

## Journaux et incidents

Les exécutions sont dans `logs/<RUN_ID>/main.log` et `modules.log` (horodatage UTC), les incidents ouverts dans `logs/incidents/<RUN_ID>.json`, les comptes rendus de nettoyage dans `reports/nettoyage-*.json`.

Chaque fiche d'incident propose un titre, une explication en français, une action et un niveau d'incertitude : c'est une **hypothèse**, jamais une preuve de cause, et le journal brut reste la référence. `status: open` protège le journal de la purge. Pour clore, passer `status` à `resolved` et remplir `resolution` avec la cause corrigée et le test qui le prouve. Une erreur qui disparaît après un redémarrage ne clôt rien.

Nettoyage (sessions de plus de sept jours seulement ; incidents ouverts, journaux systemd, `state/`, Borg et rapports de certification jamais touchés) :

```bash
python3 scripts/maintenance/weekly-log-cleanup.py            # simulation
python3 scripts/maintenance/weekly-log-cleanup.py --apply    # supprime les sessions éligibles
```

Activation hebdomadaire facultative (lundi 03:00, rattrapage avec `Persistent=true`), si le dépôt est dans `~/FEDORA_GNOME_CUSTOM` ; sinon adapter `ExecStart` et `ConditionPathIsDirectory` :

```bash
mkdir -p ~/.config/systemd/user
cp systemd/user/fgc-weekly-log-cleanup.{service,timer} ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now fgc-weekly-log-cleanup.timer
```

## Avant de demander de l'aide

Joindre toujours le commit (`git rev-parse HEAD`), `/etc/os-release`, `uname -a` et la sortie de `./diagnostic.sh`. Selon le domaine, ajouter `./diagnostics/graphics-doctor` et `display-doctor`, `./diagnostics/virtualization-doctor` et `./control.sh kvm guard-check`, ou le rapport de `./scripts/collect-boot-failure.sh`. Relire avant de publier : ni mot de passe, ni clé privée, ni jeton.

## Un contrôle GitHub Actions devient rouge

Trouver la première cause, pas masquer le job final :

1. Ouvrir le workflow rouge pour le **SHA exact**, et l'**étape** précise qui échoue.
2. Lire journaux et artefacts : réseau, dépendance RPM, exception, coredump, état des VM.
3. Distinguer un défaut fonctionnel d'une rupture externe (registre, CDN, miroir), ou d'un test instable : relancer ne suffit pas, il faut trouver la course.
4. Corriger sur une branche, faire passer les contrôles, fusionner, puis vérifier les checks du **push** sur `main` (autre SHA que la PR).

| Symptôme | Cause déjà vue | Réflexe |
|---|---|---|
| `toomanyrequests` à l'initialisation des conteneurs | registre limité | images Fedora depuis `registry.fedoraproject.org` |
| `Cannot download openh264` | dépôt Cisco injoignable depuis le runner | isoler ce dépôt s'il n'est pas requis, sans retirer de paquet requis |
| coredump dans `fedora-gnome-vm / lab` | crash ou blocage GNOME/Mutter | lire GDM, Wayland/XWayland, unités utilisateur, `systemd-coredump` |
| `Tests / contracts` rouge | une dépendance a échoué ou été sautée | corriger le job amont ; `contracts` reste fermé par défaut |

Ne jamais désactiver `journal_health`, retirer une assertion bloquante, ajouter `|| true` ou ignorer un coredump. Voir [CI](CI_VALIDATION.md) et le [laboratoire Fedora/GNOME](FEDORA_GNOME_CI_LAB.md).
