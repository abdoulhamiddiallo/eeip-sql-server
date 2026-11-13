/* =====================================================================
   EEIP · Script 03 : partitionnement MENSUEL
   ---------------------------------------------------------------------
   Une électricité mesurée toutes les 15 minutes produit des millions de
   lignes : on découpe par MOIS.
   pf_MoisUtc  (datetime2(0)) : pour core.Mesure, en temps UTC
   pf_MoisDate (date)         : pour la couche analytique, en jours locaux
   RANGE RIGHT : chaque borne est le PREMIER instant de sa partition.
     partition 1      : tout ce qui est avant 2015-01-01 (FG_ARCHIVE)
     partitions 2..N  : un mois chacune, de janvier 2015 à M+3 (FG_MESURE)
     partition N+1    : au-delà de la dernière borne : TOUJOURS VIDE
   Avec un index columnstore, SQL Server ne coupe (SPLIT) qu'une partition
   vide : la procédure ops.usp_Partition_Etendre (script 13) ajoute
   chaque mois la borne suivante, la dernière partition reste vide.
   Les bornes sont générées par GENERATE_SERIES (SQL Server 2022).
   ===================================================================== */
USE EEIP;
GO

DECLARE @fin date = DATEADD(MONTH, 4, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1));
DECLARE @nb int = DATEDIFF(MONTH, '2015-01-01', @fin);       -- nombre de bornes
DECLARE @bornesUtc nvarchar(max), @bornesDate nvarchar(max), @groupes nvarchar(max), @sql nvarchar(max);

SELECT @bornesUtc  = STRING_AGG(CAST(N'''' + CONVERT(nchar(10), DATEADD(MONTH, s.value, CAST('2015-01-01' AS date)), 23) + N' 00:00:00''' AS nvarchar(max)), N', ')
                         WITHIN GROUP (ORDER BY s.value),
       @bornesDate = STRING_AGG(CAST(N'''' + CONVERT(nchar(10), DATEADD(MONTH, s.value, CAST('2015-01-01' AS date)), 23) + N'''' AS nvarchar(max)), N', ')
                         WITHIN GROUP (ORDER BY s.value),
       @groupes    = STRING_AGG(CAST(N'FG_MESURE' AS nvarchar(max)), N', ')
FROM GENERATE_SERIES(0, @nb - 1) AS s;

IF NOT EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = N'pf_MoisUtc')
BEGIN
    SET @sql = N'CREATE PARTITION FUNCTION pf_MoisUtc (datetime2(0)) AS RANGE RIGHT FOR VALUES (' + @bornesUtc + N');';
    EXEC sys.sp_executesql @sql;
    -- @nb bornes donnent @nb + 1 partitions : la première en archive, les @nb autres en FG_MESURE
    SET @sql = N'CREATE PARTITION SCHEME ps_MoisUtc AS PARTITION pf_MoisUtc TO (FG_ARCHIVE, ' + @groupes + N');';
    EXEC sys.sp_executesql @sql;
    -- le groupe qui recevra la prochaine partition créée par SPLIT
    EXEC sys.sp_executesql N'ALTER PARTITION SCHEME ps_MoisUtc NEXT USED FG_MESURE;';
END

IF NOT EXISTS (SELECT 1 FROM sys.partition_functions WHERE name = N'pf_MoisDate')
BEGIN
    SET @sql = N'CREATE PARTITION FUNCTION pf_MoisDate (date) AS RANGE RIGHT FOR VALUES (' + @bornesDate + N');';
    EXEC sys.sp_executesql @sql;
    EXEC sys.sp_executesql N'CREATE PARTITION SCHEME ps_MoisDate AS PARTITION pf_MoisDate ALL TO (FG_MART);';
END
GO

/* Contrôle : nombre de partitions et dernière borne */
SELECT pf.name AS Fonction, pf.fanout AS Partitions,
       MIN(CAST(prv.value AS date)) AS PremiereBorne, MAX(CAST(prv.value AS date)) AS DerniereBorne
FROM sys.partition_functions AS pf
JOIN sys.partition_range_values AS prv ON prv.function_id = pf.function_id
WHERE pf.name IN (N'pf_MoisUtc', N'pf_MoisDate')
GROUP BY pf.name, pf.fanout;

/* Dans quelle partition tombe chaque instant ? */
SELECT d.Exemple, $PARTITION.pf_MoisUtc(d.Exemple) AS NumeroPartition
FROM (VALUES (CAST('1990-01-01' AS datetime2(0))), ('2014-12-31 23:45:00'), ('2015-01-01 00:00:00'),
             ('2015-02-01 00:00:00'), (CAST(SYSUTCDATETIME() AS datetime2(0)))) AS d(Exemple);
GO
