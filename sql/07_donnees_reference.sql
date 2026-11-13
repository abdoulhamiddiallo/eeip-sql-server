/* =====================================================================
   EEIP · Script 07 : les données de référence et le catalogue
   ---------------------------------------------------------------------
   Rejouable : chaque bloc n'ajoute que ce qui manque (MERGE ou NOT EXISTS).
   Tout ce qui pilote l'ingestion est ici, en données, pas dans le code :
   ajouter un pays, une filière ou une frontière = ajouter une ligne.
   ===================================================================== */
USE EEIP;
GO

/* ---------- 1. Sources ---------- */
MERGE core.Source AS c
USING (VALUES
    (1, 'RTE',      N'RTE, Réseau de transport d''électricité (API data.rte-france.com)',
        'https://digital.iservices.rte-france.com/open_api', N'Conditions du portail RTE', 1, 1),
    (2, 'ODRE',     N'Open Data Réseaux Énergies (éCO2mix de RTE, GRTgaz, Teréga)',
        'https://odre.opendatasoft.com/api/explore/v2.1', N'Licence ouverte Etalab 2.0', 0, 2),
    (3, 'ENTSOE',   N'ENTSO-E Transparency Platform',
        'https://web-api.tp.entsoe.eu/api', N'Conditions ENTSO-E, réutilisation avec citation', 1, 3),
    (4, 'EUROSTAT', N'Eurostat, office statistique de l''Union européenne',
        'https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data', N'CC BY 4.0', 0, 1)
) AS s (SourceId, Code, Nom, UrlBase, Licence, NecessiteCle, Priorite)
ON c.SourceId = s.SourceId
WHEN MATCHED THEN UPDATE SET Code = s.Code, Nom = s.Nom, UrlBase = s.UrlBase, Licence = s.Licence,
                             NecessiteCle = s.NecessiteCle, Priorite = s.Priorite
WHEN NOT MATCHED THEN INSERT (SourceId, Code, Nom, UrlBase, Licence, NecessiteCle, Priorite)
                      VALUES (s.SourceId, s.Code, s.Nom, s.UrlBase, s.Licence, s.NecessiteCle, s.Priorite);
GO

/* ---------- 2. Thèmes ---------- */
MERGE core.Theme AS c
USING (VALUES (1, 'CONSOMMATION', N'Consommation'), (2, 'PRODUCTION', N'Production'),
              (3, 'PRIX', N'Prix de l''électricité'), (4, 'ECHANGES', N'Échanges transfrontaliers'),
              (5, 'MIX', N'Mix énergétique et dépendance'), (6, 'EMISSIONS', N'Émissions de CO2'),
              (7, 'CAPACITE', N'Capacités installées')) AS s (ThemeId, Code, Libelle)
ON c.ThemeId = s.ThemeId
WHEN MATCHED THEN UPDATE SET Code = s.Code, Libelle = s.Libelle
WHEN NOT MATCHED THEN INSERT (ThemeId, Code, Libelle) VALUES (s.ThemeId, s.Code, s.Libelle);
GO

/* ---------- 3. Indicateurs canoniques ---------- */
MERGE core.Indicateur AS c
USING (VALUES
 ('CONSO_ELEC',         N'Consommation d''électricité (puissance appelée)',                 1, N'MW',       'PUISSANCE', N'Moyenne de l''intervalle, toutes sources temps réel'),
 ('PREV_CONSO_J1',      N'Prévision de consommation établie la veille (J-1)',              1, N'MW',       'PUISSANCE', N'éCO2mix'),
 ('CONSO_GAZ',          N'Consommation brute de gaz (GRTgaz et Teréga)',                    1, N'MW',       'PUISSANCE', N'Open Data Réseaux Énergies'),
 ('CONSO_FINALE_ELEC',  N'Consommation finale d''électricité',                              1, N'GWh',      'ENERGIE',   N'Eurostat nrg_cb_e, FC'),
 ('PROD_ELEC',          N'Production d''électricité par filière',                           2, N'MW',       'PUISSANCE', N'Négative pour le pompage et la charge des batteries'),
 ('PROD_ELEC_MENSUELLE',N'Production nette d''électricité par filière, mensuelle',          2, N'GWh',      'ENERGIE',   N'Eurostat nrg_cb_pem'),
 ('PRIX_SPOT_J1',       N'Prix de l''électricité du marché à un jour (day-ahead)',          3, N'EUR/MWh',  'PRIX',      N'ENTSO-E, couplage européen'),
 ('PRIX_MENAGES',       N'Prix de l''électricité pour les ménages, toutes taxes comprises', 3, N'EUR/kWh',  'PRIX',      N'Eurostat nrg_pc_204, tranche 2 500 à 4 999 kWh'),
 ('PRIX_ENTREPRISES',   N'Prix de l''électricité pour les entreprises, hors TVA',           3, N'EUR/kWh',  'PRIX',      N'Eurostat nrg_pc_205, tranche 500 à 1 999 MWh'),
 ('FLUX_PHYSIQUE',      N'Flux physique entrant depuis la contrepartie',                    4, N'MW',       'PUISSANCE', N'ENTSO-E A11 et RTE'),
 ('ECHANGE_COMMERCIAL', N'Échange commercial avec la contrepartie (positif = importation)', 4, N'MW',       'PUISSANCE', N'éCO2mix'),
 ('SOLDE_ECHANGES',     N'Solde des échanges physiques (positif = importation)',            4, N'MW',       'PUISSANCE', N'éCO2mix'),
 ('IMPORT_ELEC',        N'Importations d''électricité',                                     4, N'GWh',      'ENERGIE',   N'Eurostat nrg_cb_e'),
 ('EXPORT_ELEC',        N'Exportations d''électricité',                                     4, N'GWh',      'ENERGIE',   N'Eurostat nrg_cb_e'),
 ('ENERGIE_BRUTE',      N'Énergie brute disponible par produit',                            5, N'ktep',     'ENERGIE',   N'Eurostat nrg_bal_c, GAE'),
 ('PART_RENOUV_ELEC',   N'Part des renouvelables dans l''électricité',                      5, N'%',        'RATIO',     N'Eurostat nrg_ind_ren'),
 ('DEPENDANCE_ENERGIE', N'Dépendance énergétique',                                          5, N'%',        'RATIO',     N'Eurostat nrg_ind_id'),
 ('INTENSITE_CO2',      N'Intensité carbone de la production d''électricité',               6, N'gCO2/kWh', 'INTENSITE', N'éCO2mix, mesurée'),
 ('GES_ELECTRICITE',    N'Émissions de GES : production publique d''électricité et de chaleur', 6, N'Mt CO2e', 'MASSE', N'Eurostat env_air_gge, CRF 1.A.1.a'),
 ('GES_TOTAL',          N'Émissions totales de GES (hors UTCATF)',                          6, N'Mt CO2e',  'MASSE',     N'Eurostat env_air_gge'),
 ('CAPACITE_INSTALLEE', N'Capacité de production installée par filière',                    7, N'MW',       'PUISSANCE', N'ENTSO-E A68')
) AS s (Code, Libelle, ThemeId, Unite, Nature, Description)
ON c.Code = s.Code
WHEN MATCHED THEN UPDATE SET Libelle = s.Libelle, ThemeId = s.ThemeId, Unite = s.Unite, Nature = s.Nature, Description = s.Description
WHEN NOT MATCHED THEN INSERT (Code, Libelle, ThemeId, Unite, Nature, Description)
                      VALUES (s.Code, s.Libelle, s.ThemeId, s.Unite, s.Nature, s.Description);
