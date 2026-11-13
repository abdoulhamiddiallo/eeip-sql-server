"""Tests hors ligne du programme d'ingestion : des réponses synthétiques au format exact de chaque
producteur (JSON Opendatasoft, XML ENTSO-E, JSON RTE, JSON-stat Eurostat), sans base ni réseau.

Lancer :  python tests/test_ingestion.py      (ou : python -m pytest tests)
"""
import datetime as dt
import json
import sys
import types
from pathlib import Path

# pyodbc simulé : les tests ne touchent à aucune base
faux = types.ModuleType("pyodbc")
faux.Connection = object
faux.Error = Exception
sys.modules.setdefault("pyodbc", faux)

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "ingestion"))
import eeip_ingestion as ei  # noqa: E402

U = dt.datetime


def requete(source, jeu, params, zone="FR", contrepartie=None, debut=dt.date(2025, 1, 1),
            fenetre=31, recouvrement=3, dernier=None):
    return ei.Requete(cfg_id=1, source=source, jeu=jeu, params=params, indicateur="X", zone=zone,
                      zone_eic="10YFR-RTE------C", contrepartie=contrepartie, contrepartie_eic=None,
                      debut=debut, fenetre=fenetre, recouvrement=recouvrement,
                      dernier_instant=dernier, derniere_empreinte=None)


# ---------------------------------------------------------------- outils
def test_en_utc_ramene_tout_en_utc():
    assert ei.en_utc("2026-07-01T12:00:00+02:00") == U(2026, 7, 1, 10, 0)
    assert ei.en_utc("2026-01-15T12:00:00+01:00") == U(2026, 1, 15, 11, 0)
    assert ei.en_utc("2026-03-29T01:00:00Z") == U(2026, 3, 29, 1, 0)
    assert ei.en_utc("") is None and ei.en_utc("pas une date") is None


def test_nombre_accepte_les_formats_des_sources():
    assert ei.nombre("12,5") == 12.5
    assert ei.nombre(7) == 7.0
    for vide in (None, "", "NaN", ":", "ND", True):
        assert ei.nombre(vide) is None


def test_le_jeton_ne_sort_jamais():
    url = "https://web-api.tp.entsoe.eu/api?securityToken=abc123&documentType=A44"
    assert "abc123" not in ei.masquer(url)
    assert "securityToken=***" in ei.masquer(url)


def test_empreinte_stable_et_sensible():
    assert ei.empreinte(["a", "b"]) == ei.empreinte(["a", "b"])
    assert ei.empreinte(["a", "b"]) != ei.empreinte(["a", "c"])
    assert len(ei.empreinte(["x"])) == 32                      # SHA-256


def test_debut_de_jour_minuit_local():
    # un jour publié à 23:00 UTC la veille (minuit à Paris en hiver) est rangé au bon jour
    assert ei.debut_de_jour(U(2025, 12, 31, 23, 0)) == U(2026, 1, 1)
    assert ei.debut_de_jour(U(2026, 6, 30, 22, 0)) == U(2026, 7, 1)


# ---------------------------------------------------------------- fenêtres
def test_premier_chargement_grille_fixe():
    r = requete("ODRE", "eco2mix-national-tr", {}, fenetre=30, debut=dt.date(2026, 1, 1))
    f = ei.fenetres(r, U(2026, 3, 1))
    assert f[0] == (U(2026, 1, 1), U(2026, 1, 31))
    assert f[-1][1] == U(2026, 3, 1)


def test_reprise_au_filigrane_moins_le_recouvrement():
    r = requete("ODRE", "eco2mix-national-tr", {}, fenetre=30, recouvrement=3,
                dernier=U(2026, 11, 10, 17, 45))
    assert ei.fenetres(r, U(2026, 11, 12))[0][0] == U(2026, 11, 7)


