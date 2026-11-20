# Guide de A à Z — comprendre le projet Olist DW sans aucune connaissance en data engineering

> **À qui s'adresse ce guide ?** À quelqu'un qui sait à peine ce qu'est une base de données.
> **Objectif :** à la fin, tu sais (1) ce qu'est ce projet, (2) ce que contiennent les 9 tableaux,
> (3) comment ils sont reliés, (4) pourquoi il y a autant de fichiers, (5) exactement ce que tu dois faire.
>
> Tous les chemins ci-dessous sont relatifs à **ce dossier** (`olist-dw-student/olist-dw-student/`),
> c'est-à-dire le dossier qui contient `Dockerfile`, `dags/`, `include/`, `README.md`.
>
> Les 4 schémas à regarder en même temps que ce texte :
>
> | Schéma | Fichier | Ce qu'il montre |
> |---|---|---|
> | Le trajet des données | `docs/01_pipeline.png` | les 5 étapes du pipeline |
> | Les 9 tableaux et leurs liens | `docs/02_relations_raw.png` | version simplifiée des relations |
> | Le schéma complet | `docs/olist_database_schema.png` | toutes les colonnes, types, PK/FK |
> | Le schéma en étoile | `docs/03_etoile_marts.png` | ce que tu dois construire en TP3 |

---

## 0. Le vocabulaire, expliqué avec des mots simples

| Mot | Traduction simple | Analogie |
|---|---|---|
| **Table** (tableau) | Un tableau Excel : des lignes et des colonnes | Un onglet Excel |
| **Ligne** (enregistrement) | Une chose : 1 commande, 1 produit, 1 client… | Une ligne Excel |
| **Colonne** (champ) | Une information sur cette chose : prix, date, ville… | Une colonne Excel |
| **Base de données** | Un classeur contenant plusieurs tableaux | Un fichier Excel avec plusieurs onglets |
| **Schéma** (SQL Server) | **Un dossier** qui range des tables : `raw`, `staging`, `marts` | 3 tiroirs dans le même meuble |
| **Clé primaire (PK)** | Le numéro d'identité **unique** d'une ligne | Le numéro de commande |
| **Clé étrangère (FK)** | Un numéro qui **pointe vers une autre table** | Sur une ligne de facture, le numéro de client |
| **Jointure** | Retrouver une info dans une autre table grâce à une clé | `RECHERCHEV` / `VLOOKUP` dans Excel |
| **1 → N** | Une ligne d'une table correspond à plusieurs lignes d'une autre | 1 commande → 3 articles |
| **ETL / ELT** | Prendre des données quelque part, les transformer, les ranger | Copier → nettoyer → classer |
| **DAG** | Une **liste de tâches avec des flèches** (« fais A, puis B, puis C ») | Une recette de cuisine ordonnée |
| **Airflow / Astro** | Le programme qui exécute les DAG au bon moment | Le chef de cuisine qui lance les étapes |
| **dbt** | Des fichiers SQL qui transforment les tables et testent le résultat | La recette de nettoyage |
| **Dimension** | Une table qui sert à **découper** les chiffres : qui, quoi, où, quand | Les filtres d'un tableau croisé dynamique |
| **Fait** | Une table de **nombres à additionner** : ventes, montants, délais | Les valeurs d'un tableau croisé dynamique |
| **Mesure** | Un calcul : somme, compte, moyenne | `SOMME(...)`, `NB(...)` dans Excel |
| **Cube SSAS** | Un tableau croisé dynamique pré-calculé, interrogeable dans Excel | Un TCD géant et rapide |
| **MDX** | Le langage pour poser une question au cube | Une requête, comme SQL |
| **Asset** | Un petit drapeau « cette donnée est prête » | Un post-it « étape terminée » |

⚠️ **Attention au mot « schéma »** : il a 3 sens ici.
1. `raw` / `staging` / `marts` = des **dossiers** dans SQL Server.
2. « le schéma d'une table » = la **liste de ses colonnes**.
3. « le schéma de la base » = le **dessin des relations** (`docs/olist_database_schema.png`).

---

## 1. À quoi sert ce projet, au fond ?

On te donne les données d'un vrai site de e-commerce brésilien (**Olist**, dataset Kaggle) :
des commandes, des clients, des produits, des vendeurs, des paiements, des avis clients,
des codes postaux. Elles arrivent sous forme de **9 fichiers dans 4 formats différents**.