GO

/* ---------- 4. Zones : 30 pays, 6 zones de prix, 3 agrégats, 12 régions ---------- */
MERGE core.Zone AS c
USING (VALUES
 -- Code      Nom                                    Type        ISO2  EIC                  Eurostat     Parent  Fuseau                            Lat        Lon       UE
 ('AT',      N'Autriche',                           'PAYS',     'AT', '10YAT-APG------L',  'AT',        NULL, 'W. Europe Standard Time',         48.208200, 16.373800, 1),
 ('BE',      N'Belgique',                           'PAYS',     'BE', '10YBE----------2',  'BE',        NULL, 'Romance Standard Time',           50.850300,  4.351700, 1),
 ('BG',      N'Bulgarie',                           'PAYS',     'BG', '10YCA-BULGARIA-R',  'BG',        NULL, 'FLE Standard Time',               42.697700, 23.321900, 1),
 ('CY',      N'Chypre',                             'PAYS',     'CY', '10YCY-1001A0003J',  'CY',        NULL, 'GTB Standard Time',               35.185600, 33.382300, 1),
 ('CZ',      N'Tchéquie',                           'PAYS',     'CZ', '10YCZ-CEPS-----N',  'CZ',        NULL, 'Central Europe Standard Time',    50.075500, 14.437800, 1),
 ('DE',      N'Allemagne',                          'PAYS',     'DE', '10Y1001A1001A83F',  'DE',        NULL, 'W. Europe Standard Time',         52.520000, 13.405000, 1),
 ('DK',      N'Danemark',                           'PAYS',     'DK', '10Y1001A1001A65H',  'DK',        NULL, 'Romance Standard Time',           55.676100, 12.568300, 1),
 ('EE',      N'Estonie',                            'PAYS',     'EE', '10Y1001A1001A39I',  'EE',        NULL, 'FLE Standard Time',               59.437000, 24.753600, 1),
 ('ES',      N'Espagne',                            'PAYS',     'ES', '10YES-REE------0',  'ES',        NULL, 'Romance Standard Time',           40.416800, -3.703800, 1),
 ('FI',      N'Finlande',                           'PAYS',     'FI', '10YFI-1--------U',  'FI',        NULL, 'FLE Standard Time',               60.169900, 24.938400, 1),
 ('FR',      N'France',                             'PAYS',     'FR', '10YFR-RTE------C',  'FR',        NULL, 'Romance Standard Time',           48.856600,  2.352200, 1),
 ('GR',      N'Grèce',                              'PAYS',     'GR', '10YGR-HTSO-----Y',  'EL',        NULL, 'GTB Standard Time',               37.983800, 23.727500, 1),
 ('HR',      N'Croatie',                            'PAYS',     'HR', '10YHR-HEP------M',  'HR',        NULL, 'Central European Standard Time',  45.815000, 15.981900, 1),
 ('HU',      N'Hongrie',                            'PAYS',     'HU', '10YHU-MAVIR----U',  'HU',        NULL, 'Central Europe Standard Time',    47.497900, 19.040200, 1),
 ('IE',      N'Irlande',                            'PAYS',     'IE', '10YIE-1001A00010',  'IE',        NULL, 'GMT Standard Time',               53.349800, -6.260300, 1),
 ('IT',      N'Italie',                             'PAYS',     'IT', '10YIT-GRTN-----B',  'IT',        NULL, 'W. Europe Standard Time',         41.902800, 12.496400, 1),
 ('LT',      N'Lituanie',                           'PAYS',     'LT', '10YLT-1001A0008Q',  'LT',        NULL, 'FLE Standard Time',               54.687200, 25.279700, 1),
 ('LU',      N'Luxembourg',                         'PAYS',     'LU', '10YLU-CEGEDEL-NQ',  'LU',        NULL, 'W. Europe Standard Time',         49.611600,  6.131900, 1),
 ('LV',      N'Lettonie',                           'PAYS',     'LV', '10YLV-1001A00074',  'LV',        NULL, 'FLE Standard Time',               56.949600, 24.105200, 1),
 ('MT',      N'Malte',                              'PAYS',     'MT', '10Y1001A1001A93C',  'MT',        NULL, 'W. Europe Standard Time',         35.898900, 14.514600, 1),
 ('NL',      N'Pays-Bas',                           'PAYS',     'NL', '10YNL----------L',  'NL',        NULL, 'W. Europe Standard Time',         52.367600,  4.904100, 1),
 ('PL',      N'Pologne',                            'PAYS',     'PL', '10YPL-AREA-----S',  'PL',        NULL, 'Central European Standard Time',  52.229700, 21.012200, 1),
 ('PT',      N'Portugal',                           'PAYS',     'PT', '10YPT-REN------W',  'PT',        NULL, 'GMT Standard Time',               38.722300, -9.139300, 1),
 ('RO',      N'Roumanie',                           'PAYS',     'RO', '10YRO-TEL------P',  'RO',        NULL, 'GTB Standard Time',               44.426800, 26.102500, 1),
 ('SE',      N'Suède',                              'PAYS',     'SE', '10YSE-1--------K',  'SE',        NULL, 'W. Europe Standard Time',         59.329300, 18.068600, 1),
 ('SI',      N'Slovénie',                           'PAYS',     'SI', '10YSI-ELES-----O',  'SI',        NULL, 'Central Europe Standard Time',    46.056900, 14.505800, 1),
 ('SK',      N'Slovaquie',                          'PAYS',     'SK', '10YSK-SEPS-----K',  'SK',        NULL, 'Central Europe Standard Time',    48.148600, 17.107700, 1),
 ('NO',      N'Norvège',                            'PAYS',     'NO', '10YNO-0--------C',  'NO',        NULL, 'W. Europe Standard Time',         59.913900, 10.752200, 0),
 ('CH',      N'Suisse',                             'PAYS',     'CH', '10YCH-SWISSGRIDZ',  'CH',        NULL, 'W. Europe Standard Time',         46.948000,  7.447400, 0),
 ('GB',      N'Royaume-Uni',                        'PAYS',     'GB', '10YGB----------A',  'UK',        NULL, 'GMT Standard Time',               51.507400, -0.127800, 0),
 ('DE_LU',   N'Allemagne-Luxembourg (zone de prix)','ZONE_PRIX', NULL, '10Y1001A1001A82H', NULL,        'DE', 'W. Europe Standard Time',         52.520000, 13.405000, 1),
 ('IT_NORD', N'Italie Nord (zone de prix)',         'ZONE_PRIX', NULL, '10Y1001A1001A73I', NULL,        'IT', 'W. Europe Standard Time',         45.464200,  9.190000, 1),
 ('DK1',     N'Danemark Ouest (zone de prix)',      'ZONE_PRIX', NULL, '10YDK-1--------W', NULL,        'DK', 'Romance Standard Time',           56.162900, 10.203900, 1),
 ('DK2',     N'Danemark Est (zone de prix)',        'ZONE_PRIX', NULL, '10YDK-2--------M', NULL,        'DK', 'Romance Standard Time',           55.676100, 12.568300, 1),
 ('NO2',     N'Norvège Sud (zone de prix)',         'ZONE_PRIX', NULL, '10YNO-2--------T', NULL,        'NO', 'W. Europe Standard Time',         58.969800,  5.733100, 0),
 ('SE3',     N'Suède Centre (zone de prix)',        'ZONE_PRIX', NULL, '10Y1001A1001A46L', NULL,        'SE', 'W. Europe Standard Time',         59.329300, 18.068600, 1),
 ('EU27',    N'Union européenne (27 pays)',         'AGREGAT',  NULL, NULL,                'EU27_2020', NULL, 'Romance Standard Time',           50.850300,  4.351700, 1),
 ('EA20',    N'Zone euro (20 pays)',                'AGREGAT',  NULL, NULL,                'EA20',      NULL, 'Romance Standard Time',           50.110900,  8.682100, 1),
 ('DE_BE',   N'Allemagne et Belgique (échanges éCO2mix)', 'AGREGAT', NULL, NULL,           NULL,        NULL, 'W. Europe Standard Time',         51.000000,  7.000000, 1),
 ('FR-IDF',  N'Île-de-France',                      'REGION',   NULL, NULL,                NULL,        'FR', 'Romance Standard Time',           48.849900,  2.637000, 1),
 ('FR-CVL',  N'Centre-Val de Loire',                'REGION',   NULL, NULL,                NULL,        'FR', 'Romance Standard Time',           47.751400,  1.675000, 1),
 ('FR-BFC',  N'Bourgogne-Franche-Comté',            'REGION',   NULL, NULL,                NULL,        'FR', 'Romance Standard Time',           47.280500,  4.999400, 1),
 ('FR-NOR',  N'Normandie',                          'REGION',   NULL, NULL,                NULL,        'FR', 'Romance Standard Time',           49.120000,  0.110000, 1),
 ('FR-HDF',  N'Hauts-de-France',                    'REGION',   NULL, NULL,                NULL,        'FR', 'Romance Standard Time',           50.480100,  2.793700, 1),
 ('FR-GES',  N'Grand Est',                          'REGION',   NULL, NULL,                NULL,        'FR', 'Romance Standard Time',           48.699800,  6.187800, 1),
 ('FR-PDL',  N'Pays de la Loire',                   'REGION',   NULL, NULL,                NULL,        'FR', 'Romance Standard Time',           47.473800, -0.830000, 1),
 ('FR-BRE',  N'Bretagne',                           'REGION',   NULL, NULL,                NULL,        'FR', 'Romance Standard Time',           48.202000, -2.932600, 1),
 ('FR-NAQ',  N'Nouvelle-Aquitaine',                 'REGION',   NULL, NULL,                NULL,        'FR', 'Romance Standard Time',           45.708700,  0.626900, 1),
 ('FR-OCC',  N'Occitanie',                          'REGION',   NULL, NULL,                NULL,        'FR', 'Romance Standard Time',           43.892700,  2.193200, 1),
 ('FR-ARA',  N'Auvergne-Rhône-Alpes',               'REGION',   NULL, NULL,                NULL,        'FR', 'Romance Standard Time',           45.447100,  4.385300, 1),
 ('FR-PAC',  N'Provence-Alpes-Côte d''Azur',        'REGION',   NULL, NULL,                NULL,        'FR', 'Romance Standard Time',           43.935200,  6.067900, 1)
) AS s (Code, Nom, TypeZone, CodeIso2, CodeEic, CodeEurostat, ParentCode, Fuseau, Latitude, Longitude, EstUE)
ON c.Code = s.Code
WHEN MATCHED AND (   c.Nom <> s.Nom OR c.TypeZone <> s.TypeZone
                  OR c.CodeEic IS DISTINCT FROM s.CodeEic OR c.CodeEurostat IS DISTINCT FROM s.CodeEurostat
                  OR c.ParentCode IS DISTINCT FROM s.ParentCode OR c.Fuseau <> s.Fuseau OR c.EstUE <> s.EstUE
                  OR c.Origine <> 'REFERENCE')
    THEN UPDATE SET Nom = s.Nom, TypeZone = s.TypeZone, CodeIso2 = s.CodeIso2, CodeEic = s.CodeEic,
                    CodeEurostat = s.CodeEurostat, ParentCode = s.ParentCode, Fuseau = s.Fuseau,
                    Latitude = s.Latitude, Longitude = s.Longitude, EstUE = s.EstUE, Origine = 'REFERENCE'
