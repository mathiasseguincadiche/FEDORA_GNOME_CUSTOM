# GATE 2 — Fedora 44 GNOME sous VirtualBox

Ce document définit le **GATE 2 graphique officiel** utilisé après Gate 1 WSL2 et avant toute certification bare-metal.

La version applicable reste celle de [`../VERSION`](../VERSION). Gate 2 doit utiliser exactement le même commit Git et le même `module-plan` que Gate 1.

Le protocole complet est défini dans [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md).

## Objectif

Gate 2 valide de vraies fonctions desktop qui ne sont pas prouvables sous WSL2 ou en CI :

- Fedora 44 ;
- GNOME Shell 50 ;
- session Wayland ;
- GNOME core et portals ;
- Nautilus/GVfs/Sushi/File Roller ;
- Ptyxis et le socle GTK4/libadwaita géré ;
- contenu réel du dossier XDG `~/Bureau` rendu sur le fond d'écran ;
- Corbeille DING visible ;
- Home, volumes externes et volumes réseau masqués ;
- bouton **Afficher le bureau** dans la zone gauche du panneau supérieur ;
- clic gauche `toggle-desktop` ;
- raccourci `Super+D` ;
- restauration des fenêtres après un second toggle ;
- Resource Monitor visible dans la zone droite du panneau ;
- CPU, RAM et débit réseau lisibles en temps réel dans la VM ;
- persistance après déconnexion/reconnexion et reboot ;
- validation visuelle humaine explicite avant création de la preuve Gate 2.

La température CPU physique Ryzen et la télémétrie de la vraie Intel Arc B580 ne sont pas simulées dans VirtualBox : elles restent **EXPECTED** jusqu'au GATE 3 bare-metal.

La preuve Gate 2 porte donc toujours :

```text
hardware_certification=DEFERRED
manual_visual=PASS
```

## Prérequis : preuve Gate 1

Copier dans la VM la preuve produite sous WSL2 puis l'importer :

```bash
./control.sh validate import /chemin/gate1-<commit>.json
./control.sh validate gate2 status
```

L'import est refusé si le commit ou le `module-plan` ne correspond pas à la VM de Gate 2.

## Principe de sécurité

Le LAB reste un entrypoint séparé :

```bash
scripts/lab/apply-gnome-virtualbox.sh
```

Il ne contourne pas `lib/apply_gate.sh` et **`install.sh --apply reste interdit`** dans VirtualBox.

Le LAB est accepté uniquement si toutes les preuves suivantes concordent :

1. `runtime_environment=vm` ;
2. `systemd-detect-virt --vm` renvoie `oracle` ;
3. les informations DMI correspondent à VirtualBox/Oracle/innotek ;
4. Fedora Linux 44 est installé ;
5. GNOME Shell 50 est actif ;
6. la session courante est GNOME sous Wayland ;
7. l'exécution est faite par l'utilisateur graphique, jamais par root ;
8. une preuve Gate 1 actuelle a été importée avant la signature Gate 2.

Un simple override de variable d'environnement ne peut pas autoriser ce LAB : l'identité runtime est redétectée par `engine_bootstrap`.

## Surface autorisée

`--apply` peut uniquement converger le desktop de laboratoire :

- paquets GNOME core et XDG portals ;
- Nautilus, GVfs, Sushi, File Roller/Nautilus et service de préwarm utilisateur ;
- applications GTK4/libadwaita prévues par le projet, dont Ptyxis natif ;
- utilitaires `curl`, `unzip`, `xdg-user-dirs`, `glib2` ;
- boutons GNOME `minimize,maximize,close` à droite ;
- DING depuis l'artefact GNOME Extensions review `74408`, version de site `95`, UUID `ding@rastersoft.com`, compatible GNOME Shell 50 ;
- XDG Desktop vers `~/Bureau` ;
- Corbeille visible, Home/volumes externes/volumes réseau masqués ;
- Show Desktop Plus depuis l'artefact GNOME Extensions review `70326`, version de site `8`, UUID `show-desktop-plus@attentivecoder`, compatible GNOME Shell 50 ;
- `left-end`, `toggle-desktop`, `Super+D` et badge masqué ;
- Resource Monitor depuis l'artefact GNOME Extensions review `70909`, version de site `28`, UUID `Resource_Monitor@Ory0n`, compatible GNOME Shell 50 ;
- CPU, RAM, Ethernet/Wi-Fi et GPU guest activés, disque/swap masqués, rafraîchissement 2 s ;
- activation des trois extensions utilisateur ;
- doctors Nautilus, Ptyxis, portals et VirtualBox GNOME LAB ;
- marqueur LAB lié au commit après postchecks réussis.

DING, Show Desktop Plus et Resource Monitor sont installés depuis des **artefacts GNOME-reviewed pinés**.

## Surface interdite

Le LAB ne charge ni n'applique :

- kernel-vanilla ;
- firmware ou microcode ;
- pilote Arc/`xe` ou configuration/télémétrie GPU physique ;
- partitionnement, montage `/data`, SMART ou benchmark T705 ;
- KVM/libvirt, `devops-nat`, nftables ou firewalld ;
- sauvegarde Restic de production ;
- baseline hardware ;
- orchestrateur complet ;
- `apply_gate_open` ;
- `diagnostics/final-certification` ;
- `capture-golden-release.sh`.

