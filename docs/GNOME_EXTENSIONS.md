# Extensions GNOME 50 — politique Golden Workstation

Référence : Fedora Linux 44 Workstation + GNOME 50 + Wayland.

Le projet distingue les extensions **fonctionnelles** des extensions purement cosmétiques. L'objectif est de conserver un bureau proche de l'upstream, stable à 240 Hz et simple à diagnostiquer après une mise à jour ou un suspend/resume.

## Extensions fonctionnelles activées

### Dash to Dock

**Activé par défaut** depuis le paquet Fedora officiel.

Le projet conserve les réglages Fedora/upstream sauf décision explicite versionnée.

### AppIndicator

**Activé par défaut** depuis le paquet Fedora officiel pour les logiciels utilisant AppIndicator/KStatusNotifierItem.

AppIndicator fait partie du contrat fonctionnel courant au même titre que Dash to Dock.

### Desktop Icons NG (DING)

**Activé par défaut** depuis l'artefact GNOME Extensions **review `74408` / version de site `95`**, UUID `ding@rastersoft.com`, déclaré compatible GNOME Shell 50.

Fedora 44 ne fournit pas DING dans le manifest RPM du projet. Le téléchargement est donc volontairement limité à l'URL GNOME-reviewed exacte inscrite dans `config/gnome.conf`. L'installateur contrôle l'UUID, la compatibilité GNOME 50, compile le schéma GSettings et écrit un marqueur de provenance.

DING répond au besoin fonctionnel de disposer d'un vrai bureau de travail visible sur le fond d'écran. L'état Golden impose :

```text
Dossier XDG Desktop   ~/Bureau
Contenu de ~/Bureau   visible sur le bureau
Corbeille             visible
Dossier personnel     masqué
Volumes externes      masqués
Volumes réseau        masqués
```

Le dossier `~/Bureau` est créé si nécessaire et enregistré comme répertoire XDG `DESKTOP`. DING affiche donc le **contenu réel** de ce dossier ; le projet ne crée pas une copie ou un pseudo-bureau parallèle.

Réglages certifiés :

```text
org.gnome.shell.extensions.ding show-trash           true
org.gnome.shell.extensions.ding show-home            false
org.gnome.shell.extensions.ding show-volumes         false
org.gnome.shell.extensions.ding show-network-volumes false
```

### Show Desktop Plus

**Activé par défaut** comme contrôle fonctionnel « Afficher le bureau ».

Source gérée : artefact **version 8 / review GNOME Extensions `70326`**, déclaré compatible GNOME Shell 50. Le projet n'utilise pas une URL `latest` flottante : l'URL versionnée est inscrite dans `config/gnome.conf` et l'installateur vérifie l'UUID et la déclaration GNOME 50 avant installation.

État Golden :

```text
UUID                   show-desktop-plus@attentivecoder
Position panneau       left-end (haut/gauche)
Clic gauche            toggle-desktop
Clic milieu            hide-focused
Workspace              workspace courant
Moniteur actif seul    false
Raccourci               Super+D
Style d'icône          desktop
Badge fenêtres         false
```

Un clic gauche masque les fenêtres du workspace courant pour dégager immédiatement le bureau DING ; un second clic restaure les fenêtres suivies par l'extension. `Super+D` fournit le même accès au clavier.

### Resource Monitor

**Activé par défaut** pour la télémétrie lisible en permanence dans la barre supérieure.

Source gérée : artefact GNOME Extensions **review `70909` / version de site `28`**, UUID `Resource_Monitor@Ory0n`, déclaré compatible GNOME Shell 50. Comme DING et Show Desktop Plus, le projet utilise l'artefact GNOME-reviewed exact et conserve un marqueur de provenance.

Profil Golden volontairement compact :

```text
CPU                  utilisation % + température Ryzen Tctl
RAM                  pourcentage utilisé
Ethernet             débit descendant | montant, auto-hide si inactif
Wi-Fi                débit descendant | montant, auto-hide si inactif
GPU Intel Arc B580   charge % + température si exposée par xe/hwmon
Rafraîchissement     2 secondes
Position             zone droite du panneau
Disque               masqué dans le panneau
Swap                  masquée dans le panneau
```