WHEN NOT MATCHED THEN
    INSERT (Code, Nom, TypeZone, CodeIso2, CodeEic, CodeEurostat, ParentCode, Fuseau, Latitude, Longitude, EstUE, Origine)
    VALUES (s.Code, s.Nom, s.TypeZone, s.CodeIso2, s.CodeEic, s.CodeEurostat, s.ParentCode, s.Fuseau,
            s.Latitude, s.Longitude, s.EstUE, 'REFERENCE');
GO

/* ---------- 5. Alias de zones ---------- */
MERGE core.ZoneAlias AS c
USING (VALUES
 -- éCO2mix régional : code INSEE de la région
 ('ODRE', '11', 'FR-IDF'), ('ODRE', '24', 'FR-CVL'), ('ODRE', '27', 'FR-BFC'), ('ODRE', '28', 'FR-NOR'),
 ('ODRE', '32', 'FR-HDF'), ('ODRE', '44', 'FR-GES'), ('ODRE', '52', 'FR-PDL'), ('ODRE', '53', 'FR-BRE'),
 ('ODRE', '75', 'FR-NAQ'), ('ODRE', '76', 'FR-OCC'), ('ODRE', '84', 'FR-ARA'), ('ODRE', '93', 'FR-PAC'),
 -- éCO2mix national : chaque colonne d'échange commercial désigne une contrepartie
 ('ODRE', 'ech_comm_angleterre', 'GB'), ('ODRE', 'ech_comm_espagne', 'ES'), ('ODRE', 'ech_comm_italie', 'IT_NORD'),
 ('ODRE', 'ech_comm_suisse', 'CH'), ('ODRE', 'ech_comm_allemagne_belgique', 'DE_BE'),
 -- RTE : noms de pays des flux physiques, au cas où le code EIC manque
 ('RTE', 'Allemagne', 'DE_LU'), ('RTE', 'Belgique', 'BE'), ('RTE', 'Suisse', 'CH'), ('RTE', 'Italie', 'IT_NORD'),
 ('RTE', 'Espagne', 'ES'), ('RTE', 'Grande-Bretagne', 'GB'), ('RTE', 'Angleterre', 'GB'), ('RTE', 'France', 'FR')
) AS s (SourceCode, CodeExterne, CodeZoneCible)
ON c.SourceCode = s.SourceCode AND c.CodeExterne = s.CodeExterne
WHEN MATCHED THEN UPDATE SET CodeZoneCible = s.CodeZoneCible
WHEN NOT MATCHED THEN INSERT (SourceCode, CodeExterne, CodeZoneCible) VALUES (s.SourceCode, s.CodeExterne, s.CodeZoneCible);
GO

