# Troubleshooting — runbook opérationnel

Ce document part des **symptômes**. L'objectif est de diagnostiquer avant de modifier le système.

Règles générales :

- ne pas désactiver SELinux pour contourner un problème ;
- ne pas désactiver firewalld ;
- ne pas supprimer les règles nftables KVM au hasard ;
- ne pas ajouter `force_probe`, ASPM/APST/C-State ou sleep-mode global sans preuve ;
- ne pas reformater `/data` pour corriger un problème libvirt ;
- conserver les logs avant toute remédiation importante.

## 1. `install.sh --apply` est refusé

### Ce que cela signifie

L'APPLY possède plusieurs gates. Un refus est normalement une protection, pas une panne de l'installateur.

### Vérifier

```bash
git status --short
git rev-parse HEAD
./diagnostics/baseline-doctor status
./install.sh --dry-run
```

Puis vérifier qu'un backup pré-APPLY du même commit existe :

```bash
./prepare-preapply-backup.sh
```

Enfin, sur la machine réelle uniquement, vérifier `config/local.conf` :

```text
REAL_MACHINE_APPROVED=true
```

### Causes courantes

- environnement WSL2/VM/conteneur au lieu du bare-metal ;
- dépôt Git modifié ;
- dry-run absent ou lié à un autre commit ;
- baseline RAM/NVMe incomplète ;
- backup Restic absent/invalide ;
- Secure Boot actif alors que Kernel Vanilla est demandé ;
- approbation réelle non activée ;
- confirmation interactive incorrecte.

Ne contourner aucun de ces gates en éditant un marker à la main.

---

## 2. DNF ou un dépôt RPM échoue

### Diagnostic de base

```bash
dnf repolist
dnf check
dnf repoquery --available bash
```

Pour RPM Fusion :

```bash
dnf repolist | grep -i rpmfusion
```

Pour inspecter les fichiers de repos gérés :

```bash
ls -l /etc/yum.repos.d/
```

### Si VS Code ou Brave n'est pas installable

Vérifier d'abord le dépôt et la résolution du paquet au lieu de télécharger un RPM arbitraire depuis un site tiers.

```bash
dnf repoquery --available code
dnf repoquery --available brave-browser
```

Le preflight Fedora 44 CI valide aussi ces dépôts. Une rupture externe peut donc être un problème éditeur temporaire.

---

## 3. Flatpak ou une application Flathub manque

```bash
flatpak remotes
flatpak list
```

Vérifier Flathub :

```bash
flatpak remote-info flathub <APP_ID>
```

Les mises à jour Flatpak sont manuelles par contrat :

```bash
flatpak update
```

L'absence d'un timer d'update Flatpak automatique est normale.

---

## 4. Codecs, vidéo ou accélération multimédia

Lancer :

```bash
./diagnostics/media-doctor
```

Puis :

```bash
vainfo
ffmpeg -decoders | grep -Ei 'h264|hevc|av1|vp9'
```

Le projet choisit le pilote média Intel à partir des capacités mesurées. Ne remplacer `libva-intel-media-driver` par un autre fournisseur uniquement parce qu'un forum le recommande.

Si VA-API fonctionne et expose H.264/HEVC/AV1/VP9, le fournisseur courant doit généralement être conservé.

---

## 5. GNOME, portail ou application Flatpak dysfonctionne

Lancer :

```bash
./diagnostics/gnome-doctor
./diagnostics/portal-doctor
./diagnostics/applications-doctor
```

Vérifier la session :

```bash
echo "$XDG_SESSION_TYPE"
gnome-shell --version
```

Le contrat attendu est Wayland.

Pour les portals :

```bash
systemctl --user status xdg-desktop-portal.service
systemctl --user status xdg-desktop-portal-gnome.service
```

Ne basculer pas globalement vers X11 pour masquer un défaut Wayland/GPU sans diagnostic.

---

## 6. Dash to Dock / AppIndicator / dock incorrect

Le profil courant utilise **Dash to Dock et AppIndicator**.

```bash
./diagnostics/gnome-doctor
./diagnostics/applications-doctor
```

Inspecter les extensions :

```bash
gnome-extensions list --enabled
```

Le dock certifié est :

