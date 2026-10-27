# Certification GNOME Desktop Integration

Ce runbook ferme la couche d'intégration entre **GNOME Shell 51, Nautilus, Ptyxis, LocalSearch, XDG Portals, applications par défaut et accès fichiers aux VM**.

L'objectif n'est pas d'ajouter des effets ou de remplacer les composants GNOME natifs. Le profil reste Fedora 45 + GNOME 51 + Wayland + Adwaita/libadwaita.

## Contrats automatisés

Les doctors dédiés sont :

```bash
./diagnostics/gnome-runtime-doctor
./diagnostics/localsearch-doctor
./diagnostics/nautilus-ptyxis-doctor
./diagnostics/ptyxis-integration-doctor
./diagnostics/default-apps-doctor
./diagnostics/portal-functional-doctor
./diagnostics/gnome-desktop-integration-doctor
```

Sur le bare-metal avec Rocky DevOps en service :

```bash
./diagnostics/nautilus-vm-live-doctor --certify
```

### GNOME runtime

`gnome-runtime-doctor` exige une session GNOME/Wayland réelle, GNOME Shell présent sur D-Bus, les services utilisateur Portal/PipeWire/WirePlumber actifs, les extensions Golden sans état `ERROR`/`OUT_OF_DATE` et l'absence de signature critique GNOME Shell/Mutter/GJS/portal dans le journal utilisateur du boot courant.

### LocalSearch

`localsearch` est une dépendance Golden explicite de Nautilus, et `xdg-user-dirs-gtk` une dépendance GNOME explicite. Le doctor valide le service, son état, les emplacements indexés, l'éligibilité d'un fichier canari dans `$HOME` et sa découverte réelle par la recherche.

### Nautilus → Ptyxis

La Golden conserve le chemin Fedora natif `Open in Console → org.gnome.Ptyxis`. L'ancien paquet `gnome-terminal-nautilus` est interdit pour éviter un second terminal concurrent dans le menu de Files.

Le test fonctionnel Ptyxis vérifie notamment `--working-directory` avec un chemin contenant des espaces, Bash, `TERM` et l'activation GApplication/D-Bus.

### Applications par défaut

Le profil gère explicitement :

- dossiers → Nautilus ;
- PDF → Papers ;
- images → Loupe ;
- texte → GNOME Text Editor ;
- vidéo → Showtime ;
- archives → File Roller ;
- HTTP/HTTPS/HTML → Brave sur le profil production complet.

La CI native utilise le sous-ensemble GNOME pour ses essais ; le système installé qualifie les associations du profil complet.

### XDG Portals

Le doctor fonctionnel valide FileChooser, OpenURI, Notification et ScreenCast. Les surfaces D-Bus sont contrôlées automatiquement ; les essais du système installé demandent en plus une confirmation utilisateur des interactions graphiques qui ne doivent pas être simulées en contournant les dialogues de sécurité GNOME.

### Accès fichiers KVM

En Gate 3, `nautilus-vm-live-doctor --certify` effectue un véritable aller-retour GIO :

- Rocky DevOps via SFTP.

Pour cet invité : listing, écriture d'un canari, relecture puis suppression. Le doctor rafraîchit ensuite les bookmarks Nautilus gérés.

## Avant installation — Live USB

Le [contrôle Live USB](FEDORA45_LIVE_PREFLIGHT.md) observe le bureau Fedora natif, l’affichage et les périphériques sur le PC. Il ne personnalise pas la session avec les extensions du projet. Les interactions de ces extensions, les applications finales et l’intégration Rocky se qualifient après APPLY et redémarrage.

## Gate 3 — bare-metal

Après l'APPLY et les cinq cycles suspend/resume certifiés du fingerprint courant :

```bash
./scripts/validation/gnome-ux-matrix.sh gate3
```

Cette commande exige :

- preuve Live native courante importée après installation ;
- nombre minimal de cycles suspend/resume ;
- GNOME runtime sain ;
- LocalSearch réel ;
- Ptyxis/CWD fonctionnel ;
- associations par défaut ;
- Portals fonctionnels ;
- accès SFTP à Rocky si KVM est activé ;
- confirmation visuelle de la stabilité GNOME après suspend/resume.

Elle produit :

```text
$STATE_ROOT/final/evidence/gnome-ux.ok
```

lié à `workstation_runtime_fingerprint` et `effective_config_sha256`.

Ensuite :

```bash
./diagnostics/final-certification certify
```

`application-runtime-doctor` inclut la validation GNOME transversale sur le bare-metal, de sorte qu'une dérive de GNOME/Nautilus/Ptyxis/LocalSearch/default-apps ou des preuves Gate 3 rende la certification runtime invalide.

## Principe de maintenance

Aucune extension Nautilus tierce n'est ajoutée pour `Open in Console`. Aucun thème, fork de Nautilus, remplacement de Ptyxis ou effet compositor n'est nécessaire à cette certification. Les évolutions doivent privilégier les interfaces Fedora/GNOME natives et ajouter une preuve seulement lorsqu'elle protège un comportement fonctionnel réel.
