# CI et validation bout-en-bout

La CI combine contrats statiques, intégration Fedora 44 et vraie VM Ubuntu 26.04. Elle complète les certifications sur la machine physique ; elle ne les remplace pas.

## Tests de contrats

`.github/workflows/tests.yml` valide notamment :

- structure et politiques hardware/GNOME ;
- applications et multimédia ;
- KVM/libvirt ;
- bootstrap Ubuntu ;
- accès VM ;
- backup/recovery ;
- gouvernance CI ;
- Bash UX et dock ;
- **Nautilus complet / GVfs / Sushi / File Roller** ;
- **Ptyxis natif et séparation terminal/Bash** ;
- **ergonomie desktop DING + Show Desktop Plus** ;
- **LAB GNOME VirtualBox fail-closed** ;
- durcissement pré-1.0 ;
- **fail-closed du guard KVM** ;
- **authentification de l'image Ubuntu** ;
- **cohérence documentation ↔ code/config**.

## Contrat documentaire

La documentation est testée comme une partie du produit.

La CI bloque notamment :

- retour d'anciennes commandes `baseline-doctor record-*` ;
- profil GNOME qui oublierait l'une des **cinq extensions fonctionnelles** : Dash to Dock, AppIndicator, Desktop Icons NG, Show Desktop Plus ou Resource Monitor ;
- documentation qui exclurait encore Desktop Icons alors que DING est désormais Golden ;
- disparition de `~/Bureau`, de la Corbeille ou de `Super+D` du contrat ergonomique documenté ;
- retour de l'ancienne affirmation selon laquelle Fedora 44 fournirait DING comme RPM ;
- disparition de draw.io du catalogue documentaire alors qu'il reste géré ;
- valeurs `devops-nat`/`virbr50`/CIDR incohérentes avec la configuration ;
- suppression du portail débutant/glossaire/runbook ;
- liens Markdown locaux cassés dans les documents inspectés ;
- réintroduction de notes publiques spécifiques à un connector/outillage de maintenance.

Ce test ne remplace pas la relecture éditoriale humaine, mais empêche les divergences factuelles déjà identifiées de revenir silencieusement.

## Nautilus et Ptyxis

`tests/test_nautilus_integration_contract.sh` protège :

- la séparation GNOME core / Nautilus ;
- le manifeste Files complet ;
- les backends SMB/MTP déclaratifs ;
- `NAUTILUS_ENABLE_PREVIEWS` et la politique de miniatures ;
- Sushi et l'intégration File Roller ;
- l'absence du workaround IBus dans le module Nautilus ;
- l'appel du doctor Nautilus par la certification finale.

`tests/test_ptyxis_contract.sh` protège :

- Ptyxis comme terminal Fedora natif ;
- le doctor terminal distinct de `shell-doctor` ;
- la certification finale de Ptyxis ;
- l'absence de Toolbx implicite dans le HOST Golden.

## Desktop ergonomics

`tests/test_desktop_ergonomics_contract.sh` exige :

- DING lié à l'artefact GNOME Extensions review `74408`, version de site `95`, GNOME Shell `50` ;
- absence de faux paquet `gnome-shell-extension-desktop-icons-ng` dans le manifest Fedora 44 ;
- `~/Bureau` comme dossier XDG Desktop ;
- Corbeille visible, Home/volumes externes/volumes réseau masqués ;
- Show Desktop Plus lié à l'artefact GNOME Extensions review `70326`, version de site `8`, GNOME Shell `50` ;
- UUID `show-desktop-plus@attentivecoder` ;
- bouton `left-end`, clic gauche `toggle-desktop`, `Super+D`, badge désactivé ;
- diagnostic GNOME et workflows Fedora couvrant ces invariants.

Cette CI valide configuration, provenance et schémas. Elle ne prétend pas prouver visuellement que les icônes sont rendues sur le framebuffer ou que plusieurs vraies fenêtres GNOME se masquent/restaurent : cette preuve appartient au GATE 2 VirtualBox puis au bare-metal.

## VirtualBox GNOME LAB

`tests/test_virtualbox_gnome_lab_contract.sh` protège le LAB GATE 2 :

- identité VirtualBox doublement validée par `systemd-detect-virt --vm = oracle` et DMI ;
- Fedora 44, GNOME Shell 50 et Wayland requis ;
- entrypoint limité aux modules GNOME settings/extensions ;
- dépendances système limitées à `curl`, `unzip`, `xdg-user-dirs`, `glib2` ;
- DING et Show Desktop Plus installés depuis leurs artefacts GNOME-reviewed pinés ;
- doctor LAB strictement read-only ;
- interdiction de charger l'orchestrateur complet ou les modules kernel/hardware/KVM/backup ;
- rejet dynamique de la CI avec code sécurité `50` ;
- confirmation par le doctor que `install.sh --apply` et la baseline bare-metal restent bloqués en VirtualBox.

La procédure normative est [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md).

## Shell quality

Tous les scripts suivis sont vérifiés par `bash -n` et ShellCheck.