```text
Nautilus → Brave → Ptyxis → VS Code → Bitwarden → Slack → LibreOffice → GNOME Software
```

Blur My Shell et Just Perfection ne font pas partie de l'état Golden certifié par défaut.

---

## 7. Arc B580 non détectée ou rendu instable

Le fonctionnement attendu est :

```text
PCI        8086:e20b
pilote     xe
```

Lancer :

```bash
./diagnostics/kernel-doctor
./diagnostics/firmware-doctor
./diagnostics/graphics-doctor
./diagnostics/arc-compute-doctor
```

Puis :

```bash
lspci -nnk | grep -A4 -Ei 'VGA|Display'
journalctl -k -b | grep -Ei 'xe|drm|firmware|AER|PCIe'
```

Ne pas ajouter `xe.force_probe` ou `i915.force_probe`. Le projet exige le support normal du matériel par la pile courante.

---

## 8. Affichage ou polices dégradés après veille/power-cycle écran

Ne modifier pas Fontconfig en premier.

```bash
./diagnostics/graphics-doctor
./diagnostics/display-doctor
./diagnostics/gnome-doctor
journalctl -k -b | grep -Ei 'xe|drm|AER|PCIe'
```

Le display recovery traite ce symptôme comme un problème possible de chaîne DRM/KMS/Mutter/link et réapplique le profil 2560×1440/~240 Hz, scale 1.0, SDR/default et Full RGB.

Comparer avec la preuve suspend/resume correspondante.

---

## 9. Réveil de veille incorrect

```bash
./diagnostics/suspend-doctor
./diagnostics/usb-resume-doctor
cat /sys/power/mem_sleep
```

Inspecter :

```bash
journalctl -k -b | grep -Ei 'xe|drm|xhci|usb|nvme|AER|PCIe|ACPI'
```

Ne forcer `deep`, `s2idle`, ASPM ou APST qu'après reproduction et analyse ciblée.

Après correction/reboot, les anciennes preuves ne suffisent pas : les cycles doivent être enregistrés à nouveau avec :

```bash
./diagnostics/final-certification record-suspend
```

---

## 10. Redémarrage inexpliqué / crash

```bash
./scripts/collect-boot-failure.sh
journalctl -b -1 -p warning..alert
coredumpctl list
```

Inspecter également :

```bash
journalctl -k -b -1 | grep -Ei 'panic|Oops|watchdog|MCE|EDAC|AER|PCIe|nvme|xe|drm|thermal'
```

Conserver le rapport du collecteur avant de modifier kernel/firmware.

---

# KVM / libvirt

## 11. `virtualization-doctor` échoue immédiatement

```bash
./diagnostics/virtualization-doctor
```

Vérifier :

```bash
ls -l /dev/kvm
lsmod | grep kvm
virsh --connect qemu:///system list --all
```

Sur cette plateforme, `kvm_amd` doit être présent.

Si libvirt ne répond pas :

```bash
systemctl status virtqemud.socket
systemctl status virtnetworkd.socket
systemctl status virtstoraged.socket
```

Si les daemons modulaires ne sont pas présents, le projet peut utiliser le fallback `libvirtd.socket`; ne lancer pas simultanément une migration manuelle improvisée entre les deux modèles.

---

## 12. `/data` ou le pool `devops-data` est absent

Vérifier le montage :

```bash
findmnt /data
findmnt -no SOURCE,FSTYPE,TARGET /data
lsblk -f
```

Attendu :

```text
/data
EXT4
second NVMe physique
```

Le projet refuse de partitionner/formater ce SSD automatiquement.

Vérifier le pool :

```bash
virsh --connect qemu:///system pool-info devops-data
virsh --connect qemu:///system pool-list --all
```

Vérifier SELinux :

```bash
ls -Zd /data/libvirt /data/libvirt/images
semanage fcontext -l | grep '/data/libvirt'
```

Ne corriger pas avec `chmod 777`.

---

## 13. `devops-nat` est absent ou inactif

```bash
virsh --connect qemu:///system net-list --all
virsh --connect qemu:///system net-info devops-nat
virsh --connect qemu:///system net-dumpxml devops-nat
```

Attendu :

