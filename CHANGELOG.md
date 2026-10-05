# Changelog

## 0.20.0 — Linux amont et préparation Fedora 45

- Retrait du noyau personnalisé et de ses réglages CPU/SELinux : canal Vanilla unique, dernière stable comparée à kernel.org, RC/linux-next/RPM obsolètes refusés.
- Rétention N/N-1 sur kernel-core ; sources officielles signées récupérables, sans prétendre qu'un téléchargement constitue une installation.
- Profils Fedora 44/50 et transition Fedora 45/51 avec blocage du futur profil tant que média final, archives GNOME 51 et preuves ne sont pas promus.
- Préparation et finalisation DNF5 system-upgrade avec sauvegarde Borg complète des VM arrêtées, identité commit/config et contrôle du boot réel.
- CI preview Fedora 45, inspection des archives d'extensions et rapports de dépendances explicites ; candidats distincts des verrous actifs.
- Contrôle de la clé Fedora et du couple nom/hash du CHECKSUM signé ; installation neuve paramétrée par release.
- Documentation, README, ADR et tests alignés. Qualification physique et promotion Fedora 45 restent à réaliser.


## 0.19.1 — 2026-10-01

- Laboratoire Fedora 44/GNOME 50 sur runner GitHub : image signée et verrouillée, session Wayland réelle, extensions épinglées, Nautilus/Ptyxis et redémarrage avec identifiant de boot distinct.
- Reprise isolée d'une VM QEMU sauvegardée à froid par le vrai Borg non chiffré : disque autonome, NVRAM et état swtpm comparés, démarrage en réseau restrict=on et canary TPM NV persistant.
- Reconstruction depuis une seconde image Fedora neuve avec réinstallation GNOME, extraction de l'archive de fichiers exacte en staging et contrôle contenu/modes/liens.
- Le contexte obligatoire contracts vérifie explicitement, même après un échec, que tous les jobs ont réussi ; les skips/annulations ne peuvent devenir un succès requis. La suite rapide démarre sans attendre les VM. Il attend le laboratoire ; les rapports conservent journaux et états DEFERRED pour les gates officielles, APPLY de production, CachyOS et Windows.
- Guides alignés sur CachyOS BORE, couverture des disques VM et runbook de reprise isolée. La qualification visuelle VirtualBox et matérielle reste à exécuter.

## 0.19.0 — 2026-10-01

- Journaux noyau : lecture complète avant recherche ; erreur de lecture, journal vide et erreur de recherche bloquent les PASS CPU/NVMe/GPU/veille/USB.
- Borg reste sans chiffrement. Tout avertissement de création bloque le succès ; une tentative quotidienne échouée invalide le précédent marker et expose son échec au diagnostic.
- Pré-APPLY et backup complet vérifient l'archive exacte. Le backup complet restaure son canary et enregistre une preuve atomique liée au commit, à la configuration, au matériel et au dépôt. La certification réouvre l'archive et son manifeste.
- Reprise OS/VM basée exclusivement sur une archive complète avec manifeste de récupération, commit et couverture VM explicites. Contrôle d'espace avant la capture système, les disques VM et l'écriture au dépôt ; option `--staging-root`.
- Le check obligatoire `contracts` dépend désormais de l'audit Fedora et du roundtrip Borg Fedora 44. L'audit refuse les blocages inattendus ; la publication attend les workflows réussis du SHA exact sur main.
- Nouveaux tests de journaux, certification/restauration/capacité et portes CI ; documentation de la qualification GNOME, récupération isolée et matériel encore à réaliser sur machine.


## 0.18.1 — 2026-09-27

- **Porte d'APPLY testée par son comportement** : nouveau `tests/test_apply_gate_behavior.sh`, exécuté dans un vrai pseudo-terminal. Chaque condition bloque seule, avec son propre message (runtime non bare-metal, fonction désactivée, machine non approuvée, Git modifié, baseline absente, archive Borg pré-APPLY absente, absence de terminal). La preuve de dry-run est vérifiée avec la vraie bibliothèque de preuves : un changement de commit, de configuration ou de matériel la rend caduque. Seule la phrase exacte ouvre la porte.
- Qualité du test prouvée par mutation : supprimer la vérification du terminal, celle de la sauvegarde, celle de la phrase de confirmation ou celle de l'empreinte de configuration fait échouer le test.

## 0.18.0 — 2026-09-27

