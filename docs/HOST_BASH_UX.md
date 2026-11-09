# Environnement Bash de l'hôte

> Mise à jour : 2026-11-09 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-09 — paquets et contrôles relus contre `manifests/packages-shell.txt`, fichiers et alias contre `shell/bash/` et `scripts/shell/install-host-bash-ux.sh` — matériel : non vérifié

La machine hôte Fedora 45 conserve Bash comme shell de travail et Ptyxis comme terminal GNOME. La couche gérée fournit une expérience terminal professionnelle sans remplacer Bash par Zsh et sans framework de prompt.

## Séparation terminal / shell

Le contrat distingue deux couches :

- [`PTYXIS.md`](PTYXIS.md) décrit le terminal GNOME natif, son paquet Fedora et son doctor ;
- ce document décrit le shell Bash chargé dans Ptyxis et utilisable également depuis une console/TTY.

Toolbx/Podman ne sont pas ajoutés implicitement à l'hôte. KVM reste l'environnement DevOps principal ; un éventuel profil Toolbx devra faire l'objet d'une option explicite future.

## Paquets Fedora

- `bash-completion` ;
- `fzf` ;
- `zoxide` ;
- `direnv`.

Ils proviennent des dépôts Fedora 45 et sont vérifiés par le package preflight.

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

- listes de fichiers : `ll`, `la` ;
- Git : `g`, `gs`, `ga`, `gc`, `gp`, `gpl`, `gl` ;
- Docker : `dc` (Compose), `dps` ;
- Kubernetes : `k`, `kgp`, `kgs`, `kgn`, `kd`, `kl` ;
- Terraform : `tf`, `tfi`, `tfp`, `tff`, `tfv`.

Aucun alias ne remplace `rm`, `mv`, `cp` ou `sudo`.

## Vérifier le profil après l'installation

**Pourquoi :** un prompt qui s'affiche ne prouve pas que les fichiers installés, les complétions et la sauvegarde initiale sont corrects.

**Préparer :** ouvrir un terminal sur le Fedora installé, une fois l'APPLY terminé, puis se placer à la racine du dépôt. Les scripts ci-dessous observent l'état installé : avant l'APPLY, des contrôles peuvent légitimement échouer.

```bash
./diagnostics/shell-doctor
./diagnostics/ptyxis-doctor
```

- **Succès du shell :** `shell-doctor` affiche les contrôles `OK` puis `BASH UX HEALTHY` / `READY`. Il compare les fichiers gérés avec `shell/bash/`, vérifie l'unicité du bloc `.bashrc`, la copie `bashrc.pre-fgc`, la syntaxe et un essai interactif isolé.
- **Succès du terminal :** `ptyxis-doctor` affiche `PTYXIS HEALTHY` et aucun `KO`. Certains `WARN` (session ou schéma GNOME indisponible) ne font pas échouer le script, mais **ne prouvent pas** le fonctionnement graphique ; voir [Ptyxis](PTYXIS.md).
- **Échec :** un `KO` du shell entraîne un code de sortie non nul. Ne pas déclarer le poste qualifié tant que sa cause n'est pas comprise.

## Dépannage ciblé

| Symptôme | Vérification en lecture seule | Suite |
|---|---|---|
| `package ... KO` | `rpm -q bash-completion fzf zoxide direnv` | Revoir la phase d'installation du shell et ses journaux ; ne pas ajouter des paquets hors du profil pour masquer l'écart. |
| `managed ... KO` ou `current ... KO` | Comparer le fichier de `shell/bash/` avec `~/.config/fedora-gnome-custom/bash/` | Vérifier le dépôt et la dernière exécution de l'APPLY ; ne pas écraser le fichier à l'aveugle. |
| `.bashrc managed block invalid` | Inspecter les marqueurs `# >>> fedora-gnome-custom bash ux >>>` et `# <<< fedora-gnome-custom bash ux <<<` dans `~/.bashrc` | Sauvegarder la version actuelle et corriger les marqueurs avec prudence. L'installateur refuse les blocs mal formés. |
| `pre-FGC .bashrc backup KO` | Vérifier `~/.local/state/fedora-gnome-custom/bash/bashrc.pre-fgc` | Rechercher la sauvegarde de première installation ; ne jamais fabriquer une copie en la présentant comme l'originale. |
| `interactive managed profile smoke KO` | Examiner les contrôles précédents, puis la syntaxe avec `bash -n ~/.config/fedora-gnome-custom/bash/init.sh` | Corriger la dépendance ou le fichier identifié, relancer le doctor et contrôler une vraie nouvelle session Bash. |

La validation automatique ne remplace ni l'ouverture effective d'un terminal ni la certification finale sur le PC physique.
