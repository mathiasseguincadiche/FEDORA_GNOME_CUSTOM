# Dépannage

Ce guide part d'un **symptôme**. Méthode : observer, diagnostiquer, corriger le minimum, puis revalider. Commencer par l'état réel :

```bash
./control.sh status
./control.sh doctor all
```

Chaque ligne `KO` nomme le contrôle en échec. Corriger le **premier** défaut réel, pas le dernier message.

**À ne jamais faire** : désactiver SELinux ou firewalld ; supprimer les règles nftables KVM ; ajouter `force_probe`, ou forcer ASPM, APST, C-States ou un mode de veille sans preuve ; reformater `/data` ; `chmod 777` ; éditer ou recréer un marqueur de preuve à la main ; modifier une configuration avant d'avoir conservé les journaux.

Machines virtuelles : voir le [dépannage KVM](KVM_QUICKSTART.md#dépannage).

## Installation et APPLY

**`install.sh --apply` refusé.** C'est une protection, pas une panne. Vérifier :

```bash
git status --short
./diagnostics/baseline-doctor status
./install.sh --dry-run
./prepare-preapply-backup.sh
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

**Polices ou affichage dégradés après veille.** Ne pas toucher Fontconfig en premier. `./diagnostics/display-doctor`, puis `./repair.sh display`, qui réapplique 2560×1440/~240 Hz, échelle 1.0, SDR et RGB complet, et seulement sur l'EDID certifié connecté à la B580.

**EDID attendu absent ou plusieurs écrans.** `./diagnostics/display-doctor`, `cat ~/.config/fedora-gnome-custom/display-certified.env`. Un écran réellement remplacé impose de refaire la baseline. La capture initiale exige un seul écran cible : débrancher les écrans secondaires pendant la certification.

**Réveil de veille incorrect.** `./diagnostics/suspend-doctor`, `./diagnostics/usb-resume-doctor`, `cat /sys/power/mem_sleep`, `journalctl -k -b | grep -Ei 'xe|drm|xhci|usb|nvme|AER|PCIe|ACPI'`. Ne forcer `deep`, `s2idle`, ASPM ou APST qu'après reproduction et analyse. Après correction, enregistrer de nouveaux cycles (`./control.sh validate gate3 record-suspend`).

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

**Wi-Fi identity lock en KO.** `lspci -Dnnk | grep -A4 -Ei 'Network controller|Wireless'`. Le verrou porte sur le PCI ID et le pilote, pas l'adresse PCI. Ne réenrôler (`./diagnostics/baseline-doctor enroll-wifi`) qu'après avoir compris le changement.

**Ventilateurs ou capteurs (NCT6687D-R).** Seul le pilote Fedora `nct6683`, en lecture seule, est autorisé ; le BIOS garde le contrôle des ventilateurs. `lsmod | grep nct6683`, `sensors`. Si le pilote refuse la carte (`sudo dmesg | grep -i nct6683` signale un *customer ID* non supporté), et seulement dans ce cas : `HARDWARE_NCT6683_FORCE="true"` dans `config/local.conf`, puis `./control.sh install apply`. Retour arrière : remettre `false`, supprimer `/etc/modprobe.d/fedora-gnome-custom-nct6683-force.conf` et recharger le module. `msi_fan_brute_force` et les modules tiers restent refusés. Sans tachymètre vivant, vérifier d'abord les branchements CPU_FAN/PUMP/SYS_FAN et les RPM dans le BIOS.

**T705 négocié en x2 ou sous PCIe 5.0.** `./diagnostics/storage-doctor`, `sudo nvme list`, `lspci -tv`. Attendu : x4 et ≥ 32 GT/s pour chacun. Vérifier le slot M.2, le partage de lignes PCIe et l'UEFI ; ne pas désactiver ASPM ou APST par réflexe.

**SMART T705 en KO.** `sudo nvme smart-log /dev/nvme0 -o json`, puis `journalctl -k -b | grep -Ei 'nvme|PCIe Bus Error|AER'`. Bloquants : `critical_warning` non nul, `media_errors` non nul, réserve sous le seuil, usure anormale, température critique, reset ou erreur I/O, erreur PCIe non corrigée. `num_err_log_entries` seul est historique : le corréler avec le journal courant.

## Noyau

État : `./control.sh kernel status` et `./control.sh kernel doctor`. Politique : [Linux amont](UPSTREAM_LINUX.md).

**Nouveau N installé mais démarrage sur N-1.** `./control.sh kernel install-latest`, puis redémarrer. Pendant une mise à jour offline, `./control.sh update finalize` remet N par défaut et demande un redémarrage si besoin. Aucun noyau n'est supprimé tant que N n'a pas démarré.

**Régression sur N.** `./control.sh kernel rollback` choisit N-1 comme défaut sans supprimer N. Recertifier l'état retenu si la matrice a changé.

**Ni N ni N-1 ne démarrent.** Au démarrage, maintenir **Maj** ou appuyer sur **Échap** pour afficher GRUB (Fedora l'affiche aussi après un démarrage raté), puis choisir l'entrée Fedora sans `vanilla`. Une fois connecté : `./control.sh kernel fallback` en fait le défaut sans rien supprimer. Retour au dernier amont : `./control.sh kernel install-latest`. Retour complet aux paquets Fedora : `./control.sh kernel rollback-fedora`.

**Trop de noyaux installés.** `rpm -q --qf '%{NAME}\t%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core | sort -V`. Attendu : au plus deux noyaux amont et un noyau Fedora de secours. `./control.sh kernel prune` retire les versions exactes en trop ; le noyau démarré est protégé : redémarrer sur N puis relancer.

**Transaction DNF offline en attente.** `./control.sh update status`, `./control.sh update reboot`, puis `./control.sh update finalize` après le redémarrage.

**Certification `STALE`.** `./diagnostics/software-matrix-doctor diff` montre ce qui a changé. Lancer les doctors concernés, puis recertifier ; ne jamais recréer les marqueurs.

## Données `/data` et Gaming

Contrat : `/data` est l'EXT4 du second T705, avec `Documents`, `Projets`, `ISO`, `Jeux` et `IA/Openclaw` en `0750`, label `user_home_t`, et `libvirt` en `virt_image_t`. `Documents` est aussi le dossier XDG Documents. Le projet ne formate ni ne partitionne jamais ce disque.

**`/data` absent ou mauvais système de fichiers.** `findmnt -n -T /data -o SOURCE,FSTYPE`, `lsblk -f`, `./control.sh doctor data`. Restaurer le montage du disque existant, sans formater. Après une réinstallation : `./diagnostics/baseline-doctor storage-identity`, puis `enroll-data NUMERO_DE_SERIE` ; deux partitions d'un même NVMe sont refusées.

**Dossier absent, propriétaire, mode ou label incorrect.** L'APPLY recrée les dossiers sans supprimer leur contenu. `stat -c '%U:%G %a %n' /data/*` et `ls -Zd /data/*`. Pour les labels, `sudo restorecon -RFv /data/Documents /data/Projets /data/IA/Openclaw /data/ISO /data/Jeux /data/libvirt`. Jamais de `chown -R` aveugle, ni de lien vers `/data/libvirt`.

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
python3 scripts/maintenance/weekly-log-cleanup.py --apply
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
| `Tests / contracts` rouge | une dépendance a échoué ou été sautée | corriger le job amont ; `contracts` reste fail-closed |

Ne jamais désactiver `journal_health`, retirer une assertion bloquante, ajouter `|| true` ou ignorer un coredump. Voir [CI](CI_VALIDATION.md) et le [laboratoire Fedora/GNOME](FEDORA_GNOME_CI_LAB.md).