/* ---------- 6. Filières : famille, renouvelable, fossile, bas carbone, CO2 (g/kWh), couleur ----------
   Facteurs CO2 : émissions directes indicatives de la combustion, à ajuster si besoin. */
MERGE core.Filiere AS c
USING (VALUES
 ('NUCLEAIRE',     N'Nucléaire',                    'NUCLEAIRE',     0, 0, 1,    0.0, '#F2C12E',  1),
 ('CHARBON',       N'Charbon',                      'CHARBON',       0, 1, 0,  986.0, '#6B5B45',  2),
 ('LIGNITE',       N'Lignite',                      'CHARBON',       0, 1, 0, 1100.0, '#4A3F31',  3),
 ('GAZ_HOUILLE',   N'Gaz dérivé du charbon',        'CHARBON',       0, 1, 0,  900.0, '#8A7560',  4),
 ('TOURBE',        N'Tourbe',                       'CHARBON',       0, 1, 0, 1100.0, '#7A6A50',  5),
 ('GAZ',           N'Gaz naturel',                  'GAZ',           0, 1, 0,  429.0, '#E4572E',  6),
 ('FIOUL',         N'Fioul',                        'PETROLE',       0, 1, 0,  777.0, '#8E44AD',  7),
 ('PETROLE',       N'Pétrole et produits pétroliers','PETROLE',      0, 1, 0,  777.0, '#7D3C98',  8),
 ('SCHISTE',       N'Schiste bitumineux',           'PETROLE',       0, 1, 0, 1000.0, '#5B2C6F',  9),
 ('THERMIQUE',     N'Thermique fossile',            'THERMIQUE',     0, 1, 0,  500.0, '#C0392B', 10),
 ('HYDRAULIQUE',   N'Hydraulique',                  'HYDRAULIQUE',   1, 0, 1,    0.0, '#2E86C1', 11),
 ('HYDRO_FIL',     N'Hydraulique au fil de l''eau', 'HYDRAULIQUE',   1, 0, 1,    0.0, '#5DADE2', 12),
 ('HYDRO_LAC',     N'Hydraulique de lacs',          'HYDRAULIQUE',   1, 0, 1,    0.0, '#1B4F72', 13),
 ('STEP',          N'Turbinage des STEP',           'HYDRAULIQUE',   0, 0, 1,    0.0, '#21618C', 14),
 ('EOLIEN',        N'Éolien',                       'EOLIEN',        1, 0, 1,    0.0, '#48C9B0', 15),
 ('EOLIEN_TERRE',  N'Éolien terrestre',             'EOLIEN',        1, 0, 1,    0.0, '#76D7C4', 16),
 ('EOLIEN_MER',    N'Éolien en mer',                'EOLIEN',        1, 0, 1,    0.0, '#138D75', 17),
 ('SOLAIRE',       N'Solaire',                      'SOLAIRE',       1, 0, 1,    0.0, '#F5B041', 18),
 ('BIOENERGIES',   N'Bioénergies',                  'BIOENERGIES',   1, 0, 1,    0.0, '#27AE60', 19),
 ('BIOMASSE',      N'Biomasse',                     'BIOENERGIES',   1, 0, 1,    0.0, '#229954', 20),
 ('BIOGAZ',        N'Biogaz',                       'BIOENERGIES',   1, 0, 1,    0.0, '#52BE80', 21),
 ('DECHETS',       N'Déchets',                      'BIOENERGIES',   0, 0, 0,  494.0, '#7F8C8D', 22),
 ('GEOTHERMIE',    N'Géothermie',                   'AUTRES',        1, 0, 1,    0.0, '#CB4335', 23),
 ('MARIN',         N'Énergies marines',             'AUTRES',        1, 0, 1,    0.0, '#1ABC9C', 24),
 ('AUTRES_RENOUV', N'Autres renouvelables',         'AUTRES',        1, 0, 1,    0.0, '#82E0AA', 25),
 ('RENOUVELABLES', N'Renouvelables et biocarburants','RENOUVELABLES',1, 0, 1,    0.0, '#2ECC71', 26),
 ('AUTRES',        N'Autres',                       'AUTRES',        0, 0, 0,    0.0, '#AAB7B8', 27),
 ('POMPAGE',       N'Pompage des STEP',             'STOCKAGE',      0, 0, 1,    0.0, '#154360', 28),
 ('STOCKAGE',      N'Batteries',                    'STOCKAGE',      0, 0, 1,    0.0, '#5D6D7E', 29),
 ('ELECTRICITE',   N'Électricité (échanges nets)',  'VECTEURS',      0, 0, 0,    0.0, '#3498DB', 30),
 ('CHALEUR',       N'Chaleur',                      'VECTEURS',      0, 0, 0,    0.0, '#E67E22', 31)
) AS s (Code, Libelle, Famille, EstRenouvelable, EstFossile, EstBasCarbone, FacteurCO2, Couleur, Ordre)
ON c.Code = s.Code
WHEN MATCHED THEN UPDATE SET Libelle = s.Libelle, Famille = s.Famille, EstRenouvelable = s.EstRenouvelable,
                             EstFossile = s.EstFossile, EstBasCarbone = s.EstBasCarbone, Couleur = s.Couleur, Ordre = s.Ordre
                             -- FacteurCO2 n'est jamais écrasé : vous pouvez l'ajuster à la main
