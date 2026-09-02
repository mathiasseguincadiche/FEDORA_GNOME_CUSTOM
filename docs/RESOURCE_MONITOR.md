# Resource Monitor — télémétrie de la Golden Workstation

## Objectif

Resource Monitor est l'extension GNOME 50 retenue pour afficher dans la barre supérieure les métriques utiles au quotidien sans ouvrir un outil de diagnostic :

```text
CPU     utilisation % + température
RAM     utilisation %
NET     download | upload sur Ethernet ou Wi-Fi actif
GPU     charge Intel Arc B580 + température si hwmon l'expose
```

Le profil privilégie une lecture compacte. Les statistiques disque et swap restent disponibles dans les doctors/outils système mais ne sont pas affichées en permanence dans le panneau.

## Source gérée

```text
Extension       Resource Monitor
UUID            Resource_Monitor@Ory0n
Version site    28
Review GNOME     70909
GNOME Shell      50
Schema          org.gnome.shell.extensions.resource-monitor
```

Artefact exact :

```text
https://extensions.gnome.org/review/download/70909.shell-extension.zip
```

`scripts/gnome/install-resource-monitor.sh` refuse toute autre URL, UUID ou cible GNOME Shell. Il compile le schéma GSettings et écrit `.fedora-gnome-custom-source` dans le répertoire de l'extension.

## Profil visuel Golden

```text
Position               droite
Rafraîchissement       2 s
Icônes                  oui
Ordre                   CPU | RAM | Ethernet | Wi-Fi | GPU
CPU %                   oui
CPU fréquence           non
Load average            non
CPU température         oui
RAM                     % utilisée
Swap                    masquée
Débit réseau            B/s auto-scale
Interface inactive      auto-hide
GPU charge              oui
GPU température         oui si disponible
Nom complet GPU         masqué dans le panneau
Disque I/O              masqué
Espace disque           masqué
```

Les interfaces Ethernet et Wi-Fi restent toutes deux activées dans le profil mais `netautohidestatus=true` masque automatiquement celle qui n'est pas active. Cela évite de devoir modifier le profil quand le HOST passe du LAN 5G au Wi-Fi.

## Ryzen 7 7700

Le module cherche les capteurs `k10temp` ou `zenpower` dans `/sys/class/hwmon` et préfère le label `Tctl` lorsqu'il existe. La source exacte est écrite dans la liste de capteurs Resource Monitor au moment de l'APPLY bare-metal.

La température physique Ryzen n'est jamais certifiée en VirtualBox/WSL2.

## Intel Arc B580 / xe

La carte cible doit être le périphérique DRM dont :

```text
vendor = 0x8086
device = 0xe20b
```

Pour la charge GPU, Resource Monitor v28 sait rechercher les compteurs sysfs Intel :

```text
gpu_busy_percent
gt_busy_percent
```

Le module Golden reprend exactement cette frontière. Sur bare-metal :

- B580 absente → `KO` ;
- B580 présente + compteur de charge lisible → `PASS` ;
- B580 présente sans compteur de charge → `KO` ;
- température DRM hwmon absente mais charge valide → `WARN`.

Cette règle évite qu'une absence de télémétrie `xe` soit présentée comme un faux `0 %`.

Si le kernel/driver B580 ne publie finalement aucun de ces deux compteurs lors du GATE 3, le projet ne contournera pas le problème. Un backend Intel supplémentaire devra être qualifié séparément avant d'entrer dans le Golden.

## Réseau

Resource Monitor lit les compteurs réseau du système et affiche deux valeurs par interface :

```text
download | upload
```

Le GATE 2 VirtualBox doit prouver visuellement que ces valeurs changent lorsqu'un trafic réel est généré. Le GATE 3 confirme ensuite le comportement sur le LAN 5G/Wi-Fi de la workstation.

## Validation

Doctor dédié :

```bash
bash diagnostics/resource-monitor-doctor
```

Doctor GNOME global :

```bash
./diagnostics/gnome-doctor
```

Le doctor dédié vérifie :

- payload ;
- provenance GNOME review ;
- activation ;
- réglages GSettings ;
- CPU/RAM/réseau ;
- sur bare-metal, capteur Ryzen ;
- B580 `8086:e20b` ;
- source de charge B580 ;
- source de température B580 si exposée.

## GATE 2 VirtualBox

Dans le LAB GNOME :

```text
CPU % / RAM % / débit réseau     preuve visuelle requise
Température Ryzen physique       EXPECTED
Arc B580 charge/température      EXPECTED
```

Voir [`VIRTUALBOX_GNOME_LAB.md`](VIRTUALBOX_GNOME_LAB.md).

## GATE 3 bare-metal

Le GATE 3 exige `resource-monitor-doctor` sans KO. La télémétrie B580 n'est donc jamais considérée certifiée à partir d'une VM ou d'une CI.
