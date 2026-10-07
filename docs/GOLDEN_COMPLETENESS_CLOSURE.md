# Golden Workstation — fermeture de la complétude

> Fait partie du parcours de certification : vue d'ensemble dans [`CERTIFICATION.md`](CERTIFICATION.md).

Ce runbook comble les derniers écarts entre un déploiement Fedora 44 correct et une **Golden Workstation certifiée physiquement**. Aucun des tests longs ou interactifs ci-dessous ne s'exécute automatiquement pendant l'APPLY.

## Périmètre

Cette fermeture rend les contrats suivants *fail-closed* (bloquants en cas de doute) sur la vraie machine :

- `gaming-doctor` est obligatoire, car le Gaming fait partie du profil Golden canonique ;
- la Gate 3 exige les deux invités KVM Golden (Rocky Linux et Windows 11) et une preuve vivante VirtIO/QEMU-GA de Windows ;
- la certification finale de la sauvegarde exige une archive Borg complète et récente, un dépôt joignable et un contrôle d'intégrité approfondi ;
- le Ryzen 7 7700 passe un test de charge CPU prolongé dédié avant la certification de la baseline ;
- la certification du refroidissement identifie trois canaux distincts et actifs : pompe de l'AIO, ventilateur CPU/radiateur, ventilateur système ;
- le contrôleur Bluetooth est enregistré par son identité USB et doit rester lié au pilote Fedora `btusb` ;
- le réseau filaire et le Wi-Fi de l'hôte reçoivent chacun une vraie preuve DHCP/IP/route/DNS/HTTPS ; le Wi-Fi prouve en plus son association ;
- l'audio reçoit une preuve de lecture, de capture et une confirmation humaine ;
- chaque application GTK4 gérée est lancée par son lanceur `.desktop` installé, sous Wayland ;
- l'Arc B580 passe un test de charge Vulkan/3D prolongé, suivi d'une inspection `xe`/PCIe/AER ;
- l'écran OLED certifié doit exposer les capacités VRR et HDR, et un humain confirme leur fonctionnement réel.

Toutes les preuves physiques sont liées à l'empreinte matériel/noyau/pilote et à la configuration effective. Une dérive du matériel ou de l'exécution concernée rend la preuve caduque (`STALE`).

## 1. Compléments de la baseline matérielle avant APPLY

À exécuter sur l'hôte physique Fedora 44 final.

### Identité Bluetooth

```bash
./diagnostics/baseline-doctor enroll-bluetooth
```

Le contrôleur enregistré doit garder la même identité USB et utiliser le pilote Fedora intégré `btusb`.

### Enregistrement des canaux de refroidissement

Lister d'abord les canaux NCT6687D pendant que la pompe et les ventilateurs tournent :

```bash
./diagnostics/baseline-doctor list-cooling
```

Identifier trois canaux **différents** et les enregistrer dans cet ordre :

```bash
./diagnostics/baseline-doctor enroll-cooling fanN fanN fanN
#                                               pompe CPU  système
```

L'enregistrement est refusé si un canal choisi est absent ou sous le seuil minimal de rotation. La baseline et le diagnostic matériel exigent ensuite que les trois canaux restent actifs.

### Test de charge du Ryzen

```bash
./diagnostics/baseline-doctor run-cpu-soak
```

Durée par défaut : 1800 secondes. Le test charge tous les CPU avec `stress-ng --verify`, échantillonne `k10temp`, exige une température inférieure à 95 °C par défaut, vérifie AMD P-State et le boost avant et après, et refuse tout signal MCE, EDAC non corrigé, seuil thermique critique ou blocage dur (*hard lockup*).

Terminer ensuite les tests RAM/NVMe existants et certifier la baseline :

```bash
./diagnostics/baseline-doctor run-memory-test 5600
./diagnostics/baseline-doctor run-memory-test 6000
./diagnostics/baseline-doctor run-nvme-test root
./diagnostics/baseline-doctor run-nvme-test data
./diagnostics/baseline-doctor certify
```

Le certificat de baseline ne peut pas être créé sans le test de charge CPU, le verrou Bluetooth et le verrou des canaux de refroidissement.

## 2. Preuve vivante de l'invité Windows 11

Dans l'invité Windows 11 final, attacher le média VirtIO de confiance et exécuter en administrateur :

```powershell
.\Configure-GuestIntegration.ps1
```

Le script refuse les périphériques VirtIO en mauvaise santé et exige explicitement un stockage, un réseau et un ballon VirtIO sains ainsi qu'un QEMU Guest Agent en fonctionnement. Il écrit :

```text
C:\ProgramData\FedoraGnomeCustom\guest-integration.json
```