WHEN NOT MATCHED THEN INSERT (Code, Libelle, Famille, EstRenouvelable, EstFossile, EstBasCarbone, FacteurCO2, Couleur, Ordre)
                      VALUES (s.Code, s.Libelle, s.Famille, s.EstRenouvelable, s.EstFossile, s.EstBasCarbone,
                              s.FacteurCO2, s.Couleur, s.Ordre);
GO

/* ---------- 7. Alias de filières : un code par source ---------- */
MERGE core.FiliereAlias AS c
USING (VALUES
 -- éCO2mix (nom de la colonne)
 ('ODRE', 'nucleaire', 'NUCLEAIRE'), ('ODRE', 'charbon', 'CHARBON'), ('ODRE', 'gaz', 'GAZ'), ('ODRE', 'fioul', 'FIOUL'),
 ('ODRE', 'eolien', 'EOLIEN'), ('ODRE', 'solaire', 'SOLAIRE'), ('ODRE', 'hydraulique', 'HYDRAULIQUE'),
 ('ODRE', 'bioenergies', 'BIOENERGIES'), ('ODRE', 'pompage', 'POMPAGE'), ('ODRE', 'thermique', 'THERMIQUE'),
 -- ENTSO-E (psrType) ; _CONSO = la part consommée (pompage, charge des batteries)
 ('ENTSOE', 'B01', 'BIOMASSE'), ('ENTSOE', 'B02', 'LIGNITE'), ('ENTSOE', 'B03', 'GAZ_HOUILLE'), ('ENTSOE', 'B04', 'GAZ'),
 ('ENTSOE', 'B05', 'CHARBON'), ('ENTSOE', 'B06', 'FIOUL'), ('ENTSOE', 'B07', 'SCHISTE'), ('ENTSOE', 'B08', 'TOURBE'),
 ('ENTSOE', 'B09', 'GEOTHERMIE'), ('ENTSOE', 'B10', 'STEP'), ('ENTSOE', 'B11', 'HYDRO_FIL'), ('ENTSOE', 'B12', 'HYDRO_LAC'),
 ('ENTSOE', 'B13', 'MARIN'), ('ENTSOE', 'B14', 'NUCLEAIRE'), ('ENTSOE', 'B15', 'AUTRES_RENOUV'), ('ENTSOE', 'B16', 'SOLAIRE'),
 ('ENTSOE', 'B17', 'DECHETS'), ('ENTSOE', 'B18', 'EOLIEN_MER'), ('ENTSOE', 'B19', 'EOLIEN_TERRE'), ('ENTSOE', 'B20', 'AUTRES'),
 ('ENTSOE', 'B25', 'STOCKAGE'), ('ENTSOE', 'B10_CONSO', 'POMPAGE'), ('ENTSOE', 'B25_CONSO', 'STOCKAGE'),
 -- RTE (production_type)
 ('RTE', 'NUCLEAR', 'NUCLEAIRE'), ('RTE', 'FOSSIL_GAS', 'GAZ'), ('RTE', 'FOSSIL_HARD_COAL', 'CHARBON'), ('RTE', 'FOSSIL_OIL', 'FIOUL'),
 ('RTE', 'HYDRO_RUN_OF_RIVER_AND_POUNDAGE', 'HYDRO_FIL'), ('RTE', 'HYDRO_WATER_RESERVOIR', 'HYDRO_LAC'),
 ('RTE', 'HYDRO_PUMPED_STORAGE', 'STEP'), ('RTE', 'PUMPING', 'POMPAGE'), ('RTE', 'WIND_ONSHORE', 'EOLIEN_TERRE'),
 ('RTE', 'WIND_OFFSHORE', 'EOLIEN_MER'), ('RTE', 'SOLAR', 'SOLAIRE'), ('RTE', 'BIOMASS', 'BIOMASSE'),
 ('RTE', 'WASTE', 'DECHETS'), ('RTE', 'OTHER', 'AUTRES'),
 -- Eurostat (SIEC)
 ('EUROSTAT', 'N9000', 'NUCLEAIRE'), ('EUROSTAT', 'N900H', 'NUCLEAIRE'), ('EUROSTAT', 'C0000', 'CHARBON'),
 ('EUROSTAT', 'C0000X0350-0370', 'CHARBON'), ('EUROSTAT', 'P1000', 'TOURBE'), ('EUROSTAT', 'S2000', 'SCHISTE'),
 ('EUROSTAT', 'G3000', 'GAZ'), ('EUROSTAT', 'O4000XBIO', 'PETROLE'), ('EUROSTAT', 'RA100', 'HYDRAULIQUE'),
 ('EUROSTAT', 'RA200', 'GEOTHERMIE'), ('EUROSTAT', 'RA300', 'EOLIEN'), ('EUROSTAT', 'RA400', 'SOLAIRE'),
 ('EUROSTAT', 'CF_R', 'BIOENERGIES'), ('EUROSTAT', 'X9900', 'AUTRES'), ('EUROSTAT', 'RA000', 'RENOUVELABLES'),
 ('EUROSTAT', 'W6100_6220', 'DECHETS'), ('EUROSTAT', 'E7000', 'ELECTRICITE'), ('EUROSTAT', 'H8000', 'CHALEUR')
) AS s (SourceCode, CodeExterne, CodeFiliere)
ON c.SourceCode = s.SourceCode AND c.CodeExterne = s.CodeExterne
WHEN MATCHED THEN UPDATE SET CodeFiliere = s.CodeFiliere
WHEN NOT MATCHED THEN INSERT (SourceCode, CodeExterne, CodeFiliere) VALUES (s.SourceCode, s.CodeExterne, s.CodeFiliere);
GO