```text
Active:    yes
Autostart: yes
bridge:    virbr50
network:   192.168.50.0/24
```

Vérifier le bridge :

```bash
ip addr show virbr50
```

Vérifier la zone firewalld :

```bash
firewall-cmd --get-zone-of-interface=virbr50
```

Attendu :

```text
libvirt
```

---

## 14. Le guard KVM est en mode `emergency`

Vérifier :

```bash
sudo /usr/local/libexec/fedora-gnome-custom/kvm-network-guard check
sudo nft list table inet fedora_gnome_custom_kvm
systemctl status fedora-gnome-custom-kvm-guard.service
journalctl -u fedora-gnome-custom-kvm-guard.service -b --no-pager
```

`guard_mode=emergency` signifie que le projet a préféré **couper le forwarding des VM** plutôt que conserver une isolation potentiellement obsolète.

Causes typiques :

- réseau `192.168.50.0/24` en conflit avec le LAN courant ;
- uplink par défaut détecté mais aucun réseau directement connecté exploitable ;
- erreur nftables ;
- changement de connectivité incomplet.

Vérifier les routes :

```bash
ip -4 route
ip -4 route show scope link
```

Puis demander une reconstruction :

```bash
sudo systemctl reload fedora-gnome-custom-kvm-guard.service
sudo /usr/local/libexec/fedora-gnome-custom/kvm-network-guard check
```

Le résultat attendu est :

```text
guard_mode=normal
```

Ne supprimer pas la table pour récupérer Internet dans la VM : cela supprimerait justement la barrière de sécurité.

Voir [`KVM_NETWORK.md`](KVM_NETWORK.md).

---

## 15. La VM Ubuntu n'a pas d'adresse IP

Vérifier que la VM est démarrée :

```bash
virsh --connect qemu:///system domstate ubuntu-devops
```

Interfaces :

```bash
virsh --connect qemu:///system domiflist ubuntu-devops
```

Adresse via Guest Agent :

```bash
virsh --connect qemu:///system domifaddr ubuntu-devops --source agent
```

Fallback DHCP :

```bash
virsh --connect qemu:///system net-dhcp-leases devops-nat
```

Si aucune lease n'existe, vérifier `devops-nat` avant de modifier la configuration réseau Ubuntu.

---

## 16. Ubuntu n'a plus Internet mais le HOST en a

D'abord vérifier le mode du guard :

```bash
sudo /usr/local/libexec/fedora-gnome-custom/kvm-network-guard check
```

Si :

```text
guard_mode=emergency
```

la coupure Internet VM est **volontaire** jusqu'à résolution du recalcul réseau.

Si le guard est normal :

```bash
virsh --connect qemu:///system net-info devops-nat
virsh --connect qemu:///system net-dhcp-leases devops-nat
```

Dans Ubuntu :

```bash
ip route
getent ahostsv4 example.com
curl -I https://example.com
```

Puis exécuter depuis Fedora :

```bash
bash scripts/kvm/runtime_certification.sh
```

---

## 17. La création Ubuntu refuse l'image cloud

Le profil exige maintenant l'authentification Canonical.

Conserver dans le même dossier :

```text
ubuntu-26.04-server-cloudimg-amd64.img
SHA256SUMS
SHA256SUMS.gpg
```

Tester séparément :

```bash
bash scripts/kvm/verify_ubuntu_cloud_image.sh \
  --image /data/libvirt/iso/ubuntu-26.04-server-cloudimg-amd64.img \
  --sha256sums /data/libvirt/iso/SHA256SUMS \
  --signature /data/libvirt/iso/SHA256SUMS.gpg
```

Un échec peut signifier :

- fichiers de releases différentes mélangés ;
- image corrompue ;
- signature invalide ;
- keyserver indisponible ;
- clé locale incorrecte.

Pour une vérification hors ligne, fournir une clé Canonical obtenue par un canal de confiance avec `--key-file` ou `--canonical-key-file` selon le script appelé.

Ne contourner pas ce contrôle en renommant une autre image.

---

## 18. Le bootstrap Ubuntu ne termine pas

Dans la VM :

```bash
cloud-init status --long
sudo cat /var/log/devops-bootstrap.log
sudo cat /var/lib/fedora-gnome-custom/ubuntu-devops-bootstrap.env
```

