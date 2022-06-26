# Outils de gestion ROK4

## Summary

Le projet ROK4 a été totalement refondu, dans son organisation et sa mise à disposition. Les composants sont désormais disponibles dans des releases sur GitHub au format debian.

Cette release contient les outils de gestion et d'analyse.

## Changelog

### [Added]

* Les outils sont capables de lire les descripteurs directement sur les stockages objets
* Ajout d'un [outil](README.md#convert2json) permettant de convertir les descripteurs de pyramide dans l'ancien format (XML) au nouveau format (JSON)
* Ajout d'un [outil](README.md#pyrolyse) d'analyse de pyramide (taille moyenne des dalles, utiles, temps d'accès au stockage...)

### [Changed]

* Les paramètres ont été uniformisés entre les différents outils (comme `--pyramid` pour fournir le chemin vers un descripteur de pyramide)
* Les chemins sont fournis dans un format précisant le type de stockage : `(file|ceph|s3|swift)://<chemin vers le fichier ou l'objet>`. Dans le cas du stockage objet, le chemin est de la forme `<nom du contenant>/<nom de l'objet>`
* L'outil de création du descripteur de couche affiche le résultat dans la sortie standard

<!-- 
### [Added]

### [Changed]

### [Deprecated]

### [Removed]

### [Fixed]

### [Security] 
-->