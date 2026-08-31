# Ubuntu Server 26.04 — provisioning DevOps

## Objectif

`ubuntu-devops` doit être exploitable comme laboratoire DevOps/Ops après son premier démarrage, sans installer toute cette chaîne d'outils sur le HOST Fedora.

Le flux est :

```text
image cloud Ubuntu Server 26.04
+ SHA256SUMS
+ SHA256SUMS.gpg
        ↓
authentification Canonical
        ↓
create_ubuntu_devops_vm.sh
        ↓
cloud-init + utilisateur mathias + clé SSH
        ↓
/usr/local/sbin/devops-bootstrap.sh
        ↓
stack DevOps
        ↓
/usr/local/sbin/devops-verify.sh
```

## 1. Préparer l'image officielle

Télécharger depuis la release Ubuntu Cloud Images correspondante :

```text
ubuntu-26.04-server-cloudimg-amd64.img
SHA256SUMS
SHA256SUMS.gpg
```

Les trois fichiers doivent appartenir à la même release.

Le projet n'accepte pas une image uniquement à partir de son nom.

Test manuel avant création :

```bash
bash scripts/kvm/verify_ubuntu_cloud_image.sh \
  --image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img \
  --sha256sums /data/libvirt/iso/SHA256SUMS \
  --signature /data/libvirt/iso/SHA256SUMS.gpg
```

Le script épingle l'empreinte du signataire Canonical attendue, vérifie la signature de la liste puis le SHA-256 de l'image.

## 2. Créer la VM

```bash
bash scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img
```

Si `SHA256SUMS` et `SHA256SUMS.gpg` sont dans le même dossier que l'image, ils sont découverts automatiquement.

La création échoue avant `qemu-img convert` si l'authentification ne passe pas.

## Sécurité du mot de passe

Le dépôt ne contient aucun mot de passe invité.

`create_ubuntu_devops_vm.sh` demande le mot de passe au terminal sans écho, génère immédiatement un hash SHA-512 avec `openssl passwd -6`, puis n'intègre que ce hash dans le seed cloud-init.

SSH reste key-only :

```text
ssh_pwauth: false
root désactivé
clé publique injectée
```

Le mot de passe reste destiné à la console et à `sudo`.

## Logiciels installés

Le bootstrap couvre notamment :

- Git/Git LFS, GitHub CLI `gh` et GitLab CLI `glab` ;
- Docker Engine, Docker CLI, containerd, Buildx et Compose plugin ;
- Ansible ;
- Terraform ;
- Azure CLI ;
- AWS CLI v2 ;
- kubectl ;
- Helm ;
- kind ;
- Minikube ;
- K9s, kubectx/kubens, yq ;
- Node.js 22 LTS ;
- OpenJDK 21 + Maven ;
- Python 3, pip, venv et pipx ;
- SSH server, QEMU Guest Agent et rsync ;
- outils de diagnostic : `jq`, `shellcheck`, `dnsutils`, `traceroute`, `iproute2`, `netcat`, `htop`, `tmux`, `ripgrep`, etc.

## Sources du bootstrap

Le bootstrap utilise des canaux explicites :

- Docker — dépôt APT officiel Docker ;
- GitHub CLI — dépôt APT GitHub CLI ;
- Terraform — dépôt APT HashiCorp ;
- Azure CLI — dépôt Microsoft ;
- kubectl — `pkgs.k8s.io` ;
- Helm — dépôt Debian avec vérification d'empreinte ;
- AWS CLI v2 — ZIP + signature détachée ;
- kind/Minikube/yq/K9s — releases précises avec contrôles de checksum selon leur contrat.

Aucun `curl | bash` n'est utilisé.

Ubuntu 26.04 étant récent, les dépôts éditeurs sont sondés sur le codename courant. Lorsqu'un éditeur ne publie pas encore ce canal mais documente une suite de compatibilité acceptée par le projet, le fallback est explicite et apparaît dans les logs.

## Premier boot

Le seed cloud-init contient le bootstrap/verify exacts du checkout qui crée la VM.

Contrôler :

```bash
cloud-init status --long
sudo cat /var/log/devops-bootstrap.log
```

Puis :

```bash
sudo /usr/local/sbin/devops-verify.sh
```

## Accès depuis Fedora

Administration :

```bash
ssh mathias@<ip-ou-nom-de-la-vm>
sftp mathias@<ip-ou-nom-de-la-vm>
```

Dans Nautilus :

```text
sftp://mathias@<ip-ou-nom-de-la-vm>/home/mathias
```

Aucun partage de répertoire HOST↔VM n'est configuré automatiquement.

## Logs utiles

```bash
sudo cat /var/log/devops-bootstrap.log
sudo cat /var/lib/fedora-gnome-custom/ubuntu-devops-bootstrap.env
cloud-init status --long
systemctl status qemu-guest-agent
```

Depuis Fedora, la validation finale des invités est :

```bash
bash scripts/kvm/runtime_certification.sh
```

Pour les symptômes fréquents, utiliser [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).
