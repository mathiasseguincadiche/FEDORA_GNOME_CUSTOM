# Accès aux fichiers des VM depuis GNOME / Nautilus

## Objectif

Permettre depuis Fedora 44 de parcourir, ouvrir, copier et glisser-déposer des fichiers des deux VM sans partager un répertoire HOST dans les invités.

Le design est volontairement asymétrique :

```text
Fedora / Nautilus
├── SFTP/SSH → ubuntu-devops → /home/mathias
└── SMB      → windows-11   → C:\VM-Share
```

## Ubuntu Server 26.04

`openssh-server` est installé par le bootstrap invité. Le helper HOST découvre l'adresse IPv4 courante via QEMU Guest Agent ou la lease DHCP libvirt, puis ajoute un favori Nautilus de la forme :

```text
sftp://mathias@192.168.50.x/home/mathias
```

Le backend SFTP est fourni par GVfs. L'accès conserve les permissions Linux réelles de `mathias` ; il n'accorde pas de privilèges supplémentaires sur `/root`, `/etc`, etc.

## Windows 11

La création de la VM génère un petit ISO local nommé `windows-guest-tools.iso`, attaché au guest avec le label `FGC_TOOLS`. Il contient `Configure-VMShare.ps1`.

Après l'installation de Windows :

1. ouvrir PowerShell **en administrateur** ;
2. repérer le CD `FGC_TOOLS` ;
3. exécuter `Configure-VMShare.ps1` depuis ce CD.

Le script :

- crée `C:\VM-Share` ;
- crée le partage SMB `VM-Share` pour l'utilisateur Windows courant ;
- n'active aucun accès invité/anonyme ;
- ouvre uniquement TCP/445 depuis `192.168.50.0/24` dans Windows Firewall.

Le helper HOST ajoute ensuite un favori de la forme :

```text
smb://192.168.50.x/VM-Share
```

Nautilus demandera les identifiants Windows lors de la première connexion. Aucun secret n'est enregistré dans Git par le projet.

## Helper HOST

```bash
bash scripts/kvm/configure_nautilus_vm_access.sh refresh
```

Commandes disponibles :

```text
install / refresh   détecte les IP et crée/met à jour les favoris
show                affiche les favoris gérés
remove              retire seulement les favoris gérés par le projet
open-ubuntu         ouvre Ubuntu DevOps dans Nautilus via SFTP
open-windows        ouvre Windows VM dans Nautilus via SMB
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
- aucune exposition globale du filesystem Windows ;
- pas de SMB invité/anonyme ;
- SSH reste la méthode d'administration principale d'Ubuntu ;
- SMB reste limité au partage `VM-Share` ;
- le réseau physique reste isolé par le contrat `devops-nat`.