/* ---------- 8. Frontières (une ligne par paire, ZoneA < ZoneB) ---------- */
MERGE core.Frontiere AS c
USING (VALUES ('BE', 'FR', 1), ('DE_LU', 'FR', 1), ('CH', 'FR', 1), ('FR', 'IT_NORD', 1), ('ES', 'FR', 1),
              ('FR', 'GB', 0),                     -- le Royaume-Uni ne publie plus sur ENTSO-E depuis 2021
              ('DE_LU', 'NL', 1), ('BE', 'DE_LU', 1), ('AT', 'DE_LU', 1), ('CH', 'DE_LU', 1), ('CZ', 'DE_LU', 1),
              ('DE_LU', 'PL', 1), ('BE', 'NL', 1), ('ES', 'PT', 1), ('AT', 'CH', 1), ('CH', 'IT_NORD', 1),
              ('AT', 'IT_NORD', 1), ('AT', 'CZ', 1), ('CZ', 'PL', 1)) AS s (ZoneA, ZoneB, ChargerFlux)
ON c.ZoneA = s.ZoneA AND c.ZoneB = s.ZoneB
WHEN MATCHED THEN UPDATE SET ChargerFlux = s.ChargerFlux
WHEN NOT MATCHED THEN INSERT (ZoneA, ZoneB, ChargerFlux) VALUES (s.ZoneA, s.ZoneB, s.ChargerFlux);
GO

/* ---------- 9. Règles de qualité et paramètres d'exploitation ---------- */
MERGE dq.Regle AS c
USING (VALUES
 ('FRAICHEUR_INFRA_HEURES', 48,   NULL, N'Une série infra-journalière sans point depuis plus de N heures'),
 ('FRAICHEUR_MENSUEL_MOIS',  4,   NULL, N'Une série mensuelle sans point depuis plus de N mois'),
 ('FRAICHEUR_ANNUEL_MOIS',  30,   NULL, N'Une série annuelle ou semestrielle sans point depuis plus de N mois'),
 ('PRIX_BORNES',          -500, 5000,   N'Prix day-ahead hors de [Seuil ; Seuil2] EUR/MWh'),
 ('PUISSANCE_MAX_MW',   200000,   NULL, N'Aucune zone ne dépasse cette puissance en MW'),
 ('SAUT_PCT',              0.5,   NULL, N'Variation de consommation de plus de 50 % entre deux points consécutifs'),
 ('TROU_PAS',                4,   NULL, N'Trou de plus de N pas dans une série infra-horaire, sur les 7 derniers jours'),
 ('REVISION_FORTE_PCT',    0.2,   NULL, N'Valeur révisée de plus de 20 %'),
 ('CONCORDANCE_PCT',      0.05,   NULL, N'Deux sources différentes de plus de 5 % sur la moyenne d''un jour')
) AS s (Code, Seuil, Seuil2, Description)
ON c.Code = s.Code
WHEN NOT MATCHED THEN INSERT (Code, Seuil, Seuil2, Description) VALUES (s.Code, s.Seuil, s.Seuil2, s.Description);

MERGE ops.Parametre AS c
USING (VALUES
 ('MART_DERNIER_LOT',         N'0',  N'Dernier lot déjà agrégé dans mart.MesureJour (filigrane)'),
 ('BRUT_CONSERVATION_JOURS',  N'90', N'Durée de conservation des réponses brutes ODRÉ, ENTSO-E et RTE'),
 ('PARTITION_MOIS_AVANCE',    N'3',  N'Nombre de mois futurs toujours prêts dans les partitions'),
 ('ARCHIVE_APRES_MOIS',       N'24', N'Âge en mois à partir duquel une partition passe en COLUMNSTORE_ARCHIVE')
) AS s (Cle, Valeur, Description)
ON c.Cle = s.Cle
WHEN NOT MATCHED THEN INSERT (Cle, Valeur, Description) VALUES (s.Cle, s.Valeur, s.Description);
GO

/* ---------- 10. Le catalogue : ce que la plateforme charge ---------- */

/* 10.1 Open Data Réseaux Énergies : éCO2mix national (consolidé puis temps réel), régional, gaz */
DECLARE @odre TABLE (Jeu varchar(120), Indicateur varchar(40), Zone varchar(12), Parametres nvarchar(4000),
                     Debut date, Fenetre smallint, Recouvrement smallint);
