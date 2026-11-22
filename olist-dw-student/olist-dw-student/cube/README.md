# Olist Sales cube (SSAS Multidimensional) — TP 8

Le cube se branche **sur `marts`** (produit par dbt), pas sur `raw`.

Nombre de lignes attendues dans `marts` avant de commencer :

| Table | Lignes |
|---|---|
| `marts.fact_sales` | 112 650 |
| `marts.fact_payments` | 103 886 |
| `marts.fact_orders` | 99 441 |
| `marts.dim_date` | 1 461 (2016-2019) + 1 membre `unknown` = 1 462 |
| `marts.dim_customers` | 99 441 |
| `marts.dim_products` | 32 951 |
| `marts.dim_sellers` | 3 095 |
| `marts.dim_payment_type` | 5 |
| `marts.dim_order_status` | 8 |

---

## 0. Prérequis matériels

SQL Server **Express n' inclut pas Analysis Services**. Il faut installer l'instance SSAS
depuis les médias **gratuits** de SQL Server 2022 **Developer** :

1. Télécharger l'ISO/installeur « SQL Server 2022 Developer » (gratuit, usage non-production).
2. Lancer `setup.exe` → **Installation** → **Nouvelle installation autonome de SQL Server**.
   ⚠️ Ne PAS choisir « Ajouter des fonctionnalités » sur l'instance Express existante :
   une instance Express ne peut pas recevoir SSAS.
3. Écran **Type d'installation** : **Ajouter des fonctionnalités à une instance existante** →
   sélectionner une **nouvelle** instance nommée, par exemple `OLAP` → l'écran
   **Sélection de fonctionnalités** propose alors **Analysis Services**.
   Plus simple encore : choisir **Nouvelle instance** et ne cocher QUE
   **Analysis Services** (décocher Moteur de base de données).
4. Écran **Configuration d'Analysis Services** :
   * Mode serveur : **Multidimensionnel et exploration de données** (surtout pas Tabular) ;
   * Administrateurs : ajouter votre compte Windows (`DESKTOP-xxx\votre_nom`) ;
   * Ajouter l'utilisateur actuel : **coché**.
5. Le compte de service reste `NT Service\MSSQLServerOLAPService` (instance par défaut) ou
   `NT Service\MSSQLServerOLAPService$OLAP` (instance nommée `OLAP`).
6. Vérifier : `services.msc` → *SQL Server Analysis Services* → **En cours d'exécution**.

> Le moteur de base de données reste sur Express : les deux instances cohabitent sans
> problème, elles n'utilisent pas le même port.

## 1. Droits du compte de service SSAS sur le DW

Dans SSMS (moteur de base de données, en admin) : exécuter
`include/sql/05_ssas_service_access.sql`. Il crée le login Windows du service et lui donne
`SELECT` sur le schéma `marts`.

Contrôle (PowerShell admin) pour connaître le nom exact du compte :

```powershell
Get-CimInstance Win32_Service -Filter "Name like '%OLAP%'" | Select-Object Name, StartName
```

## 2. Visual Studio + extension

1. Installer **Visual Studio 2022 Community** (gratuit) avec la charge de travail
   **« Développement Azure »** ou **« Stockage et traitement des données »**.
2. Dans *Gérer les extensions* → onglet **En ligne** → chercher
   **« Microsoft Analysis Services Projects »** → installer → redémarrer VS.
3. *Fichier → Nouveau → Projet* → **Analysis Services Multidimensional and Data Mining
   Project** → nom `OlistCube`, emplacement `C:\dev\OlistCube`.

## 3. Data Source (connexion au DW)

Double-clic sur **Data Sources** → *Nouvelle source de données* :

| Champ | Valeur |
|---|---|
| Fournisseur | **Microsoft OLE DB Driver for SQL Server** (ou *SQL Server Native Client*) |
| Serveur | `localhost\SQLEXPRESS` |
| Authentification | **Utiliser l'authentification Windows** |
| Base de données | `OlistDW` |
| Impersonation | **Utiliser le compte de service** |

Si « Utiliser le compte de service » échoue au traitement avec
`Login failed for user 'NT SERVICE\MSSQLSERVEROLAPService'`, c'est que l'étape 1 n'a pas été
faite (ou que le nom du compte est celui d'une instance nommée — voir le commentaire en fin
de `05_ssas_service_access.sql` pour la variante « utilisateur spécifique » avec
`olist_dbt_login`).

## 4. Data Source View (DSV)

Sélectionner **toutes les tables du schéma `marts`** (9 tables) puis *Terminer*.

Nommer les relations comme dans le schéma en étoile :