Le but du TP est de construire un **entrepôt de données** (*data warehouse*) capable de
répondre à des questions métier :

- « Combien avons-nous vendu en 2017 ? Et par catégorie de produit ? »
- « Quel est le montant total des paiements ? »
- « Quel pourcentage des commandes livrées sont en retard ? »
- « Quels États achètent le plus ? »

Pour répondre, on range les données **en 3 étages**, et à la fin on branche Excel dessus.

> **Ce dépôt est un squelette volontairement incomplet.** Il contient **un seul exemple terminé**
> (la table `orders`) à chaque étage. Ton travail est de **reproduire le même motif pour les 8 autres
> tables**, puis de construire l'étoile et le cube. Ce n'est pas un bug : c'est l'exercice.

---

## 2. L'idée centrale : 3 tiroirs (les 3 couches)

Regarde `docs/01_pipeline.png`. Retiens cette image :

```
FICHIERS  ──►  RAW  ──►  STAGING  ──►  MARTS  ──►  CUBE / Excel
 (brut)     (copie)    (nettoyé)    (étoile)      (questions)
```

| Tiroir | Ce qu'on y met | Qui le remplit | Analogie |
|---|---|---|---|
| `raw` | La **photocopie exacte** des fichiers. Tout est du **texte**, même les nombres et les dates. Aucun nettoyage. Deux colonnes en plus : `_source_file`, `_loaded_at`. | Les 9 DAG Airflow `load_raw_*` | On scanne les papiers sans rien corriger |
| `staging` | Les mêmes données, mais **propres et typées** : dates en dates, prix en nombres, codes postaux réparés, doublons supprimés. Ce sont des **vues**. | dbt (`stg_*.sql`) | On recopie au propre dans un classeur |
| `marts` | Le **modèle final en étoile** : dimensions + faits, prêt à être analysé. Ce sont des **tables**. | dbt (`dim_*.sql`, `fact_*.sql`) | On prépare le tableau croisé dynamique |

**Pourquoi 3 tiroirs et pas un seul ?** Parce que si une erreur arrive, on peut tout reconstruire
à partir de `raw` sans jamais perdre la donnée d'origine. Et parce que `raw` garde la preuve de
ce que le fichier contenait vraiment (par exemple un code postal `1037` au lieu de `01037`).

Les 3 tiroirs sont dans **la même base** `OlistDW`, sur **SQL Server** installé sur ta machine
Windows (pas dans Docker). Les comptes : `olist_ingest_login` écrit dans `raw`,
`olist_dbt_login` lit `raw` et écrit `staging` + `marts` (voir `include/sql/00_admin_setup_reference.sql`).

---

## 3. Les 9 tableaux sources, un par un

Les nombres de lignes et les « pièges » viennent de `dags/dbt/olist/models/staging/_sources.yml`
(ce fichier est le **catalogue** des sources : lis-le, il est écrit pour toi).

| Table (= 1 fichier) | Format du fichier | 1 ligne = … | Lignes | Le piège à corriger en staging |
|---|---|---|---|---|
| `orders` | **JSONL** (1 commande par ligne) | 1 commande | 99 441 | Tout est encapsulé dans une colonne `record` → il faut `OPENJSON` pour déplier |
| `order_items` | **Parquet** | 1 article dans 1 commande | 112 650 | Vrais types (int, double, timestamp) ; quelques dates en 2020 |
| `payments` | **JSON** (un grand tableau) | 1 ligne de paiement | 103 886 | `payment_value` est un nombre JSON → à convertir en `DECIMAL(12,2)` |
| `reviews` | **JSON** | 1 avis client | 99 224 | `review_id` répété 814 fois ; 551 commandes ont plusieurs avis ; accents et retours à la ligne |
| `customers` | **Parquet** | 1 client (1 commande) | 99 441 | Le code postal était un nombre → `01037` est devenu `1037` (zéro perdu) |
| `products` | **CSV** | 1 produit | 32 951 | 610 catégories vides ; fautes de frappe `product_name_lenght`, `product_description_lenght` |
| `sellers` | **CSV** | 1 vendeur | 3 095 | Ici les zéros des codes postaux sont conservés |
| `geolocation` | **Parquet** | 1 relevé géographique | 1 000 163 | 261 831 doublons exacts ; un même code postal a beaucoup de lignes |
| `category_translation` | **CSV** | 1 traduction de catégorie | 71 | BOM UTF-8 en début de fichier ; 2 catégories sans traduction |

