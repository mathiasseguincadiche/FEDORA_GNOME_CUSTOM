# Laboratoire Fedora/GNOME sur GitHub

Ce prétest fonctionne exclusivement sur un runner GitHub jetable. Il ne lance
aucune commande sur le PC de l'opérateur. Le job réutilisable
`.github/workflows/fedora-gnome-vm.yml` est appelé par `Tests` à chaque push/PR.
Le contexte obligatoire `contracts` attend sa réussite, ainsi que les deux
jobs Fedora existants. La publication attend donc aussi ce laboratoire.

## Image et démarrage

L'image Fedora Cloud Base 44 compose 1.7 est verrouillée dans
`.github/fedora44-cloud.lock` par nom et SHA-256. Son CHECKSUM est vérifié par
la seule clé Fedora 44 dont l'empreinte est épinglée. Un changement de média
demande une modification revue de ce verrou.

Sources officielles :
[Fedora Cloud](https://www.fedoraproject.org/cloud/download/) et
[empreinte Fedora 44](https://fedoraproject.org/security/).

QEMU démarre un disque autonome, UEFI OVMF, TPM logiciel swtpm et un GPU virtio.
L'accélération disponible est enregistrée ; TCG permet l'émulation lorsque
KVM est absent. Les limites de temps restent bloquantes. GitHub indique que
la virtualisation imbriquée est techniquement possible mais non officiellement
prise en charge : [documentation des runners](https://docs.github.com/en/actions/concepts/runners/github-hosted-runners).
Le laboratoire ne nécessite aucun runner installé chez l'utilisateur.

GNOME 50 est installé sur Fedora Cloud, puis lancé par GDM en session Wayland
réelle. L'autologin et les réglages empêchant la veille sont propres à cette
image éphémère. SELinux reste enforcing et firewalld actif. Les trois extensions
DING, Show Desktop Plus et Resource Monitor utilisent l'installateur de
production et les artefacts/hash du verrou existant.

## Exercices et critères

| Exercice | Résultat requis |
|---|---|
| Média | Signature de la clé Fedora 44 + paire nom/SHA exacte |
| Démarrage | Fedora 44, SSH, cloud-init terminé, identité du boot enregistrée |
| GNOME | GDM, Shell 50, session logind Wayland active, bus Shell, extensions ACTIVE, processus Nautilus/Ptyxis et portal |
| Redémarrage | Identifiant du boot différent, GNOME et données/TPM persistants |
| Fichiers Borg | Vrai moteur du projet, dépôt non chiffré, archive exacte vérifiée ; roundtrip quotidien existant rejoué dans Fedora |
| Archive VM à froid | QEMU et swtpm arrêtés avant capture ; disque sans backing, NVRAM et TPM inclus ; vérification intégrale Borg et comparaison des membres |
| VM récupérée | Démarrage des fichiers extraits, GNOME, données, canary TPM NV identique, réseau restrict=on |
| Fedora reconstruit | Seconde image neuve, réinstallation indépendante de GNOME, données absentes avant extraction ; archive exacte restaurée en staging puis fichiers de test remis et comparés |

Le réseau de récupération utilise `restrict=on` avec un seul port SSH sur
127.0.0.1. QEMU interdit les connexions sortantes et conserve ce canal de
contrôle explicite : [documentation réseau QEMU](https://www.qemu.org/docs/master/system/invocation.html).
Le test refuse une connexion sortante réussie. La VM originale est arrêtée et
son dossier déplacé avant de démarrer la copie récupérée.

## Rapports

L'artefact `fedora-gnome-boot-recovery-<run_id>` conserve 14 jours :

- `report.json` : commit du code exact, étapes, quatre identifiants de boot,
  archive/id, hash du disque et de la NVRAM, chiffrement et isolation ;
- consoles QEMU, sorties installation/restauration et signature du média ;
- journaux complets du boot, du noyau et de l'utilisateur, unités en échec,
  inventaire des paquets et sessions pour chaque étape.

Un crash enregistré par systemd-coredump ou un message journal de priorité
critique bloque le test. Les autres messages restent disponibles pour analyse.
Une lecture de journal en échec reste un échec. Aucun PASS n'est écrit si une
étape manque ou si un redémarrage conserve le même identifiant de boot.
Les clés SSH, user-data, disques et dépôts Borg ne sont pas publiés en artefact.

## Portée des preuves

Le rapport porte `scope=fedora-gnome-qemu-pretest`. Il n'écrit aucun fichier
de certification officiel. Restent explicitement DEFERRED :

- Gate 1 WSL2 et Gate 2 VirtualBox avec contrôle visuel humain ;
- Gate 3 et matériel physique Ryzen/B580/T705/écran ;
- APPLY complet de production et démarrage du noyau CachyOS ;
- restauration des VM Ubuntu/Windows de production, UUID/libvirt/réseau,
  TPM Windows et éventuels logiciels associés.

Le noyau du laboratoire reste celui de Fedora Cloud. Installer GNOME sur une
image Cloud n'exerce pas l'installateur Anaconda/Kickstart du média Workstation.
La reconstruction vérifie les fichiers de test et GNOME ; elle ne démontre
pas la restauration de tous les paquets, jeux ou services de la workstation.

Le [runbook de reprise isolée](ISOLATED_RECOVERY_RUNBOOK.md) et
[les trois gates](THREE_GATE_VALIDATION.md) définissent les essais opérateur
restants sur le même commit. Un PASS CI conserve toutes ces limites.
