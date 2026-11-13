/* =====================================================================
   EEIP · Script 12 : le laboratoire d'optimisation
   ---------------------------------------------------------------------
   À exécuter BLOC PAR BLOC (sélectionne le bloc, puis F5), APRÈS le
   premier chargement complet. Active le plan d'exécution réel :
   menu Requête > Inclure le plan d'exécution réel (Ctrl+M).
   Lis toujours deux choses : l'onglet Messages (lectures, temps) et le
   plan (opérateurs, mode Batch ou Row, partitions lues).
   ===================================================================== */
USE EEIP;
GO

/* ---------- Labo 1 : ce que contient chaque partition (les 15 plus récentes) ---------- */
SELECT TOP (15)
        p.partition_number                  AS Partition_,
        fg.name                             AS GroupeDeFichiers,
        CAST(prv.value AS date)             AS BorneBasse,
        p.rows                              AS Lignes,
        p.data_compression_desc             AS Compression
FROM sys.partitions AS p
JOIN sys.indexes AS i              ON i.object_id = p.object_id AND i.index_id = p.index_id
JOIN sys.partition_schemes AS ps   ON ps.data_space_id = i.data_space_id
JOIN sys.destination_data_spaces AS dds
                                   ON dds.partition_scheme_id = ps.data_space_id
                                  AND dds.destination_id = p.partition_number
JOIN sys.filegroups AS fg          ON fg.data_space_id = dds.data_space_id
LEFT JOIN sys.partition_range_values AS prv
                                   ON prv.function_id = ps.function_id
                                  AND prv.boundary_id = p.partition_number - 1
WHERE p.object_id = OBJECT_ID(N'core.Mesure') AND i.index_id = 1
ORDER BY CASE WHEN p.rows > 0 THEN 0 ELSE 1 END, p.partition_number DESC;
GO

/* ---------- Labo 2 : élimination de partitions ----------
   Dans le plan : propriété « Actual Partition Count » de l'opérateur Columnstore Index Scan. */
SET STATISTICS IO, TIME ON;

-- MAUVAIS : une fonction appliquée à la colonne, SQL Server doit lire toutes les partitions
SELECT COUNT(*) AS Nb, AVG(Valeur) AS Moyenne
FROM core.Mesure
WHERE CAST(InstantUtc AS date) >= '2025-01-01' AND CAST(InstantUtc AS date) < '2025-02-01';

-- BON : un intervalle sur la colonne brute, une seule partition lue
SELECT COUNT(*) AS Nb, AVG(Valeur) AS Moyenne
FROM core.Mesure
WHERE InstantUtc >= '2025-01-01' AND InstantUtc < '2025-02-01';

SET STATISTICS IO, TIME OFF;
GO

/* ---------- Labo 3 : l'heure locale sans détruire les performances ----------
   AT TIME ZONE sur la colonne : calcul ligne à ligne, aucune élimination.
   Bornes converties UNE fois en UTC : élimination et mode batch intacts. */
SET STATISTICS TIME ON;

SELECT COUNT(*) AS Nb
FROM core.Mesure
WHERE CAST(InstantUtc AT TIME ZONE 'UTC' AT TIME ZONE 'Romance Standard Time' AS date) = '2025-07-14';

DECLARE @d datetime2(0) = CAST(SWITCHOFFSET(CAST('2025-07-14' AS datetime2(0)) AT TIME ZONE 'Romance Standard Time', '+00:00') AS datetime2(0));
SELECT COUNT(*) AS Nb
FROM core.Mesure
WHERE InstantUtc >= @d AND InstantUtc < DATEADD(DAY, 1, @d);

SET STATISTICS TIME OFF;
GO

/* ---------- Labo 4 : le columnstore ORDONNÉ saute des segments entiers ----------
   Onglet Messages : « segment reads » et « segment skipped ». Le tri par
   SerieId fait que la plupart des segments ne contiennent pas la série demandée. */
DECLARE @serie int = (SELECT TOP (1) SerieId FROM core.Serie ORDER BY NbPoints DESC);
SET STATISTICS IO ON;
SELECT @serie AS Serie, COUNT(*) AS Nb, MIN(Valeur) AS Mini, MAX(Valeur) AS Maxi
FROM core.Mesure
WHERE SerieId = @serie;
SET STATISTICS IO OFF;

