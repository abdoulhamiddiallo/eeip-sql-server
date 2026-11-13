/* =====================================================================
   EEIP · Script 09 : contrôles qualité automatiques
   ---------------------------------------------------------------------
   Seuils lus dans dq.Regle (modifiables sans toucher au code).
   FRAICHEUR       : une requête du catalogue n'apporte plus de données récentes
   HORS_BORNES     : prix hors bornes, puissance démesurée, production négative
   SAUT            : consommation qui varie brutalement d'un point à l'autre
   TROU            : intervalles manquants dans une série infra-horaire (7 jours)
   REVISION_FORTE  : valeur révisée de plus de 20 % (lu dans l'historique temporel)
   CONCORDANCE     : RTE, éCO2mix et ENTSO-E en désaccord sur la moyenne d'un jour
   ZONE_DEDUITE    : zone créée faute de correspondance : à rattacher par un alias
   Lancé à la fin de chaque lot, après l'agrégation quotidienne.
   ===================================================================== */
USE EEIP;
GO

CREATE OR ALTER PROCEDURE dq.usp_Controler
    @LotId int
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @maintenant datetime2(0) = SYSUTCDATETIME(),
            @frInfra float, @frMens float, @frAnn float, @prixMin float, @prixMax float,
            @pMax float, @saut float, @trou float, @rev float, @conc float,
            @dMin datetime2(0), @dMax datetime2(0);

    SELECT @frInfra = MAX(CASE Code WHEN 'FRAICHEUR_INFRA_HEURES' THEN Seuil END),
           @frMens  = MAX(CASE Code WHEN 'FRAICHEUR_MENSUEL_MOIS' THEN Seuil END),
           @frAnn   = MAX(CASE Code WHEN 'FRAICHEUR_ANNUEL_MOIS'  THEN Seuil END),
           @prixMin = MAX(CASE Code WHEN 'PRIX_BORNES'            THEN Seuil END),
           @prixMax = MAX(CASE Code WHEN 'PRIX_BORNES'            THEN Seuil2 END),
           @pMax    = MAX(CASE Code WHEN 'PUISSANCE_MAX_MW'       THEN Seuil END),
           @saut    = MAX(CASE Code WHEN 'SAUT_PCT'               THEN Seuil END),
           @trou    = MAX(CASE Code WHEN 'TROU_PAS'               THEN Seuil END),
           @rev     = MAX(CASE Code WHEN 'REVISION_FORTE_PCT'     THEN Seuil END),
           @conc    = MAX(CASE Code WHEN 'CONCORDANCE_PCT'        THEN Seuil END)
    FROM dq.Regle;

    DELETE dq.Anomalie WHERE LotId = @LotId AND TypeAnomalie <> 'CODE_INCONNU';   -- rejouable

    /* 0. Les séries touchées par le lot et leur période : une seule lecture de core.Mesure,
          puis chaque contrôle part de cette petite liste */
    CREATE TABLE #touchees (SerieId int PRIMARY KEY, Debut datetime2(0) NOT NULL, Fin datetime2(0) NOT NULL);
    INSERT #touchees (SerieId, Debut, Fin)
    SELECT SerieId, MIN(InstantUtc), MAX(InstantUtc) FROM core.Mesure WHERE LotId = @LotId GROUP BY SerieId;
    SELECT @dMin = MIN(Debut), @dMax = MAX(Fin) FROM #touchees;

    /* 1. Fraîcheur, au niveau de la requête du catalogue */
    INSERT dq.Anomalie (LotId, TypeAnomalie, InstantUtc, Detail)
    SELECT @LotId, 'FRAICHEUR', f.Dernier,
           CONCAT(c.SourceCode, N' ', c.Jeu, N' ', c.IndicateurCode, N' ', c.ZoneCode,
                  N' : dernier point au ', CONVERT(char(16), f.Dernier, 120), N' UTC')
    FROM cfg.RequeteACharger AS c
    CROSS APPLY (SELECT MAX(s.DernierInstant) AS Dernier, MIN(s.Granularite) AS Gran
                 FROM core.Serie AS s WHERE s.CfgId = c.CfgId) AS f
    WHERE c.Actif = 1
      AND ISNULL(c.DernierStatut, '') <> 'SANS_CLE'
      AND f.Dernier < CASE WHEN f.Gran IN ('PT15M', 'PT30M', 'PT60M', 'P1D') THEN DATEADD(HOUR, -@frInfra, @maintenant)
                           WHEN f.Gran = 'P1M' THEN DATEADD(MONTH, -@frMens, @maintenant)
                           ELSE DATEADD(MONTH, -@frAnn, @maintenant) END;

    /* 2. Valeurs hors bornes, parmi ce que le lot a écrit */
    INSERT dq.Anomalie (LotId, TypeAnomalie, SerieId, InstantUtc, Valeur, Detail)
    SELECT TOP (5000) @LotId, 'HORS_BORNES', m.SerieId, m.InstantUtc, m.Valeur,
           CONCAT(i.Code, N' ', z.Code, ISNULL(N' ' + f.Code, N''), N' : ', m.Valeur, N' ', i.Unite)
    FROM core.Mesure AS m
    JOIN core.Serie AS s ON s.SerieId = m.SerieId
    JOIN core.Indicateur AS i ON i.IndicateurId = s.IndicateurId
    JOIN core.Zone AS z ON z.ZoneId = s.ZoneId
    LEFT JOIN core.Filiere AS f ON f.FiliereId = s.FiliereId
    WHERE m.LotId = @LotId
      AND m.InstantUtc BETWEEN @dMin AND @dMax
      AND (   (i.Code = 'PRIX_SPOT_J1' AND (m.Valeur < @prixMin OR m.Valeur > @prixMax))
           OR (i.Unite = N'MW' AND ABS(m.Valeur) > @pMax)
           OR (i.Code IN ('PROD_ELEC', 'CONSO_ELEC') AND m.Valeur < -1
               AND ISNULL(f.Famille, '') <> 'STOCKAGE' AND ISNULL(f.Code, '') <> 'STEP'))
    OPTION (RECOMPILE);

    /* 3. Sauts brutaux de consommation (entre deux points consécutifs) */
    WITH Pts AS (
        SELECT m.SerieId, m.InstantUtc, m.Valeur, m.LotId,
               LAG(m.Valeur) OVER (PARTITION BY m.SerieId ORDER BY m.InstantUtc) AS Precedent
        FROM core.Mesure AS m
        JOIN core.Serie AS s ON s.SerieId = m.SerieId
        JOIN core.Indicateur AS i ON i.IndicateurId = s.IndicateurId
        WHERE i.Code = 'CONSO_ELEC'
          AND m.SerieId IN (SELECT SerieId FROM #touchees)
          AND m.InstantUtc >= DATEADD(DAY, -10, @maintenant)
    )
    INSERT dq.Anomalie (LotId, TypeAnomalie, SerieId, InstantUtc, Valeur, Detail)
    SELECT TOP (1000) @LotId, 'SAUT', SerieId, InstantUtc, Valeur,
           CONCAT(N'De ', Precedent, N' à ', Valeur, N' MW')
    FROM Pts
    WHERE LotId = @LotId AND Precedent > 1000
      AND ABS(Valeur - Precedent) / Precedent > @saut;

    /* 4. Trous dans les séries infra-horaires touchées, sur les 7 derniers jours (îlots et lacunes) */
    WITH Pts AS (
        SELECT m.SerieId, s.PasMinutes, m.InstantUtc,
               LAG(m.InstantUtc) OVER (PARTITION BY m.SerieId ORDER BY m.InstantUtc) AS Precedent
        FROM core.Mesure AS m
        JOIN core.Serie AS s ON s.SerieId = m.SerieId
        WHERE s.PasMinutes <= 60
          AND s.SerieId IN (SELECT SerieId FROM #touchees)
          AND m.InstantUtc >= DATEADD(DAY, -7, @maintenant)
    )
    INSERT dq.Anomalie (LotId, TypeAnomalie, SerieId, InstantUtc, Detail)
    SELECT TOP (1000) @LotId, 'TROU', SerieId, Precedent,
           CONCAT(DATEDIFF(MINUTE, Precedent, InstantUtc) / PasMinutes - 1, N' pas manquants avant ',
                  CONVERT(char(16), InstantUtc, 120))
    FROM Pts
    WHERE DATEDIFF(MINUTE, Precedent, InstantUtc) > PasMinutes * @trou;

    /* 5. Révisions fortes : la version courante face à celle qu'elle a remplacée */
    INSERT dq.Anomalie (LotId, TypeAnomalie, SerieId, InstantUtc, Valeur, Detail)
    SELECT TOP (2000) @LotId, 'REVISION_FORTE', c.SerieId, c.InstantUtc, c.Valeur,
           CONCAT(N'Avant : ', h.Valeur, N' (', h.Qualite, N') ; après : ', c.Valeur, N' (', c.Qualite, N')')
    FROM core.Mesure AS c
    JOIN core.MesureHistorique AS h
      ON h.SerieId = c.SerieId AND h.InstantUtc = c.InstantUtc AND h.ValidTo = c.ValidFrom
    WHERE c.LotId = @LotId
      AND h.Valeur IS NOT NULL AND ABS(h.Valeur) > 1 AND c.Valeur IS NOT NULL
      AND c.InstantUtc BETWEEN @dMin AND @dMax
      AND ABS(c.Valeur - h.Valeur) / ABS(h.Valeur) > @rev
    OPTION (RECOMPILE);

    /* 6. Concordance entre sources, sur les moyennes quotidiennes (mart.MesureJour) */
    INSERT dq.Anomalie (LotId, TypeAnomalie, SerieId, Detail)
    SELECT TOP (1000) @LotId, 'CONCORDANCE', a.SerieId,
           CONCAT(i.Code, N' ', z.Code, N' le ', CONVERT(char(10), ja.JourLocal, 23), N' : ',
                  sa.Code, N' = ', CAST(ja.Moyenne AS decimal(12,1)), N' ; ',
                  sb.Code, N' = ', CAST(jb.Moyenne AS decimal(12,1)))
    FROM core.Serie AS a
    JOIN core.Serie AS b
      ON  b.IndicateurId = a.IndicateurId AND b.ZoneId = a.ZoneId
      AND b.FiliereId IS NOT DISTINCT FROM a.FiliereId
      AND b.ContrepartieId IS NOT DISTINCT FROM a.ContrepartieId
      AND b.SourceId > a.SourceId
    JOIN core.Indicateur AS i ON i.IndicateurId = a.IndicateurId
    JOIN core.Zone AS z ON z.ZoneId = a.ZoneId
    JOIN core.Source AS sa ON sa.SourceId = a.SourceId
    JOIN core.Source AS sb ON sb.SourceId = b.SourceId
    JOIN mart.MesureJour AS ja ON ja.SerieId = a.SerieId
    JOIN mart.MesureJour AS jb ON jb.SerieId = b.SerieId AND jb.JourLocal = ja.JourLocal
    WHERE i.Code IN ('CONSO_ELEC', 'PROD_ELEC')
      AND ja.JourLocal >= DATEADD(DAY, -10, CAST(@maintenant AS date))
      AND jb.JourLocal >= DATEADD(DAY, -10, CAST(@maintenant AS date))
      AND ja.Completude >= 0.95 AND jb.Completude >= 0.95
      AND ABS(ja.Moyenne) > 100
      AND ABS(ja.Moyenne - jb.Moyenne) / ABS(ja.Moyenne) > @conc;

    /* 7. Zones déduites, à rattacher par un alias */
    INSERT dq.Anomalie (LotId, TypeAnomalie, Detail)
    SELECT @LotId, 'ZONE_DEDUITE', CONCAT(N'Zone ', z.Code, N' (', z.Nom, N') sans correspondance')
    FROM core.Zone AS z
    WHERE z.Origine = 'DEDUITE';

    SELECT TypeAnomalie, COUNT(*) AS Nombre
    FROM dq.Anomalie WHERE LotId = @LotId
    GROUP BY TypeAnomalie ORDER BY TypeAnomalie;
END
GO
