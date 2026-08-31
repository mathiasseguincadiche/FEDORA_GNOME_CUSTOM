# Ubuntu DevOps Ready — 0.10.0

La VM `ubuntu-devops` est un Ubuntu Server 26.04 dédié aux labs/projets DevOps, créé à la demande sur `qemu:///system` et stocké sur `/data`.

## Profil

- 6 vCPU `host-passthrough` ; 16 Gio RAM ; qcow2 160 Gio ; Q35 + UEFI ; VirtIO ;
- `devops-nat`, QEMU Guest Agent, VirtIO RNG, balloon ;
- aucun GPU passthrough et aucun autostart.

## Stack prête après le premier bootstrap

- Git/Git LFS, `gh`, `glab` ;
- Docker CE, Compose v2, Buildx, containerd ;
- kubectl **v1.37.x**, Helm, kind **v0.33.0**, Minikube **v1.38.1** avec driver Docker, K9s, kubectx/kubens, yq v4 ;
- Terraform, Ansible ;
- AWS CLI v2, Azure CLI ;
- Node.js 22 LTS, npm, Corepack ;
- OpenJDK 21, Maven ;
- Python 3/pip/venv/pipx, ShellCheck, jq, ripgrep, rsync, SSH, tmux et outils réseau.

Les identifiants GitHub/GitLab/AWS/Azure restent manuels : aucun token n'est embarqué.

## Authentification

Le script de création demande un mot de passe runtime afin de conserver un accès **console/sudo**. SSH est différent : `ssh_pwauth: false`, root désactivé et clé publique injectée par cloud-init. `verify-devops.sh` exige `PasswordAuthentication no` dans la configuration effective de `sshd`.

## Supply-chain

Aucun `curl | bash`.

- APT + dépôts signés pour Ubuntu/Docker/GitHub/HashiCorp/Azure/Kubernetes/Helm ;
- Kubernetes est figé sur la génération `v1.37` pour éviter un saut de minor silencieux ;
- kind v0.33.0 et Minikube v1.38.1 sont téléchargés depuis leur release précise et vérifiés avec les checksums publiés ;
- yq v4.53.3 et K9s v0.51.0 utilisent des SHA-256 attendus versionnés ;
- Helm vérifie l'empreinte de clé du dépôt ;
- AWS CLI v2 utilise `awscli-exe-linux-x86_64.zip` + `.sig`, vérifiée par `gpgv` avec la clé publique AWS et l'empreinte attendue `FB5D B77F D5C1 18B8 0511 ADA8 A631 0ACC 4672 475C`.

Voir aussi `docs/SUPPLY_CHAIN.md`.

## Création

```bash
scripts/kvm/create_ubuntu_devops_vm.sh \
  --cloud-image /chemin/ubuntu-26.04-server-cloudimg-amd64.img
```

Le bootstrap et le verify exacts du checkout host sont encodés dans cloud-init. Le premier démarrage exécute automatiquement `/usr/local/sbin/devops-bootstrap.sh`.

## Validation

Dans la VM :

```bash
sudo /usr/local/sbin/devops-verify.sh
```

Depuis Fedora :

```bash
scripts/kvm/runtime_certification.sh
```

Le workflow `Ubuntu 26.04 real VM pretest` authentifie une image Canonical, exécute le bootstrap exact, smoke-test Docker/Node/Java/Kubernetes/cloud/IaC, redémarre la VM et vérifie la persistance. Il tourne aussi chaque semaine afin de détecter une rupture de dépôt, clé, signature ou release externe.

## Accès aux fichiers

Fedora → Ubuntu reste en SSH/SFTP via Nautilus/GIO. Aucun partage host VirtioFS n'est introduit.