| Table de faits | Colonne | Table de dimension | Colonne |
|---|---|---|---|
| `fact_sales` | `date_key` | `dim_date` | `date_key` |
| `fact_sales` | `customer_key` | `dim_customers` | `customer_key` |
| `fact_sales` | `product_key` | `dim_products` | `product_key` |
| `fact_sales` | `seller_key` | `dim_sellers` | `seller_key` |
| `fact_sales` | `order_status_key` | `dim_order_status` | `order_status_key` |
| `fact_payments` | `date_key` | `dim_date` | `date_key` |
| `fact_payments` | `customer_key` | `dim_customers` | `customer_key` |
| `fact_payments` | `payment_type_key` | `dim_payment_type` | `payment_type_key` |
| `fact_orders` | `purchase_date_key` | `dim_date` | `date_key` |
| `fact_orders` | `approved_date_key` | `dim_date` | `date_key` |
| `fact_orders` | `delivered_carrier_date_key` | `dim_date` | `date_key` |
| `fact_orders` | `delivered_customer_date_key` | `dim_date` | `date_key` |
| `fact_orders` | `customer_key` | `dim_customers` | `customer_key` |
| `fact_orders` | `order_status_key` | `dim_order_status` | `order_status_key` |

⚠️ Les 4 relations de `fact_orders` vers `dim_date` seront signalées comme
**« relations ambiguës »** par l'assistant : c'est **normal et voulu** (Rôle-playing
dimension). Il faudra choisir un *rôle* différent pour chacune à l'étape 6.

## 5. Dimensions

Pour chaque dimension : clic droit sur **Dimensions** → *Nouvelle dimension* → cocher
**Utiliser une table existante** → choisir la table.

| Dimension | Clé (Key) | Name | Hiérarchie à créer |
|---|---|---|---|
| `dim_date` → **Date** | `date_key` | `full_date` | **Calendar** : Calendar Year (`year`) > Quarter (`quarter_key`) > Month (`month_key`) > Day (`full_date`) |
| `dim_customers` → **Customer** | `customer_key` | `customer_id` | **Geography** : State > City > Customer |
| `dim_products` → **Product** | `product_key` | `product_id` | **Categories** : Category (`category_name_english`) > Product |
| `dim_sellers` → **Seller** | `seller_key` | `seller_id` | **Geography** : State > City > Seller |
| `dim_payment_type` → **Payment Type** | `payment_type_key` | `payment_type` | — |
| `dim_order_status` → **Order Status** | `order_status_key` | `order_status` | — |

Points qui font échouer le traitement si on les oublie :

* **Date** : la table a **deux jeux de colonnes** et c'est volontaire :
  * l'attribut **Day** a pour **Key** `date_key` (INT YYYYMMDD, utilisé par les relations
    des tables de faits) et pour **Name** `full_date` ;
  * les attributs **Calendar Year**, **Quarter** et **Month** ont pour **Key**
    `year`, `quarter_key` (AAAAC, ex. `20171`) et `month_key` (AAAAMM, ex. `201701`),
    et pour **Name** `year`, `quarter` (1-4) et `month_name` (« January »…).

  ⚠️ **Ne mettez pas `month` ou `quarter` en clé** : ces valeurs (1-12, 1-4) se répètent
  chaque année, SSAS fusionnerait alors les 4 janvier en un seul membre. C'est justement
  pour cela que `dim_date` expose `month_key` et `quarter_key`.
  Le membre `date_key = -1` (« Unknown ») est indispensable : sans lui, les lignes dont la
  date est inconnue seraient perdues.

  Construction dans VS : assistant Dimension → décocher les colonnes inutiles
  (`month`, `quarter`, `day_of_month`, `day_of_week`, `day_name`, `is_weekend` restent des
  attributs désactivés/masqués), puis dans l'onglet *Attributs* : clic droit sur
  `month_key` → *Propriétés* → `NameColumn = month_name`, `OrderBy = Key` ;
  idem `quarter_key` avec `NameColumn = quarter` ; `date_key` avec
  `NameColumn = full_date`.
* **Order Status** : attribut `Order Status` = `order_status` (clé) / `order_status_label`
  (nom). C'est `[Order Status].[Order Status].[Delivered]` qui est utilisé dans les
  calculs (le nom du membre est `Delivered`, pas `delivered`).
* **Product** : attribut **Category** = `category_name_english` (pas `category_name`, qui est
  le portugais). Les 610 produits sans catégorie valent déjà `unknown`.
* Lors de l'assistant dimension, accepter **« Aucune relation détectée »** en le corrigeant
  à la main dans l'onglet *Relations d'attributs* si VS ne trouve pas la table liée
  (`dim_products` est reliée à elle-même, pas de hiérarchie naturelle à détecter).

## 6. Cube et groupes de mesures

Clic droit sur **Cubes** → *Nouveau cube* → **Utiliser les tables existantes** :

| Groupe de mesures | Table | Colonnes de mesure | Mesures renommées |
|---|---|---|---|
| **Sales** | `fact_sales` | `price`, `freight_value`, `total_value`, `item_count`, `order_id` | **Sales Amount**, **Freight Amount**, **Total Amount**, **Item Count**, **Order Count** |
| **Payments** | `fact_payments` | `payment_value`, `payment_installments` | **Payment Value**, **Installments** |
| **Orders** | `fact_orders` | `orders_count`, `is_late`, `delivery_days`, `review_score` | **Orders Count**, **Late Orders**, **Delivery Days**, **Review Score Sum** |