Ces domaines restent exclusivement bare-metal.

## Commandes Gate 2

Afficher le périmètre :

```bash
./control.sh validate gate2 plan
```

Appliquer le LAB :

```bash
./control.sh validate gate2 apply
# moteur sous-jacent :
scripts/lab/apply-gnome-virtualbox.sh --apply
```

Si GNOME Shell ne voit pas immédiatement une extension nouvellement installée, se déconnecter/reconnecter puis relancer la même commande. L'opération est convergente.

Contrôles read-only :

```bash
./control.sh validate gate2 check
```

Ils exécutent notamment :

```text
diagnostics/virtualbox-gnome-lab-doctor
diagnostics/nautilus-integration-doctor
diagnostics/ptyxis-doctor
diagnostics/portal-doctor
```

Le doctor exige `KO=0`. Il confirme également que le REAL APPLY production et la baseline bare-metal restent bloqués dans VirtualBox.

## Checklist visuelle obligatoire

Après les checks automatisés sans KO :

1. créer `~/Bureau/FGC_GATE2_TEST.txt` et `~/Bureau/FGC_GATE2_DOSSIER/` ;
2. vérifier visuellement que le fichier et le dossier apparaissent sur le fond d'écran ;
3. vérifier que la Corbeille est visible ;
4. vérifier que Home et les volumes ne sont pas ajoutés au bureau ;
5. ouvrir Nautilus et naviguer dans plusieurs dossiers ;
6. confirmer prévisualisation/intégration archives selon le profil installé ;
7. lancer Ptyxis normalement depuis GNOME et vérifier son affichage ;
8. ouvrir trois fenêtres distinctes ;
9. cliquer sur Afficher le bureau : les fenêtres doivent être masquées ;
10. recliquer : les fenêtres doivent être restaurées ;
11. répéter avec `Super+D` ;
12. vérifier Resource Monitor : **CPU %**, **RAM %** et débit réseau ;
13. générer du trafic (`curl` ou téléchargement d'un paquet) et constater la variation download/upload ;
14. vérifier qu'aucune extension n'affiche d'erreur répétée et qu'il n'y a pas de régression visuelle évidente ;
15. accepter comme `EXPECTED` l'absence de température Ryzen physique et de métriques Arc B580 ;
16. se déconnecter/reconnecter et refaire les contrôles importants ;
17. rebooter la VM et refaire les contrôles importants ;
18. relancer `./control.sh validate gate2 check`.

Les contrôles de rendu, de toggle et de lisibilité sont des **preuves visuelles/comportementales** : la CI ne doit jamais les simuler ou les convertir en PASS automatique.

## Signature humaine Gate 2

Après la checklist :

```bash
./control.sh validate gate2 sign
```

Le script relance les doctors puis demande de taper exactement :

```text
JE_VALIDE_VISUELLEMENT_GATE2
```

La preuve créée contient le SHA-256 exact de la preuve Gate 1 importée dans `predecessor_sha256`.

## Classification des preuves

Dans VirtualBox :

- Fedora 44 / GNOME 50 / Wayland : **PASS** ;
- Nautilus/GVfs et Ptyxis : **PASS** ;
- DING / Show Desktop / XDG Desktop : **PASS** si réellement observés ;
- Resource Monitor installé/activé/configuré : **PASS** ;
- CPU %, RAM % et débit réseau du guest : **PASS** si observés ;
- contrôle visuel humain : **PASS** après signature ;
- température physique Ryzen `k10temp/Tctl` : **EXPECTED** ;
- Arc B580/`xe` charge/température/ReBAR/x8 : **EXPECTED** ;
- production APPLY bloqué : **PASS du garde-fou** ;
- baseline hardware bloquée : **PASS du garde-fou** ;
- T705 physiques : **EXPECTED** ;
- KVM host `qemu:///system` et `devops-nat` : **EXPECTED**.

Aucun élément hardware `EXPECTED` du GATE 2 ne peut être réutilisé comme preuve GATE 3.

## Export vers Gate 3

Exporter les deux preuves :

```bash
./control.sh validate export 1 /chemin/export
./control.sh validate export 2 /chemin/export
```

Gate 3 vérifiera que Gate 2 référence exactement le SHA-256 de Gate 1.

## GATE 3 — exigences physiques

Sur la vraie workstation, `bash diagnostics/resource-monitor-doctor` doit obtenir `KO=0`.

La cible B580 exacte `8086:e20b` doit être résolue dans `/sys/class/drm`. La charge GPU doit provenir d'un vrai compteur `gpu_busy_percent` ou `gt_busy_percent`. Si le kernel `xe` ne fournit pas l'un de ces compteurs sur la B580, le GATE 3 reste bloqué pour cette métrique : il faudra qualifier un backend Intel supplémentaire au lieu de fabriquer une valeur.

La suite est décrite dans [`THREE_GATE_VALIDATION.md`](THREE_GATE_VALIDATION.md).