Le code de Resource Monitor v28 détecte les GPU Intel via DRM/sysfs. Pour la B580, le projet exige le PCI `8086:e20b` et tente les compteurs `gpu_busy_percent` puis `gt_busy_percent`. La température GPU est lue via le `hwmon` DRM lorsqu'il est exposé.

Le choix est **fail-closed** sur le bare-metal : si la B580 est présente mais qu'aucune vraie source de charge GPU n'est lisible, `gnome.telemetry`/`resource-monitor-doctor` passent en KO. Le projet n'affiche jamais un faux `0 %` pour contourner une limitation de télémétrie `xe`. L'absence de température GPU peut rester WARN si le compteur de charge est valide.

Le Ryzen 7 7700 utilise en priorité le capteur `k10temp`/`Tctl` (ou `zenpower` lorsqu'il est exposé). Aucun daemon de monitoring supplémentaire n'est requis : les données CPU/RAM/réseau viennent des interfaces kernel et les données GPU de DRM/sysfs.

## Blur My Shell

Installable, mais **désactivé dans l'état Golden certifié**. Il ajoute un chemin de rendu cosmétique sans bénéfice fonctionnel nécessaire et complique l'analyse des régressions à 240 Hz ou après reprise de veille.

Il peut être testé manuellement A/B après certification, mais son activation ne fait pas partie de la baseline Golden.

## Extension Manager

`com.mattjakeman.ExtensionManager` reste installé depuis Flathub comme interface d'administration des extensions.

## Exclusions

Just Perfection et Dash to Panel ne sont pas imposés par le projet. Les anciennes extensions Desktop Icons autres que DING ne font pas partie du profil. Astra Monitor n'est pas retenu pour le Golden : son monitoring GPU documenté ne couvre pas la cible Intel Arc du projet aussi directement que Resource Monitor.

## Convergence et première session

Les RPM Dash to Dock/AppIndicator peuvent être installés alors que GNOME Shell tourne déjà. DING, Show Desktop Plus et Resource Monitor sont ajoutés dans le répertoire d'extensions utilisateur depuis leurs artefacts GNOME-reviewed pinés. Si la session GNOME courante ne voit pas encore un nouvel UUID, APPLY échoue volontairement et demande une déconnexion/reconnexion ; après reconnexion, relancer APPLY permet l'activation et le postcheck.

Le projet ne désactive jamais les contrôles simplement pour contourner cette frontière de session Wayland.

## Validation VirtualBox avant bare-metal

Le GATE 2 utilise [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md). Son entrypoint séparé peut converger DING, Show Desktop Plus, Resource Monitor et les boutons de fenêtres dans une vraie session Fedora 44 GNOME 50/Wayland sous VirtualBox. `install.sh --apply` reste bloqué en VM. Les métriques CPU/RAM/réseau peuvent être observées dans le LAB ; la télémétrie physique Ryzen/B580 reste `EXPECTED` jusqu'au bare-metal.

## Diagnostic

```bash
./diagnostics/gnome-doctor
bash ./diagnostics/resource-monitor-doctor
./diagnostics/virtualbox-gnome-lab-doctor   # uniquement dans le LAB VirtualBox
```

Le doctor GNOME vérifie notamment :

- installation, provenance et activation de DING ;
- `~/Bureau` comme XDG Desktop ;
- Corbeille visible et volumes masqués ;
- présence/provenance/activation de Show Desktop Plus ;
- position gauche, action toggle et `Super+D` ;
- absence de badge de fenêtres ;
- présence/provenance/réglages de Resource Monitor ;
- sur bare-metal, capteur Ryzen et vraie télémétrie de charge de l'Arc B580 ;
- les autres extensions fonctionnelles du profil.

## Ajouter une extension

Une nouvelle extension doit :

- répondre à un besoin fonctionnel explicite ;
- être compatible GNOME 50 ;
- provenir d'une source gérée et reproductible ;
- être testée par rapport à l'état certifié ;
- ne jamais être utilisée pour masquer un problème Mutter/Wayland/GPU.

La source de vérité détaillée du profil est [`GNOME_PROFILE.md`](GNOME_PROFILE.md).
