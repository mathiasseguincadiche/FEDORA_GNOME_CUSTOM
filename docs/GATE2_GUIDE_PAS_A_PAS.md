# Gate 2 — Guide pas à pas (Fedora 44 GNOME sous VirtualBox)

Guide pratique pour réaliser la Gate 1 puis la Gate 2 depuis un PC Windows 11, sans risque pour Windows ni pour les disques. La procédure normative reste [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md) et [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md) : en cas de différence, ces deux documents font foi.

## À quoi sert la Gate 2

La Gate 2 prouve que le **bureau GNOME du projet fonctionne vraiment**, dans une machine virtuelle, avant de toucher au PC. C'est la répétition générale : on regarde le résultat à l'écran, en vrai, sans aucun risque pour Windows ni pour les disques.

Ce qu'elle prouve :

- Fedora 44, GNOME Shell 50 et la session Wayland démarrent et fonctionnent ;
- Nautilus, Ptyxis, les portails et les extensions du projet s'installent, s'activent et se comportent comme prévu ;
- les réglages tiennent après une déconnexion et un redémarrage ;
- **un humain** a regardé l'écran et valide ce qu'il voit.

Ce qu'elle ne prouve pas : rien du matériel réel. La B580, les T705, l'écran 240 Hz, la veille ou les températures restent marqués **EXPECTED** (« attendu, à prouver plus tard »). Ils sont vérifiés à la Gate 3, sur le vrai PC. C'est normal et voulu.

## Le parcours complet en 3 gates

La Gate 2 se place entre deux autres étapes. Chaque gate produit un petit fichier de preuve (JSON) que la suivante exige.

1. **Gate 1 — Fedora 44 dans WSL2, sous Windows.** Vérifie la logique du projet (tests, configuration, garde-fous). Produit `gate1-<commit>.json`.
2. **Gate 2 — Fedora 44 GNOME dans VirtualBox.** Vérifie le bureau réel et la validation visuelle. Exige la preuve Gate 1 et produit `gate2-<commit>.json`, qui contient l'empreinte exacte de la preuve Gate 1.
3. **Gate 3 — Fedora 44 installée sur le vrai PC.** Vérifie le matériel et délivre la certification finale. Exige les deux preuves précédentes.

La règle d'or : **les trois gates utilisent exactement le même commit Git.** Si le projet change entre deux gates, les anciennes preuves deviennent invalides et il faut les refaire. Le projet le vérifie tout seul : il refuse une preuve qui ne correspond pas.

## Avant de commencer

Prévoir **2 à 3 heures** la première fois, téléchargements compris. Tout se passe sur le PC Windows 11.

| Élément | Ce qu'il faut | Pourquoi |
| --- | --- | --- |
| WSL2 | Windows 11 à jour, droits administrateur | Gate 1 |
| Oracle VirtualBox | Version 7.1 ou plus récente | Gate 2 |
| Image Fedora 44 Workstation | Fichier `Fedora-Workstation-Live-44-1.7.x86_64.iso`, depuis fedoraproject.org | Installer la VM |
| Espace disque libre | Environ 80 Go | VM (60 Go) + WSL + téléchargements |
| Un dossier d'échange | `C:\GoldenValidation` | Faire passer la preuve Gate 1 dans la VM |

Deux points à connaître avant de se lancer :

- **WSL2 et VirtualBox cohabitent, mais VirtualBox ralentit.** WSL2 active l'hyperviseur de Windows (Hyper-V). VirtualBox fonctionne alors par-dessus, plus lentement, et affiche parfois une petite tortue verte en bas de la fenêtre. C'est attendu, et suffisant pour la Gate 2.
- **Une nouvelle version de Fedora invalide les preuves.** Si le projet passe sur Fedora 45 (ADR 0016), les gates devront être refaites. Faire la Gate 2 avant reste utile : c'est un entraînement réel, et elle peut révéler des défauts avant le jour J.

## Étape A — La Gate 1 sous WSL2

La Gate 2 exige la preuve de la Gate 1 : on commence donc par elle.

1. **Installer Fedora 44 dans WSL2.** Ouvrir PowerShell en administrateur et taper :

    ```powershell
    wsl --install FedoraLinux-44
    ```

    Si Windows demande un redémarrage, accepter, puis relancer la commande. Au premier démarrage, Fedora demande de créer un nom d'utilisateur et un mot de passe.

2. **Ouvrir Fedora.** Dans PowerShell : `wsl -d FedoraLinux-44`. On est maintenant dans un terminal Linux.

3. **Installer les outils de base.** L'image WSL est minimale :

    ```bash
    sudo dnf upgrade --refresh -y
    sudo dnf install -y git gawk procps-ng util-linux grep curl jq tar gzip
    ```

4. **Récupérer le projet et noter le commit.** Le dossier de travail doit être propre : `git status --short` ne doit rien afficher.

    ```bash
    git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
    cd FEDORA_GNOME_CUSTOM
    git status --short
    git rev-parse HEAD
    ```

    Noter la longue suite affichée par `git rev-parse HEAD` : c'est le commit à utiliser aux trois gates.