def test_entsoe_jamais_plus_d_un_an():
    r = requete("ENTSOE", "A65", {}, fenetre=900, debut=dt.date(2023, 1, 1))
    assert all((b - a).days <= 365 for a, b in ei.fenetres(r, U(2026, 1, 1)))


def test_eurostat_un_seul_appel():
    r = requete("EUROSTAT", "nrg_cb_pem", {}, debut=dt.date(1990, 1, 1))
    assert len(ei.fenetres(r, U(2026, 11, 12))) == 1


# ---------------------------------------------------------------- ODRÉ (éCO2mix)
def test_odre_temps_reel_et_consolide_meme_serie():
    params = {"champs": ["nucleaire", "eolien"], "role": "filiere", "champ_qualite": "nature"}
    enr = [{"date_heure": "2026-01-01T00:00:00+00:00", "nature": "Données temps réel", "nucleaire": 50000, "eolien": "8000"},
           {"date_heure": "2026-01-01T00:15:00+00:00", "nature": "Données temps réel", "nucleaire": 50100, "eolien": None}]
    tr = ei.analyser_odre(ei.Reponse("u", 200, json.dumps(enr)), requete("ODRE", "eco2mix-national-tr", params))
    enr2 = [dict(e, nature="Données consolidées") for e in enr]
    cons = ei.analyser_odre(ei.Reponse("u", 200, json.dumps(enr2)), requete("ODRE", "eco2mix-national-cons-def", params))
    assert {l[0] for l in tr} == {l[0] for l in cons}          # le consolidé révise le temps réel
    assert len(tr) == 3                                         # la valeur vide est ignorée
    assert {l[4] for l in tr} == {"PT15M"}                      # pas déduit des instants
    assert {l[7] for l in tr} == {"T"} and {l[7] for l in cons} == {"C"}


def test_odre_qualite():
    assert ei.qualite_odre("Données définitives") == "D"
    assert ei.qualite_odre("Données consolidées") == "C"
    assert ei.qualite_odre(None) == "T"


def test_odre_champ_renomme_signale():
    enr = [{"date_heure": "2026-01-01T00:00:00+00:00", "autre": 1}]
    try:
        ei.analyser_odre(ei.Reponse("u", 200, json.dumps(enr)),
                         requete("ODRE", "eco2mix-national-tr", {"champs": ["nucleaire"]}))
    except ei.AucuneDonnee as ex:
        assert "champs disponibles" in str(ex)
    else:
        raise AssertionError("un champ renommé doit être signalé")


# ---------------------------------------------------------------- ENTSO-E
XML_A44 = """<?xml version="1.0" encoding="UTF-8"?>
<Publication_MarketDocument xmlns="urn:iec62325.351:tc57wg16:451-3:publicationdocument:7:3">
 <TimeSeries><curveType>A03</curveType>
  <Period><timeInterval><start>2026-01-01T23:00Z</start><end>2026-01-02T00:00Z</end></timeInterval>
   <resolution>PT15M</resolution>
   <Point><position>1</position><price.amount>80.5</price.amount></Point>
   <Point><position>3</position><price.amount>-2</price.amount></Point>
  </Period>
 </TimeSeries>
</Publication_MarketDocument>"""


def test_entsoe_courbe_a03_prolonge_la_valeur():
    lignes = ei.analyser_entsoe(ei.Reponse("u", 200, XML_A44), requete("ENTSOE", "A44", {"documentType": "A44"}))
    assert [l[6] for l in lignes] == [80.5, 80.5, -2.0, -2.0]   # positions 2 et 4 prolongées
    assert lignes[0][5] == U(2026, 1, 1, 23, 0) and lignes[1][5] == U(2026, 1, 1, 23, 15)
    assert {l[7] for l in lignes} == {"D"}                      # un prix publié est définitif