Les exemptions globales sont limitées afin que les variables inutilisées et fautes de noms ne soient pas masquées à l'échelle du dépôt.

## Fedora 44 package preflight

Résolution des manifests, y compris les manifests Nautilus dédiés, RPM Fusion, dépôts VS Code/Brave, Flathub, swaps multimédia, extensions GNOME 50 et packages KVM, y compris GnuPG nécessaire à l'authentification d'image Ubuntu.

Pour l'ergonomie desktop, il télécharge et valide les artefacts GNOME-reviewed : DING review `74408`/version `95`, Show Desktop Plus review `70326`/version `8` et Resource Monitor review `70909`/version `28`. Le workflow contrôle les UUID, la compatibilité GNOME Shell 50 et les payloads attendus.

Ce workflow tourne sur push/PR et périodiquement afin de détecter une rupture externe sans commit.

## Fedora 44 desktop integration pretest

`.github/workflows/desktop-integration-pretest.yml` est un gate ciblé Files/terminal. Dans un conteneur Fedora 44, il :

1. installe réellement GNOME core, les manifests Nautilus base/optionnels et le catalogue GTK4 ;
2. exige les RPM Nautilus/GVfs/Sushi/File Roller/Ptyxis ;
3. vérifie le payload `file-roller-nautilus` pour l'API extensions-4 de Nautilus ;
4. vérifie le schéma Nautilus et l'énumération GIO dans une session D-Bus ;
5. exécute `nautilus --version` ;
6. vérifie la commande et le desktop entry Ptyxis ;
7. vérifie le schéma Ptyxis et `ptyxis --version`.

Ce workflow ne prétend pas mesurer le cold-start graphique réel ni la perception utilisateur. Ces preuves restent au GATE runtime.

## Fedora 44 host integration pretest

Dans un conteneur Fedora 44, installe réellement le contrat HOST/GNOME/KVM/backup, teste Bash UX et dock via un utilisateur normal, valide RPM Fusion, vendor RPM, Flathub et extensions.

Un utilisateur de test installe DING et Show Desktop Plus depuis leurs artefacts GNOME-reviewed, converge `~/Bureau` et les préférences, puis relit les GSettings et les marqueurs de provenance.

Ce workflow ne simule pas VirtualBox ou une session GNOME graphique : le LAB GATE 2 reste une preuve runtime distincte.

Il tourne aussi périodiquement.

## Architecture non-regression

Bloque notamment :

- ouverture du gate machine réelle ;
- confusion VM/conteneur avec bare-metal ;
- X11 comme contrat ;
- `force_probe` ;
- GPU passthrough ;
- VirtioFS HOST-share ;
- affaiblissement KVM ;
- flush firewall ;
- formatage dans les modules ;
- SSH guest par mot de passe ;
- installateur AWS non signé ;
- Kickstart non piné ;
- affaiblissement du backup fail-closed.

## KVM network fail-closed

Le contrat statique exige :

```text
mode emergency
        ↓
reconcile
        ↓
mode normal seulement après validation
```

Le dispatcher NetworkManager ne doit plus masquer un échec de reload avec `|| true` et ne doit pas lancer un reload asynchrone laissant une fenêtre où l'ancien LAN serait considéré encore valide.

La preuve runtime finale reste bare-metal.

## Authentification image Ubuntu

Le contrat exige :

- empreinte Canonical épinglée ;
- signature GPG de `SHA256SUMS` ;
- SHA-256 de l'image ;
- appel du verifier par le script de création ;
- politique activée dans `vm-profiles.conf`.

## Ubuntu 26.04 real VM pretest

Le workflow :

1. télécharge l'image Canonical ;
2. télécharge `SHA256SUMS` et sa signature ;
3. authentifie la liste ;
4. vérifie l'image ;
5. démarre une vraie VM QEMU (KVM si disponible, TCG sinon) ;
6. exécute le bootstrap exact ;
7. vérifie Docker/Node/Java/Kubernetes/cloud/IaC ;
8. redémarre pour tester la persistance.

Il tourne périodiquement afin de surveiller les dépôts externes et signatures.

## Ce qui reste runtime/physique

- rendu visuel réel DING et action Show Desktop dans une session GNOME complète (GATE 2 puis bare-metal) ;
- vrai cold-start Nautilus ;
- intégration périphériques réels MTP/AFC/GPhoto ;
- Arc B580/`xe` ;
- Level Zero/OpenCL réel ;
- GNOME/Wayland/display 240 Hz physique ;
- suspend/resume ;
- les deux T705 ;
- firmware/BIOS ;
- Secure Boot ;
- isolation LAN KVM réelle ;
- changement Ethernet/Wi-Fi réel ;
- second-host LAN → VM.

Voir aussi [`GITHUB_GOVERNANCE.md`](GITHUB_GOVERNANCE.md), [`NAUTILUS.md`](NAUTILUS.md), [`PTYXIS.md`](PTYXIS.md), [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md) et [`SUPPLY_CHAIN.md`](SUPPLY_CHAIN.md).