INSERT @odre
SELECT j.Jeu, i.Indicateur, 'FR', i.Parametres, j.Debut, j.Fenetre, j.Recouvrement
FROM (VALUES ('eco2mix-national-cons-def', CAST('2023-01-01' AS date), 92, 31),
             ('eco2mix-national-tr',       CAST('2025-01-01' AS date), 31,  3)) AS j (Jeu, Debut, Fenetre, Recouvrement)
CROSS JOIN (VALUES
 ('CONSO_ELEC',         N'{"champs":["consommation"]}'),
 ('PREV_CONSO_J1',      N'{"champs":["prevision_j1"]}'),
 ('PROD_ELEC',          N'{"champs":["nucleaire","charbon","gaz","fioul","eolien","solaire","hydraulique","bioenergies","pompage"],"role":"filiere"}'),
 ('INTENSITE_CO2',      N'{"champs":["taux_co2"]}'),
 ('SOLDE_ECHANGES',     N'{"champs":["ech_physiques"]}'),
 ('ECHANGE_COMMERCIAL', N'{"champs":["ech_comm_angleterre","ech_comm_espagne","ech_comm_italie","ech_comm_suisse","ech_comm_allemagne_belgique"],"role":"contrepartie"}')
) AS i (Indicateur, Parametres)
UNION ALL
SELECT j.Jeu, i.Indicateur, NULL, i.Parametres, j.Debut, j.Fenetre, j.Recouvrement
FROM (VALUES ('eco2mix-regional-cons-def', CAST('2025-01-01' AS date), 31, 31),
             ('eco2mix-regional-tr',       CAST('2026-01-01' AS date), 31,  3)) AS j (Jeu, Debut, Fenetre, Recouvrement)
CROSS JOIN (VALUES
 ('CONSO_ELEC', N'{"champs":["consommation"],"champ_zone":"code_insee_region"}'),
 ('PROD_ELEC',  N'{"champs":["thermique","nucleaire","eolien","solaire","hydraulique","bioenergies","pompage"],"role":"filiere","champ_zone":"code_insee_region"}')
) AS i (Indicateur, Parametres)
UNION ALL
SELECT 'consommation-quotidienne-brute', 'CONSO_GAZ', 'FR',
       N'{"champs":["consommation_brute_gaz_totale"],"champ_qualite":null,"qualite_fixe":"P"}', '2023-01-01', 92, 7;

MERGE cfg.RequeteACharger AS c
USING @odre AS s
ON c.SourceCode = 'ODRE' AND c.Jeu = s.Jeu AND c.IndicateurCode = s.Indicateur
   AND c.ZoneCode IS NOT DISTINCT FROM s.Zone AND c.ContrepartieCode IS NULL
WHEN MATCHED THEN UPDATE SET Parametres = s.Parametres
WHEN NOT MATCHED THEN
    INSERT (SourceCode, Jeu, Parametres, IndicateurCode, ZoneCode, DebutHistorique, FenetreJours, RecouvrementJours, Commentaire)
    VALUES ('ODRE', s.Jeu, s.Parametres, s.Indicateur, s.Zone, s.Debut, s.Fenetre, s.Recouvrement, N'éCO2mix et gaz');
GO

/* 10.2 ENTSO-E : 11 zones x (consommation, production, capacités) + 11 zones de prix + flux des frontières */
DECLARE @entsoe TABLE (Jeu varchar(120), Indicateur varchar(40), Zone varchar(12), Contrepartie varchar(12),
                       Parametres nvarchar(4000), Debut date, Fenetre smallint, Recouvrement smallint);

INSERT @entsoe
SELECT d.Jeu, d.Indicateur, z.Code, NULL, d.Parametres, d.Debut, d.Fenetre, d.Recouvrement
FROM (VALUES ('A65', 'CONSO_ELEC',         N'{"documentType":"A65","processType":"A16","domaine":"outBiddingZone_Domain"}', CAST('2024-01-01' AS date), 92, 3),
             ('A75', 'PROD_ELEC',          N'{"documentType":"A75","processType":"A16","domaine":"in_Domain"}',             CAST('2024-01-01' AS date), 92, 3),
             ('A68', 'CAPACITE_INSTALLEE', N'{"documentType":"A68","processType":"A33","domaine":"in_Domain"}',             CAST('2015-01-01' AS date), 365, 365)
     ) AS d (Jeu, Indicateur, Parametres, Debut, Fenetre, Recouvrement)
CROSS JOIN (VALUES ('FR'), ('DE_LU'), ('BE'), ('NL'), ('ES'), ('PT'), ('IT'), ('CH'), ('AT'), ('PL'), ('CZ')) AS z (Code)
UNION ALL
SELECT 'A44', 'PRIX_SPOT_J1', z.Code, NULL,
       N'{"documentType":"A44","domaine":"in_out","contract_MarketAgreement.type":"A01"}', '2024-01-01', 92, 3
FROM (VALUES ('FR'), ('DE_LU'), ('BE'), ('NL'), ('ES'), ('PT'), ('IT_NORD'), ('CH'), ('AT'), ('PL'), ('CZ')) AS z (Code)
UNION ALL
-- flux physiques : les deux sens de chaque frontière (zone = destination, contrepartie = origine)
SELECT 'A11', 'FLUX_PHYSIQUE', s.Destination, s.Origine, N'{"documentType":"A11","domaine":"in_out"}', '2024-01-01', 92, 3
FROM core.Frontiere AS f
CROSS APPLY (VALUES (f.ZoneA, f.ZoneB), (f.ZoneB, f.ZoneA)) AS s (Destination, Origine)
WHERE f.ChargerFlux = 1;

MERGE cfg.RequeteACharger AS c
USING @entsoe AS s
ON c.SourceCode = 'ENTSOE' AND c.Jeu = s.Jeu AND c.IndicateurCode = s.Indicateur
   AND c.ZoneCode IS NOT DISTINCT FROM s.Zone AND c.ContrepartieCode IS NOT DISTINCT FROM s.Contrepartie