5. **Lancer la Gate 1.**

    ```bash
    ./control.sh validate gate1 run
    ```

    Résultat attendu : `GATE 1 PASS` et `hardware_certification=DEFERRED`.

6. **Exporter la preuve vers Windows.** `/mnt/c/` correspond au disque `C:` :

    ```bash
    mkdir -p /mnt/c/GoldenValidation
    ./control.sh validate export 1 /mnt/c/GoldenValidation
    ```

    Le dossier `C:\GoldenValidation` doit contenir un fichier `gate1-<commit>.json` et son `.sha256`.

## Étape B — Créer la VM Fedora 44 dans VirtualBox

Les réglages ci-dessous sont des recommandations pour la machine cible (48 Go de RAM, 8 cœurs) : le projet n'impose que Fedora 44, GNOME 50 et Wayland.

| Réglage VirtualBox | Valeur conseillée |
| --- | --- |
| Nom | `FGC-Gate2` |
| Image ISO | `Fedora-Workstation-Live-44-1.7.x86_64.iso` |
| Type / version | Linux / Fedora (64-bit) |
| Installation sans surveillance | **décochée** (installation à la main) |
| Mémoire | 8 192 Mo |
| Processeurs | 4 |
| EFI | activé |
| Disque | 60 Go, taille dynamique |
| Affichage | VMSVGA, 128 Mo de mémoire vidéo |
| Accélération 3D | désactivée au départ (plus stable) |
| Réseau | NAT |
| Dossier partagé | `C:\GoldenValidation`, nommé `GoldenValidation`, montage automatique |

Ensuite :

1. Démarrer la VM. Fedora s'ouvre en mode « Live » : choisir **Installer sur le disque dur**, utiliser tout le disque virtuel, puis créer l'utilisateur (ne pas travailler en root).
2. Redémarrer, puis se connecter. Vérifier que la session est bien Wayland :

    ```bash
    echo $XDG_SESSION_TYPE
    ```

    La réponse doit être `wayland`.

3. Mettre le système à jour et installer les additions invité, nécessaires au dossier partagé :

    ```bash
    sudo dnf upgrade --refresh -y
    sudo dnf install -y virtualbox-guest-additions git
    sudo usermod -aG vboxsf "$USER"
    ```

4. Redémarrer la VM. Le dossier partagé apparaît alors dans `/media/sf_GoldenValidation`.

Si l'affichage est vraiment trop lent, éteindre la VM et activer l'accélération 3D. Revenir en arrière si GNOME affiche des défauts graphiques.

## Étape C — Préparer la VM avec le même commit

1. **Récupérer le projet au commit noté à l'étape A.** Remplacer `<commit>` par la suite notée :

    ```bash
    git clone https://github.com/mathiasseguincadiche/FEDORA_GNOME_CUSTOM.git
    cd FEDORA_GNOME_CUSTOM
    git switch --detach <commit>
    git status --short
    ```

    `git status --short` ne doit rien afficher.

2. **Importer la preuve Gate 1** depuis le dossier partagé :

    ```bash
    ./control.sh validate import /media/sf_GoldenValidation/gate1-<commit>.json
    ./control.sh validate gate2 status
    ```

L'import est refusé si le commit ou la liste des modules ne correspondent pas à ceux de la Gate 1. Dans ce cas, revérifier le commit avec `git rev-parse HEAD`.

## Étape D — Lancer le labo GNOME

Le labo est un programme séparé, réservé à VirtualBox. L'installation réelle (`install.sh --apply`) reste **bloquée** dans la VM : c'est un garde-fou, pas une panne.

1. **Voir ce qui va être fait**, sans rien modifier :

    ```bash
    ./control.sh validate gate2 plan
    ```

2. **Appliquer le labo.** Il installe GNOME et ses portails, Nautilus et ses intégrations, Ptyxis, les extensions du projet (DING, Show Desktop Plus, Resource Monitor) et les réglages GNOME ciblés :

    ```bash
    ./control.sh validate gate2 apply
    ```

3. **Se déconnecter puis se reconnecter.** GNOME ne voit souvent les nouvelles extensions qu'après une reconnexion. Relancer ensuite la même commande `apply` : elle ne refait que ce qui manque.

4. **Lancer les contrôles automatiques** :

    ```bash
    ./control.sh validate gate2 check
    ```

    Le résultat doit afficher **`KO=0`**. Chaque ligne `KO` nomme précisément ce qui ne va pas : la corriger avant de passer à la suite.

## Étape E — La vérification visuelle, à faire soi-même

Aucun test automatique ne peut remplacer ce regard : c'est **l'opérateur** qui confirme ce qu'il voit.

Le bureau :

- [ ] Créer le fichier `~/Bureau/FGC_GATE2_TEST.txt` et le dossier `~/Bureau/FGC_GATE2_DOSSIER/`
- [ ] Le fichier et le dossier apparaissent sur le fond d'écran
- [ ] La Corbeille est visible sur le bureau
- [ ] Le dossier personnel et les disques ne sont **pas** ajoutés au bureau