-- La preuve, segment par segment : plages de SerieId et nombre de lignes
SELECT TOP (20) p.partition_number AS Partition_, s.segment_id, s.row_count,
       s.min_data_id AS SerieIdMin, s.max_data_id AS SerieIdMax
FROM sys.column_store_segments AS s
JOIN sys.partitions AS p ON p.hobt_id = s.hobt_id
JOIN sys.columns AS c ON c.object_id = p.object_id AND c.column_id = s.column_id
WHERE p.object_id = OBJECT_ID(N'core.Mesure') AND c.name = N'SerieId'
ORDER BY p.partition_number DESC, s.segment_id;
GO

/* ---------- Labo 5 : mode batch contre mode ligne ----------
   Même agrégat ; compare « CPU time » et, dans le plan, « Actual Execution Mode ». */
SET STATISTICS TIME ON;

SELECT s.IndicateurId, DATE_BUCKET(MONTH, 1, m.InstantUtc) AS Mois, COUNT(*) AS Nb, AVG(m.Valeur) AS Moyenne
FROM core.Mesure AS m JOIN core.Serie AS s ON s.SerieId = m.SerieId
GROUP BY s.IndicateurId, DATE_BUCKET(MONTH, 1, m.InstantUtc);

SELECT s.IndicateurId, DATE_BUCKET(MONTH, 1, m.InstantUtc) AS Mois, COUNT(*) AS Nb, AVG(m.Valeur) AS Moyenne
FROM core.Mesure AS m JOIN core.Serie AS s ON s.SerieId = m.SerieId
GROUP BY s.IndicateurId, DATE_BUCKET(MONTH, 1, m.InstantUtc)
OPTION (USE HINT ('DISALLOW_BATCH_MODE'));

SET STATISTICS TIME OFF;
GO

/* ---------- Labo 6 : la santé des groupes de lignes ----------
   OPEN = magasin delta (petits chargements horaires), COMPRESSED = columnstore.
   trim_reason explique un groupe de moins d'un million de lignes. */
SELECT rg.partition_number AS Partition_, rg.state_desc AS Etat, COUNT(*) AS Groupes,
       SUM(rg.total_rows) AS Lignes, SUM(rg.deleted_rows) AS LignesSupprimees,
       MAX(rg.trim_reason_desc) AS RaisonCoupe
FROM sys.dm_db_column_store_row_group_physical_stats AS rg
WHERE rg.object_id = OBJECT_ID(N'core.Mesure')
GROUP BY rg.partition_number, rg.state_desc
ORDER BY rg.partition_number DESC;

-- Compresser tout de suite le magasin delta et purger les lignes supprimées
ALTER INDEX CCI_Mesure ON core.Mesure REORGANIZE WITH (COMPRESS_ALL_ROW_GROUPS = ON);
GO

/* ---------- Labo 7 : la recherche ponctuelle passe par la clé non cluster ----------
   C'est le chemin des révisions : quelques lectures, quelle que soit la taille de la table. */
DECLARE @s int = (SELECT TOP (1) SerieId FROM core.Serie ORDER BY NbPoints DESC);
DECLARE @i datetime2(0) = (SELECT DernierInstant FROM core.Serie WHERE SerieId = @s);
SET STATISTICS IO ON;
SELECT SerieId, InstantUtc, Valeur, Qualite FROM core.Mesure WHERE SerieId = @s AND InstantUtc = @i;
SET STATISTICS IO OFF;
GO

/* ---------- Labo 8 : percentile exact ou approché (SQL Server 2022) ---------- */
SET STATISTICS TIME ON;
SELECT DISTINCT s.ZoneId,
       PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY m.Valeur) OVER (PARTITION BY s.ZoneId) AS P95Exact
FROM core.Mesure AS m JOIN core.Serie AS s ON s.SerieId = m.SerieId
JOIN core.Indicateur AS i ON i.IndicateurId = s.IndicateurId AND i.Code = 'PRIX_SPOT_J1';

SELECT s.ZoneId, APPROX_PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY m.Valeur) AS P95Approche
FROM core.Mesure AS m JOIN core.Serie AS s ON s.SerieId = m.SerieId
JOIN core.Indicateur AS i ON i.IndicateurId = s.IndicateurId AND i.Code = 'PRIX_SPOT_J1'
GROUP BY s.ZoneId;
SET STATISTICS TIME OFF;
GO

