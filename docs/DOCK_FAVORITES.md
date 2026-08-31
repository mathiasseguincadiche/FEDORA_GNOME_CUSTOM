# Curated GNOME Dock — 0.9.3

La Golden Workstation impose désormais une liste de favoris GNOME Shell déterministe afin qu'une installation fraîche présente immédiatement le même environnement de travail.

## Ordre certifié

1. Nautilus — `org.gnome.Nautilus.desktop`
2. Brave — `brave-browser.desktop`
3. Ptyxis — `org.gnome.Ptyxis.desktop`
4. Visual Studio Code — `code.desktop`
5. Bitwarden — `com.bitwarden.desktop.desktop`
6. Slack — `com.slack.Slack.desktop`
7. LibreOffice Start Center — `libreoffice-startcenter.desktop`
8. GNOME Software — `org.gnome.Software.desktop`

Remmina reste installé pour RDP/VNC/SPICE mais n'est pas épinglé dans le dock.

## Application

La politique est définie dans `config/gnome.conf` via `GNOME_DOCK_FAVORITES`.

Après l'installation des applications professionnelles, le module `applications.dock_favorites` appelle :

```bash
scripts/gnome/configure-dock-favorites.sh
```

Le script écrit `org.gnome.shell favorite-apps`, refuse les IDs invalides ou dupliqués et relit immédiatement la valeur pour confirmer l'ordre exact.

## Validation runtime

Le postcheck du module refuse la validation si :

- l'ordre `favorite-apps` diffère de la politique ;
- un lanceur `.desktop` attendu n'est pas exporté ;
- un favori est dupliqué ou mal formé.

`diagnostics/applications-doctor` vérifie également la politique et fait partie de la certification bare-metal finale.

Les lanceurs Flatpak sont recherchés dans les exports utilisateur et système. L'App ID Bitwarden étant `com.bitwarden.desktop`, son fichier desktop exporté est `com.bitwarden.desktop.desktop`.

## CI Fedora 44

Le host integration pretest :

- installe le socle Fedora contenant Nautilus, Ptyxis, LibreOffice et GNOME Software ;
- crée un utilisateur de test ;
- exécute le script réel dans une session D-Bus ;
- relit `org.gnome.shell favorite-apps` et exige l'ordre exact ;
- vérifie les lanceurs Fedora natifs disponibles dans `/usr/share/applications`.

Les applications vendor/Flatpak restent par ailleurs validées par leurs contrôles de dépôts et IDs existants. Le postcheck bare-metal donne la preuve finale que leurs lanceurs sont réellement exportés après APPLY.