Les applications :

- [ ] Nautilus s'ouvre et navigue correctement dans plusieurs dossiers
- [ ] La prévisualisation des fichiers et l'ouverture des archives fonctionnent
- [ ] Ptyxis se lance normalement depuis GNOME et s'affiche bien

Le bouton « Afficher le bureau » :

- [ ] Ouvrir trois fenêtres différentes
- [ ] Cliquer sur le bouton en haut à gauche : les fenêtres disparaissent
- [ ] Recliquer : les fenêtres reviennent
- [ ] Refaire la même chose avec le raccourci `Super+D`

La barre du haut :

- [ ] Resource Monitor affiche le CPU %, la RAM % et le débit réseau
- [ ] Pendant un téléchargement (par exemple `curl -O` d'un gros fichier), le débit réseau varie
- [ ] Aucune extension n'affiche de message d'erreur répété, aucun défaut d'affichage évident
- [ ] L'absence de température du Ryzen et des mesures de la B580 est normale dans une VM (**EXPECTED**)

La persistance :

- [ ] Se déconnecter, se reconnecter, refaire les contrôles importants
- [ ] Redémarrer la VM, refaire les contrôles importants
- [ ] Relancer `./control.sh validate gate2 check` : toujours `KO=0`

## Étape F — Signer la Gate 2 et exporter les preuves

1. **Signer.** Le script relance tous les contrôles, puis demande de taper une phrase exacte :

    ```bash
    ./control.sh validate gate2 sign
    ```

    Taper exactement, en majuscules et avec les tirets bas : `JE_VALIDE_VISUELLEMENT_GATE2`. Cette phrase est une signature : ne la taper que si toute la checklist de l'étape E est cochée.

2. **Exporter les deux preuves** dans le dossier partagé, pour la Gate 3 :

    ```bash
    ./control.sh validate export 1 /media/sf_GoldenValidation
    ./control.sh validate export 2 /media/sf_GoldenValidation
    ```

Le dossier `C:\GoldenValidation` doit maintenant contenir `gate1-<commit>.json`, `gate2-<commit>.json` et leurs fichiers `.sha256`. Copier ce dossier sur une clé USB ou dans un cloud : c'est lui qui sera importé sur le vrai PC.

## Si ça bloque

| Ce que l'on voit | Cause probable | Quoi faire |
| --- | --- | --- |
| L'import de la preuve Gate 1 est refusé | Le commit de la VM n'est pas celui de la Gate 1 | Comparer `git rev-parse HEAD` dans WSL et dans la VM, puis `git switch --detach <commit>` |
| « Git working tree must be clean » | Un fichier a été modifié dans le dossier du projet | `git status --short` pour voir lequel ; `git restore <fichier>` pour l'annuler |
| `echo $XDG_SESSION_TYPE` répond `x11` | Session GNOME sur Xorg | Se déconnecter, cliquer sur la roue dentée de l'écran de connexion, choisir « GNOME » (Wayland) |
| `/media/sf_GoldenValidation` est vide ou refusé | Additions invité absentes, ou utilisateur pas encore dans le groupe `vboxsf` | Refaire l'étape B.3, puis redémarrer la VM |
| Une extension est installée mais invisible | GNOME ne l'a pas encore chargée | Se déconnecter / reconnecter, puis relancer `gate2 apply` |
| `gate2 check` affiche des `KO` | Un élément précis ne converge pas | Lire la ligne `KO` : elle nomme l'élément ; relancer `gate2 apply` puis `check` |
| La VM est très lente, tortue verte en bas | VirtualBox tourne au-dessus de Hyper-V (WSL2) | Normal ; fermer les autres applications ; essayer l'accélération 3D |
| `install.sh --apply` est refusé dans la VM | Garde-fou voulu : l'installation réelle est réservée au vrai PC | Rien à faire, utiliser `validate gate2 apply` |

## Le résultat attendu et la suite

La Gate 2 est réussie quand les deux preuves signées sont dans `C:\GoldenValidation`, avec `manual_visual=PASS` et `hardware_certification=DEFERRED`. Elle ne délivre jamais la certification finale : seule la Gate 3 le peut.

La suite, sur le vrai PC :

1. Installer Fedora 44 avec le média vérifié par le projet.
2. Récupérer le projet au **même commit**, puis importer les preuves Gate 1 et Gate 2, dans cet ordre.
3. Faire la sauvegarde Borg d'avant installation, la répétition à blanc, puis l'installation réelle.
4. Passer les preuves physiques (écran 240 Hz, B580, veille, températures) et la certification finale.

Sources : installation de Fedora dans WSL selon la [documentation Fedora](https://docs.fedoraproject.org/hi/cloud/wsl/) ; le nom `FedoraLinux-44` figure dans la [liste officielle des distributions WSL](https://github.com/microsoft/WSL/blob/master/distributions/DistributionInfo.json).
