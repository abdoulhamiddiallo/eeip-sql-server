/* =====================================================================
   EEIP · European Energy Intelligence Platform
   Script 00 : vérification de l'instance avant de construire
   À exécuter dans SSMS, connecté à votre instance, base master.
   Ce script ne modifie rien : il lit seulement.
   ===================================================================== */
USE master;
GO

SELECT
    CAST(SERVERPROPERTY('ServerName')                AS nvarchar(128)) AS Instance,
    CAST(SERVERPROPERTY('ProductVersion')            AS nvarchar(32))  AS Version,
    CAST(SERVERPROPERTY('ProductUpdateLevel')        AS nvarchar(32))  AS MiseAJourCumulative,
    CAST(SERVERPROPERTY('Edition')                   AS nvarchar(64))  AS Edition,
    CAST(SERVERPROPERTY('Collation')                 AS nvarchar(64))  AS Classement,
    CAST(SERVERPROPERTY('InstanceDefaultDataPath')   AS nvarchar(260)) AS DossierDonnees,
    CAST(SERVERPROPERTY('InstanceDefaultLogPath')    AS nvarchar(260)) AS DossierJournal,
    CAST(SERVERPROPERTY('InstanceDefaultBackupPath') AS nvarchar(260)) AS DossierSauvegardes;

-- SQL Server 2022 (version 16) est obligatoire : columnstore ordonné, DATE_BUCKET, GENERATE_SERIES.
SELECT CASE WHEN CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(32)), 4) AS int) >= 16
            THEN N'OK : SQL Server 2022 ou plus récent'
            ELSE N'STOP : il faut SQL Server 2022' END AS VersionMinimale;

-- Les fuseaux horaires dont la plateforme a besoin doivent être connus de Windows.
SELECT name AS Fuseau, current_utc_offset AS DecalageActuel
FROM sys.time_zone_info
WHERE name IN (N'Romance Standard Time', N'W. Europe Standard Time', N'Central European Standard Time',
               N'Central Europe Standard Time', N'GMT Standard Time', N'GTB Standard Time',
               N'FLE Standard Time', N'UTC')
ORDER BY name;

-- Services : le moteur et l'Agent SQL Server.
SELECT servicename AS Service, status_desc AS Etat, startup_type_desc AS Demarrage, service_account AS Compte
FROM sys.dm_server_services;

-- Vous devez être sysadmin pour construire la plateforme.
SELECT SUSER_SNAME() AS MaConnexion, IS_SRVROLEMEMBER('sysadmin') AS JeSuisSysadmin;

-- Le nom EEIP doit être libre.
SELECT CASE WHEN DB_ID(N'EEIP') IS NULL THEN N'Libre : on peut créer EEIP'
            ELSE N'EEIP existe déjà' END AS EtatNomBase;

-- Espace disque libre sous le dossier des données (la plateforme prendra 2 à 6 Go).
SELECT DISTINCT vs.volume_mount_point AS Volume,
       CAST(vs.available_bytes / 1073741824.0 AS decimal(10,1)) AS GoLibres
FROM sys.master_files AS mf
CROSS APPLY sys.dm_os_volume_stats(mf.database_id, mf.file_id) AS vs;
GO
