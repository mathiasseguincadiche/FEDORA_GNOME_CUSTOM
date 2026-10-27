# Accès aux fichiers des VM depuis GNOME / Nautilus

## Objectif

Permettre depuis Fedora 45 de parcourir, ouvrir, copier et glisser-déposer des fichiers de la VM Rocky Linux sans partager un répertoire HOST dans les invités.

Le parcours utilise le service SSH de Rocky Linux :

```text
Fedora / Nautilus
└── SFTP/SSH → rocky-devops → /home/mathias
```

## Rocky Linux 10.2

`openssh-server` est installé par le bootstrap invité. Le helper HOST découvre l'adresse IPv4 courante via QEMU Guest Agent ou la lease DHCP libvirt, puis ajoute un favori Nautilus de la forme :

```text
sftp://mathias@192.168.50.x/home/mathias
```

Le backend SFTP est fourni par GVfs. L'accès conserve les permissions Linux réelles de `mathias` ; il n'accorde pas de privilèges supplémentaires sur `/root`, `/etc`, etc.

## Helper HOST

```bash
bash scripts/kvm/configure_nautilus_vm_access.sh refresh
```

Commandes disponibles :

```text
install / refresh   détecte l’IP de Rocky et crée/met à jour son favori
show                affiche le favori géré
remove              retire seulement le favori Rocky géré par le projet
open-rocky          ouvre Rocky DevOps dans Nautilus via SFTP
```

Le fichier de favoris utilisé est :

```text
$XDG_CONFIG_HOME/gtk-3.0/bookmarks
```

avec fallback :

```text
~/.config/gtk-3.0/bookmarks
```

Si une adresse DHCP change, il suffit de relancer `refresh`. Aucun nom d'interface Ethernet/Wi-Fi n'est codé en dur.

## Sécurité

- aucune réintroduction de VirtioFS ;
- SSH reste la méthode d’administration principale de Rocky Linux ;
- le réseau physique reste isolé par le contrat `devops-nat`.
