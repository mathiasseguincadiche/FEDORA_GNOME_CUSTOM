# Générateur des schémas de la documentation

> Mise à jour : 2026-11-05 · Responsable : @mathiasseguincadiche
> Dernière vérification : 2026-11-05 — libellés HTML des sources et éléments `<text>` des images relus dans `diagramkit.py` ; le 2026-11-04, les sept paires régénérées sont identiques octet pour octet à `docs/assets/diagrams/` ; sources rouvertes dans diagrams.net, contrastes mesurés par `verify.py` — matériel : non concerné

Les schémas de `docs/assets/diagrams/` sont produits par ce générateur, pas dessinés à la main. Chaque schéma est une paire : une source `.drawio`, éditable dans diagrams.net, et une image `.svg`, affichée par GitHub. Les deux sortent du même modèle, donc leurs libellés, leurs couleurs et leur géométrie sont identiques ; le `.svg` est écrit par le générateur, il n'est pas exporté depuis diagrams.net.

| Fichier | Rôle |
|---|---|
| `diagramkit.py` | Bibliothèque : boîtes, groupes, flèches, palette, contrôle que chaque texte tient dans sa boîte, écriture des deux formats. |
| `build.py` | Définition des sept schémas, avec le titre, la description et la géométrie de chacun. |
| `verify.py` | Contrôle : contraste de chaque couple de couleurs utilisé, libellés identiques entre `.drawio` et `.svg`. |

## Modifier un schéma

Depuis la racine du dépôt, avec Python 3 et sans dépendance externe :

1. Modifier le schéma concerné dans `tools/diagrams/build.py`, et sa description textuelle (troisième argument de `Diagram`) si le sens change.
2. Régénérer les paires dans le dossier de la documentation :

   ```bash
   python3 tools/diagrams/build.py docs/assets/diagrams
   ```

3. Contrôler les contrastes et la concordance des libellés :

   ```bash
   python3 tools/diagrams/verify.py docs/assets/diagrams
   ```

4. Mettre à jour la description textuelle qui suit l'image dans la page concernée, puis lancer `tests/test_diagram_sources.py` et `tests/test_docs_integrity.py`.

`build.py` refuse un texte qui déborde de sa boîte ou une flèche vers un élément inconnu. `tests/test_diagram_sources.py` échoue si un fichier de `docs/assets/diagrams/` ne correspond pas exactement à ce que produit le générateur : une retouche manuelle d'une image est donc détectée.

## Retoucher dans diagrams.net

Une source `.drawio` s'ouvre dans [diagrams.net](https://app.diagrams.net) (*Fichier → Ouvrir depuis → Appareil*), ou en lecture par son URL publique : `https://viewer.diagrams.net/#U` suivi de l'adresse `raw.githubusercontent.com` du fichier. Une retouche faite dans l'éditeur doit être reportée dans `build.py`, sinon la prochaine génération l'écrase et le test signale l'écart.

**Ne pas remplacer un `.svg` par un export de diagrams.net.** Les libellés des sources sont en HTML (`html=1`), pour le gras et les sous-titres : diagrams.net les exporte en `<foreignObject>`, que certains lecteurs SVG n'affichent pas, alors que le générateur écrit de simples éléments `<text>`. Un tel export diffère aussi octet pour octet de la sortie du générateur, et `tests/test_diagram_sources.py` le refuse.

## Ce que ces contrôles ne prouvent pas

`verify.py` mesure les couleurs déclarées, pas l'image affichée. Le rendu réel sur GitHub (thèmes clair et sombre, écran étroit) se vérifie en ouvrant la page ; la dernière vérification est datée en tête de ce fichier.
