/* =====================================================================
   EEIP · Script 14 : la liste de contrôle finale, automatique
   ---------------------------------------------------------------------
   La plateforme se contrôle elle-même : 14 lignes, OK ou À FAIRE.
   ===================================================================== */
USE EEIP;
WITH C AS (
    SELECT 1 AS N, N'7 fichiers, 6 groupes, RCSI, ADR et Query Store actifs' AS Controle,
           CASE WHEN (SELECT COUNT(*) FROM sys.database_files) = 7
                 AND (SELECT COUNT(*) FROM sys.filegroups) = 6
                 AND (SELECT is_read_committed_snapshot_on FROM sys.databases WHERE name = N'EEIP') = 1
                 AND (SELECT is_accelerated_database_recovery_on FROM sys.databases WHERE name = N'EEIP') = 1
                 AND (SELECT actual_state_desc FROM sys.database_query_store_options) = N'READ_WRITE'
                THEN 1 ELSE 0 END AS Ok
    UNION ALL
    SELECT 2, N'8 schémas, 2 rôles, compte de l''Agent dans eeip_chargeur',
           CASE WHEN (SELECT COUNT(*) FROM sys.schemas WHERE name IN ('cfg','raw','stg','core','dq','mart','api','ops')) = 8
                 AND (SELECT COUNT(*) FROM sys.database_principals WHERE type = 'R' AND name IN ('eeip_chargeur','eeip_lecteur')) = 2
                 AND EXISTS (SELECT 1 FROM sys.database_role_members AS rm
                             JOIN sys.database_principals AS r ON r.principal_id = rm.role_principal_id
                             JOIN sys.database_principals AS m ON m.principal_id = rm.member_principal_id
                             WHERE r.name = 'eeip_chargeur' AND m.name LIKE N'%SQL%Agent%')
                THEN 1 ELSE 0 END
    UNION ALL
    SELECT 3, N'Partitions mensuelles prêtes 2 mois à l''avance, la dernière vide',
           CASE WHEN (SELECT fanout FROM sys.partition_functions WHERE name = N'pf_MoisUtc') >= 130
                 AND (SELECT MAX(CAST(prv.value AS date)) FROM sys.partition_range_values AS prv
                      JOIN sys.partition_functions AS pf ON pf.function_id = prv.function_id
                      WHERE pf.name = N'pf_MoisUtc') >= DATEADD(MONTH, 2, DATETRUNC(MONTH, CAST(GETDATE() AS date)))
                 AND (SELECT TOP (1) p.rows FROM sys.partitions AS p
                      WHERE p.object_id = OBJECT_ID(N'core.Mesure') AND p.index_id = 1
                      ORDER BY p.partition_number DESC) = 0
                THEN 1 ELSE 0 END
    UNION ALL
    SELECT 4, N'core.Mesure : temporelle, columnstore ordonné, clé alignée',
           CASE WHEN (SELECT temporal_type FROM sys.tables WHERE object_id = OBJECT_ID(N'core.Mesure')) = 2
                 AND EXISTS (SELECT 1 FROM sys.index_columns
                             WHERE object_id = OBJECT_ID(N'core.Mesure') AND index_id = 1 AND column_store_order_ordinal = 1)
                 AND EXISTS (SELECT 1 FROM sys.indexes AS i JOIN sys.partition_schemes AS ps ON ps.data_space_id = i.data_space_id
                             WHERE i.object_id = OBJECT_ID(N'core.Mesure') AND i.name = N'PK_Mesure')
                THEN 1 ELSE 0 END
    UNION ALL
    SELECT 5, N'Référentiel : 50 zones, 30 filières, 21 indicateurs, 100 requêtes',
           CASE WHEN (SELECT COUNT(*) FROM core.Zone WHERE Origine = 'REFERENCE') >= 50
                 AND (SELECT COUNT(*) FROM core.Filiere) >= 30
                 AND (SELECT COUNT(*) FROM core.Indicateur) >= 21
                 AND (SELECT COUNT(*) FROM cfg.RequeteACharger) >= 100
                THEN 1 ELSE 0 END
    UNION ALL
    SELECT 6, N'Heure d''été et d''hiver : 7 fuseaux calculés',
           CASE WHEN (SELECT COUNT(DISTINCT Fuseau) FROM core.FuseauDecalage) >= 7
                 AND (SELECT MIN(n) FROM (SELECT COUNT(*) AS n FROM core.FuseauDecalage GROUP BY Fuseau) AS x) >= 60
                THEN 1 ELSE 0 END
    UNION ALL
    SELECT 7, N'éCO2mix chargé : un lot ODRE de plus de 100 000 lignes',
           CASE WHEN EXISTS (SELECT 1 FROM ops.Lot WHERE Sources LIKE '%ODRE%'
                             AND Statut IN ('SUCCES', 'PARTIEL') AND NbInserees > 100000)
                THEN 1 ELSE 0 END
    UNION ALL
    SELECT 8, N'ENTSO-E chargé : prix spot de 10 zones ou plus',
           CASE WHEN (SELECT COUNT(DISTINCT s.ZoneId) FROM core.Serie AS s
                      JOIN core.Indicateur AS i ON i.IndicateurId = s.IndicateurId
                      WHERE i.Code = 'PRIX_SPOT_J1' AND s.NbPoints > 1000) >= 10
                THEN 1 ELSE 0 END
    UNION ALL
    SELECT 9, N'Eurostat chargé : panel annuel de plus de 500 lignes',
           CASE WHEN (SELECT COUNT(*) FROM mart.PanelPaysAnnee) > 500 THEN 1 ELSE 0 END
    UNION ALL
    SELECT 10, N'Historisation : des versions remplacées dans l''historique',
           CASE WHEN EXISTS (SELECT 1 FROM core.MesureHistorique) THEN 1 ELSE 0 END
    UNION ALL
    SELECT 11, N'Brut compressé plus de 5 fois et relisible',
           CASE WHEN (SELECT SUM(CAST(TailleOctets AS bigint)) * 1.0 / NULLIF(SUM(DATALENGTH(ContenuGzip)), 0)
                      FROM raw.Payload) > 5
                 AND EXISTS (SELECT 1 FROM raw.vw_PayloadLisible
                             WHERE PayloadId = (SELECT MAX(PayloadId) FROM raw.Payload) AND LEN(Contenu) > 0)
                THEN 1 ELSE 0 END
    UNION ALL
    SELECT 12, N'Agrégats quotidiens et mix de la France disponibles',
           CASE WHEN (SELECT COUNT(*) FROM mart.MesureJour) > 10000
                 AND EXISTS (SELECT 1 FROM mart.vw_MixJour WHERE Zone = 'FR' AND Famille = 'NUCLEAIRE')
                THEN 1 ELSE 0 END
    UNION ALL
    SELECT 13, N'API de lecture : 5 procédures',
           CASE WHEN (SELECT COUNT(*) FROM sys.procedures WHERE schema_id = SCHEMA_ID('api')) = 5 THEN 1 ELSE 0 END
    UNION ALL
    SELECT 14, N'Les 3 travaux de l''Agent existent, le temps réel a déjà réussi',
           CASE WHEN (SELECT COUNT(*) FROM msdb.dbo.sysjobs WHERE name LIKE N'EEIP%') = 3
                 AND EXISTS (SELECT 1 FROM msdb.dbo.sysjobs AS j
                             JOIN msdb.dbo.sysjobhistory AS h ON h.job_id = j.job_id AND h.step_id = 0 AND h.run_status = 1
                             WHERE j.name = N'EEIP · Temps réel')
                THEN 1 ELSE 0 END
)
SELECT N, Controle, CASE Ok WHEN 1 THEN N'OK' ELSE N'À FAIRE' END AS Resultat
FROM C
ORDER BY N;
