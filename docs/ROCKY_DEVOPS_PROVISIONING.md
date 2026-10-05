# Rocky Linux 10.2 — provisioning DevOps

## Objectif

`rocky-devops` doit être exploitable comme laboratoire DevOps/Ops après son premier démarrage, sans installer toute cette chaîne d'outils sur le HOST Fedora.

Le flux est :

```text
image cloud Rocky Linux 10.2
+ CHECKSUM
+ CHECKSUM.asc
        ↓
authentification Rocky Linux
        ↓
create_rocky_devops_vm.sh
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

Télécharger depuis la release Rocky Linux Cloud Images correspondante :

```text
Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2
CHECKSUM
CHECKSUM.asc
```

Les trois fichiers doivent appartenir à la même release. Source officielle : [images Rocky 10.2](https://dl.rockylinux.org/pub/rocky/10.2/images/x86_64/). Le CHECKSUM global signé peut contenir plusieurs images ; le vérificateur exige une seule ligne SHA-256 pour le nom choisi. Les alias latest, autres variantes et autres versions sont refusés.

Clé de production Rocky 10 : FC226859C0860BF0DDB95B085B106C736FEDFC85, publiée sur la [page officielle des clés](https://rockylinux.org/resources/gpg-key-info).

Le projet n'accepte pas une image uniquement à partir de son nom.

Test manuel avant création :

```bash
bash scripts/kvm/verify_rocky_cloud_image.sh \
  --image /data/libvirt/iso/Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2 \
  --sha256sums /data/libvirt/iso/CHECKSUM \
  --signature /data/libvirt/iso/CHECKSUM.asc
```

Le script épingle l'empreinte du signataire Rocky Linux attendue, vérifie la signature de la liste puis le SHA-256 de l'image.

## 2. Créer la VM

```bash
bash scripts/kvm/create_rocky_devops_vm.sh \
  --cloud-image /data/libvirt/iso/Rocky-10-GenericCloud-Base-10.2-20260525.0.x86_64.qcow2
```

Si `CHECKSUM` et `CHECKSUM.asc` sont dans le même dossier que l'image, ils sont découverts automatiquement.

La création échoue avant `qemu-img convert` si l'authentification ne passe pas.

## Sécurité du mot de passe

Le dépôt ne contient aucun mot de passe invité.

`create_rocky_devops_vm.sh` demande le mot de passe au terminal sans écho, génère immédiatement un hash SHA-512 avec `openssl passwd -6`, puis n'intègre que ce hash dans le seed cloud-init.

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
- Node.js ≥ 22 ;
- OpenJDK 21 + Maven ;
- Python 3, pip, venv et pipx ;
- SSH server, QEMU Guest Agent et rsync ;
- outils de diagnostic : `jq`, `shellcheck`, `dnsutils`, `traceroute`, `iproute2`, `netcat`, `htop`, `tmux`, `ripgrep`, etc.

## Sources du bootstrap

Le bootstrap utilise des canaux explicites :

- Docker — dépôt RPM officiel Docker pour EL10 ;
- GitHub CLI — dépôt RPM GitHub CLI ;
- Terraform — dépôt RPM HashiCorp pour EL10 ;
- Azure CLI — dépôt Microsoft ;
- kubectl — `pkgs.k8s.io` ;
- Helm — v4.3.0, archive amont + SHA-256 publié ;
- AWS CLI v2 — ZIP + signature détachée ;
- kind/Minikube/yq/K9s — releases précises avec contrôles de checksum selon leur contrat.

Aucun `curl | bash` n'est utilisé.

Les dépôts Docker/HashiCorp/Microsoft utilisent le canal natif Enterprise Linux 10. Aucun repli silencieux vers EL8/EL9. CRB et EPEL 10 complètent Rocky ; les signatures RPM restent requises. SELinux reste Enforcing.

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
sudo cat /var/lib/fedora-gnome-custom/rocky-devops-bootstrap.env
cloud-init status --long
systemctl status qemu-guest-agent
```

Depuis Fedora, la validation finale des invités est :

```bash
bash scripts/kvm/runtime_certification.sh
```

Pour les symptômes fréquents, utiliser [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md).