Puis :

```bash
sudo /usr/local/sbin/devops-verify.sh
```

Distinguer :

- panne réseau/DNS ;
- dépôt éditeur temporairement indisponible ;
- signature/checksum externe modifié ;
- outil réellement non installé.

Le workflow Ubuntu 26.04 réel est également exécuté périodiquement en CI pour détecter les ruptures externes.

---

## 19. SSH Ubuntu refuse le mot de passe

C'est **normal**.

Le mot de passe runtime sert à la console et à `sudo`. SSH est key-only.

Vérifier la clé publique utilisée lors de la création puis :

```bash
ssh -v mathias@<ip-ubuntu>
```

Dans Ubuntu, la configuration effective doit conserver :

```text
PasswordAuthentication no
```

Ne l'activer pas pour contourner un problème de clé.

---

## 20. Windows ne voit pas le disque ou le réseau VirtIO

Pendant l'installation, `virtio-win.iso` doit être attaché.

Après installation, ouvrir `FGC_TOOLS` et exécuter PowerShell **en administrateur** :

```text
Configure-GuestIntegration.ps1
```

Le script installe les pilotes trouvés sur le média VirtIO et QEMU Guest Agent, puis refuse de valider si un périphérique VirtIO reste en erreur.

Depuis Fedora :

```bash
bash scripts/kvm/runtime_certification.sh
```

---

## 21. Nautilus ne voit plus Ubuntu/Windows

Rafraîchir les favoris :

```bash
bash scripts/kvm/configure_nautilus_vm_access.sh refresh
bash scripts/kvm/configure_nautilus_vm_access.sh show
```

Le helper découvre d'abord l'IP via Guest Agent, puis via DHCP libvirt.

Ubuntu utilise SFTP. Windows utilise SMB uniquement si `Configure-VMShare.ps1` a été exécuté.

Voir [`VM_FILE_ACCESS.md`](VM_FILE_ACCESS.md).

---

# Backup / Restore

## 22. `prepare-preapply-backup.sh` refuse de continuer

Vérifier :

```bash
git status --short
git rev-parse HEAD
./install.sh --dry-run
./diagnostics/backup-doctor
```

Le backup pré-APPLY exige notamment :

- dry-run réussi du même commit ;
- cible Restic externe/remote prouvée ;
- passphrase protégée ;
- espace disponible ;
- intégrité Restic ;
- restauration réelle du canary.

Un simple `restic backup` terminé ne suffit pas à produire le marker de confiance.

---

## 23. Le backup des VM est refusé

```bash
virsh --connect qemu:///system list --all
```

Avec `--include-vms`, toutes les VM concernées doivent être `shut off`.

```bash
scripts/backup/backup-now.sh --include-vms
```

Le projet refuse volontairement la copie live d'un QCOW2.

---

## 24. Restaurer sans écraser le système live

Lister :

```bash
scripts/backup/restore.sh list
```

Vérifier :

```bash
scripts/backup/restore.sh verify
```

Restaurer vers staging :

```bash
scripts/backup/restore.sh restore latest
```

Inspecter le staging avant toute copie manuelle vers `/etc`, `/boot`, `$HOME` ou `/data`.

Voir [`BACKUP_RESTORE.md`](BACKUP_RESTORE.md).

---

# Collecte minimale avant de demander de l'aide

Pour un problème système général, conserver au minimum :

```bash
git rev-parse HEAD
cat /etc/os-release
uname -a
./diagnostic.sh
```

Pour KVM :

```bash
./diagnostics/virtualization-doctor
virsh --connect qemu:///system list --all
virsh --connect qemu:///system net-list --all
virsh --connect qemu:///system pool-list --all
sudo /usr/local/libexec/fedora-gnome-custom/kvm-network-guard check
```

Pour GPU/affichage :

```bash
./diagnostics/graphics-doctor
./diagnostics/display-doctor
journalctl -k -b | grep -Ei 'xe|drm|AER|PCIe'
```

Pour un reboot/crash :

```bash
./scripts/collect-boot-failure.sh
```

Le commit Git doit toujours accompagner les rapports : les diagnostics et les corrections du projet évoluent avec la version du dépôt.
