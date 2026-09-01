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

**Activé par défaut** depuis le paquet Fedora `gnome-shell-extension-desktop-icons-ng`.

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

Source gérée : artefact **version 8 / review GNOME Extensions 70326**, déclaré compatible GNOME Shell 50. Le projet n'utilise pas une URL `latest` flottante : l'URL versionnée est inscrite dans `config/gnome.conf` et l'installateur vérifie l'UUID et la déclaration GNOME 50 avant installation.

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

## Blur My Shell

Installable, mais **désactivé dans l'état Golden certifié**. Il ajoute un chemin de rendu cosmétique sans bénéfice fonctionnel nécessaire et complique l'analyse des régressions à 240 Hz ou après reprise de veille.

Il peut être testé manuellement A/B après certification, mais son activation ne fait pas partie de la baseline Golden.

## Extension Manager

`com.mattjakeman.ExtensionManager` reste installé depuis Flathub comme interface d'administration des extensions.

## Exclusions

Just Perfection et Dash to Panel ne sont pas imposés par le projet. Les anciennes extensions Desktop Icons autres que DING ne font pas partie du profil.

## Convergence et première session

Les RPM d'extensions peuvent être installés alors que GNOME Shell tourne déjà. De même, Show Desktop Plus est ajouté dans le répertoire d'extensions utilisateur. Si la session GNOME courante ne voit pas encore un nouvel UUID, APPLY échoue volontairement et demande une déconnexion/reconnexion ; après reconnexion, relancer APPLY permet l'activation et le postcheck.

Le projet ne désactive jamais les contrôles simplement pour contourner cette frontière de session Wayland.

## Diagnostic

```bash
./diagnostics/gnome-doctor
```

Le doctor vérifie notamment :

- installation et activation de DING ;
- `~/Bureau` comme XDG Desktop ;
- Corbeille visible et volumes masqués ;
- présence/provenance/activation de Show Desktop Plus ;
- position gauche, action toggle et `Super+D` ;
- absence de badge de fenêtres ;
- les autres extensions fonctionnelles du profil.

## Ajouter une extension

Une nouvelle extension doit :

- répondre à un besoin fonctionnel explicite ;
- être compatible GNOME 50 ;
- provenir d'une source gérée et reproductible ;
- être testée par rapport à l'état certifié ;
- ne jamais être utilisée pour masquer un problème Mutter/Wayland/GPU.

La source de vérité détaillée du profil est [`GNOME_PROFILE.md`](GNOME_PROFILE.md).
