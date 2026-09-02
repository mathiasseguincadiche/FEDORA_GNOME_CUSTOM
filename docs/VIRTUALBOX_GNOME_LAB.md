# VirtualBox GNOME LAB — GATE 2

Ce document définit le **mode de convergence graphique de laboratoire** utilisé pour valider Fedora 44 + GNOME 50 avant toute installation bare-metal.

La version applicable reste celle de [`../VERSION`](../VERSION). Les preuves doivent toujours être liées au SHA Git exact testé.

## Objectif

Le GATE 2 doit pouvoir vérifier de vraies fonctions GNOME qui ne sont pas prouvables sous WSL2 ou en CI :

- session GNOME 50 sous Wayland ;
- contenu réel du dossier XDG `~/Bureau` rendu sur le fond d'écran ;
- Corbeille DING visible ;
- Home, volumes externes et volumes réseau masqués ;
- bouton **Afficher le bureau** dans la zone gauche du panneau supérieur ;
- clic gauche `toggle-desktop` ;
- raccourci `Super+D` ;
- restauration des fenêtres après un second toggle ;
- Resource Monitor visible dans la zone droite du panneau ;
- CPU, RAM et débit réseau lisibles en temps réel dans le LAB ;
- persistance après déconnexion/reconnexion et reboot.

La température CPU physique Ryzen et la télémétrie de la vraie Intel Arc B580 ne sont pas simulées dans VirtualBox : elles restent **EXPECTED** jusqu'au GATE 3 bare-metal.

## Principe de sécurité

Le LAB est un entrypoint séparé :

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
7. l'exécution est faite par l'utilisateur graphique, jamais par root.

Un simple override de variable d'environnement ne peut pas autoriser ce LAB : l'identité runtime est redétectée par `engine_bootstrap`.

## Surface autorisée

`--apply` peut uniquement :

- installer les utilitaires `curl`, `unzip`, `xdg-user-dirs`, `glib2` dans la VM ;
- appliquer les boutons GNOME `minimize,maximize,close` à droite ;
- installer DING depuis l'artefact GNOME Extensions review `74408`, version de site `95`, UUID `ding@rastersoft.com`, compatible GNOME Shell 50 ;
- converger XDG Desktop vers `~/Bureau` ;
- afficher la Corbeille et masquer Home/volumes externes/volumes réseau ;
- installer Show Desktop Plus depuis l'artefact GNOME Extensions review `70326`, version de site `8`, UUID `show-desktop-plus@attentivecoder`, compatible GNOME Shell 50 ;
- configurer `left-end`, `toggle-desktop`, `Super+D` et masquer le badge ;
- installer Resource Monitor depuis l'artefact GNOME Extensions review `70909`, version de site `28`, UUID `Resource_Monitor@Ory0n`, compatible GNOME Shell 50 ;
- configurer le panneau Resource Monitor : CPU, RAM, Ethernet/Wi-Fi et GPU activés ; disque/swap masqués ; rafraîchissement 2 s ;
- activer les trois extensions utilisateur dans la session ;
- écrire un marqueur LAB lié au commit après doctor réussi.

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
- `apply_gate_open`.

Ces domaines restent exclusivement bare-metal.

## Commandes

Afficher le périmètre sans mutation :

```bash
scripts/lab/apply-gnome-virtualbox.sh --plan
```

Appliquer le LAB :

```bash
scripts/lab/apply-gnome-virtualbox.sh --apply
```

Si GNOME Shell ne voit pas immédiatement une extension nouvellement installée, se déconnecter/reconnecter puis relancer **la même commande `--apply`**. L'opération est convergente.

Contrôle read-only :

```bash
scripts/lab/apply-gnome-virtualbox.sh --check
# ou directement
diagnostics/virtualbox-gnome-lab-doctor
```

Le doctor exige `KO=0`. Il confirme également que le REAL APPLY production et la baseline bare-metal restent bloqués dans VirtualBox.

## Checklist visuelle obligatoire

Après un doctor sans KO :

1. créer `~/Bureau/FGC_GATE2_TEST.txt` et `~/Bureau/FGC_GATE2_DOSSIER/` ;
2. vérifier visuellement que le fichier et le dossier apparaissent sur le fond d'écran ;
3. vérifier que la Corbeille est visible ;
4. vérifier que Home et les volumes ne sont pas ajoutés au bureau ;
5. ouvrir trois fenêtres distinctes ;
6. cliquer sur le bouton Afficher le bureau en haut à gauche : les fenêtres doivent être masquées ;
7. recliquer : les fenêtres doivent être restaurées ;
8. répéter avec `Super+D` ;
9. vérifier dans la zone droite du panneau que Resource Monitor affiche le **CPU %** et la **RAM %** ;
10. générer du trafic réseau (par exemple téléchargement d'un paquet ou `curl`) et vérifier que les valeurs **download | upload** changent sur l'interface active ;
11. vérifier que les indicateurs disque et swap ne surchargent pas le panneau ;
12. accepter comme `EXPECTED` l'absence de température Ryzen physique et de métriques Arc B580 dans VirtualBox ; ne jamais signer ces deux métriques comme PASS dans le LAB ;
13. se déconnecter/reconnecter et refaire les contrôles ;
14. rebooter la VM et refaire les contrôles ;
15. relancer `diagnostics/virtualbox-gnome-lab-doctor` et conserver le log final.

Les contrôles de rendu du bureau, de toggle et de lisibilité Resource Monitor sont des **preuves visuelles/comportementales** : la CI ne doit jamais les simuler ou les convertir en PASS automatique.

## Classification des preuves

Dans VirtualBox :

- Fedora 44 / GNOME 50 / Wayland / DING / Show Desktop / XDG Desktop : **PASS** si réellement observés ;
- Resource Monitor installé, activé et correctement configuré : **PASS** ;
- CPU %, RAM % et débit réseau du guest : **PASS** si réellement observés ;
- température physique Ryzen `k10temp/Tctl` : **EXPECTED** ;
- Arc B580/`xe` charge/température : **EXPECTED** ;
- production APPLY bloqué : **PASS du garde-fou** ;
- baseline hardware bloquée : **PASS du garde-fou** ;
- T705 physiques : **EXPECTED** ;
- KVM host `qemu:///system` et `devops-nat` : **EXPECTED**.

Aucun élément hardware `EXPECTED` du GATE 2 ne peut être réutilisé comme preuve GATE 3.

## GATE 3 — exigence Resource Monitor

Sur la vraie workstation, `bash diagnostics/resource-monitor-doctor` doit obtenir `KO=0`.

La cible B580 exacte `8086:e20b` doit être résolue dans `/sys/class/drm`. La charge GPU doit provenir d'un vrai compteur `gpu_busy_percent` ou `gt_busy_percent`. Si le kernel `xe` ne fournit pas l'un de ces compteurs sur la B580, le GATE 3 reste bloqué pour cette métrique : il faudra alors qualifier un backend Intel supplémentaire au lieu de fabriquer une valeur.
