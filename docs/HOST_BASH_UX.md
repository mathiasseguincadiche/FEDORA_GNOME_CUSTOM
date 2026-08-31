# Fedora Host Bash UX

La machine hôte Fedora 44 conserve Bash comme shell de travail et Ptyxis comme terminal GNOME. La couche gérée fournit une expérience terminal professionnelle sans remplacer Bash par Zsh et sans framework de prompt.

La version applicable est celle de [`../VERSION`](../VERSION).

## Paquets Fedora

- `bash-completion` ;
- `fzf` ;
- `zoxide` ;
- `direnv`.

Ils proviennent des dépôts Fedora 44 et sont vérifiés par le package preflight.

## Arborescence utilisateur

L'APPLY installe :

```text
~/.config/fedora-gnome-custom/bash/
├── settings.sh
├── init.sh
├── history.sh
├── aliases.sh
├── navigation.sh
├── completion.sh
└── prompt.sh
```

Le `.bashrc` existant n'est pas remplacé.

Avant la première modification il est sauvegardé dans :

```text
~/.local/state/fedora-gnome-custom/bash/bashrc.pre-fgc
```

Puis un unique bloc géré source `init.sh`. Les ré-APPLY remplacent uniquement le bloc et les fichiers appartenant au projet.

## Prompt

Le prompt natif Bash affiche utilisateur/hôte, répertoire courant, branche Git et état tracked modifié, puis le code retour uniquement en cas d'échec.

Il n'exécute aucune commande réseau et n'utilise ni Starship ni Oh My Bash.

Exemple :

```text
mathias@fedora ~/Projets/FEDORA_GNOME_CUSTOM main*
❯
```

## Historique

- `HISTSIZE=50000` ;
- `HISTFILESIZE=100000` ;
- `ignoreboth:erasedups` ;
- `histappend` ;
- synchronisation multi-terminal via `history -a` puis `history -n` avant chaque prompt.

## Navigation

`fzf` fournit la recherche fuzzy et l'historique interactif, `zoxide` fournit `z`/`zi`, et `direnv` charge uniquement les `.envrc` explicitement autorisés par l'utilisateur.

## Complétions

Le profil charge `bash-completion`.

Lorsque `gh`, `glab`, `kubectl`, `helm` ou `minikube` sont présents, leurs complétions générées sont mises en cache sous :

```text
~/.cache/fedora-gnome-custom/bash-completions
```

et ne sont régénérées que lorsque le binaire correspondant change.

## Aliases

Les aliases restent courts et lisibles :

- Git : `gs`, `ga`, `gc`, `gp`, `gpl`, `gl` ;
- Docker Compose : `dc` ;
- Kubernetes : `k`, `kgp`, `kgs`, `kgn`, `kd`, `kl` ;
- Terraform : `tf`, `tfi`, `tfp`, `tff`, `tfv`.

Aucun alias ne remplace `rm`, `mv`, `cp` ou `sudo`.

## Certification

```bash
./diagnostics/shell-doctor
```

Le doctor vérifie paquets, fichiers gérés, unicité du bloc `.bashrc`, sauvegarde initiale, syntaxe Bash et smoke test interactif. Il fait aussi partie de la certification finale bare-metal.
