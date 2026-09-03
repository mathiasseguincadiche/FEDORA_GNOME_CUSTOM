# Ptyxis — terminal Golden Fedora

La version applicable est celle de [`../VERSION`](../VERSION).

## Rôle

Ptyxis est le terminal GNOME natif de référence de la workstation. Il est installé depuis les dépôts Fedora et ouvre le shell Bash géré par le projet.

Le contrat sépare volontairement :

- **Ptyxis** : terminal GTK/libadwaita, intégration GNOME et gestion de session ;
- **Bash UX** : historique, prompt, complétions, navigation et aliases ;
- **KVM** : frontière d'isolation principale pour les environnements DevOps lourds.

Cette séparation évite de transformer le HOST Fedora en VM de développement implicite.

## Installation

Le paquet `ptyxis` est présent dans `manifests/packages-applications-gtk4.txt` et est validé après l'installation du catalogue d'applications.

Le profil conserve le paquet Fedora natif ; aucune version Flatpak parallèle n'est installée par le Golden.

## Bash géré

Ptyxis utilise le login shell Bash du HOST. La couche versionnée est décrite dans [`HOST_BASH_UX.md`](HOST_BASH_UX.md) et fournit notamment :

- `bash-completion` ;
- `fzf` ;
- `zoxide` ;
- `direnv` ;
- historique long et synchronisé ;
- prompt Git local-only ;
- complétions DevOps mises en cache ;
- aliases non destructifs.

Le `.bashrc` utilisateur n'est jamais remplacé en bloc.

## Politique Ptyxis

Le projet conserve les préférences visuelles et profils Ptyxis proches de l'upstream tant qu'une décision fonctionnelle n'exige pas de les figer.

Il ne force donc pas arbitrairement :

- palette ;
- transparence ;
- police ;
- taille de fenêtre ;
- raccourcis personnalisés ;
- profils conteneur.

Cette règle évite de lier la certification Golden à des clés GSettings pouvant évoluer entre versions de Ptyxis sans bénéfice fonctionnel.

## Toolbx / conteneurs

Ptyxis sait s'intégrer à Podman, Distrobox et Toolbx. Cette capacité n'implique pas que ces outils deviennent automatiquement des dépendances du HOST Golden.

Pour le profil actuel :

```text
HOST Fedora          minimal et administrable
Ptyxis + Bash        outils opérateur locaux
KVM Ubuntu DevOps    environnement DevOps principal
KVM Windows 11       environnement Windows
Toolbx               non imposé par défaut
```

Toolbx pourra être ajouté ultérieurement comme profil explicitement optionnel si un besoin de sandbox CLI légère sur le HOST est validé. Il ne doit pas apparaître implicitement dans `packages-shell.txt`.

## Doctor

```bash
./diagnostics/ptyxis-doctor
```

Le doctor vérifie :

- paquet Fedora `ptyxis` ;
- commande native `ptyxis` ;
- desktop entry `org.gnome.Ptyxis.desktop` ;
- visibilité du schéma GSettings lorsque le runtime l'expose ;
- Bash comme login shell ;
- session GNOME/Wayland lorsqu'elle est disponible.

Le doctor est appelé par la validation applications, le `workstation-doctor` et la certification finale.

## Validation complémentaire

```bash
./diagnostics/shell-doctor
./diagnostics/ptyxis-doctor
```

Le premier valide le shell ; le second valide le terminal et son intégration Fedora/GNOME. Les deux contrôles sont volontairement distincts.