**Pourquoi 4 formats différents ?** C'est pédagogique : tu dois apprendre à lire un CSV, un JSON,
un JSONL et un Parquet. `scripts/convert_formats.py` fabrique ces fichiers à partir des 9 CSV Kaggle,
et introduit volontairement les défauts ci-dessus pour que tu apprennes à les nettoyer.

> Les fichiers de données eux-mêmes ne sont **pas dans le dépôt** : le professeur les fournit,
> à déposer dans `include/data/olist/`. C'est pour ça que `dags/load_raw_orders.py` cherche
> `*olist_orders_dataset.*` : l'étoile autorise un préfixe dans le nom du fichier.

---

## 4. Les relations entre tableaux : la partie la plus importante

Ouvre `docs/02_relations_raw.png` (version simple) et `docs/olist_database_schema.png` (version complète).

### 4.1 Comprendre PK / FK avec un exemple

Imagine la commande **`C-001`** passée par le client **`CL-9`** :

**`orders`** (1 ligne)

| order_id (PK) | customer_id (FK) | order_status | date d'achat |
|---|---|---|---|
| C-001 | CL-9 | delivered | 2017-05-01 |

**`customers`** (1 ligne)

| customer_id (PK) | ville | état |
|---|---|---|
| CL-9 | sao paulo | SP |

→ `orders.customer_id = CL-9` te dit « va chercher la ligne `CL-9` dans `customers` pour connaître
la ville ». **C'est exactement un `RECHERCHEV`.** La colonne qui reçoit la valeur s'appelle une
**clé étrangère** ; la colonne qui identifie la ligne d'arrivée s'appelle la **clé primaire**.

### 4.2 Le « chef d'orchestre » : `orders`

Presque tout part de `order_id`. Pour une seule commande `C-001` :

