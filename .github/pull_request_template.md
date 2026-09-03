## Objectif

Décrire brièvement le changement et le problème résolu.

## Contrat de revue

- [ ] Le périmètre reste minimal et ne contourne aucun moteur protégé.
- [ ] `VERSION`, `CHANGELOG.md`, README et documentation normative sont cohérents si le contrat Golden change.
- [ ] Les téléchargements directs sont épinglés par version et checksum/signature lorsque applicable.
- [ ] Le `--dry-run` reste non mutant et `--apply` reste protégé par le gate bare-metal/backup/baseline.
- [ ] Aucun `force_probe`, désactivation SELinux/firewalld, GPU passthrough ou contournement KVM fail-closed n'est introduit.
- [ ] L'impact backup/restore/disaster-recovery est revu si des données persistantes ou services sont modifiés.
- [ ] Les tests contractuels/comportementaux couvrent les nouveaux invariants.
- [ ] Les workflows requis sont verts sur le SHA exact de la PR.
- [ ] Toute preuve matérielle non reproductible en CI reste explicitement différée au GATE bare-metal.

## Validation

Indiquer les tests exécutés, les preuves CI et, si nécessaire, les contrôles bare-metal à réaliser après fusion.
