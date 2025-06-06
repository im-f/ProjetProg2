# Borrow Checker

_MiniRust_ est un petit language de programmation inspiré de `Rust` et implémenté sur OCaml.

Pour ce projet, il nous a été demandé de completer le code concernant le `BorrowChecker`. Ce dernier, etant le trait le plus characteristique de rust, nous a donner l'opportunité de comprendre le language à un niveau plus avancé que jamais. 

### Travail Reéaliseé
Au cours du projet, on nous a ete demande de completer cinq taches lesquelles se trouvent en sa totalite dans les fichier `borrowck.ml` et `uninitialized_places.ml`.

Voici ce qui a ete demande : 

- Analyse statique de l'initialisation des places : 
Cette tache demandait de completer du code dans le fichier `uninitialized_places.ml`. Specifiquement, les fonctions `move_or_copy`, `foreach_root` et `foreach_succesor`. 
Pour `move_or_copy`, on fait un analyse du type de la place donné en parametre. Pour savoir si on copie ou on bouge une place, il faut verifier que sont type soit _copy_. Si il l'est, rien ne change : on peut intialiser une place avec le meme contenue. Sinon, on est obligé de bouger le contenue et donc déinitialisé la place. 
Les fonctions `foreach_root` et `foreach_succesor` ont ete largement inspiré par les fonctions du meme nom dans le fichier `active_borrows.ml`. `foreach_root` fait en sorte qu'on commence avec un _state_ ou toutes les variables sont pas initialisées. Une fois qu'on a ça, on peut procédé a l'analyse fait par `foreach_succesor`. Celui-ci, itere sur toutes les instructions du programme pour initialisé correctement les places qui doivent etre initalisés.  
- Vérification d'emprunt partagés : 
Cette tache a lieu dans le fichier `borrowck.ml`. Elle nous demande de verifier a chaque fois que tout les emprunts partagés sont correctement fait. Pour ceci, on itere sur les instruction du programme pour trouver des endroits ou on pourrais avoir des possible conflits. Par example, lors de la création d'un emprunt. En rust, faire des modifications sur des emprunts partagés est impossible et cette tache fait en sorte qu'on respecte cette contrainte.
- Création des contraintes sur les _lifetimes_ :
Cette tache, qui ce trouve au fichier `borrowck.ml`, est divisé en deux partie : création des contraintes _outlives_ (les contraintes de survie) et les contraintes _living_ (les contraintes de vie). 
Pour les contraintes de survie, il est important d'enforcer le fait que certaines _lifetimes_ doivent durer plus longtemps que d'autres. Un des cas d'interet peut nous servir comme example ici : l'egalisation de certaines _lifetimes_. Meme si MiniRust n'implemente pas le sous-typage, si une variable avec une certaine _lifetime_ est stocké sous une place avec une _lifetime_ differente, ces deux doivent avoir une durée identique. Cette contrainte et autres, on été implementé en interant sur les instructions du programme. Chaque fois qu'y a une instruction qui utilise une place, on s'interese goblalment a une chose : si elle a un type qui utilise des _lifetimes_ (les emprunts et les structures). Si c'est le cas, on fait test les choses necessaires (plus d'information au sujet dans le code).
- Quatrieme tache : 
- Cinquieme tache : 

### Difficultées rencontrées

Tout au long, j'ai eu des difficultes a comprendre non seulement le sujet mais le code donné aussi. La troisieme tache en particulier, m'a paru specialement compliqué a comprendre. L'implementation des lifetimes n'ete pas extremement claire lors de ma lecture du code ce qui a rendu la tache beaucoup plus complique que necessaire. 
Comprendre pourquoi certains tests ne passent pas ete une difficulté aussi. Lors de la lecture des tests et leur message d'erreur (ou manque de), trouver pourquoi le code que j'avais ecris n'etait pas suffisant, n'etait pas facile. C'est a cause de ça, que je rend ce projet avec plusieurs tests de base sans passer meme si je sort avec l'impression d'avoir compris comment marche un borrow checker. 
Je peux pas dire que j'ai trouvé une solution a ces problemes, vu que le projet n'est pas completement finis. Cependant, faire des recherches sur le fonctionnement d'un borrow checker et demander de l'aide a mes camarades, m'a aidé avancé jusqu'a ce point. 

## Conclusion

Je peux pas dire que je suis totalement satisfaite avec le travail que je vous rend ici. Ce projet, qui est difficile de base, est devenue plus compliqué a cause d'une manque de temps produite par des circonstances exterieures, le debut d'un stage etant une d'elles. 
Néanmoins, le theme du projet m'a parue extremement interessant et je ressort avec des connaissances que je contente d'avoir obtenue. 