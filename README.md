# Borrow Checker

_MiniRust_ est un petit langage de programmation inspiré de `Rust` et implémenté sur OCaml.

Pour ce projet, il nous a été demandé de compléter le code concernant le `BorrowChecker`. Ce dernier, étant le trait le plus caractéristique de rust, nous a donné l'opportunité de comprendre le langage à un niveau plus avancé que jamais. 

### Travail Réalisé
Au cours du projet, on nous a demandé de compléter cinq tâches qui se trouvent dans sa totalité dans les fichiers `borrowck.ml` et `uninitialized_places.ml`.

Voici ce qui a été demandé : 

- #### Analyse statique de l'initialisation des places 
Cette tâche demandait de compléter du code dans le fichier `uninitialized_places.ml`. Specifiquement, les fonctions `move_or_copy`, `foreach_root` et `foreach_succesor`. \
Pour `move_or_copy`, on fait une analyse du type de la place donné en paramètre. Pour savoir si on copie ou si on bouge une place, il faut vérifier que son type soit _copy_. Si il l'est, rien ne change : on peut intialiser une place avec le même contenu. Sinon, on est obligé de bouger le contenu et donc déinitialisé la place. \
Les fonctions `foreach_root` et `foreach_succesor` ont été largement inspirées par les fonctions du même nom dans le fichier `active_borrows.ml`. `foreach_root` fait en sorte qu'on commence avec un _state_ ou toutes les variables ne sont pas initialisées. Une fois qu'on a ça, on peut procéder à l'analyse faite par `foreach_succesor`. Celui-ci, itere sur toutes les instructions du programme pour initialiser correctement les places qui doivent être initialisées.  
- #### Vérification d'emprunt partagés 
Cette tache a lieu dans le fichier `borrowck.ml`. Elle nous demande de vérifier à chaque fois que tous les emprunts partagés sont correctement faits. Pour ceci, on itere sur les instructions du programme pour trouver des endroits où on pourrait avoir des possibles conflits. Par exemple, lors de la création d'un emprunt. En rust, faire des modifications sur des emprunts partagés est impossible et cette tâche fait en sorte qu'on respecte cette contrainte.
- #### Création des contraintes sur les _lifetimes_ 
Cette tache, qui se trouve au fichier `borrowck.ml`, est divisée en deux parties : création des contraintes _outlives_ (les contraintes de survie) et les contraintes _living_ (les contraintes de vie). \
Pour les contraintes de survie, il est important de renforcer le fait que certaines _lifetimes_ doivent durer plus longtemps que d'autres. Un des cas d'intérêt peut nous servir comme exemple ici : l'égalisation de certaines _lifetimes_. Même si MiniRust n'implémente pas le sous-typage, si une variable avec une certaine _lifetime_ est stockée sous une place avec une _lifetime_ différente, ces deux doivent forcément avoir une durée identique. Cette contrainte et d'autres, ont été implémentés en intégrant les instructions du programme. Chaque fois qu'y a une instruction qui utilise une place, on s'intéresse globalement à une chose : si elle a un type qui utilise des _lifetimes_ (les emprunts et les structures). Si c'est le cas, on teste les choses nécessaires (plus d'information au sujet dans le code). \
Pour les contraintes de vie, on s'intéresse à vérifier si une _lifetime_ est vivante ou pas lors d'un moment particulier du programme. Pour ceci, on itére à nouveau sur les instructions. À chaque itération, on associe toutes les lifetimes génériques au point du programme qui se trouve lors de cette instruction. Une fois qu'on a fait ça, il reste juste à vérifier que toutes les _lifetimes_ des variables locales vivantes n'ont pas encore expiré.

- #### Verification des contraintes _outlives_ 
Notre quatrième tâche se trouve également dans le fichier `borrowck.ml`. Elle consistait à compléter la fonction `borrowk` en faisant une vérification que les contraintes _outlives_ ont été correctement déclarés. \
Pour cela, on itère sur les _lifetimes_ generiques de la fonction. À chaque fois, on reprend les _program points_ associés a les _lifetimes_ et on vérifie que tout est en ordre selon ce qui à été mis dans le graphe des contraintes de survie du programme.

- #### Vérification de conflit d'emprunts
La cinquième et dernière tâche de ce projet consistait à compléter du code se trouvant dans le fichier `borrowck.ml`. \
Il s'agissait de vérifier qu'on utilise jamais un emprunt actif quand il est interdit de le faire. Le travail pour cette partie était plus faible mais est le plus important jusqu'à présent.

### Difficultés rencontrés

Tout au long, j'ai eu des difficultés à comprendre non seulement le sujet mais aussi le code donné. La troisième tâche en particulier, m'a paru specialement compliquée à comprendre. L'implémentation des lifetimes n'était pas extrêmement claire lors de ma lecture du code ce qui a rendu la tâche beaucoup plus compliqué que nécessaire. \
Comprendre pourquoi certains tests ne passent pas était une difficulté aussi. Lors de la lecture des tests et leur message d'erreur (ou manque de), trouver pourquoi le code que j'avais écrit n'était pas suffisant, n'était pas facile. C'est a cause de ça, que je rend ce projet avec plusieurs tests de base sans passer même si je sort avec l'impression d'avoir compris comment marche un borrow checker. \
Je peux pas dire que j'ai trouvé une solution à ces problèmes, vu que le projet n'est pas complètement fini. Cependant, faire des recherches sur le fonctionnement d'un borrow checker et demander de l'aide a mes camarades, m'a aidé avancer jusqu'à ce point. 

## Conclusion

Je ne peux pas dire que je suis totalement satisfaite du travail fait. Ce projet, qui est difficile de base, est devenu plus compliqué à cause d'une manque de temps produite par des circonstances extérieures, le début d'un stage étant une d'elles. \
Néanmoins, le thème du projet m'a parue extrêmement intéressant et je ressort avec des connaissances que je suis contente d'avoir obtenue.