* **Order Count** est une mesure **Distinct Count** sur `order_id` (clic droit sur la
  mesure → *Propriétés* → `AggregateFunction = DistinctCount`). C'est la seule façon
  d'obtenir 99 441 et non 112 650.
* `is_late`, `orders_count`, `item_count` sont des colonnes INT : SSAS les prend comme
  mesures *Sum* par défaut, c'est exactement ce qu'on veut.
* `delivery_days` et `review_score` peuvent être NULL (commande non livrée / sans avis) :
  la *Sum* les ignore, c'est le comportement attendu pour les moyennes.

Puis, dans l'onglet **Dimension Usage** du cube designer, affecter les rôles :

| Groupe de mesures | Dimension | Relation |
|---|---|---|
| Sales | Date | `date_key` → Regular |
| Sales | Customer / Product / Seller / Order Status | Regular |
| Payments | Date, Customer, Payment Type | Regular |
| Orders | **Purchase Date** | `purchase_date_key` |
| Orders | **Approved Date** | `approved_date_key` |
| Orders | **Delivered to Carrier Date** | `delivered_carrier_date_key` |
| Orders | **Delivered to Customer Date** | `delivered_customer_date_key` |
| Orders | Customer, Order Status | Regular |

Les 4 rôles de Date se renomment dans l'onglet *Dimension Usage* (colonne `Date` :
`Purchase Date`, etc.). **Sans ces rôles, le cube ne se déploie pas** (« ambigu »).

## 7. Calculs

Onglet **Calculations** → onglet *Script view* (icône `{}`) → remplacer tout le contenu par
`mdx/calculated_members.mdx` → **Build** (icône ✔) puis **Deploy**.

## 8. Déploiement et traitement

* Projet → *Propriétés* → **Deployment** :
  * Server : `localhost` (ou `localhost\OLAP` pour une instance nommée) ;
  * Database : `OlistDW`.
* **Générer** puis **Déployer** (clic droit sur le projet → *Deploy*). Le traitement peut
  être lancé automatiquement : sinon, dans SSMS, clic droit sur la base `OlistDW` →
  *Browse* / *Process*.
* Vérifier : SSMS → clic droit sur **Analysis Services** → *Se connecter* → base `OlistDW`
  → cube `Olist Sales`.

## 9. Résultats attendus (valeurs de référence du cours)

| Contrôle | Valeur |
|---|---|
| Sales Amount (toutes années) | 13 591 643,70 |
| Sales Amount 2016 / 2017 / 2018 | 49 785,92 / 6 155 806,98 / 7 386 050,80 |
| Item Count 2016 / 2017 / 2018 | 370 / 50 864 / 61 416 |
| Payment Value | 16 008 872,12 |
| Late Rate (commandes livrées) | 6,77 % (6 534 sur 96 478) |
| Orders Count (`fact_orders`) | 99 441 |
| Order Count sur `fact_sales` (distinct `order_id`) | 98 666 (775 commandes n'ont aucune ligne) |
| Installments (`SUM(payment_installments)`) | 296 423 (le 104 634 du document de cours ne correspond pas à la somme de la colonne) |

Requêtes : `mdx/business_questions.mdx` (SSAS). Contrôle SQL équivalent :
`include/sql/06_validate_warehouse_totals.sql` (moteur de base de données).

## 10. Trois pièges qui changent les chiffres

1. **Le Late Rate se calcule sur les commandes livrées seulement.**
   `Late Orders / Orders Count` sur *toutes* les commandes donne 0,79 % ; la référence
   6,77 % est `Late Orders / Delivered Orders` (6 534 / 96 478). Le membre
   `[Measures].[Late Rate]` restreint déjà à `[Order Status].[Order Status].[Delivered]`.
2. **`is_late` compare des dates, pas des horodatages.** `fact_orders` le calcule au jour ;
   sur les timestamps on obtient 7 826 (8,11 %) parce que la date estimée est stockée à
   00:00:00.
3. **Deux chiffres du document de cours ne correspondent pas aux fichiers sources**, et le DW
   donne raison aux fichiers : `COUNT(DISTINCT order_id)` sur `fact_sales` vaut **98 666**
   (les 775 commandes annulées/indisponibles avant tout article n'ont aucune ligne — le
   99 441 est le nombre de *commandes*, à lire sur `fact_orders`), et
   `SUM(payment_installments)` vaut **296 423** (103 886 paiements, maximum 24 fois).
   Le script `06_validate_warehouse_totals.sql` contient les deux contrôles (§8).

## 11. Fichiers de ce dossier

| Fichier | Contenu |
|---|---|
| `mdx/calculated_members.mdx` | membres calculés + jeux nommés à coller dans l'onglet **Calculations** |
| `mdx/business_questions.mdx` | 14 requêtes MDX à exécuter dans SSMS et à comparer aux valeurs de référence |
| `../include/sql/05_ssas_service_access.sql` | droits `SELECT` du compte de service SSAS sur `marts` |
| `../include/sql/06_validate_warehouse_totals.sql` | les mêmes chiffres vérifiés **en SQL** sur `marts`, avant d'ouvrir le cube |
