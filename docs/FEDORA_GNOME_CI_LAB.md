# Laboratoire Fedora/GNOME sur GitHub

Ce prétest fonctionne exclusivement sur un runner GitHub jetable. Il ne lance
aucune commande sur le PC de l'opérateur. Le job réutilisable
`.github/workflows/fedora-gnome-vm.yml` est appelé par `Tests` sur les push vers `main` et les pull requests.
Le contexte obligatoire `contracts` attend sa réussite, celle de la suite
rapide `logic-contracts` et des deux jobs Fedora existants. La publication attend donc aussi ce laboratoire.

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
KVM est absent. Les limites de temps restent bloquantes. Le disque virtuel du
fixture est limité à 10 Gio ; sa capacité maximale plus 2 Gio de réserve doit
tenir sur le runner avant chaque création. Les captures à froid dimensionnent
l'espace d'après les tailles logiques des membres. L'original CI est supprimé
après vérification Borg avant extraction, puis la copie et le dépôt jetables
sont supprimés après le boot récupéré, avant reconstruction. Ces contrôles
évitent de retenir plusieurs générations de disques jusqu'au pic de stockage. GitHub indique que
la virtualisation imbriquée est techniquement possible mais non officiellement
prise en charge : [documentation des runners](https://docs.github.com/en/actions/concepts/runners/github-hosted-runners).
Le laboratoire ne nécessite aucun runner installé chez l'utilisateur.

GNOME 50 est installé sur Fedora Cloud, puis lancé par GDM en session Wayland
réelle. L'autologin et les réglages empêchant la veille sont propres à cette
image éphémère. Avant chaque arrêt/redémarrage, le laboratoire attend que
GNOME retire lui-même son marqueur de protection d'initialisation (environ
une minute), puis revérifie session, réglages persistants et extensions actives.
La session se ferme par `gnome-session-quit --logout --no-prompt`, puis GDM
s'arrête avant le redémarrage/arrêt système. Le rapport exige
`session_shutdown=gnome-logout`.
Il ne supprime jamais ce marqueur et ne réactive pas les extensions pour
faire réussir un redémarrage. Le journal persistant permet aussi de refuser
un crash ou une erreur critique sur le boot précédent, y compris à l'arrêt.
Ce scénario ne qualifie pas un redémarrage précipité pendant la première
minute d'initialisation, ni un reboot direct avec `systemctl` pendant que
le bureau est ouvert. Ce dernier chemin a produit des timeouts d'arrêt de
GNOME Shell et SIGABRT dans le laboratoire ; le contrôle du boot précédent
les a rendus bloquants. Il reste à qualifier sur les autres environnements.
Aucun timeout de GNOME, mécanisme de protection ni contrôle des coredumps
n'est affaibli pour faire réussir ce parcours. SELinux reste enforcing et firewalld actif. Les trois extensions
DING, Show Desktop Plus et Resource Monitor utilisent l'installateur de
production et les artefacts/hash du verrou existant. Les ZIP sont téléchargés
avec TLS strict par le runner, vérifiés puis transférés dans la VM ; le même
installateur revérifie leur hash et leurs métadonnées depuis ce cache absolu.
Aucun téléchargement non authentifié ni option curl insecure n'est utilisé.

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
son dossier jetable supprimé après vérification de l'archive et avant de démarrer
la copie récupérée. Cette suppression concerne uniquement les données de test CI.
Les originaux de production restent conservés selon le runbook opérateur.

## Rapports

L'artefact `fedora-gnome-boot-recovery-<run_id>` conserve 14 jours :

- `report.json` : commit du code exact, étapes, quatre identifiants de boot,
  archive/id, hash du disque et de la NVRAM, chiffrement, isolation et méthode de fermeture de session ;
- consoles QEMU, sorties installation/restauration et signature du média ;
- journaux complets du boot et des boots précédents, du noyau et de l'utilisateur, unités en échec,
  inventaire des paquets et sessions pour chaque étape.

Un crash enregistré par systemd-coredump, un message journal de priorité
critique ou une unité système/utilisateur en échec bloque le test. Les autres messages restent disponibles pour analyse.
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

Le check obligatoire `contracts` s'exécute avec `always()` puis contrôle
explicitement que chacun des quatre jobs a conclu `success`. Un job dépendant
simplement sauté peut être accepté comme check requis par GitHub ; ici tout
`skipped`, `failure` ou `cancelled` produit un véritable échec du check agrégé.
Voir [les conditions GitHub](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-jobs-with-conditions).
