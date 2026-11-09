# Ptyxis — terminal

> Mise à jour : 2026-11-09 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-09 — paquet, doctor et conditions de session relus contre `manifests/packages-applications-gtk4.txt`, contrôles contre `diagnostics/ptyxis-doctor` — matériel : non vérifié

> Fait partie du bureau GNOME du projet : vue d'ensemble dans [`GNOME.md`](GNOME.md).

## Rôle

Ptyxis est le terminal GNOME natif de référence de la workstation. Il est installé depuis les dépôts Fedora et ouvre le shell Bash géré par le projet.

Le contrat sépare volontairement :

- **Ptyxis** : terminal GTK/libadwaita, intégration GNOME et gestion de session ;
- **Bash UX** : historique, prompt, complétions, navigation et aliases ;
- **KVM** : frontière d'isolation principale pour les environnements DevOps lourds.

Cette séparation évite de transformer l'hôte Fedora en VM de développement implicite.

## Installation

Le paquet `ptyxis` est présent dans `manifests/packages-applications-gtk4.txt` et est validé après l'installation du catalogue d'applications.

Le profil conserve le paquet Fedora natif ; le projet n'installe aucune version Flatpak parallèle.

## Bash géré

Ptyxis utilise le login shell Bash de l'hôte. La couche versionnée est décrite dans [`HOST_BASH_UX.md`](HOST_BASH_UX.md) et fournit notamment :

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

Cette règle évite de lier la certification à des clés GSettings pouvant évoluer entre versions de Ptyxis sans bénéfice fonctionnel.

## Toolbx / conteneurs

Ptyxis sait s'intégrer à Podman, Distrobox et Toolbx. Cette capacité n'en fait pas des dépendances automatiques de l'hôte.

Pour le profil actuel :

```text
Hôte Fedora          minimal et administrable
Ptyxis + Bash        outils opérateur locaux
KVM Rocky DevOps    environnement DevOps principal
Toolbx               non imposé par défaut
```

Toolbx pourra être ajouté ultérieurement comme profil explicitement optionnel si un besoin de sandbox CLI légère sur l'hôte est validé. Il ne doit pas apparaître implicitement dans `packages-shell.txt`.

## Vérification après installation

**Pourquoi :** installer le paquet `ptyxis` ne suffit pas à prouver que GNOME peut le lancer avec le bon shell.

**Préparer :** depuis la racine du dépôt sur Fedora installé, ouvrir une session GNOME/Wayland, idéalement sous l'utilisateur qui utilise le poste. Avant l'APPLY, l'absence du paquet ou de la configuration gérée peut être normale.

```bash
./diagnostics/ptyxis-doctor
./diagnostics/shell-doctor
```

Le premier contrôle le RPM `ptyxis`, son exécutable, son lanceur `org.gnome.Ptyxis.desktop`, le schéma GSettings **s'il est exposé**, le login shell et la session. Le second contrôle le profil Bash chargé par Ptyxis.

**Résultat attendu :** aucun `KO`, synthèse `PTYXIS HEALTHY`, puis `BASH UX HEALTHY` / `READY`. Un `WARN` de Ptyxis ne provoque pas automatiquement un échec ; une session différente de GNOME/Wayland ou un schéma non exposé reste **à confirmer dans la vraie session**, pas une preuve d'intégration graphique réussie. Ces doctors ne réalisent pas de test visuel humain.

## En cas d'échec

| Indication du doctor | Contrôle ciblé | Action prudente |
|---|---|---|
| `ptyxis missing` ou `native command unavailable` | `rpm -q ptyxis` puis `command -v ptyxis` | Relire le journal d'APPLY et le manifeste GTK4 ; ne pas substituer une version Flatpak non prévue. |
| `org.gnome.Ptyxis.desktop missing` | `test -r /usr/share/applications/org.gnome.Ptyxis.desktop` | Vérifier le contenu du paquet Fedora et l'installation du bureau. |
| `expected Bash login shell` | `getent passwd "$(id -un)"` | Comparer le shell du compte au contrat du projet ; ne pas changer le shell système sans examiner les effets. |
| `GSettings schema not visible` ou session différente | `echo "$XDG_CURRENT_DESKTOP / $XDG_SESSION_TYPE"` | Refaire le contrôle dans GNOME/Wayland ; le warning seul ne prouve ni panne ni réussite graphique. |
| Shell `KO` malgré Ptyxis `OK` | [Guide Bash et son dépannage](HOST_BASH_UX.md#dépannage-ciblé) | Corriger la couche Bash ; ce n'est pas une raison pour réinstaller le terminal. |

Après les doctors, **ouvrir réellement Ptyxis**, créer un nouvel onglet, vérifier les caractères, le prompt, les commandes et les raccourcis utiles. Consigner tout défaut pour la [qualification physique](QUALIFICATION.md) (Gate 3).