/* ---------- Labo 9 : un plan par profil de paramètre (PSP, SQL Server 2022) ----------
   La France a des dizaines de séries, une région une ou deux : SQL Server peut
   garder plusieurs plans pour la même procédure. Lance les deux appels, puis
   regarde les variantes enregistrées par le Query Store. */
EXEC api.usp_Serie_Obtenir @Indicateur = 'PROD_ELEC', @Zone = 'FR', @Pas = 'P1D';
EXEC api.usp_Serie_Obtenir @Indicateur = 'PROD_ELEC', @Zone = 'FR-BRE', @Pas = 'P1D';
SELECT v.query_variant_query_id, v.parent_query_id, v.dispatcher_plan_id
FROM sys.query_store_query_variant AS v;
GO

/* ---------- Labo 10 : le Query Store, boîte noire et levier (indications) ---------- */
SELECT TOP (10)
        q.query_id,
        LEFT(qt.query_sql_text, 120)                                                    AS DebutRequete,
        SUM(rs.count_executions)                                                        AS Executions,
        CAST(SUM(rs.avg_duration * rs.count_executions) / 1000.0 AS decimal(18,1))      AS DureeTotaleMs,
        CAST(MAX(rs.max_logical_io_reads) AS bigint)                                    AS MaxLecturesLogiques,
        COUNT(DISTINCT p.plan_id)                                                       AS NbPlans
FROM sys.query_store_query AS q
JOIN sys.query_store_query_text    AS qt ON qt.query_text_id = q.query_text_id
JOIN sys.query_store_plan          AS p  ON p.query_id = q.query_id
JOIN sys.query_store_runtime_stats AS rs ON rs.plan_id = p.plan_id
GROUP BY q.query_id, LEFT(qt.query_sql_text, 120)
ORDER BY DureeTotaleMs DESC;

-- Exemple d'indication posée SANS toucher au code (remplace 0 par un query_id du tableau) :
-- EXEC sys.sp_query_store_set_hints @query_id = 0, @query_hints = N'OPTION (MAXDOP 2)';
-- EXEC sys.sp_query_store_clear_hints @query_id = 0;
SELECT query_id, query_hint_text FROM sys.query_store_query_hints;
GO

/* ---------- Labo 11 : combien ferait gagner COLUMNSTORE_ARCHIVE sur une partition ancienne ? ---------- */
DECLARE @p int = (SELECT MIN(p.partition_number) FROM sys.partitions AS p
                  WHERE p.object_id = OBJECT_ID(N'core.Mesure') AND p.index_id = 1 AND p.rows > 0
                    AND p.partition_number > 1);
EXEC sys.sp_estimate_data_compression_savings
     @schema_name = N'core', @object_name = N'Mesure', @index_id = 1,
     @partition_number = @p, @data_compression = N'COLUMNSTORE_ARCHIVE';
GO

/* ---------- Labo 12 : voyage dans le temps ----------
   Un quart d'heure de production nucléaire française : toutes ses versions
   (temps réel, puis consolidé, puis définitif), puis l'état connu il y a 30 jours. */
DECLARE @inst datetime2(0) = (SELECT TOP (1) m.InstantUtc
                              FROM core.MesureHistorique AS m
                              JOIN core.Serie AS s ON s.SerieId = m.SerieId
                              JOIN core.Filiere AS f ON f.FiliereId = s.FiliereId AND f.Code = 'NUCLEAIRE'
                              JOIN core.Zone AS z ON z.ZoneId = s.ZoneId AND z.Code = 'FR'
                              ORDER BY m.ValidTo DESC);
SELECT @inst AS InstantEtudie;
IF @inst IS NOT NULL
    EXEC api.usp_Revisions_Lister @Indicateur = 'PROD_ELEC', @Zone = 'FR', @Filiere = 'NUCLEAIRE', @InstantUtc = @inst;

DECLARE @vu datetime2(3) = DATEADD(DAY, -30, SYSUTCDATETIME());
EXEC api.usp_Serie_Obtenir @Indicateur = 'CONSO_ELEC', @Zone = 'FR', @Pas = 'P1D',
                           @Debut = '2025-01-01', @Fin = '2025-01-08', @VuAuUtc = @vu;
GO
