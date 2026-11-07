# Exporter une VM Rocky et vérifier sa reprise en laboratoire

> Mise à jour : 2026-11-06 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-06 — profil `rocky-devops`, stockage, cloud-init et métadonnées recoupés avec `scripts/kvm/create_rocky_devops_vm.sh`, `config/vm-profiles.conf` et la politique Borg ; **export/import de VM non rejoués** — matériel : non vérifié

**But :** disposer d'une copie indépendante de la VM, puis prouver que ses composants permettent de démarrer une **autre instance isolée**, sans toucher au domaine d'origine. Cette procédure concerne le profil actuel `rocky-devops`, géré par libvirt `qemu:///system` sur Fedora ; elle ne suppose pas que tout projet de VM possède ce même profil.

Le **centre de contrôle n'automatise pas les exports** : `./control.sh backup now` et Borg excluent délibérément les disques, XML, NVRAM et médias cloud-init des VM. Ce geste est volontairement manuel, décidé par l'opérateur. Voir les [règles de sauvegarde](BACKUP_RESTORE.md#exports-de-vm), le [démarrage KVM](KVM_QUICKSTART.md) et la [reprise isolée générale](ISOLATED_RECOVERY_RUNBOOK.md).

## Résumé d'exécution

- [ ] Machine virtuelle identifiée, démarrage de production préservé, arrêt propre constaté
- [ ] Support de destination externe, chiffré et assez grand, monté et vérifié
- [ ] Définition XML, disque autonome, NVRAM et ISO cloud-init inventoriés
- [ ] Copie hors ligne terminée ; intégrité, contenu et empreintes vérifiés
- [ ] Copie transférée sur un **hôte libvirt de laboratoire distinct** et sans réseau de production
- [ ] VM de laboratoire démarrée deux fois, contenu contrôlé, preuves conservées

**Préconditions :** outils `virsh`, `qemu-img`, `sha256sum`, accès à `sudo`, espace suffisant pour les données **réelles** du disque invité et son export, support externe distinct de `/data` et du SSD système. Une image qcow2 de capacité virtuelle 160 Gio peut occuper moins de place sur disque, mais la conversion doit pouvoir s'étendre : ne pas se fier à la seule taille apparente. Ne jamais partager publiquement une image, son cloud-init ou une définition XML contenant des informations d'environnement.

## 1. Identifier la VM et constater son arrêt

Sur **l'hôte Fedora d'origine** :

```bash
sudo virsh --connect qemu:///system list --all
sudo virsh --connect qemu:///system dominfo rocky-devops
sudo virsh --connect qemu:///system domblklist rocky-devops --details
sudo virsh --connect qemu:///system dumpxml --inactive rocky-devops
```

Le profil créé par le projet utilise normalement le disque `/data/libvirt/images/rocky-devops.qcow2` et un ISO cloud-init sous `/data/libvirt/cloud-init/rocky-devops/seed.iso`. **Ces chemins sont des valeurs issues du code, pas une autorisation à les supposer corrects sur la machine actuelle** : la sortie de `domblklist` et les éléments `<source>`, `<nvram>` et `<tpm>` du XML font foi.

Faire arrêter proprement l'invité :

```bash
sudo virsh --connect qemu:///system shutdown rocky-devops
sudo virsh --connect qemu:///system domstate rocky-devops
```

L'arrêt peut être asynchrone. Répéter **uniquement** `domstate` jusqu'à lire `shut off`. Si la VM ne s'arrête pas, interrompre l'export et diagnostiquer le système invité. **Ne pas copier le qcow2 d'une VM active, ne pas utiliser `virsh destroy` pour accélérer cette procédure et ne pas supprimer des snapshots.**

## 2. Préparer une destination indépendante et sûre

Choisir un **support externe chiffré**, déverrouillé et monté sur un chemin stable, accessible également à `sudo` (pas un montage d'interface invisible au service libvirt). Adapter l'exemple :

```bash
VM_EXPORT_MOUNT="/chemin/absolu/du/support-externe-chiffre"
mountpoint -q -- "$VM_EXPORT_MOUNT" && findmnt --target "$VM_EXPORT_MOUNT"
lsblk -f                # identifier le vrai support et son volume chiffré
df -h -- "$VM_EXPORT_MOUNT"
```

**Arrêt** si le point de montage n'est pas dédié, s'il n'est pas chiffré, si sa capacité est insuffisante, si les chemins ne correspondent pas à l'inventaire ou si la VM est encore active. Aucun fichier d'export ne doit être écrit dans le dépôt Git ou sur le qcow2 source.

Après validation **humaine** des préconditions :

```bash
umask 077
VM_EXPORT_DIR="$VM_EXPORT_MOUNT/rocky-devops-$(date +%Y%m%d-%H%M%S)"
mkdir -- "$VM_EXPORT_DIR"   # création refusée si ce nom existe déjà

# Le XML exporté décrit la VM arrêtée, y compris UUID et chemins des ressources.
sudo virsh --connect qemu:///system dumpxml --inactive rocky-devops \
  > "$VM_EXPORT_DIR/rocky-devops.xml"

# Relever les membres réels ; ne pas copier un chemin deviné.
grep -nE '<(name|uuid|disk|source|nvram|tpm|interface|filesystem|hostdev)' \
  "$VM_EXPORT_DIR/rocky-devops.xml"
```

**À conserver ensemble pour le même instant d'arrêt :** XML du domaine, contenu du ou des disques, NVRAM UEFI propre à la VM, médias cloud-init encore attachés et, **uniquement si ajouté par l'opérateur**, état TPM/swtpm exact. Le profil Rocky standard du dépôt ne crée pas de TPM émulé. Si le XML contient un TPM, arrêter le parcours standard : son état doit être inventorié et copié avec les méthodes adaptées **à la version de libvirt/swtpm présente sur l'hôte**, sans supposer un chemin fixe ni certifier une copie incomplète.

## 3. Exporter un disque qcow2 autonome, hors ligne

Relire dans `domblklist` le fichier **source**, puis le reporter explicitement ici :

```bash
# Chemin lu dans le XML/virsh, exemple du profil actuel à contrôler.
VM_DISK_SOURCE="/data/libvirt/images/rocky-devops.qcow2"
sudo qemu-img info --backing-chain "$VM_DISK_SOURCE"
sudo qemu-img check "$VM_DISK_SOURCE"
```

Une *backing chain* est une suite de disques dépendants les uns des autres. Exporter uniquement son dernier élément ferait perdre les blocs présents dans les images parentes. Le `qemu-img convert` suivant lit le disque **et sa chaîne** pour produire un **qcow2 autonome de l'état courant**, sans recopier les historiques de snapshots comme objets réutilisables :

```bash
# Écriture sur le support d'export uniquement ; source arrêtée et non modifiée.
sudo qemu-img convert -p -O qcow2 \
  "$VM_DISK_SOURCE" "$VM_EXPORT_DIR/rocky-devops.qcow2"

# Comparaison du contenu logique, puis intégrité de la nouvelle image.
sudo qemu-img compare -f qcow2 -F qcow2 \
  "$VM_DISK_SOURCE" "$VM_EXPORT_DIR/rocky-devops.qcow2"
sudo qemu-img check "$VM_EXPORT_DIR/rocky-devops.qcow2"
sudo qemu-img info --backing-chain "$VM_EXPORT_DIR/rocky-devops.qcow2"
```

**Réussite :** comparaison sans différence, `qemu-img check` sain et export n'affichant **aucun fichier de backing externe**. Si la conversion ou la comparaison échoue, ne pas qualifier l'export. Ne jamais effacer les fichiers sources pour gagner de l'espace après un échec.

## 4. Compléter l'export et sceller son inventaire

Relever la **vraie** source NVRAM dans la balise `<nvram>` du XML. Si elle est présente, copier ce fichier **sans le remplacer par une NVRAM d'une autre VM** :

```bash
# À REMPLACER après lecture du XML : ne pas utiliser un chemin supposé.
VM_NVRAM_SOURCE="/chemin/reel/lu-dans-la-balise-nvram"
sudo install -m 0600 -- "$VM_NVRAM_SOURCE" \
  "$VM_EXPORT_DIR/rocky-devops-nvram.fd"
```

Pour le média cloud-init encore référencé par le XML, copier la **source réellement déclarée** (le profil courant utilise `.../seed.iso`) :

```bash
VM_SEED_SOURCE="/data/libvirt/cloud-init/rocky-devops/seed.iso"
sudo install -m 0600 -- "$VM_SEED_SOURCE" \
  "$VM_EXPORT_DIR/rocky-devops-seed.iso"
```

Ces deux commandes sont **conditionnelles** : adapter les sources d'après le XML et vérifier leur présence avant la copie. Une NVRAM requise mais absente, un média attaché manquant ou un TPM non traité **bloque** la déclaration d'un export complet. Le média cloud-init peut contenir des informations sensibles ; garder le support chiffré hors ligne après contrôle.

Créer un inventaire de tous les membres exportés **dans le dossier nouvellement créé**, sans y glisser d'autres données :

```bash
(
  cd "$VM_EXPORT_DIR" || exit 1
  find . -maxdepth 1 -type f ! -name MANIFEST.sha256 -print0 \
    | xargs -0 sudo sha256sum -- > MANIFEST.sha256
  sudo sha256sum --check MANIFEST.sha256
)
```

Vérifier que la liste contient **tous** les membres attendus, puis conserver le rapport du contrôle et les informations de version/UUID/heure d'arrêt. Un `sha256sum --check` réussi garantit que les fichiers exportés n'ont pas changé depuis le manifeste ; il ne garantit **pas** que l'invité démarre. Ce dernier point exige l'étape suivante.

## 5. Restaurer et tester sur un autre hôte libvirt

**Environnement obligatoire : laboratoire isolé**, distinct de l'hôte de production. Ne pas définir une copie sous le même UUID sur l'hôte où tourne l'original ; ne jamais lancer un clone avec les interfaces, partages ou périphériques de production. Avant toute écriture :

1. Monter le support chiffré sur l'hôte de laboratoire, relancer `sha256sum --check` depuis le dossier exporté et confirmer le manifeste : `cd /chemin/du/dossier-export && sudo sha256sum --check MANIFEST.sha256`. **Remplacer ce chemin** par le montage réel ; interrompre la suite au premier échec.
2. Vérifier `virsh --connect qemu:///system list --all`, le pool de stockage **de laboratoire**, les droits de libvirt, SELinux et la capacité. Choisir des chemins **neufs**, sans fichier de VM à écraser.
3. Copier le qcow2 autonome dans le pool de laboratoire. Copier la NVRAM et, si nécessaire, l'ISO cloud-init aux emplacements **autorisés par cet hôte**. Examiner puis corriger propriétaires, permissions et labels avec `stat`, `ls -Z` et `restorecon` sur **ces seules copies**.
4. Faire une copie de `rocky-devops.xml` sous un **nouveau nom** de fichier, puis y adapter le nom du domaine, son UUID si requis par la coexistence, tous les chemins de fichiers et surtout les éléments réseau. **Retirer les interfaces réseau**, les partages de l'hôte, les passthrough et toute référence de production. Ne jamais éditer l'original.
5. Contrôler le XML modifié avec `virt-xml-validate /chemin/du/rocky-devops-lab.xml`, puis relire les balises `<interface>`, `<filesystem>`, `<hostdev>`, `<disk>` et `<nvram>`. Si le projet ne peut pas garantir l'absence de toute sortie réseau, **ne pas définir ni démarrer** la copie.
6. Après validation manuelle du fichier et de ses chemins, définir la VM **sur le laboratoire seulement** avec `sudo virsh --connect qemu:///system define /chemin/du/rocky-devops-lab.xml`. Cette commande **modifie l'inventaire libvirt du laboratoire** ; elle n'est pas une commande de précontrôle.
7. Démarrer depuis l'hôte isolé avec `sudo virsh --connect qemu:///system start NOM_DU_DOMAINE_LAB`, utiliser la console de l'invité, contrôler le système et plusieurs fichiers témoins, puis l'arrêter proprement et refaire un second démarrage.

**Conditions de réussite :** fichiers exacts et cohérents, pas de backing externe non exporté, disque/NVRAM rattachés au bon domaine, démarrage réel de la copie, données accessibles, second redémarrage réussi et **aucune sortie vers le LAN ou Internet de production**. Conserver les journaux de démarrage et les traces de vérification. Ne pas interpréter un simple `virsh define` réussi comme un PRA validé.

## En cas d'échec et limites

| Défaillance | Mesure immédiate et diagnostic |
| --- | --- |
| VM encore active | **Ne rien copier** ; attendre un arrêt propre, puis revérifier `domstate` |
| Backing chain, disque ou NVRAM manquant | Stopper la certification de l'export ; retrouver les membres à la même date d'arrêt |
| Comparaison qcow2 ou manifeste en échec | Préserver l'original, diagnostiquer le support et l'espace, créer un nouvel export au lieu d'écraser l'ancien |
| XML de laboratoire contient une interface/partage de production | **Ne pas démarrer** ; retirer les liens concernés sur la copie du XML, revalider |
| Échec SELinux/libvirt au démarrage | Lire le journal du domaine et les labels ; corriger uniquement les copies et chemins du laboratoire, sans désactiver SELinux |
| Machine démarrée mais données absentes | Ne pas déclarer PASS ; vérifier cohérence des volumes, instant d'export et fichiers témoins |

Le nettoyage d'une VM de laboratoire est une **opération destructive distincte** : relever exactement son nom, ses volumes et sa NVRAM, puis demander l'accord du propriétaire avant suppression ; ne jamais faire une commande de suppression globale. L'export d'origine doit rester intact jusqu'à la fin de l'essai. Cette procédure est **documentée et relue contre le code, pas encore validée par une restauration réelle**. Une exécution encadrée et la conservation de preuves sont indispensables avant de la considérer comme certifiée.