- **Sauvegardes sans chiffrement, par décision du propriétaire** (ADR 0014) : Restic chiffre toujours ses dépôts et ne pouvait pas respecter cette exigence. Le moteur devient **Borg 1.x** (`borgbackup`, 1.4 sur Fedora 44) avec un dépôt `--encryption=none`. Un dépôt chiffré est désormais **refusé** par la politique.
- Moteur centralisé : tous les appels Borg passent par `backup_engine_*` dans `lib/backup_runtime.sh` (environnement, création, dernière archive, correspondance exacte, contrôle, extraction, rétention, compactage). Archives `fgc-preapply-*`, `fgc-full-*`, `fgc-daily-*`.
- Pré-APPLY : création confirmée du dépôt, archive relue intégralement (`borg check --verify-data`), canary réellement extrait et comparé ; le marker enregistre nom **et** identifiant de l'archive, revérifiés avec le type attendu au moment de l'APPLY.
- Rétention `borg prune` par classe (`full`, `daily`) puis un seul `borg compact` ; les archives pré-APPLY ne sont jamais supprimées automatiquement. Timer renommé `fedora-gnome-backup-retention` ; les anciennes unités Restic sont désactivées et supprimées par l'APPLY.
- Correctif trouvé en testant : sur un dépôt chiffré, Borg attendait indéfiniment une passphrase. Une passphrase vide explicite le fait échouer immédiatement ; une `BORG_PASSPHRASE` ambiante n'atteint jamais Borg.
- Avertissements Borg (code 1, fichier modifié pendant la lecture) signalés sans invalider l'archive ; codes ≥ 2 = échec.
- Configuration : `BACKUP_ENGINE="borg"`, `BACKUP_ENCRYPTION="none"`, clés `BACKUP_KEEP_*` et `BACKUP_RETENTION_*` ; plus aucun fichier de passphrase. Restauration par nom d'archive (ou `latest`), nom malformé refusé.
- Nouveau test réel `tests/test_borg_roundtrip.sh` (runtime installé, `--verify-data`, permissions, lien symbolique, exclusion des secrets, rétention, preuve pré-APPLY exacte, refus d'un dépôt chiffré) ; garde-fous de tests adaptés à Borg.
- Documentation : ADR 0014, guide de sauvegarde réécrit, une vingtaine de documents alignés ; ADR 0002/0009/0011/0012 annotées.

## 0.17.0 — 2026-09-27 (audit croisé Claude + ChatGPT)

Version de consolidation : intègre les PR #69 et #71 (ChatGPT), corrige leurs échecs de CI et leurs interactions, et ajoute une relecture indépendante. Détail et preuves : `docs/AUDIT_RUNTIME_2026-09-27.md`.

Moteur (PR #71, relu et conservé) :

- **Correctif critique** : une phase de module appelée dans un `if` désactivait `set -e` ; une commande pouvait échouer en plein APPLY sans faire échouer le module. Chaque module tourne désormais dans son propre processus Bash strict (`scripts/engine/run-module.sh`) ; un `exit 0` prématuré est un échec.
- Verrou d'installation par utilisateur ; `--dry-run --collect-all` visite les 72 modules sans jamais émettre de preuve d'APPLY ; CI « Fedora 44 installer audit ».
- Références des extensions GNOME centralisées dans `config/gnome-extensions.lock` (constantes non surchargeables dans `local.conf`) et installateur unique ; compatibilité GNOME validée sur le champ `shell-version` réel (plus de faux positif « 50 n'importe où »).
- Lecture complète des journaux noyau avant recherche d'erreurs CPU/NVMe (plus de faux « aucune erreur » par SIGPIPE ou journal illisible) ; manifestes de paquets manquants refusés ; restaurations confinées à la zone de staging.

Consolidation et relecture (Claude) :

- CI de la PR #71 réparée : `non-regression.yml` cherchait encore des clés déplacées dans le lock ; le conteneur Fedora refusait Git (*dubious ownership*), ce qui faisait échouer `backup.daily` — reproduit puis corrigé (`safe.directory`).
- Fusion de la PR #69 : 8 conflits résolus. Lanceur de #71 conservé (celui de #69 relançait tout le démarrage pour chaque module et dispersait les journaux) ; protections d'erreur de #69 intégrées au canal noyau CachyOS.
- Interaction corrigée : le confinement des restaurations (#71) cassait le test Restic réel de #69.
- Verrou étendu à la mise à jour, au cycle de vie noyau (sauf `status`), au pré-APPLY et aux sauvegardes ; réentrance réservée aux vrais descendants du détenteur (un PID copié ou forgé est refusé).
- Postchecks mémoire et veille : ne renvoient plus un échec quand une information facultative est illisible. La vitesse RAM configurée est comparée aux **6000 MT/s** du kit (avertissement si le profil EXPO/XMP est désactivé).

PR #69 — fiabilité après audit :

- Correction des faux PASS du moteur, prérequis manquants, sorties noyau et preuves périmées.
- Sauvegarde liée à la configuration, restauration vérifiée et couverture NVRAM/TPM.
- Identification PCI, fio non privilégié, réseau par interface et disque Kickstart stable.
- Reprise écran préservant la disposition et HDR ; nouveaux tests comportementaux et Restic réel.
- Parcours d’installation vierge et qualification physique explicitement distincts des preuves CI.

## 0.16.0 — 2026-09-26

- **Vrai noyau CachyOS** : nouveau canal `KERNEL_CHANNEL="cachyos"` (défaut Golden) basé sur le COPR officiel `bieszczaders/kernel-cachyos` (BORE, sched_ext, x86-64-v3). Le canal `vanilla` reste disponible. Jusqu'ici la couche « Fedora-Cachy » ne faisait que du réglage runtime : le noyau restait Kernel Vanilla (ADR 0012).
- Garde-fous CachyOS avant toute mutation : CPU `x86-64-v3` prouvé par le chargeur dynamique, accord explicite `KERNEL_CACHYOS_SELINUX_MODULE_LOAD` pour `domain_kernel_load_modules`, motif de dépôt excluant `-addons`/`-lto`/`-lts`/`-rc`.
- Le `kernel-core` Fedora reste installé comme entrée de secours ; `rollback-to-fedora.sh` désactive aussi le COPR CachyOS et remet un noyau Fedora par défaut.
- kernel-doctor, politique GRUB, Control Center et état `rolling.env` indiquent le canal actif. Correction du défaut affiché `Fedora fallback true` alors que la politique est `false`.
- **Finition « Ubuntu-grade »** : nouveau module `gnome.polish` et `config/gnome-polish.conf` — dock Ubuntu (gauche, pleine hauteur, focus/réduire/aperçus), démarrage sur le bureau, accent, jour dans l'horloge, fenêtres centrées, `adw-gtk3` avec suivi clair/sombre automatique, Tiling Assistant v55 épinglé par URL GitHub et SHA-256 (ADR 0013).
- Nouveau `diagnostics/polish-doctor`, intégré au workstation doctor et à `./control.sh doctor polish` ; APPLY, postcheck et doctor partagent une seule table d'état désiré.
- **Tests comportementaux** : `test_kernel_channel_behavior.sh` et `test_gnome_polish_behavior.sh` exécutent le vrai code contre de faux `dnf5`/`rpm`/`gsettings` au lieu de chercher du texte. Ils ont révélé un bug réel : la détection `x86-64-v3` pouvait échouer aléatoirement (`grep -q` + `pipefail` → SIGPIPE).
- Garde-fou CI : tout `tests/test_*.sh` doit être exécuté par un workflow.
- Schéma de configuration : énumérations ajoutées pour le canal noyau, l'accent, la position et le clic du dock.
- **Correctif critique** : trois modules applicatifs (`applications.professional`, `applications.appimage`, `applications.dock_favorites`) définissaient des fonctions dont le nom ne correspondait pas au contrat de l'orchestrateur ; le premier APPLY réel se serait arrêté sur « contract missing ». Nouveau test `test_module_catalog_behavior.sh` qui source chaque module du catalogue réel.
- **Soin de l'écran QD-OLED** (fiche matérielle) : dock en *intellihide*, style sombre appliqué une seule fois (le choix clair/sombre de l'utilisateur n'est jamais réimposé ni signalé comme dérive), assombrissement puis veille écran à 5 min ; lissage de police en niveaux de gris confirmé.
- Documentation du disque de sauvegarde XS1000 comme cible Restic externe (ext4 requis).
- **Préparation Fedora 45 / GNOME 51** : nouvel outil lecture seule `scripts/development/release-readiness.sh` (COPR noyaux, extensions GNOME, Tiling Assistant, paquets Fedora ; `--pin` produit les lignes SHA-256 prêtes à copier), rapport CI hebdomadaire, test comportemental et runbook `docs/UPGRADE_FEDORA_45.md`. Aucune bascule tant que Fedora 45 n'est pas finale et que tous les composants ne sont pas `READY`.
- Documentation : les comptes rendus d'étapes passées (`PRE1_HARDENING`, `INDUSTRIAL_READINESS`, `HARDWARE_KVM_COMPLETION`) sont rangés dans `docs/history/`, non normatifs.
- Passage du projet à **0.16.0** et préparation de la prerelease `v0.16.0-rc.1`.

## 0.15.0 — 2026-09-19

- **Fedora-Cachy coherence closure** : promotion de la couche performance en socle opérateur de première classe, sans modifier les garde-fous Fedora/GNOME/SELinux/KVM.
- Ajout d'un menu interactif **Performance Fedora-Cachy** au Workstation Control Center et d'un état performance visible dans le tableau de bord.
- Le profil performance conserve AMD P-State/EPP, TuneD/tuned-ppd, zram Fedora, GameMode dynamique, SCX fail-safe et le benchmark T705 borné ; aucun tuning global expérimental n'est activé par défaut.
- `performance-doctor --certify` exige le profil Golden normal avant une certification finale et conserve SCX en capacité optionnelle tant que le smoke test bare-metal n'a pas réussi.
- La certification Gate 3 et son contrôle live intègrent désormais explicitement le contrat performance ; un drift performance invalide l'état runtime Golden.
- Les cycles suspend/resume revalident le socle CPU/TuneD afin de détecter une dérive de politique d'alimentation après reprise.
- Le bundle Golden embarque désormais `performance-runtime.policy`, son SHA-256 et un bloc `performance_runtime` dans `golden-release.json`.
- Le tableau de bord valide également `effective_config_sha256` et `module_plan_sha256`, évitant d'afficher une ancienne certification comme valide après une modification de configuration ou de politique.
- Documentation, Control Center, contrats CI, release manifest et version projet sont réalignés sur la même surface Fedora + finition workstation + performance mesurée.
- Passage du projet à **0.15.0** et préparation de la prerelease `v0.15.0-rc.1`.
## 0.14.0 — 2026-09-03

- **Final Hardening / Release Candidate** : fermeture des écarts pré-1.0 sans ajout d'un nouveau socle fonctionnel.
- Runtime fail-closed : un environnement dont le bare-metal n'est pas positivement prouvé devient `unknown` et ne peut pas ouvrir l'APPLY.
- Orchestrateur durci : chaque module doit fournir `precheck`, `plan`, `apply` et `postcheck`; un APPLY en échec conserve son code retour et produit un rapport durable de convergence partielle.
- Correction Arc B580/VA-API : le render node est résolu par PCI `8086:e20b` au lieu de supposer `/dev/dri/renderD128` sur un HOST multi-GPU.
- Nautilus est séparé du GNOME core et complété par un manifeste dédié : GVfs archive/AFC/GOA/NFS, SMB/MTP déclaratifs, Sushi et `file-roller-nautilus`.
- Ajout de `nautilus-integration-doctor`, distinct du benchmark cold-start, intégré au postcheck, au workstation doctor et à la certification finale.
- Les flags `NAUTILUS_ENABLE_SMB`, `NAUTILUS_ENABLE_MTP` et `NAUTILUS_ENABLE_PREVIEWS` pilotent désormais réellement la convergence attendue.
- Le workaround historique `ibus-typing-booster` est déplacé hors de Nautilus et désactivé par défaut ; il reste un escape hatch explicite dans l'intégration desktop.
- Ajout de `ptyxis-doctor` afin de certifier séparément le terminal Fedora natif et la couche Bash ; Toolbx reste hors du HOST Golden par défaut.
- Ajout du workflow **Fedora 44 desktop integration pretest** pour installer et valider réellement Nautilus/GVfs/Sushi/File Roller/Ptyxis dans Fedora 44.
- Le contrôle `check-main-protection.sh` valide désormais le ruleset effectif, le ciblage de `main`, les required checks et la politique merge-only au lieu de se fier au seul booléen legacy `branch.protected`.
- DING review `74408`, Show Desktop Plus review `70326` et Resource Monitor review `70909` sont vérifiés par SHA-256 exact avant installation.
- Backup quotidien et rétention Restic exécutés depuis un bundle autonome versionné par SHA et vérifié par manifeste; timer hebdomadaire 7 daily / 4 weekly / 6 monthly sur les snapshots `full` et `daily`.
- Kickstart : serveur `sshd` HOST désactivé, `openssh-clients` conservé pour les connexions HOST → VM.
- Guard KVM étendu aux routes IPv4 non-default du HOST afin de bloquer LAN, VPN, réseaux d'entreprise et tunnels routés tout en conservant la sortie Internet via la route par défaut.
- Les Flatpaks `community-unverified` doivent être présents dans une allowlist versionnée explicite.
- Service KVM nftables renforcé avec sandbox systemd et capacités réseau bornées.
- Choix Golden confirmés : pas de LUKS imposé, pas de Secure Boot HOST, `kernel-vanilla/stable` latest-stable avec kernels Fedora conservés comme fallback.
- Ajout de `SECURITY.md`, `CODEOWNERS`, d'un template de PR et de contrats comportementaux supplémentaires pour le hardening.
- Ajout d'un schéma de configuration strict, validé avant sourcing, avec refus des clés inconnues, types invalides, doublons et syntaxe exécutable.
- Préparation de la prerelease GitHub `v0.14.0-rc.1` via manifeste et workflow idempotent; politique de dépôt cible: merge commit unique et suppression automatique des branches fusionnées.
- Documentation synchronisée avec Nautilus/Ptyxis, Resource Monitor, la supply-chain GNOME, la rétention Restic et la portée LAN/VPN du guard KVM.

## 0.13.0 — 2026-09-01

- Ajout du **Workstation Control Center** avec `control.sh` comme point d'entrée opérateur recommandé et `menu.sh` conservé comme alias de compatibilité.
- Remplacement du menu plat historique par neuf socles lisibles : Installation & convergence, Mises à jour, Sauvegarde & restauration, Diagnostics & santé, Kernel & boot, KVM / machines virtuelles, Maintenance, Certification, Logs & preuves.
- Ajout d'un tableau de bord terminal affichant version, Fedora, runtime, kernel actif, politique `kernel-vanilla/stable latest-stable`, Arc B580/driver, état Git, backup, certification, KVM et besoin de reboot.
- Ajout d'une présentation ANSI limitée aux vrais TTY avec support `NO_COLOR=1`; aucune dépendance TUI externe n'est introduite.
- Ajout d'un mode CLI scriptable (`control.sh install|update|backup|doctor|kernel|kvm|cert|logs`) conservant les codes de retour des moteurs appelés.
- La couche UI reste volontairement mince : aucune logique `apply_gate_open`, Restic, DNF, Flatpak ou nftables n'est dupliquée dans `control.sh`/`lib/control_center.sh`.
- Ajout de `scripts/maintenance/update-system.sh` pour les mises à jour quotidiennes structurées.
- La mise à jour complète sécurisée exige un runtime bare-metal, réalise un backup Restic complet et son contrôle d'intégrité avant `dnf upgrade --refresh`, met ensuite à jour les Flatpaks, consulte fwupd en lecture seule puis exécute le diagnostic global et indique le besoin de reboot.
- Le firmware n'est **jamais flashé automatiquement** par le nouvel updater ; seule `fwupdmgr get-updates` est utilisée dans le parcours automatisé.
- La politique kernel reste inchangée : `kernel-vanilla/stable` suit la dernière stable upstream, plancher actuel `7.2.2`, kernel Fedora conservé comme fallback ; aucune branche `mainline`, `-rc` ou `linux-next` n'entre dans le Golden.
- Ajout de `docs/CONTROL_CENTER.md`, mise à jour du portail documentaire et du README pour faire du cockpit l'interface opérateur principale.
- Ajout de `tests/test_workstation_control_center_contract.sh` et extension des contrats entrypoints/documentation afin d'empêcher toute régression vers un cockpit monolithique ou un contournement des moteurs protégés.

## 0.12.0 — 2026-09-01

- Ajout de **Desktop Icons NG (DING)** au profil fonctionnel Golden depuis l'artefact GNOME Extensions review `74408` / version de site `95`, UUID `ding@rastersoft.com`, déclaré compatible GNOME Shell 50.
- Fedora 44 ne fournit pas DING dans le manifest RPM du projet ; l'installateur dédié valide l'URL pinée, l'UUID, la compatibilité GNOME 50, compile le schéma GSettings et enregistre la provenance.
- Le dossier XDG Desktop est convergé vers `~/Bureau` ; son contenu devient visible sur le fond d'écran GNOME.
- La **Corbeille** est affichée sur le bureau ; Home, volumes externes et volumes réseau sont masqués par défaut afin de garder une surface de travail propre.
- Ajout de **Show Desktop Plus** depuis l'artefact GNOME Extensions review `70326` / version de site `8`, déclaré compatible GNOME Shell 50 ; l'installateur valide l'UUID et la compatibilité avant installation et enregistre la provenance.
- Show Desktop Plus est configuré en `left-end` dans la barre supérieure, clic gauche `toggle-desktop`, `Super+D` activé, badge de fenêtres désactivé et comportement par workspace conservé.
- `gnome-doctor` certifie désormais DING, `~/Bureau`, la Corbeille, la provenance des deux extensions utilisateur et les réglages du bouton/raccourci.
- Ajout de `xdg-user-dirs` et `unzip` aux dépendances gérées requises par cette ergonomie.
- Le Fedora package preflight valide les deux artefacts GNOME-reviewed DING/Show Desktop Plus ; le Fedora host pretest les installe dans un utilisateur de test, compile leurs schémas et converge les GSettings.
- Ajout du contrat CI `test_desktop_ergonomics_contract.sh` et maintien d'exceptions externes étroites limitées aux deux installateurs GNOME-reviewed pinés.
- Ajout du **LAB GNOME VirtualBox fail-closed** : `scripts/lab/apply-gnome-virtualbox.sh` exige Fedora 44, GNOME Shell 50/Wayland et une identité VirtualBox concordante (`systemd-detect-virt=oracle` + DMI), puis ne converge que les boutons de fenêtres, DING et Show Desktop Plus.
- Ajout de `diagnostics/virtualbox-gnome-lab-doctor` et `tests/test_virtualbox_gnome_lab_contract.sh`; le doctor confirme aussi que `install.sh --apply` et la baseline hardware restent interdits/invalides en VirtualBox.
- La validation graphique finale DING + Show Desktop est explicitement réalisée au GATE 2 GNOME/VirtualBox puis confirmée bare-metal ; aucune preuve graphique n'est simulée en CI.

## 0.11.0 — 2026-08-31

- Refonte de la documentation opérateur : ajout de `docs/README.md` comme portail, `docs/GLOSSARY.md`, `docs/KVM_QUICKSTART.md` et `docs/KVM_NETWORK.md`.
- Transformation de `docs/TROUBLESHOOTING.md` en vrai runbook par symptôme couvrant APPLY, DNF/repos, Flatpak, codecs, GNOME/portals, Arc B580, veille/affichage, KVM/libvirt, `/data`, `devops-nat`, Ubuntu/Windows et Restic.
- Documents normatifs rendus version-neutral et reliés à `VERSION` afin d'éviter les références actives 0.8/0.9 devenues ambiguës ; les numéros historiques restent dans les release notes/changelog.
- Correction de la documentation GNOME : Dash to Dock **et AppIndicator** sont les deux extensions fonctionnelles gérées ; Blur My Shell reste hors de l'état Golden certifié.
- Suppression des anciennes commandes `baseline-doctor record-*` de la documentation WSL2.
- Ajout de draw.io au catalogue documentaire professionnel et clarification de la révision 1.7 du cahier des charges par rapport au numéro de release.
- Nettoyage de `GITHUB_GOVERNANCE.md` : suppression des limitations propres à un connector/outillage particulier et ajout d'un contrat documentaire public.
- Réseau KVM rendu réellement **fail-closed lors d'un changement de connectivité** : le dispatcher NetworkManager installe désormais un guard d'urgence synchronement avant tout reconcile ; si la redécouverte/validation du nouvel uplink échoue, le forwarding via `virbr50` reste bloqué.
- `fedora-gnome-custom-kvm-guard.service` utilise `reconcile` au start/reload avec retry `Restart=on-failure`; suppression du reload asynchrone `--no-block` et du `|| true` qui pouvait masquer un échec.
- `runtime_certification.sh` exige le service KVM guard actif, un reconcile réussi, `guard_mode=normal`, les règles nftables bidirectionnelles et la couverture de tous les CIDR uplink détectés.
- La preuve Ubuntu→LAN est renforcée : le gateway physique doit d'abord être prouvé joignable depuis le HOST avant que son injoignabilité depuis la VM soit considérée comme une preuve de blocage.
- La portée de sécurité du guard est documentée précisément : réseaux IPv4 directement connectés/uplink par défaut ; les routes/VPN additionnels devront être ajoutés explicitement s'ils doivent entrer dans le contrat futur.
- Ajout de `scripts/kvm/verify_ubuntu_cloud_image.sh` : empreinte Canonical cloud-image épinglée, vérification GPG de `SHA256SUMS`, puis SHA-256 de l'image avant création du disque Ubuntu.
- `create_ubuntu_devops_vm.sh` exige désormais l'authentification de l'image Canonical ; `gnupg2` est ajouté au socle KVM Fedora.
- `create_windows11_vm.sh` accepte `--windows-sha256` et `--virtio-sha256` afin de vérifier les médias lorsqu'un hash obtenu depuis une source de confiance indépendante est disponible ; sans hash, le script avertit explicitement que la provenance reste une responsabilité opérateur.
- Ajout des contrats CI `test_kvm_network_fail_closed.sh`, `test_vm_image_auth_contract.sh` et `test_documentation_contract.sh` ; le workflow `Tests` les exécute sur chaque push/PR.
- Le contrat documentaire vérifie notamment les commandes obsolètes, AppIndicator, draw.io, les invariants `devops-nat`, les liens Markdown locaux et la couverture minimale du troubleshooting.

## 0.10.0 — 2026-08-30

- Consolidation **pré-1.0** : priorité au durcissement, à la reproductibilité, aux preuves et à la cohérence de release.
- Intégration officielle de draw.io (`com.jgraph.drawio.desktop`) au catalogue professionnel, corrigeant l'ajout précédent non reflété dans `VERSION`/CHANGELOG.
- Détection runtime renforcée avec `systemd-detect-virt` : VM et conteneurs ne sont plus classés bare-metal par défaut.
- Le `--dry-run` est désormais décrit explicitement comme un **preflight non-mutant / plan de convergence**, sans prétendre simuler les transactions.
- La politique Kernel Vanilla exige réellement le `kernel-core` le plus récent disponible dans les dépôts activés, respecte `KERNEL_VENDOR_CHANGE_ALLOWED`, garde le plancher 7.2.2 et les kernels Fedora fallback.
- Nettoyage des clés de configuration mortes identifiées lors de l'audit pré-1.0 ; `DISPLAY_CERT_TOLERANCE_HZ` est maintenant réellement consommé.
- Les preuves Nautilus/suspend utilisent un fingerprint runtime incluant hardware, kernel, linux-firmware, firmware Intel GPU, Mesa, Mutter et GNOME Shell.
- `final-certification` exige désormais le socle KVM host lorsque KVM est activé.
- Réseau KVM explicitement IPv4-only : `KVM_IPV6_ENABLED=false` et activation IPv6 fail-closed tant qu'une isolation dual-stack équivalente n'est pas implémentée.
- Kickstart rendu déterministe : le SHA Git courant est incorporé et le `%post` fetch/checkout exactement ce commit ; aucun `git clone ... || true` permissif.
- VM Ubuntu : SSH key-only (`ssh_pwauth: false`), mot de passe runtime conservé pour console/sudo, suppression de `NOPASSWD:ALL`.
- Supply-chain Ubuntu : Kubernetes figé sur la génération v1.37.x, kind v0.33.0, Minikube v1.38.1 ; AWS CLI v2 installé depuis ZIP + signature détachée vérifiée avec la clé AWS officielle.
- Politique Flatpak explicite : mises à jour manuelles/utilisateur, aucun updater Flatpak silencieux créé par le projet.
- Ajout de `manifests/application-provenance.tsv` pour distinguer Fedora/vendor signé/Flathub vérifié/Flathub communautaire.
- Réduction des exemptions globales ShellCheck : SC2034 et SC2153 ne sont plus masqués globalement.
- Les prétests Fedora package, Fedora host et Ubuntu VM sont programmés chaque semaine en plus des déclenchements PR/push.
- Ajout de `docs/PRE1_HARDENING.md`, `docs/SUPPLY_CHAIN.md`, `docs/GITHUB_GOVERNANCE.md` et du contrôle manuel `scripts/development/check-main-protection.sh`.

## 0.9.3 — 2026-08-30

- Ajout d'une politique **Curated GNOME Dock** déterministe après installation des applications professionnelles.
- Ordre épinglé : Nautilus → Brave → Ptyxis → VS Code → Bitwarden → Slack → LibreOffice → GNOME Software.
- Remmina reste installé mais volontairement non épinglé.
- Ajout du script idempotent `configure-dock-favorites.sh` qui écrit et relit `org.gnome.shell favorite-apps`.
- Le module `applications.dock_favorites` valide les IDs, interdit les doublons, applique l'ordre et exige que les huit lanceurs `.desktop` soient réellement exportés.
- `applications-doctor` contrôle désormais l'ordre du dock et la présence des lanceurs ; il est ajouté à la certification bare-metal finale.
- Le Fedora 44 host integration pretest exécute la configuration réelle sous un utilisateur de test dans une session D-Bus et relit le GSettings persistant.
- Ajout du contrat CI `test_dock_favorites_contract.sh` et de `docs/DOCK_FAVORITES.md`.

## 0.9.2 — 2026-08-30

- Ajout de la couche **Fedora Host Bash UX** pour que Ptyxis ouvre directement un Bash professionnel et prêt à travailler sur l'OS hôte.
- Ajout des paquets Fedora officiels `bash-completion`, `fzf`, `zoxide` et `direnv`.
- Ajout d'un profil modulaire sous `~/.config/fedora-gnome-custom/bash/` avec historique, aliases, navigation, complétions et prompt séparés.
- Le `.bashrc` utilisateur n'est jamais remplacé : sauvegarde initiale `bashrc.pre-fgc`, puis bloc géré unique et idempotent.
- Historique étendu à 50 000/100 000 entrées, `histappend`, déduplication et synchronisation multi-terminal `history -a` / `history -n`.
- Prompt Bash natif deux lignes avec utilisateur/hôte, chemin, branche Git, état tracked modifié et code retour en erreur ; aucune commande réseau et aucun framework Starship/Oh My Bash.
- Ajout d'aliases DevOps courts pour Git, Docker Compose, Kubernetes et Terraform, sans alias destructif pour `rm`, `mv`, `cp` ou `sudo`.
- Les complétions de `gh`, `glab`, `kubectl`, `helm` et `minikube` sont générées uniquement si les binaires existent puis mises en cache.
- Ajout de `shell-doctor`, intégré à `workstation-doctor` et à la certification bare-metal finale.
- Le prétest Fedora 44 crée un utilisateur réel dans le conteneur, installe le profil Bash et exécute un smoke test interactif.
- Ajout de `docs/HOST_BASH_UX.md` et passage de la Golden Workstation en version 0.9.2.

## 0.9.1 — 2026-08-30

- Passage de la VM Ubuntu Server 26.04 au profil **Ubuntu DevOps Ready** : objectif `clone → build/test → containerize → deploy` dès le premier login après bootstrap.
- Ajout de GitLab CLI `glab` en complément de Git/Git LFS et GitHub CLI.
- Ajout de Node.js 22 LTS, npm et Corepack pour les projets Angular/JavaScript.
- Ajout d'OpenJDK 21 et Maven pour les projets Java/Spring.
- Ajout de Minikube avec Docker comme driver par défaut, en complément de kind, kubectl et Helm.
- Ajout de K9s, kubectx/kubens et du binaire Go `yq` v4.
- Minikube vérifie le checksum publié de sa release ; `yq` v4.53.3 et K9s v0.51.0 sont épinglés avec SHA-256 attendu. Aucun `curl | bash` n'est introduit.
- `verify-devops.sh` certifie les nouveaux outils, les versions minimales Node/OpenJDK, le driver Minikube et conserve les contrôles Docker/QEMU Guest Agent.
- Le vrai prétest Ubuntu 26.04 compile/exécute un programme Java, exécute Node, vérifie Docker Compose, GitLab CLI et les outils Kubernetes, puis exige leur persistance après reboot.
- Ajout de `docs/UBUNTU_DEVOPS_READY.md` et passage de la Golden Workstation en version 0.9.1.

## 0.9.0 — 2026-08-30

- Ajout de la couche **Desktop & Lifecycle Completion** pour transformer la Golden Workstation en poste principal quotidien/professionnel, sans copier Ubuntu/Yaru ni multiplier les extensions cosmétiques.
- AppIndicator officiel Fedora activé et certifié en complément de Dash to Dock ; Blur My Shell reste désactivé par défaut.
- Intégration GNOME Keyring/Secret Service, CUPS/IPP-over-USB/Avahi/AirScan, VPN OpenVPN/OpenConnect, TuneD PPD, français/dictionnaires/polices, Remmina et support mobile/iPhone.
- Ajout du runtime Intel Arc Level Zero/OpenCL et d'`arc-compute-doctor`, qui exige l'énumération réelle de l'Arc B580.
- Ajout de `portal-doctor` pour certifier ScreenCast/FileChooser/OpenURI et Notification via xdg-desktop-portal/PipeWire/Wayland.
- Politique lifecycle DNF5 : téléchargement automatique autorisé, **installation automatique interdite**, **reboot automatique interdit**, avec `fstrim.timer` et refresh metadata fwupd.
- Ajout d'une sauvegarde utilisateur Restic quotidienne par timer systemd, chiffrée, sans prune silencieux et sans inclure la passphrase Restic ; absence du disque externe = skip propre, pas corruption du statut.
- Durcissement de la certification suspend/resume : un cycle physique ne peut être compté qu'une fois et le repair display doit être postérieur au hook de reprise correspondant.
- `display-doctor` vérifie désormais le `Current mode` réellement actif à 2560×1440 ~240 Hz.
- Restauration des preuves runtime KVM du garde réseau : table nft présente, gateway KVM joignable et LAN physique bloqué depuis Ubuntu lorsque la politique l'exige.
- Extension de la matrice known-good aux composants desktop/portal/power/compute et ajout du contrat CI `test_desktop_lifecycle_contract.sh`.

## 0.8.2 — 2026-08-30

- Ajout d'une politique GNOME explicite imposant les trois contrôles de fenêtre **Réduire / Agrandir / Fermer** à droite via `org.gnome.desktop.wm.preferences button-layout`.
- Le module GNOME applique `:minimize,maximize,close` de façon idempotente et refuse la validation post-APPLY si la valeur réellement enregistrée diffère.
- Ajout d'un contrat CI empêchant une régression silencieuse vers le comportement GNOME par défaut sans boutons Réduire/Agrandir.

## 0.8.1 — 2026-08-30

- Ajout explicite de `amd-ucode-firmware` pour le Ryzen 7 7700 et `intel-gpu-firmware` pour l'Arc B580, avec `firmware-doctor` et détection des échecs de chargement firmware.
- Certification de la MSI MAG B850M Mortar WiFi : Realtek 8126-VB/`r8169`/5000baseT, Wi-Fi 7 et 6 GHz détectés dynamiquement, Bluetooth, ALC4080 USB Audio/PipeWire et xHCI.
- Extension du hook suspend/resume aux contrôleurs réseau/audio/USB et ajout de `usb-resume-doctor` dans chaque preuve post-veille.
- Ajout d'une matrice known-good BIOS + kernel + linux-firmware/microcode + Mesa + Mutter + GNOME Shell + Nautilus + QEMU/libvirt, invalidée lors d'un changement de version jusqu'à recertification.
- Ajout du benchmark T705 KVM `io_uring` vs AIO natif, filesystem-safe, avec sélection persistante du meilleur backend ; `cache=none` et discard/unmap restent la base sûre.
- Ubuntu 26.04 et Windows 11 exposent désormais le channel QEMU Guest Agent, VirtIO RNG et balloon mémoire ; Windows expose aussi le channel SPICE.
- Ajout de `Configure-GuestIntegration.ps1` pour installer/certifier les drivers VirtIO et QEMU Guest Agent depuis l'ISO fourni par l'opérateur.
- `runtime_certification.sh` exige désormais la réponse `guest-ping` des deux VMs et valide les périphériques de virtualisation.
- Ajout du contrat CI `test_hardware_kvm_completion_contract.sh` et de la documentation `HARDWARE_KVM_COMPLETION.md`.

## 0.8.0 — 2026-08-30

- Ajout du profil **Golden Workstation** séparant baseline pré-APPLY et certification runtime post-APPLY.
- Ajout de Fedora Kernel Vanilla `@kernel-vanilla/stable`, plancher Linux `7.2.2`, contrôle Secure Boot fail-closed, `kernel-doctor` et rollback explicite vers les kernels Fedora.
- Conservation obligatoire des kernels Fedora déjà installés comme fallback de boot ; aucun retrait agressif de kernels.
- Remplacement des preuves RAM/NVMe déclaratives par des tests automatisés : `stress-ng --verify` à 5600/6000 et `fio` filesystem-safe avec CRC32C sur root + `/data`.
- Les preuves automatisées contiennent le SHA-256 de leurs logs ; root et `/data` doivent résoudre vers deux NVMe physiques distincts.
- Fingerprint renforcé : BIOS/UUID plateforme, CPU, GPU/driver, mémoire, serial/firmware NVMe et EDID disponible.
- La validation suspend/resume n'est plus un prérequis pré-APPLY : elle est déplacée après installation/reboot afin de ne pas bloquer l'installation des corrections qu'elle doit mesurer.
- Ajout d'un vrai benchmark **cold-start Nautilus** : processus absent au départ, mesure jusqu'à possession de `org.gnome.Nautilus`, cible 1200 ms et hard limit 2000 ms.
- Ajout d'un prewarm GNOME login limité à Portal/GIO ; Nautilus lui-même n'est jamais pré-démarré.
- Thumbnails Nautilus configurés `local-only` ; suppression optionnelle d'`ibus-typing-booster` pour réduire une dépendance de premier lancement non nécessaire à ce profil.
- Ajout du display recovery GNOME 50 via `gdctl` : 2560×1440, ~240 Hz, scale 1.0, SDR/default et Full RGB.
- Ajout d'un watcher user sur resume logind, `MonitorsChanged` de Mutter et hotplug/change DRM afin de réappliquer le display state après veille ou power-cycle écran.
- Ajout de `display-doctor`, capture `drm_info` et preuve de repair.
- Blur My Shell désactivé par défaut dans le profil Golden Workstation afin de réduire les variables du compositor à 240 Hz ; Dash to Dock reste activé.
- Ajout de `final-certification` exigeant kernel/GPU/display/GNOME sains, cold-start courant et cinq cycles suspend/resume post-APPLY avec repair récent.
- Ajout d'un générateur Kickstart Fedora 44 protégé ciblant uniquement le NVMe explicitement choisi ; aucune sélection destructive automatique de disque.
- Ajout des contrats CI Golden Workstation et mise à jour de la documentation GNOME/installation.

## 0.7.1 — 2026-08-27

- Hardening WSL2 et supply-chain : isolation runtime bare-metal/WSL2/CI, blocage APPLY/certification hors bare-metal, entrypoints contrôlés et GitHub Actions épinglées.

Voir l'historique Git antérieur pour les versions 0.1.0 à 0.7.0.