- `orders` → **1 ligne** (le chef d'orchestre, le statut et les dates)
- `order_items` → **N lignes** (1 par article acheté : prix, frais de port, produit, vendeur)
- `payments` → **N lignes** (1 par moyen de paiement : carte, bon d'achat, échéances…)
- `reviews` → **0, 1 ou N lignes** (les avis, avec la note de 1 à 5)

C'est le `1 → N` du schéma : **une** commande, **plusieurs** articles/paiements/avis.

### 4.3 Toutes les relations, en une table

| De | Vers | Cardinalité | Colonne de jointure | Ce que ça donne |
|---|---|---|---|---|
| `customers` | `orders` | 1 → 1 | `customer_id` | la ville du client d'une commande |
| `orders` | `order_items` | 1 → N | `order_id` | les articles d'une commande |
| `orders` | `payments` | 1 → N | `order_id` | les paiements d'une commande |
| `orders` | `reviews` | 1 → N | `order_id` | les avis d'une commande |
| `products` | `order_items` | 1 → N | `product_id` | le nom / la catégorie de l'article |
| `sellers` | `order_items` | 1 → N | `seller_id` | le vendeur de l'article |
| `category_translation` | `products` | 1 → N | `product_category_name` | la catégorie en anglais |
| `geolocation` | `customers` / `sellers` | N ↔ N *(approximatif)* | `zip_code_prefix` | latitude / longitude d'un code postal |

### 4.4 Les 4 cas particuliers à connaître (ce sont des questions d'examen)

1. **`customer_id` ≠ `customer_unique_id`.** Dans Olist, un même client qui commande 2 fois a
   2 `customer_id` différents mais 1 seul `customer_unique_id`. C'est pour ça que la relation
   `customers → orders` est notée **1 → 1** dans le schéma complet. Si tu veux compter « le nombre
   de vrais clients », utilise `customer_unique_id`.
2. **`reviews` n'a pas de clé simple.** `review_id` se répète (814 fois) : la clé est
   **`review_id + order_id`**. Il faut choisir un avis par commande (par exemple le plus récent)
   avant de le mettre dans `fact_orders`.
3. **`geolocation` n'a pas de clé.** Un code postal a plusieurs lignes (plusieurs quartiers),
   et il y a 261 831 doublons. Les pointillés dans le schéma veulent dire : « lien approximatif,
   pas une vraie clé ». On s'en sert pour enrichir, pas pour joindre stricto sensu.
4. **`dim_date` joue 4 rôles.** `fact_orders` a 4 dates (achat, remise au transporteur, livraison
   réelle, livraison estimée) → 4 liens vers la même dimension date (`cube/README.md`). On appelle
   ça une *dimension à rôles multiples*.

### 4.5 Où trouver ces informations dans le dossier ?

Tu n'as rien à deviner : tout est déjà écrit à 4 endroits.

| Fichier | Ce que tu y apprends |
|---|---|
| `dags/dbt/olist/models/staging/_sources.yml` | Les 9 tables, leurs lignes, leur format et **tous les pièges** |
| `scripts/draw_schema.py` → `docs/olist_database_schema.png` | Le dessin complet des relations (PK/FK, 1/N, pointillés) |
| `include/sql/raw/orders.sql` + `dags/dbt/olist/models/staging/stg_orders.sql` | Les **colonnes réelles** d'une table brute et leur version nettoyée |
| `cube/README.md` | Les dimensions, les hiérarchies et les 3 tables de faits attendues |

---

## 5. Pourquoi autant de fichiers ? (la décomposition)

Un projet de données sépare toujours **4 responsabilités** :
**l'ordonnancement** (qui fait quoi et quand), **le code** (comment), **la configuration**
(avec quels identifiants / quelle version), **la documentation et les tests** (vérifier).

Analogie : un restaurant.
`dags/` = le planning du service, `include/` = les ingrédients et les ustensiles,
`dags/dbt/olist/` = les recettes, `Dockerfile`/`*.yml` = l'installation de la cuisine,
`tests/` = le contrôle qualité, `*.md` = le mode d'emploi.

| Famille | Fichiers | Rôle | Touché par toi ? |
|---|---|---|---|
| **Ordonnancement** | `dags/load_raw_orders.py`, les 8 autres `dags/load_raw_*.py`, `dags/dbt_olist.py`, `dags/test_sql_connection.py` | Les DAG : la liste ordonnée des tâches | ✅ 8 fichiers à créer |
| **SQL de création** | `include/sql/raw/orders.sql` + 8 autres | Le `CREATE TABLE` de chaque table `raw` | ✅ 8 fichiers à créer |
| **Outils partagés** | `include/olist_raw/loader.py` | Lire les 4 formats, insérer par lots de 1 000, compter, créer un Asset | ❌ **ne pas modifier** |
| **Diagnostic** | `include/olist_raw/diagnose.py`, `dags/test_sql_connection.py` | Tester la connexion en 7 étapes avec messages d'erreur | ❌ |
| **Transformation** | `dags/dbt/olist/models/staging/stg_orders.sql`, `_sources.yml`, `_staging.yml`, `macros/*.sql` | Nettoyer / typer / tester | ✅ à compléter (TP3) |
| **Modèle final** | `dags/dbt/olist/models/marts/...` *(à créer)* | Dimensions + faits | ✅ à créer (TP3) |
| **Configuration** | `Dockerfile`, `requirements.txt`, `packages.txt`, `docker-compose.override.yml`, `dbt_project.yml`, `profiles.yml`, `packages.yml` | Installer Airflow, ODBC, dbt ; définir les schémas cibles | ❌ (sauf réglages) |
| **Administration SQL** | `include/sql/00_…` à `05_…` | Créer la base, les 3 schémas, les 2 logins, les droits, l'accès SSAS | ❌ fait par le professeur |
| **Documentation** | `README.md`, `cube/README.md`, `GUIDE_DEBUTANT.md`, `docs/*.png` | Le mode d'emploi | 📖 à lire |
| **Tests** | `tests/dags/test_dag_integrity.py` | Vérifier que les DAG se chargent et ont la bonne structure | ✅ à étendre |
| **Préparation** | `scripts/convert_formats.py`, `download_data.sh`, `draw_schema.py`, `draw_learning_diagrams.py` | Fabriquer les fichiers, dessiner les schémas | ❌ |
| **Données** | `include/data/olist/` *(absent)* | Les 9 fichiers à charger | 📦 fournis par le prof |

### 5.1 Pourquoi « un fichier par table » ?

Parce que chaque table a **son format, ses colonnes et son SQL**. Le motif est toujours le même :

```
include/sql/raw/<table>.sql     →  1 fichier qui décrit les colonnes de LA table
dags/load_raw_<table>.py        →  1 DAG qui charge LA table
dags/dbt/olist/models/staging/stg_<table>.sql  →  1 modèle qui nettoie LA table
```

9 tables × 3 = 27 petits fichiers. C'est volontaire : c'est plus facile à corriger, à relancer
individuellement et à noter qu'un énorme script unique. `load_raw_orders.py` est le **modèle
à recopier** : il est déjà commenté ligne par ligne pour toi.

### 5.2 Le cycle de vie d'UNE table (`orders`), pas à pas

Suis ces 5 tâches dans `dags/load_raw_orders.py` — c'est le cœur du projet :

| # | Tâche | Fichier utilisé | Ce qui se passe |
|---|---|---|---|
| 1 | `find` | `loader.find_file()` | Cherche `*olist_orders_dataset.*` dans `include/data/olist/` |
| 2 | `create_table` | `include/sql/raw/orders.sql` | Crée `raw.orders` **seulement si elle n'existe pas** |
| 3 | `truncate_table` | SQL direct | Vide la table → relancer ne duplique jamais les lignes |
| 4 | `load_to_raw` | `loader.read_json_records()` + `write_raw()` | Lit le JSONL, ajoute `_source_file` / `_loaded_at`, insère par lots de 1 000 |
| 5 | `check_rows` | `loader.count_rows()` | Compare « écrites » et « en base », échoue si différence, puis **lève le drapeau Asset** `raw.orders` |

Et ensuite : les 9 Assets alimentent le DAG `dbt_olist` (`dags/dbt_olist.py`). Quand les 9 drapeaux
sont levés, **Cosmos** transforme chaque modèle dbt en tâches Airflow `run` puis `test`.
C'est toute la magie de l'orchestration : personne n'appelle personne directement, on passe par
des « drapeaux ».

### 5.3 Les 3 machines et leurs fichiers

| Machine | Fichier de config | Ce qu'il faut retenir |
|---|---|---|
| **Astro / Airflow 3.1** (dans Docker) | `Dockerfile`, `requirements.txt`, `docker-compose.override.yml` | ODBC Driver 18, provider MSSQL, Cosmos, `host.docker.internal` pour atteindre Windows |
| **dbt-sqlserver** (dans un venv du conteneur) | `dbt_project.yml`, `profiles.yml`, `packages.yml` | `staging`/`intermediate` → vues, `marts` → tables ; `dbt_utils` installé par `dbt deps` |
| **SQL Server + SSAS** (sur Windows) | `include/sql/00_…`, `cube/README.md` | Express pour la base, **Developer** pour Analysis Services (Express ne l'inclut pas) |

Deux connexions Airflow à créer à la main dans l'UI (Admin > Connections) :
`mssql_raw` (login `olist_ingest_login`) et `mssql_dbt` (login `olist_dbt_login`),
host `host.docker.internal`, base `OlistDW`, port `1433`, Extra vide.

---

## 6. Le schéma en étoile : ce que tu dois construire (TP3)

Regarde `docs/03_etoile_marts.png`.

- **Au centre, les FAITS** = des tables de nombres. Le « grain » (niveau de détail) est essentiel :
  - `fact_sales` : **1 ligne = 1 article vendu** → Sales Amount, Freight Amount, Total Amount, Item Count, Order Count
  - `fact_payments` : **1 ligne = 1 paiement** → Payment Value, Installments
  - `fact_orders` : **1 ligne = 1 commande** → Orders Count, Late Orders (`is_late`), Delivery Days, Review Score Sum
- **Autour, les DIMENSIONS** = les axes d'analyse, avec leurs hiérarchies :
  `dim_date` (Année → Trimestre → Mois → Jour), `dim_customer` (État → Ville → Client),
  `dim_product` (Catégorie → Produit), `dim_seller` (État → Ville → Vendeur),
  `dim_payment_type`, `dim_order_status`.

Les macros du projet t'aident (`dags/dbt/olist/macros/`) :

| Macro | Utilité |
|---|---|
| `clean_text('col')` | Enlève les espaces, transforme `''` en `NULL` |
| `to_ts`, `to_int`, `to_money`, `to_float` | Convertit du texte en date / entier / montant / décimal (valeur invalide → `NULL`, pas d'erreur) |
| `zip5('col')` | Répare les codes postaux : `1037` → `01037` |
| `date_key('col')` | Clé date `AAAAMMJJ`, ou `-1` si la date manque |
| `surrogate_key([...])` | Fabrique une clé stable (MD5) à partir des colonnes naturelles |

---

## 7. Ce que **TU** dois faire, étape par étape

### Étape 0 — Faire fonctionner la porte d'entrée (avant tout code)

1. Installer Docker Desktop, l'Astro CLI, SQL Server Express + SSMS sur Windows.
2. Demander au professeur : les 9 fichiers de données et les 2 mots de passe.
3. Déposer les fichiers dans `include/data/olist/`.
4. `astro dev start` → http://localhost:8080 → créer la connexion `mssql_raw`.
5. Déclencher le DAG **`test_sql_connection`** : les **7 tâches doivent être vertes**.
   Si une est rouge, **ouvre son log** : `diagnose.py` écrit exactement quoi corriger.
6. Déclencher **`load_raw_orders`** : les 5 tâches doivent être vertes et `raw.orders` doit contenir 99 441 lignes.
7. Vérifier dans SSMS : `SELECT COUNT(*) FROM raw.orders;`

> Après `astro dev kill`, la connexion est supprimée → il faut la recréer. C'est normal.

### Étape 1 — TP2 : les 8 autres chargements (le plus gros du travail)

> **Mise à jour** : les 16 fichiers du TP2 ont été écrits et poussés sur la branche
> (`dags/load_raw_*.py`, `include/sql/raw/*.sql`, test étendu aux 9 tables). Cette section explique
> comment ils ont été construits — utile pour comprendre et vérifier.
>
> Pour **chacune** des 8 tables, crée 2 fichiers en recopiant `orders` :

**a) `include/sql/raw/<table>.sql`** — reprendre le motif de `include/sql/raw/orders.sql`.
Pour un fichier JSON / JSONL, une seule colonne `record` suffit :

```sql
-- include/sql/raw/payments.sql
IF OBJECT_ID(N'raw.payments', N'U') IS NULL
BEGIN
    CREATE TABLE raw.payments (
        record        NVARCHAR(MAX),   -- tout le paiement, en JSON texte
        _source_file  NVARCHAR(260),
        _loaded_at    NVARCHAR(30)
    );
END;
```

Pour un CSV / Parquet, **une colonne par champ du fichier**, tout en `NVARCHAR` (+ les 2 colonnes
métadonnées). Exemple `products` :

```sql
IF OBJECT_ID(N'raw.products', N'U') IS NULL
BEGIN
    CREATE TABLE raw.products (
        product_id                    NVARCHAR(100),
        product_category_name         NVARCHAR(200),
        product_name_lenght           NVARCHAR(50),   -- orthographe d'origine : ne pas "corriger" ici
        product_description_lenght    NVARCHAR(50),
        product_photos_qty            NVARCHAR(50),
        product_weight_g              NVARCHAR(50),
        product_length_cm             NVARCHAR(50),
        product_height_cm             NVARCHAR(50),
        product_width_cm              NVARCHAR(50),
        _source_file                  NVARCHAR(260),
        _loaded_at                    NVARCHAR(30)
    );
END;
```

**b) `dags/load_raw_<table>.py`** — copier `load_raw_orders.py` et changer 4 choses :
`TABLE`, `FILE_PATTERN`, le lecteur, et le nom du fichier SQL.

```python
# dags/load_raw_payments.py  (exemple JSON)
from include.olist_raw.loader import (
    CONN_ID, SQL_DIR, count_rows, raw_asset, find_file, read_json_records, write_raw
)
TABLE = "payments"
FILE_PATTERN = "*olist_order_payments_dataset.*"
# ...
sql="sql/raw/payments.sql"                       # create_table
sql=f"TRUNCATE TABLE raw.{TABLE};"                # truncate_table
df = read_json_records(path)                      # load_to_raw
```

La seule ligne qui change vraiment d'une table à l'autre, c'est le **lecteur** :

| Table | Motif de fichier | Lecteur à utiliser |
|---|---|---|
| `order_items` | `*olist_order_items_dataset.*` | `read_parquet_as_is` |
| `payments` | `*olist_order_payments_dataset.*` | `read_json_records` |
| `reviews` | `*olist_order_reviews_dataset.*` | `read_json_records` |
| `customers` | `*olist_customers_dataset.*` | `read_parquet_as_is` |
| `products` | `*olist_products_dataset.*` | `read_csv_as_is` |
| `sellers` | `*olist_sellers_dataset.*` | `read_csv_as_is` |
| `geolocation` | `*olist_geolocation_dataset.*` | `read_parquet_as_is` |
| `category_translation` | `*product_category_name_translation.*` | `read_csv_as_is` |

**À ne pas oublier :**
- garder les 5 tâches dans le même ordre (`find → create_table → truncate_table → load_to_raw → check_rows`) : le test `tests/dags/test_dag_integrity.py` le vérifie ;
- garder `@task(outlets=[raw_asset(TABLE)])` sur `check_rows` : sans ça, `dbt_olist` ne démarrera jamais ;
- `loader.py` vérifie que **toutes les colonnes du fichier existent dans la table**. Erreur
  « These columns … are missing in raw.X » → corrige le `.sql` **puis** `DROP TABLE raw.X` dans SSMS
  (le `CREATE TABLE IF NOT EXISTS` ne modifie pas une table déjà créée) ;
- `geolocation` fait 1 000 163 lignes → ~1 000 lots : c'est long, c'est normal ;
- ne laisse **jamais deux fichiers** correspondant au même motif dans `include/data/olist/`
  (`find_file` prend le premier par ordre alphabétique) ;
- étendre `tests/dags/test_dag_integrity.py` pour boucler sur les 9 tables (actuellement il ne teste que `orders`) ;
- lancer `astro dev pytest` à la fin.

**Validation TP2** : les 9 DAG verts + `include/sql/02_raw_counts_and_audit.sql` (à compléter, il
n'audite que 4 tables aujourd'hui) + les Assets visibles dans l'UI Airflow.

### Étape 2 — TP3 : staging, dimensions, faits

1. Créer les 8 autres `models/staging/stg_<table>.sql` sur le modèle de `stg_orders.sql` :
   - JSON/JSONL → `OPENJSON(...)` pour déplier `record` ;
   - CSV/Parquet → `select {{ clean_text('col') }} ... from {{ source('olist', '<table>') }}` ;
   - appliquer `to_ts`, `to_money`, `to_int`, `zip5`, `clean_text` ;
   - dédupliquer `geolocation` et choisir 1 avis par commande pour `reviews`
     (SQL Server : `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)` puis `WHERE rn = 1` ;
     pas de `QUALIFY` en T-SQL).
2. Déclarer les tests (`not_null`, `unique`, `relationships`) dans `_staging.yml` et les nouveaux `.yml`.
3. Créer `models/marts/dimensions/` (6 dimensions) et `models/marts/facts/` (3 faits) avec
   `surrogate_key()` et `date_key()`.
4. Créer la connexion `mssql_dbt` dans l'UI, puis déclencher le DAG **`dbt_olist`**.
   Cosmos exécute `dbt run` puis `dbt test` pour chaque modèle ; le graphe Airflow = la lignée dbt.

### Étape 3 — TP4 : le cube `Olist Sales`

Suis `cube/README.md` : installer **SQL Server Developer** pour Analysis Services (mode
*Multidimensional*), Visual Studio + l'extension *Analysis Services Projects*, créer la Data Source,
la Data Source View sur `marts`, les 6 dimensions avec hiérarchies, le cube avec 3 groupes de mesures,
puis déployer / traiter / parcourir dans Excel ou SSMS.

⚠️ Le README du cube mentionne `mdx/calculated_members.mdx`, `mdx/business_questions.mdx` et
`include/sql/06_validate_cube_totals.sql` : **ces 3 fichiers n'existent pas dans le dépôt** → à
demander au professeur ou à écrire.

### Étape 4 — Valider avec les chiffres attendus

Ce sont les « réponses du corrigé » (`cube/README.md`). Si tu obtiens ces nombres, ton modèle est juste :

| Contrôle | Valeur attendue |
|---|---|
| Sales Amount (toutes années) | 13 591 643,70 |
| Sales Amount 2016 / 2017 / 2018 | 49 785,92 / 6 155 806,98 / 7 386 050,80 |
| Item Count 2016 / 2017 / 2018 | 370 / 50 864 / 61 416 |
| Payment Value | 16 008 872,12 |
| Taux de retard (commandes livrées) | 6,77 % (6 535 sur 96 476) |

### Ce que tu ne dois **pas** modifier

`include/olist_raw/loader.py` (le README le dit explicitement), `diagnose.py`, le `Dockerfile`,
`requirements.txt`, `profiles.yml`, `dbt_project.yml`, les scripts d'administration `include/sql/0*.sql`.
Tu les **utilises**, tu ne les changes pas.

---

## 8. Les pièges du dépôt lui-même (pour ne pas perdre une heure dessus)

| Problème | Détail | Que faire |
|---|---|---|
| `.env.example` absent | Le README dit `cp .env.example .env` | Créer un `.env` vide (ou demander le fichier au prof) |
| `.gitignore` absent | Les données sont dites « git-ignored » | Ajouter `include/data/olist/`, `.env`, `__pycache__/` |
| `include/data/olist/` absent | Les 9 fichiers ne sont pas fournis | Les récupérer auprès du professeur |
| Fichiers MDX / `06_validate_cube_totals.sql` absents | Référencés par `cube/README.md` | Les réclamer |
| Numérotation des TP incohérente | README : dbt = TP3, cube = TP4 ; `stg_orders.sql` dit « TP 4 » ; `profiles.yml`, `04_scd2_demo.sql` disent « TP7 » ; `05_ssas_service_access.sql` dit « TP8 » | Suis l'ordre logique de ce guide, pas les numéros |
| `_sources.yml` parle du DAG `olist_dw_pipeline` | Ce DAG n'existe pas : il y a 9 DAG `load_raw_*` | Ne pas le chercher |
| `scripts/draw_schema.py` écrivait dans `/home/claude/erd/` | Chemin d'origine de l'auteur | **Corrigé** : écrit maintenant dans `docs/` (SVG toujours, PNG si `cairosvg` est installé) |
| `02_raw_counts_and_audit.sql` | N'audite que 4 tables, cite une tâche `report_counts` inexistante | À compléter en TP2 |
| `test_nine_loading_dags` | Ne teste que `orders` | À étendre aux 9 tables |
| Connexion perdue | Après `astro dev kill` | Recréer `mssql_raw` dans l'UI |

---

## 9. En cas de blocage

| Symptôme | Cause probable | Où regarder |
|---|---|---|
| Une tâche de `test_sql_connection` est rouge | Connexion, driver, DNS, port 1433, mot de passe ou droits | **Le log de la tâche** : il contient le correctif |
| `No file matching ... in include/data/olist` | Fichiers pas déposés ou mauvais nom | `include/data/olist/`, motif `FILE_PATTERN` |
| `These columns ... are missing in raw.X` | Le `CREATE TABLE` ne correspond pas au fichier | Corriger le `.sql` puis `DROP TABLE raw.X` |
| `Row counts differ` | Fichier lu deux fois ou `TRUNCATE` oublié | Log de `load_to_raw` / `check_rows` |
| `dbt_olist` ne démarre pas | Les 9 Assets ne sont pas tous rafraîchis | Vue « Assets » d'Airflow ; sinon déclencher le DAG à la main |
| `Login failed for user` | Mot de passe ou mode d'authentification SQL Server | Admin > Connections ; SSMS > Server Properties > Security |
| `geolocation` très lent | 1 000 163 lignes, 1 000 lots d'INSERT | Normal, attendre |
| `Cannot open database OlistDW` | Champ « Schema » de la connexion vide | Mettre `OlistDW` |

---

## 10. Résumé en une page (checklist)

- [ ] Je comprends : **fichiers → raw (copie) → staging (propre) → marts (étoile) → cube (Excel)**.
- [ ] Je sais qu'`orders` est la table centrale et que `order_id` relie `order_items`, `payments`, `reviews`.
- [ ] Je sais qu'une **PK** identifie une ligne, qu'une **FK** pointe vers une autre table, et qu'une jointure = `RECHERCHEV`.
- [ ] J'ai lu `README.md`, `_sources.yml` et les 4 schémas de `docs/`.
- [ ] J'ai fait tourner `test_sql_connection` (7/7 vert) puis `load_raw_orders` (5/5 vert).
- [ ] TP2 (fichiers fournis, reste à exécuter) : déclencher les 9 DAGs `load_raw_*`, vérifier les 9 compteurs.
- [ ] TP3 : 8 modèles staging + 6 dimensions + 3 faits + tests dbt, via `dbt_olist`.
- [ ] TP4 : cube `Olist Sales`, mesures, hiérarchies, déploiement SSAS.
- [ ] Validation : 13 591 643,70 de ventes et 6,77 % de retards.

**Ordre de lecture recommandé du dossier :**
`README.md` → ce guide + `docs/01_pipeline.png` → `docs/02_relations_raw.png` →
`_sources.yml` → `include/sql/raw/orders.sql` → `dags/load_raw_orders.py` →
`include/olist_raw/loader.py` → `stg_orders.sql` + `macros/casting.sql` →
`dags/dbt_olist.py` → `cube/README.md` → `scripts/convert_formats.py` → `tests/`.

---

*Les schémas sont régénérables avec `python scripts/draw_learning_diagrams.py` et
`python scripts/draw_schema.py` (aucune dépendance pour le SVG).*