XML_A75 = """<?xml version="1.0" encoding="UTF-8"?>
<GL_MarketDocument xmlns="urn:iec62325.351:tc57wg16:451-6:generationloaddocument:3:0">
 <TimeSeries><outBiddingZone_Domain.mRID>10YFR-RTE------C</outBiddingZone_Domain.mRID>
  <MktPSRType><psrType>B10</psrType></MktPSRType>
  <Period><timeInterval><start>2026-01-01T00:00Z</start><end>2026-01-01T01:00Z</end></timeInterval>
   <resolution>PT60M</resolution><Point><position>1</position><quantity>1200</quantity></Point>
  </Period>
 </TimeSeries>
</GL_MarketDocument>"""


def test_entsoe_pompage_compte_en_negatif():
    l = ei.analyser_entsoe(ei.Reponse("u", 200, XML_A75), requete("ENTSOE", "A75", {"documentType": "A75"}))
    assert l == [("A75/FR/-/B10_CONSO/PT60M", "FR", "B10_CONSO", None, "PT60M", U(2026, 1, 1), -1200.0, "T")]


def test_entsoe_aucune_donnee_n_est_pas_une_erreur():
    ack = """<Acknowledgement_MarketDocument xmlns="urn:x"><Reason><code>999</code>
             <text>No matching data found for Data item</text></Reason></Acknowledgement_MarketDocument>"""
    assert ei.analyser_entsoe(ei.Reponse("u", 200, ack), requete("ENTSOE", "A65", {"documentType": "A65"})) == []


# ---------------------------------------------------------------- RTE
def test_rte_flux_par_frontiere():
    corps = {"physical_flows": [{"sender_country_eic_code": "10YCH-SWISSGRIDZ",
                                 "receiver_country_eic_code": "10YFR-RTE------C",
                                 "values": [{"start_date": "2026-01-01T00:00:00+01:00",
                                             "end_date": "2026-01-01T01:00:00+01:00", "value": 1500}]}]}
    l = ei.analyser_rte(ei.Reponse("u", 200, json.dumps(corps)),
                        requete("RTE", "physical_flow/v1/physical_flows", {"cle": "physical_flows"}))
    assert l[0][1:] == ("10YFR-RTE------C", None, "10YCH-SWISSGRIDZ", "PT60M", U(2025, 12, 31, 23, 0), 1500.0, "T")


# ---------------------------------------------------------------- Eurostat (JSON-stat 2.0)
def test_eurostat_decodage_ligne_par_ligne():
    corps = {"id": ["siec", "geo", "time"], "size": [2, 2, 2],
             "dimension": {"siec": {"category": {"index": {"N9000": 0, "RA100": 1}}},
                           "geo": {"category": {"index": {"FR": 0, "DE": 1}}},
                           "time": {"category": {"index": {"2023": 0, "2024": 1}}}},
             "value": {"0": 10, "3": 21, "5": 30, "7": 41}, "status": {"7": "p"}}
    l = ei.analyser_eurostat(ei.Reponse("u", 200, json.dumps(corps)),
                             requete("EUROSTAT", "nrg_bal_peh", {"dim_filiere": "siec"}, debut=dt.date(1990, 1, 1)),
                             {"FR", "DE"})
    vu = {(x[1], x[2], x[5].year): (x[6], x[7]) for x in l}
    assert vu == {("FR", "N9000", 2023): (10.0, "D"), ("DE", "N9000", 2024): (21.0, "D"),
                  ("FR", "RA100", 2024): (30.0, "D"), ("DE", "RA100", 2024): (41.0, "P")}


def test_eurostat_periodes():
    assert ei.periode_eurostat("2024") == (U(2024, 1, 1), "P1Y")
    assert ei.periode_eurostat("2025-M07") == (U(2025, 7, 1), "P1M")
    assert ei.periode_eurostat("2025-S2") == (U(2025, 7, 1), "P6M")
    assert ei.periode_eurostat("2025Q1") is None


if __name__ == "__main__":
    tests = [(n, f) for n, f in sorted(globals().items()) if n.startswith("test_")]
    for n, f in tests:
        f()
        print(f"OK  {n}")
    print(f"{len(tests)} tests réussis")