L'hôte récupère ce marqueur par le QEMU Guest Agent ; ni dossier partagé ni identifiant de l'invité ne sont utilisés.

Vérification côté hôte :

```bash
./diagnostics/windows-guest-doctor
```

La Gate 3 exige aussi `kvm-domain-doctor --require-guests` : l'absence du domaine Rocky Linux (`rocky-devops`) ou Windows est bloquante.

## 3. Preuve Borg complète avant la Gate 3 finale

Créer une sauvegarde complète récente depuis le même commit Git que celui qui sera certifié :

```bash
./scripts/backup/backup-now.sh
./diagnostics/backup-doctor --certify
```

`--certify` est strict. Il exige le marqueur de sauvegarde complète courant, le commit Git correspondant, le marqueur d'intégrité, la fraîcheur, la résolution et l'accessibilité du dépôt, et `borg check --verify-data`.

## 4. Preuves physiques d'exécution

Importer d'abord les preuves Gate 1 et Gate 2 courantes, puis exécuter ce qui suit une fois les applications finales et les invités KVM en place.

### Test de charge Vulkan de l'Arc B580

```bash
./control.sh validate gate3 gpu-soak
```

Par défaut : deux cubes Vulkan simultanés pendant 900 secondes. Tout échec d'un processus Vulkan, ou tout signal critique `xe`, PCIe non corrigé ou AER, bloque la preuve.

### Connectivité filaire de l'hôte

```bash
./control.sh validate gate3 network-lan
```

Exige une interface Ethernet NetworkManager connectée, une IPv4 globale, une route par défaut, le DNS et un vrai accès HTTPS. L'IPv6 est validée lorsqu'une adresse IPv6 globale est présente.

### Connectivité Wi-Fi de l'hôte

```bash
./control.sh validate gate3 network-wifi
```

Exige la même preuve réseau, plus une vraie association `iw`.

Les deux preuves peuvent être capturées à des moments différents ; elles doivent toutes deux rester valides pour l'empreinte physique courante.

### Lecture et capture audio

```bash
./control.sh validate gate3 audio-cert
```

Le test joue une tonalité ALSA sur les haut-parleurs et enregistre un court échantillon du microphone. Il exige ensuite la phrase de confirmation physique exacte affichée par la commande. Cela empêche un PASS silencieux fondé sur la seule détection du périphérique.

### VRR et HDR

```bash
./control.sh validate gate3 display-cert
```

La preuve d'affichage exige :

1. le contrat existant connecteur/EDID exact de l'Arc B580 et 2560×1440 à ~240 Hz ;
2. la capacité VRR côté DRM ;
3. un bloc *CTA HDR Static Metadata* dans l'EDID de l'écran ;
4. une confirmation humaine explicite après activation et essai du VRR et du HDR dans GNOME.

Pour l'écran cible ASUS ROG Strix OLED XG27AQDMES, VRR/Adaptive-Sync, HDR10 et 240 Hz font donc partie du contrat Golden et ne sont pas optionnels.

### État

```bash
./control.sh validate gate3 physical-status
```

Un PASS exige ces cinq marqueurs courants : `gpu-soak`, `network-lan`, `network-wifi`, `audio` et `display-capabilities`.

## 5. Certification finale de l'exécution KVM

Démarrer les deux invités Golden et vérifier que le marqueur Windows existe, puis exécuter :

```bash
./scripts/kvm/runtime_certification.sh
```

La certification publique conserve les tests existants de l'hôte, de Rocky Linux, du XML et du réseau fail-closed, et ajoute la preuve stricte et vivante du QGA Windows.

## 6. Cinq cycles physiques de veille/réveil

Enregistrer cinq cycles réels et distincts, comme déjà exigé :

```bash
./control.sh validate gate3 record-suspend
```

Répéter après chaque cycle physique de veille/réveil séparé.

## 7. Certification Golden finale

```bash
./control.sh validate gate3 certify
```

Un PASS final exige désormais, en plus des contrats existants :

- une baseline valide avec test de charge CPU, verrou Bluetooth et verrou du refroidissement ;
- une certification Borg stricte ;
- les cinq preuves physiques d'exécution ;
- le Gaming activé et `gaming-doctor` en PASS sur la pile Arc B580/Wayland/240 Hz ;
- les deux domaines KVM ;
- la preuve vivante VirtIO/QGA de Windows ;
- l'activation complète des applications gérées ;
- les cinq cycles de veille/réveil existants et la preuve de démarrage à froid de Nautilus.

Seule cette commande physique peut créer le marqueur Golden final. La CI, WSL2 et VirtualBox ne peuvent toujours pas certifier le matériel de la workstation.