WHEN MATCHED THEN UPDATE SET Parametres = s.Parametres
WHEN NOT MATCHED THEN
    INSERT (SourceCode, Jeu, Parametres, IndicateurCode, ZoneCode, ContrepartieCode, DebutHistorique, FenetreJours, RecouvrementJours, Commentaire)
    VALUES ('ENTSOE', s.Jeu, s.Parametres, s.Indicateur, s.Zone, s.Contrepartie, s.Debut, s.Fenetre, s.Recouvrement, N'Transparency Platform');
GO

/* 10.3 RTE : consommation réalisée, production par filière, flux physiques (clé d'application requise) */
MERGE cfg.RequeteACharger AS c
USING (VALUES
 ('consumption/v1/short_term',                                   'CONSO_ELEC',    'FR', N'{"cle":"short_term","type":"REALISED"}'),
 ('actual_generation/v1/actual_generations_per_production_type', 'PROD_ELEC',     'FR', N'{"cle":"actual_generations_per_production_type"}'),
 ('physical_flow/v1/physical_flows',                             'FLUX_PHYSIQUE', NULL, N'{"cle":"physical_flows"}')
) AS s (Jeu, Indicateur, Zone, Parametres)
ON c.SourceCode = 'RTE' AND c.Jeu = s.Jeu AND c.IndicateurCode = s.Indicateur
WHEN MATCHED THEN UPDATE SET Parametres = s.Parametres
WHEN NOT MATCHED THEN
    INSERT (SourceCode, Jeu, Parametres, IndicateurCode, ZoneCode, DebutHistorique, FenetreJours, RecouvrementJours, Commentaire)
    VALUES ('RTE', s.Jeu, s.Parametres, s.Indicateur, s.Zone, '2025-01-01', 7, 2, N'data.rte-france.com');
GO

/* 10.4 Eurostat : statistiques officielles annuelles, semestrielles et mensuelles */
MERGE cfg.RequeteACharger AS c
USING (VALUES
 ('nrg_cb_pem',  'PROD_ELEC_MENSUELLE', '2015-01-01',
  N'{"local":{"unit":"GWH"},"dim_filiere":"siec","garder":{"siec":["N9000","C0000","G3000","O4000XBIO","RA100","RA200","RA300","RA400","CF_R","X9900"]}}'),
 ('nrg_cb_e',    'CONSO_FINALE_ELEC',   '1990-01-01', N'{"local":{"nrg_bal":"FC","siec":"E7000","unit":"GWH"}}'),
 ('nrg_cb_e',    'IMPORT_ELEC',         '1990-01-01', N'{"local":{"nrg_bal":"IMP","siec":"E7000","unit":"GWH"}}'),
 ('nrg_cb_e',    'EXPORT_ELEC',         '1990-01-01', N'{"local":{"nrg_bal":"EXP","siec":"E7000","unit":"GWH"}}'),
 ('nrg_pc_204',  'PRIX_MENAGES',        '2007-01-01', N'{"local":{"siec":"E7000","nrg_cons":"KWH2500-4999","unit":"KWH","tax":"I_TAX","currency":"EUR"}}'),
 ('nrg_pc_205',  'PRIX_ENTREPRISES',    '2007-01-01', N'{"local":{"siec":"E7000","nrg_cons":"MWH500-1999","unit":"KWH","tax":"X_VAT","currency":"EUR"}}'),
 ('nrg_ind_ren', 'PART_RENOUV_ELEC',    '2004-01-01', N'{"local":{"nrg_bal":"REN_ELC","unit":"PC"}}'),
 ('nrg_ind_id',  'DEPENDANCE_ENERGIE',  '1990-01-01', N'{"local":{"siec":"TOTAL","unit":"PC"}}'),
 ('nrg_bal_c',   'ENERGIE_BRUTE',       '1990-01-01',
  N'{"serveur":{"nrg_bal":"GAE","unit":"KTOE"},"dim_filiere":"siec","garder":{"siec":["C0000X0350-0370","P1000","S2000","O4000XBIO","G3000","N900H","RA000","W6100_6220","E7000","H8000"]}}'),
 ('env_air_gge', 'GES_ELECTRICITE',     '1990-01-01', N'{"serveur":{"airpol":"GHG","src_crf":["CRF1A1A","TOTX4_MEMO"]},"local":{"src_crf":"CRF1A1A","unit":"MIO_T"}}'),
 ('env_air_gge', 'GES_TOTAL',           '1990-01-01', N'{"serveur":{"airpol":"GHG","src_crf":["CRF1A1A","TOTX4_MEMO"]},"local":{"src_crf":"TOTX4_MEMO","unit":"MIO_T"}}')
) AS s (Jeu, Indicateur, Debut, Parametres)
ON c.SourceCode = 'EUROSTAT' AND c.Jeu = s.Jeu AND c.IndicateurCode = s.Indicateur
WHEN MATCHED THEN UPDATE SET Parametres = s.Parametres
WHEN NOT MATCHED THEN
    INSERT (SourceCode, Jeu, Parametres, IndicateurCode, DebutHistorique, FenetreJours, RecouvrementJours, Commentaire)
    VALUES ('EUROSTAT', s.Jeu, s.Parametres, s.Indicateur, s.Debut, 32000, 0, N'Statistiques officielles');
GO

/* ---------- 11. Les décalages horaires de chaque fuseau ---------- */
EXEC core.usp_Fuseau_Generer;
GO

/* Contrôle */
SELECT 'Sources' AS Element, COUNT(*) AS Nombre FROM core.Source
UNION ALL SELECT 'Indicateurs', COUNT(*) FROM core.Indicateur
UNION ALL SELECT 'Zones', COUNT(*) FROM core.Zone
UNION ALL SELECT 'Filières', COUNT(*) FROM core.Filiere
UNION ALL SELECT 'Alias de filières', COUNT(*) FROM core.FiliereAlias
UNION ALL SELECT 'Frontières', COUNT(*) FROM core.Frontiere
UNION ALL SELECT 'Périodes horaires', COUNT(*) FROM core.FuseauDecalage;

SELECT SourceCode, COUNT(*) AS Requetes, SUM(CAST(Actif AS int)) AS Actives
FROM cfg.RequeteACharger GROUP BY SourceCode ORDER BY SourceCode;
GO
