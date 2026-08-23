# Ubuntu Server 26.04 — provisioning DevOps

## Objectif

`ubuntu-devops` doit être immédiatement exploitable comme laboratoire DevOps/Ops après son premier démarrage, sans installer cette chaîne d'outils sur le HOST Fedora.

Le flux est :

```text
image cloud Ubuntu Server 26.04
        ↓
create_ubuntu_devops_vm.sh
        ↓
cloud-init + utilisateur mathias + clé SSH
        ↓
/usr/local/sbin/devops-bootstrap.sh
        ↓
stack DevOps complète
        ↓
/usr/local/sbin/devops-verify.sh
```

## Sécurité du mot de passe

Le dépôt ne contient aucun mot de passe invité.

`create_ubuntu_devops_vm.sh` demande le mot de passe au terminal sans écho, génère immédiatement un hash SHA-512 avec `openssl passwd -6`, puis n'intègre que ce hash dans le seed cloud-init. La clé SSH reste la méthode d'administration normale.

## Logiciels installés

Le bootstrap est idempotent et couvre :

- Git et GitHub CLI `gh` ;
- Docker Engine, Docker CLI, containerd, Buildx et Compose plugin ;
- Ansible / ansible-core ;
- Terraform ;
- Azure CLI ;
- AWS CLI v2 ;
- kubectl ;
- Helm ;
- kind ;
- Python 3, pip, venv et pipx ;
- SSH server, qemu-guest-agent et rsync ;
- outils de diagnostic : `jq`, `shellcheck`, `dnsutils`, `traceroute`, `iproute2`, `netcat`, `htop`, `tmux`, `ripgrep`, etc.

## Sources

Le bootstrap utilise des canaux explicites :

- Docker : dépôt APT officiel Docker ;
- GitHub CLI : dépôt APT GitHub CLI ;
- Terraform : dépôt APT HashiCorp ;
- Azure CLI : dépôt Microsoft ;
- kubectl : `pkgs.k8s.io` ;
- Helm : dépôt Debian actuel hébergé par Buildkite avec vérification de l'empreinte de clé ;
- AWS CLI v2 : installateur hébergé par AWS, téléchargé dans un fichier avant exécution ;
- kind : release GitHub avec vérification SHA-256.

Aucun `curl | bash` n'est utilisé.

Ubuntu 26.04 étant récent, Docker/HashiCorp/Azure sont sondés sur le codename courant ; si un éditeur ne publie pas encore ce canal, le bootstrap utilise explicitement la suite de compatibilité `noble` et l'annonce dans le log.

## VirtioFS

```text
HOST : /data/libvirt/shared
tag  : hostshare
VM   : /mnt/hostshare
```

Le bootstrap ajoute un montage `virtiofs` `nofail` dans `/etc/fstab`. La VM est créée avec un memory backing `memfd` partagé, requis par VirtioFS.

## Vérification

Dans la VM :

```bash
sudo /usr/local/sbin/devops-verify.sh
```

Le contrôle vérifie les CLIs, Docker, qemu-guest-agent, le groupe Docker, le montage VirtioFS et le marqueur de bootstrap.

Logs :

```bash
sudo cat /var/log/devops-bootstrap.log
sudo cat /var/lib/fedora-gnome-custom/ubuntu-devops-bootstrap.env
cloud-init status --long
```
