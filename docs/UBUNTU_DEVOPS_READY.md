# Ubuntu DevOps Ready — 0.9.1

La VM `ubuntu-devops` est un environnement Ubuntu Server 26.04 dédié aux labs et projets DevOps. Elle est créée à la demande sur `qemu:///system`, stockée sur le pool `/data`, et bootstrapée automatiquement par cloud-init.

## Profil matériel virtuel

- 6 vCPU, CPU `host-passthrough` ;
- 16 Gio de RAM ;
- disque qcow2 160 Gio, VirtIO, `cache=none`, discard/unmap et backend I/O mesuré lorsque le benchmark T705 a été exécuté ;
- machine Q35 + UEFI ;
- réseau VirtIO sur `devops-nat` ;
- QEMU Guest Agent, VirtIO RNG et balloon mémoire ;
- aucun passthrough GPU ;
- aucun autostart par défaut.

## Stack prête au premier login

### Git et forges

- Git + Git LFS ;
- GitHub CLI `gh` ;
- GitLab CLI `glab`.

L'authentification aux comptes reste volontairement manuelle (`gh auth login`, `glab auth login`) : aucun token n'est embarqué dans l'image ou le dépôt.

### Containers et Kubernetes

- Docker CE ;
- Docker Compose v2 ;
- Buildx ;
- containerd ;
- kubectl ;
- Helm ;
- kind ;
- Minikube, avec `docker` configuré comme driver par défaut ;
- K9s ;
- kubectx + kubens ;
- `yq` Go v4.

`kind` et Minikube sont conservés ensemble : kind est adapté aux clusters rapides/CI, tandis que Minikube reste disponible pour les labs ou procédures qui l'exigent explicitement.

## Toolchains applicatives

### Angular / JavaScript

- Node.js 22 LTS fourni par Ubuntu 26.04 ;
- npm ;
- Corepack.

Les dépendances de projet restent locales au dépôt (`npm ci`, Corepack/pnpm/yarn selon le projet). Aucun framework JavaScript n'est installé globalement à l'aveugle.

### Java / Spring

- OpenJDK 21 JDK ;
- Maven.

Le bootstrap refuse de se déclarer terminé si Node.js est inférieur à 22 ou si `javac` n'est pas en version 21.

## Infrastructure / cloud / automatisation

- Terraform ;
- Ansible + ansible-playbook ;
- AWS CLI v2 ;
- Azure CLI ;
- Python 3, pip, venv et pipx ;
- ShellCheck, jq, ripgrep, rsync, SSH, tmux et outils réseau.

Les identifiants AWS/Azure/GitHub/GitLab ne sont jamais préchargés. Ils doivent être configurés par l'opérateur après création de la VM.

## Supply chain

Le bootstrap interdit les installations `curl | bash`.

- les toolchains Ubuntu sont installées via APT ;
- Docker, GitHub CLI, HashiCorp, Azure, Kubernetes et Helm utilisent leurs dépôts gérés ;
- Helm vérifie l'empreinte de clé attendue ;
- kind et Minikube vérifient leurs checksums de release ;
- `yq` et K9s sont épinglés sur une version et un SHA-256 attendus ;
- AWS CLI est téléchargé depuis l'installateur AWS sans exécution par pipe.

## Création

```bash
scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /chemin/ubuntu-26.04-server-cloudimg-amd64.img
```

Le script demande le mot de passe de la VM uniquement au runtime, injecte la clé SSH publique et les scripts bootstrap/verify via cloud-init, puis crée la VM sans autostart.

Le premier démarrage exécute automatiquement `/usr/local/sbin/devops-bootstrap.sh`.

## Validation

Dans la VM :

```bash
sudo /usr/local/sbin/devops-verify.sh
```

Depuis Fedora, la certification globale :

```bash
scripts/kvm/runtime_certification.sh
```

Le prétest CI `Ubuntu 26.04 real VM pretest` démarre une vraie image Canonical authentifiée, exécute le bootstrap exact du dépôt, vérifie toute la stack, lance un smoke Docker, exécute Node, compile/exécute Java, vérifie Minikube/K9s/yq/glab, redémarre la VM et exige que les outils restent disponibles après reboot.

## Accès aux fichiers

L'accès Fedora → Ubuntu reste SSH/SFTP via Nautilus/GIO. Aucun partage de répertoire hôte VirtioFS n'est ajouté au profil.
