# Virtualisation — référence KVM et Rocky DevOps

Pour l'usage quotidien et le dépannage, voir le [démarrage KVM](KVM_QUICKSTART.md). Ce document décrit l'architecture, le profil Rocky DevOps et ce qui est vérifié. Les valeurs exécutables viennent de `config/virtualization.conf` et `config/vm-profiles.conf` ; une contradiction entre ces fichiers, les scripts et ce document est un bug.

## Architecture

```text
Fedora 45 (HOST)
├── KVM / QEMU / libvirt : qemu:///system
│   ├── domaine rocky-devops
│   ├── pool devops-data → /data/libvirt/images
│   └── réseau devops-nat → virbr50 → 192.168.50.0/24
├── second T705, /data EXT4
│   ├── Documents/  Projets/  ISO/  Jeux/  IA/Openclaw/   (utilisateur, 0750, user_home_t)
│   └── libvirt/ images/ iso/ cloud-init/ nvram/ snapshots/ exports/   (virt_image_t)
└── Intel Arc B580 → reste au HOST, pilote xe
```

- **Matériel** : AMD-V/SVM, `/dev/kvm` et `kvm_amd` obligatoires sur le PC. Démons libvirt modulaires de Fedora (`virtqemud`, `virtnetworkd`, `virtstoraged`, `virtlogd`, `virtlockd`), `libvirtd` seulement en repli.
- **GPU** : aucun VFIO ni passthrough. Rocky s'administre par console série et SSH, sans affichage ; le contrat 2560×1440/~240 Hz du HOST reste prioritaire.
- **Stockage** : le projet ne partitionne ni ne formate jamais le second T705. `/data/ISO` est une bibliothèque utilisateur ; seuls les médias placés dans `/data/libvirt/iso` sont exposés à QEMU. Pool `devops-data`, type `dir`, autostart. Les VM utilisent le profil I/O mesuré par `kvm-io-doctor benchmark` (sur un fichier, jamais sur le disque brut), avec `cache=none` et `discard=unmap`.
- **Réseau** : `devops-nat`, `virbr50`, `192.168.50.0/24`, passerelle `192.168.50.254`, DHCP `192.168.50.100-200`, DNS 9.9.9.9 et 1.1.1.1, NAT IPv4, zone firewalld `libvirt`. HOST↔VM, VM↔VM et VM→Internet autorisés ; VM→LAN et LAN→VM bloqués ; aucun forwarding implicite depuis Internet. Quand l'uplink change, le guard passe d'abord en mode d'urgence, puis reconstruit les règles ; si cela échoue, l'état restrictif reste actif. Détails : [réseau KVM](KVM_NETWORK.md).
- **Fichiers** : accès Fedora → Rocky par SFTP/SSH uniquement ; aucun partage HOST↔VM (pas de VirtioFS).

## Profil `rocky-devops`

Un seul invité de référence, déclaratif, jamais créé pendant `install.sh --apply`.

```text
OS                 Rocky Linux 10.2
vCPU               6 (host-passthrough)
RAM                16 Gio
disque             160 Gio qcow2, VirtIO
machine            Q35, UEFI, sans TPM
réseau             VirtIO sur devops-nat
QEMU Guest Agent   oui
VirtIO RNG         oui
balloon            oui
graphique          aucun requis
SSH                clé publique uniquement, root désactivé
utilisateur        mathias (mot de passe saisi à la création, pour console et sudo)
autostart          non
```

Sur le HOST de 8 cœurs / 16 threads et 48 Gio, il reste environ 32 Gio avant la consommation du système et des applications. Rocky 10 exige un CPU x86-64-v3 : `host-passthrough` expose les capacités du Ryzen 7 7700 ; un modèle CPU générique sans AVX2 l'empêcherait de démarrer. Le noyau de l'invité est celui de Rocky (EL10) ; le suivi Linux amont N/N-1 ne concerne que le HOST.

## Image source authentifiée

