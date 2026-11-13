/* =====================================================================
   EEIP · Script 01 : création de la base et de ses groupes de fichiers
   ---------------------------------------------------------------------
   PRIMARY         : catalogue système uniquement (petit, toujours sain)
   FG_REFERENTIEL  : référentiel, configuration, exploitation (défaut)
   FG_ARCHIVE      : mesures antérieures à 2015 (statistiques Eurostat)
   FG_MESURE       : mesures mensuelles depuis 2015 (le gros volume)
   FG_MART         : couche analytique (agrégats quotidiens, panel)
   FG_BRUT         : réponses API brutes compressées et zone de transit
   Les fichiers vont dans les dossiers par défaut de votre instance.
   ===================================================================== */
USE master;
GO

IF DB_ID(N'EEIP') IS NOT NULL
BEGIN
    RAISERROR(N'La base EEIP existe déjà : le script 01 ne la recrée pas.', 10, 1) WITH NOWAIT;
END
ELSE
BEGIN
    DECLARE @donnees nvarchar(260) = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS nvarchar(260));
    DECLARE @journal nvarchar(260) = CAST(SERVERPROPERTY('InstanceDefaultLogPath')  AS nvarchar(260));
    DECLARE @sql nvarchar(max) = N'
CREATE DATABASE EEIP
ON PRIMARY
    (NAME = N''EEIP_systeme'',     FILENAME = N''' + @donnees + N'EEIP_systeme.mdf'',     SIZE = 64MB,  FILEGROWTH = 64MB),
FILEGROUP FG_REFERENTIEL
    (NAME = N''EEIP_referentiel'', FILENAME = N''' + @donnees + N'EEIP_referentiel.ndf'', SIZE = 64MB,  FILEGROWTH = 64MB),
FILEGROUP FG_ARCHIVE
    (NAME = N''EEIP_archive'',     FILENAME = N''' + @donnees + N'EEIP_archive.ndf'',     SIZE = 64MB,  FILEGROWTH = 64MB),
FILEGROUP FG_MESURE
    (NAME = N''EEIP_mesure'',      FILENAME = N''' + @donnees + N'EEIP_mesure.ndf'',      SIZE = 1024MB, FILEGROWTH = 512MB),
FILEGROUP FG_MART
    (NAME = N''EEIP_mart'',        FILENAME = N''' + @donnees + N'EEIP_mart.ndf'',        SIZE = 256MB, FILEGROWTH = 256MB),
FILEGROUP FG_BRUT
    (NAME = N''EEIP_brut'',        FILENAME = N''' + @donnees + N'EEIP_brut.ndf'',        SIZE = 512MB, FILEGROWTH = 512MB)
LOG ON
    (NAME = N''EEIP_journal'',     FILENAME = N''' + @journal + N'EEIP_journal.ldf'',     SIZE = 1024MB, FILEGROWTH = 512MB);';

    EXEC sys.sp_executesql @sql;
    RAISERROR(N'Base EEIP créée.', 10, 1) WITH NOWAIT;
END
GO

/* Options de base, chacune expliquée dans le guide */
ALTER DATABASE EEIP SET RECOVERY SIMPLE;                       -- poste de développement
ALTER DATABASE EEIP SET COMPATIBILITY_LEVEL = 160;             -- tout SQL Server 2022
ALTER DATABASE EEIP SET READ_COMMITTED_SNAPSHOT ON WITH ROLLBACK IMMEDIATE;  -- lecteurs jamais bloqués
ALTER DATABASE EEIP SET ACCELERATED_DATABASE_RECOVERY = ON;    -- annulations instantanées
ALTER DATABASE EEIP SET AUTO_UPDATE_STATISTICS_ASYNC ON;
ALTER DATABASE EEIP SET PAGE_VERIFY CHECKSUM;
ALTER DATABASE EEIP SET QUERY_STORE = ON;
ALTER DATABASE EEIP SET QUERY_STORE (
    OPERATION_MODE = READ_WRITE,
    QUERY_CAPTURE_MODE = AUTO,
    MAX_STORAGE_SIZE_MB = 1024,
    INTERVAL_LENGTH_MINUTES = 15,
    WAIT_STATS_CAPTURE_MODE = ON);
GO

/* Fonctions de SQL Server 2022 propres à la base */
USE EEIP;
GO
ALTER DATABASE SCOPED CONFIGURATION SET PARAMETER_SENSITIVE_PLAN_OPTIMIZATION = ON;  -- plusieurs plans selon la zone
ALTER DATABASE SCOPED CONFIGURATION SET DOP_FEEDBACK = ON;                            -- parallélisme ajusté tout seul
GO

/* Tout nouvel objet sans groupe précisé ira dans FG_REFERENTIEL, jamais dans PRIMARY */
IF NOT EXISTS (SELECT 1 FROM sys.filegroups WHERE name = N'FG_REFERENTIEL' AND is_default = 1)
    ALTER DATABASE EEIP MODIFY FILEGROUP FG_REFERENTIEL DEFAULT;
GO

ALTER AUTHORIZATION ON DATABASE::EEIP TO sa;
GO

/* Contrôle */
SELECT f.name AS Fichier, fg.name AS GroupeDeFichiers, f.physical_name AS Chemin, f.size / 128 AS TailleMo
FROM sys.database_files AS f
LEFT JOIN sys.filegroups AS fg ON fg.data_space_id = f.data_space_id
ORDER BY f.file_id;
GO
