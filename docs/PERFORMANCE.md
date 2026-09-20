# Performance runtime — profil « Fedora-Cachy »

## Objectif

Cette couche importe dans Fedora 44 les mécanismes de réactivité utiles d'une workstation orientée performance **sans transformer Fedora en distribution dérivée** et sans toucher aveuglément aux paramètres kernel, GPU, NVMe ou réseau.

La règle est :

```text
mesurer → activer temporairement → observer → restaurer → certifier
```

Le matériel cible est le Ryzen 7 7700, l'Intel Arc B580 et les deux Crucial T705 du profil Golden. Les optimisations restent donc compatibles avec GNOME/Wayland, SELinux, KVM/libvirt et les outils DevOps.

## Politique versionnée

La source de vérité est `config/performance-runtime.policy`.

Valeurs importantes :

- mode normal `balanced` ;
- AMD P-State attendu en mode `active` ;
- EPP attendu `balance_performance` en usage normal et `performance` pour un workload temporaire ;
- TuneD/tuned-ppd reste le pont GNOME/Fedora ;
- `sched_ext` est `auto`, mais **désactivé par défaut** ;
- zram conserve les defaults Fedora ;
- le scheduler NVMe est **benchmark-only** ;
- les schedulers I/O expérimentaux ne sont jamais activés par le profil Golden ;
- GameMode applique un mode temporaire par jeu et restaure l'état après le workload.

## Profils CPU / TuneD

État courant :

```bash
./control.sh perf status
```

Basculer explicitement :

```bash
./control.sh perf balanced
./control.sh perf performance
./control.sh perf powersave
```

Ces commandes mutantes sont bare-metal only. Le projet ne désactive ni SMT, ni C-States et n'applique aucun PBO/overclock automatique.

Le profil `performance` n'est pas un mode permanent recommandé : il sert aux compilations, VM ou tests où une politique temporaire agressive est utile. Le mode normal reste `balanced`.

## Gaming dynamique

GameMode reste le mécanisme par jeu. La configuration Golden ne contient aucun overclock GPU et ne remplace ni Mesa ni le pilote `xe`.

Pour une commande explicite avec bascule TuneD + GameMode + restauration :

```bash
./scripts/performance/game-performance.sh COMMAND [ARG ...]
```

Pour Steam, `gamemoderun %command%` reste la chaîne simple par titre.

## sched_ext / SCX

Le projet installe l'outillage Fedora mais ne lance aucun scheduler SCX globalement.

État read-only :

```bash
./control.sh perf sched-status
```

Smoke test explicite, borné et bare-metal :

```bash
./control.sh perf sched-smoke
```

Le doctor exige notamment `CONFIG_SCHED_CLASS_EXT`, le BTF du noyau et un binaire SCX. Le smoke utilise `timeout`, puis rend la main au scheduler du noyau. Une erreur BPF/BTF ou un échec de chargement est un KO du test, mais `sched_ext_policy=auto` laisse le runtime Golden sur le scheduler standard.

Cette prudence est volontaire : Fedora 44 a connu en septembre 2026 un problème BTF empêchant le chargement de schedulers `sched_ext` sur certains noyaux (Bugzilla #2514913). Le projet teste donc **le noyau réellement démarré** au lieu de supposer la compatibilité.

## ZRAM

Le projet installe `zram-generator-defaults` et observe Fedora ; il ne fixe ni taille, ni algorithme, ni `vm.swappiness` global.

```bash
./control.sh perf zram
```

Une absence de `/dev/zram` immédiatement après une première installation peut demander un reboot ; elle reste visible comme avertissement et sera recontrôlée par le doctor.

## NVMe T705

Aucun scheduler NVMe n'est imposé par défaut.

```bash
./control.sh perf nvme
./control.sh perf nvme-benchmark
```

Le benchmark mutant est réservé au second T705 monté sur `/data`, utilise un fichier scratch, compare uniquement `none` et `mq-deadline` lorsqu'ils sont disponibles, puis restaure toujours le scheduler initial via `trap`.

Le script refuse un modèle autre que `CT1000T705SSD3` et n'effectue aucune écriture brute sur le block device.

## Frametime

Pour l'écran 240 Hz, la moyenne FPS ne suffit pas. Le doctor sait analyser un CSV MangoHud :

```bash
./control.sh perf frametime /chemin/mangohud.csv
```

Il produit les percentiles de frametime p50/p95/p99/p99.9 et leur FPS équivalent. Ces mesures servent aux comparaisons A/B : baseline Fedora, profil balanced, profil performance et éventuellement SCX après smoke PASS.

## Certification Golden

La performance fait partie du contrat Gate 3, mais la certification ne transforme pas les expérimentations en réglages permanents.

```bash
./diagnostics/performance-doctor --certify
```

Ce mode exige notamment :

- politique `performance-runtime.policy` valide ;
- AMD P-State présent lorsque `require_amd_pstate=true`, avec mode `active`, boost CPU et EPP réellement exposé sur la cible Golden ;
- TuneD **et tuned-ppd** actifs, avec retour sur le profil correspondant à `mode_default=balanced` et EPP cohérent ;
- zram Fedora réellement instancié et actif comme swap ;
- SCX fail-safe selon `sched_ext_policy` ;
- politique NVMe toujours `benchmark-only` ;
- GameMode disponible lorsque le profil Gaming canonique est actif.

Une divergence EPP visible par rapport au profil TuneD est signalée pour diagnostic ; elle n'est pas masquée par une écriture forcée dans sysfs. Le smoke SCX et le benchmark NVMe restent des opérations explicites : ils ne sont pas déclenchés automatiquement par la certification.

Le fichier `config/performance-runtime.policy` entre dans `effective_config_sha256`. Toute modification de cette politique invalide donc les preuves Golden liées à l'ancienne configuration. Le bundle Golden embarque aussi une copie exacte de cette policy et son SHA-256.
## Interdictions

Cette couche ne doit pas introduire :

- `sysctl -w` global de performance ;
- `nohz_full` ;
- désactivation globale ASPM/APST ;
- ADIOS/BORE/BMQ imposé ;
- kernel Cachy/Zen/Liquorix ;
- Mesa git/COPR ou `force_probe` ;
- overclock GPU via GameMode ;
- recompilation globale Fedora en `znver4`.

Les optimisations CPU spécifiques peuvent être utilisées dans des workloads ou builds dédiés, jamais comme macro globale du système Fedora.