Préparer dans le même dossier, depuis la [release officielle Rocky 10.2](https://dl.rockylinux.org/pub/rocky/10.2/images/x86_64/) :

```text
Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2
CHECKSUM
CHECKSUM.asc
```

`scripts/kvm/verify_rocky_cloud_image.sh` récupère la clé Rocky 10, compare son empreinte à la valeur épinglée (`FC226859C0860BF0DDB95B085B106C736FEDFC85`, [page officielle des clés](https://rockylinux.org/resources/gpg-key-info)), vérifie la signature de `CHECKSUM`, exige une seule ligne SHA-256 pour l'image choisie, puis vérifie l'image. Les alias `latest`, les autres variantes et versions sont refusés : une image n'est jamais acceptée sur son seul nom. `create_rocky_devops_vm.sh` fait ce contrôle avant `qemu-img convert`.

Le mot de passe demandé à la création n'est jamais affiché ni stocké : seul son hash SHA-512 (`openssl passwd -6`) entre dans le seed cloud-init, avec `ssh_pwauth: false`. Le compte garde un sudo authentifié ; aucun sudo sans mot de passe n'est provisionné.

## Provisioning

```text
image authentifiée → create_rocky_devops_vm.sh → cloud-init (utilisateur, clé SSH)
   → /usr/local/sbin/devops-bootstrap.sh → stack DevOps → /usr/local/sbin/devops-verify.sh
```

Le seed embarque le bootstrap et le verify **exacts** du checkout qui crée la VM. Stack installée :

- Git/Git LFS, `gh`, `glab` ; Docker CE, Compose, Buildx, containerd ;
- kubectl v1.37.x, Helm v4.3.0, kind v0.33.0, Minikube v1.38.1 (driver Docker), K9s v0.51.0, kubectx/kubens v0.11.0, yq v4.53.3 ;
- Terraform, Ansible, AWS CLI v2, Azure CLI ;
- Node.js ≥ 22, OpenJDK 21, Maven, Python 3, pip, venv, pipx ;
- SSH, QEMU Guest Agent, rsync, ShellCheck, jq, ripgrep, tmux, outils réseau.

Provenance : dépôts RPM signés pour Rocky/EPEL 10/CRB, Docker, GitHub CLI, HashiCorp, Microsoft et `pkgs.k8s.io`, sur le canal EL10 natif sans repli EL8/EL9 ; archives versionnées avec SHA-256 pour Helm, kind, Minikube, yq, K9s et kubectx (absent d'EPEL 10.2) ; AWS CLI avec signature détachée vérifiée. Aucun `curl | bash`, SELinux Enforcing. Aucun identifiant GitHub/GitLab/AWS/Azure n'est embarqué : ils se saisissent à la main. Voir la [provenance des logiciels](SUPPLY_CHAIN.md).

**Noyau de l'invité.** L'image Cloud Base a un noyau minimal ; le bootstrap installe le noyau Rocky complet avant Docker. Si le noyau par défaut diffère du noyau chargé, le bootstrap sort en 75 sans marqueur de réussite et `fgc-devops-bootstrap.service` redémarre l'invité puis reprend. Un noyau qui ne démarre pas bloque la reprise au lieu de boucler. `cloud-init status` seul ne prouve donc rien : vérifier `systemctl status fgc-devops-bootstrap.service`, `/var/log/devops-bootstrap.log`, puis `devops-verify.sh`.

**Marqueur de provisioning.** `/var/lib/fedora-gnome-custom/rocky-devops-bootstrap.env` est écrit atomiquement à la fin. `devops-verify-bootstrap-marker.py` exige tous ses champs, refuse doublons, clés inattendues et dates invalides, et recoupe Rocky 10.2, la version Kubernetes, kind et Minikube avec le contrat. Le fichier n'est jamais exécuté ni sourcé ; binaires, services et réseau Docker sont vérifiés à part.

## Réseau Docker

Docker 29 stable utilise son backend iptables, qui charge `nft_compat` et `ip_set`. Le noyau EL10 signale ces modules par « Warning: Unmaintained driver is detected » en priorité critique. Le laboratoire garde ces notices et les marque `kernel_compatibility=WARNING` ; seules les quatre notices exactes (origine noyau, priorité 2) sont acceptées, tout autre message, erreur critique ou coredump bloque. Le backend nftables natif reste [expérimental selon Docker](https://docs.docker.com/engine/network/firewall-nftables/) et n'est pas activé ([notes RHEL 10.2](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html-single/10.2_release_notes/index)).

### Qualification réseau Docker

Un bridge interne, la résolution DNS d'un alias et une requête HTTP entre deux conteneurs, plus un port publié sur 127.0.0.1 seulement. Les ressources jetables sont étiquetées et supprimées même en cas d'erreur ; aucun réseau applicatif existant n'est touché.

```bash
docker pull busybox:1.37.0
image_id="$(docker image inspect --format '{{.Id}}' busybox:1.37.0)"
/usr/local/sbin/devops-verify-docker-network.sh "$image_id"
```

Le script n'utilise que le socket Docker local avec `--pull=never` et journalise l'ID et les RepoDigests utilisés. Il ne valide ni Swarm, ni les CNI Kubernetes, ni le débit physique. Un test réussi ne rend pas les modules EL10 maintenus.

## Ce qui est vérifié

| Où | Quoi |
|---|---|
| `diagnostics/virtualization-doctor` | KVM, libvirt, outils CLI, stockage, SELinux, OVMF, swtpm, réseau et isolation |
| `diagnostics/kvm-domain-doctor` | XML Rocky conforme au profil ci-dessus, aucun `hostdev` |
| `devops-verify.sh` (dans l'invité) | stack, services, `PasswordAuthentication no` effectif |
| `scripts/kvm/runtime_certification.sh` | domaine, Guest Agent, XML VirtIO/RNG/balloon, IP, SSH, stack, DNS/HTTPS, guard et isolement LAN |
| CI « Rocky Linux 10.2 real VM pretest » | image authentifiée, bootstrap exact, smoke tests, reboot, sauvegarde Borg de qcow2/NVRAM/seed, restauration et redémarrage isolé (`restrict=on`) |

Une preuve complète LAN → VM demande un second appareil du LAN ([réseau KVM](KVM_NETWORK.md)). La CI ne certifie aucun périphérique physique ; la qualification Rocky précède la [Gate 3](QUALIFICATION.md).

## Exports des VM

Les exports sont manuels, quand le propriétaire le décide : arrêter Rocky, puis conserver ensemble disque (autonome ou chaîne de backing complète), XML et NVRAM UEFI. Ni Borg, ni le centre de contrôle, ni la mise à niveau Fedora ne copient les disques QCOW2 ou le XML libvirt. Une reprise se vérifie sur une copie isolée ([reprise isolée](ISOLATED_RECOVERY_RUNBOOK.md)). `/data/Documents`, `/data/Projets` et `/data/IA/Openclaw` sont dans Borg ; `/data/ISO` et `/data/Jeux` non.

## Interdictions

- formater ou partitionner automatiquement le second T705, supprimer automatiquement une racine `/data`, `chmod 777` ;
- désactiver SELinux ou firewalld ;
- bridge physique automatique, VFIO/passthrough de la B580, IPv6 KVM sans isolation dual-stack certifiée ;
- créer une VM pendant `install.sh --apply`, télécharger un média OS automatiquement, autostart d'un invité ;
- mot de passe invité dans Git, interface réseau codée en dur, partage VirtioFS automatique.

## Venir d'une ancienne VM Ubuntu

Il n'y a pas de conversion en place. Garder l'ancienne VM arrêtée avec son XML, ses disques et sa NVRAM ; ne pas renommer un disque Ubuntu en Rocky (le nouveau nom de domaine évite l'écrasement). Transférer les données applicatives par SSH/SFTP, jamais `/etc`, `/usr` ou la base de paquets ; vérifier UID/GID et propriétaires des volumes ; recréer environnements Python, images et clusters avec leurs outils. Retirer toute clé `UBUNTU_SERVER_*` de `config/local.conf` (le validateur la refuse). Si une IP est réutilisée, ne mettre à jour que l'entrée `known_hosts` de cette VM, après comparaison de la nouvelle clé. Certifier Rocky avant de retirer l'ancienne VM.
