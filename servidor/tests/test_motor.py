import copy
import json
import math

import numpy as np
import pytest
from conftest import DIR_FIXTURES, RAIZ

from motor import Analizador, EspecificacionInvalida, Fotograma, cargar_especificacion, desde_dict
from motor.especificacion import Senal
from motor.filtros import FiltroOneEuro
from motor.geometria import angulo_articular, inclinacion_desde_horizontal, inclinacion_desde_vertical, redondear
from motor.repeticiones import DetectorRepeticiones

SPEC = cargar_especificacion()
FIXTURES = sorted(DIR_FIXTURES.glob("*.json"))


# ----------------------------------------------------------------- geometría
def test_angulo_articular_recto_y_extendido():
    a, b = np.array([0.0, 1.0, 0.0]), np.array([0.0, 0.0, 0.0])
    assert angulo_articular(a, b, np.array([1.0, 0.0, 0.0])) == pytest.approx(90.0)
    assert angulo_articular(a, b, np.array([0.0, -1.0, 0.0])) == pytest.approx(180.0)


def test_angulo_con_vector_nulo_es_nan():
    p = np.array([1.0, 1.0, 0.0])
    assert math.isnan(angulo_articular(p, p, np.array([0.0, 0.0, 0.0])))


def test_inclinaciones_en_imagen():
    # y crece hacia abajo en la imagen: hombro arriba de la cadera = tronco vertical.
    assert inclinacion_desde_vertical(np.array([0.0, 100.0]), np.array([0.0, 0.0])) == pytest.approx(0.0)
    assert inclinacion_desde_vertical(np.array([0.0, 100.0]), np.array([100.0, 0.0])) == pytest.approx(45.0)
    assert inclinacion_desde_horizontal(np.array([0.0, 0.0]), np.array([100.0, 0.0])) == pytest.approx(0.0)
    assert inclinacion_desde_horizontal(np.array([0.0, 0.0]), np.array([-100.0, 100.0])) == pytest.approx(45.0)


def test_redondeo_mitad_hacia_arriba_igual_que_dart():
    assert redondear(92.5) == 93
    assert redondear(91.5) == 92
    assert redondear(91.49) == 91


# -------------------------------------------------------------------- filtro
def test_filtro_one_euro_entrada_constante():
    f = FiltroOneEuro(1.2, 0.04, 1.0)
    salidas = [f(50.0, k / 30) for k in range(30)]
    assert all(s == pytest.approx(50.0) for s in salidas)


def test_filtro_one_euro_converge_tras_escalon():
    f = FiltroOneEuro(1.2, 0.04, 1.0)
    for k in range(10):
        f(0.0, k / 30)
    ultimo = 0.0
    for k in range(10, 70):
        ultimo = f(100.0, k / 30)
    assert ultimo == pytest.approx(100.0, abs=0.5)


# -------------------------------------------------------------- repeticiones
def _senal_descendente():
    return Senal("x", "x", "°", "descendente", inicio=145, fin=155, minimo_rep=125)


def test_detector_cuenta_repeticion_valida_e_incompleta():
    d = DetectorRepeticiones(_senal_descendente(), duracion_minima_s=0.4)
    valores = [170, 160, 140, 120, 100, 120, 150, 160, 170, 150, 140, 135, 140, 158, 170]
    eventos = [d.actualizar(i, i * 0.25, v) for i, v in enumerate(valores)]
    eventos = [e for e in eventos if e]
    assert [e.valida for e in eventos] == [True, False]
    assert eventos[0].idx_pico == 4  # 100° es el punto más bajo


def test_detector_descarta_movimientos_muy_breves():
    d = DetectorRepeticiones(_senal_descendente(), duracion_minima_s=0.4)
    eventos = [d.actualizar(i, i * 0.05, v) for i, v in enumerate([170, 120, 170])]
    assert not any(eventos)


def test_detector_ignora_valores_nulos_y_reporta_fase():
    d = DetectorRepeticiones(_senal_descendente(), duracion_minima_s=0.0)
    assert d.actualizar(0, 0.0, None) is None
    d.actualizar(1, 0.1, 170)
    assert d.fase == "reposo"
    d.actualizar(2, 0.2, 130)
    assert d.fase == "ida"
    d.actualizar(3, 0.3, 140)
    assert d.fase == "vuelta"


# ------------------------------------------------------------- especificación
def test_especificacion_tiene_los_seis_ejercicios():
    assert set(SPEC.ids) == {
        "sentadilla",
        "zancada",
        "curl_biceps_sentado",
        "press_hombros_sentado",
        "elevacion_lateral",
        "sentarse_pararse",
    }


def test_especificacion_rechaza_umbrales_incoherentes():
    crudo = copy.deepcopy(SPEC.crudo)
    crudo["ejercicios"][0]["senal"]["minimo_rep"] = 150  # mayor que 'inicio' en una señal descendente
    with pytest.raises(EspecificacionInvalida):
        desde_dict(crudo)


def test_especificacion_rechaza_tipo_desconocido():
    crudo = copy.deepcopy(SPEC.crudo)
    crudo["ejercicios"][0]["verificaciones"][0]["tipo"] = "inventado"
    with pytest.raises(EspecificacionInvalida):
        desde_dict(crudo)


def test_copia_de_la_app_identica_a_la_compartida():
    compartida = (RAIZ / "compartido" / "ejercicios.json").read_text(encoding="utf-8")
    app = (RAIZ / "app" / "assets" / "especificacion" / "ejercicios.json").read_text(encoding="utf-8")
    assert json.loads(compartida) == json.loads(app), "Copia app/assets/especificacion/ejercicios.json"


# ------------------------------------------------------------------ fixtures
def _cargar(ruta):
    fx = json.loads(ruta.read_text(encoding="utf-8"))
    fotogramas = []
    for f in fx["fotogramas"]:
        puntos = f["puntos"]
        if puntos is not None:
            puntos = [p if p is not None else [0.0, 0.0, 0.0, 0.0] for p in puntos]
        fotogramas.append(Fotograma.desde_listas(f["t_ms"], puntos, f.get("mundo")))
    return fx, fotogramas


@pytest.mark.parametrize("ruta", FIXTURES, ids=[r.stem for r in FIXTURES])
def test_fixture(ruta):
    fx, fotogramas = _cargar(ruta)
    analizador = Analizador(SPEC, fx["ejercicio"])
    for f in fotogramas:
        analizador.procesar(f)
    r = analizador.resultado()
    esperado = fx["esperado"]
    assert len(r["repeticiones"]) == esperado["repeticiones"]
    assert r["metricas"]["repeticiones_incompletas"] == esperado["incompletas"]
    assert sorted(h["codigo"] for h in r["hallazgos"]) == sorted(esperado["codigos"])
    assert r["puntaje"] == esperado["puntaje"]
    assert r["calidad"]["vista"] == esperado["vista"]
    # Campos de compatibilidad v1
    assert isinstance(r["feedback"], list)
    assert all(isinstance(v, float) for v in r["metricas"].values())
    json.dumps(r)  # serializable


def test_resultado_entrega_serie_acotada():
    fx, fotogramas = _cargar(DIR_FIXTURES / "sentadilla_lateral_correcta.json")
    analizador = Analizador(SPEC, fx["ejercicio"])
    for f in fotogramas:
        analizador.procesar(f)
    serie = analizador.resultado()["serie"]
    assert len(serie["t_ms"]) == len(serie["valores"]) <= SPEC.globales.puntos_serie_max
    assert serie["metrica"] == "rodilla_promedio"


# ------------------------------------------------------- objetivos personales
def _analizar_con(spec, nombre, **kwargs):
    fx, fotogramas = _cargar(DIR_FIXTURES / f"{nombre}.json")
    a = Analizador(spec, fx["ejercicio"], **kwargs)
    for f in fotogramas:
        a.procesar(f)
    return a.resultado()


def test_ajustes_cambian_umbral_y_desactivan_verificaciones():
    spec = SPEC.con_ajustes(
        {
            "sentadilla": {"SQ_PROFUNDIDAD": {"umbral": 120}, "SQ_TRONCO": {"activa": False}},
            "inexistente": {"X": {"umbral": 1}},
        }
    )
    r = _analizar_con(spec, "sentadilla_lateral_poco_profunda")
    assert [h["codigo"] for h in r["hallazgos"]] == []
    assert r["puntaje"] == 100
    # La especificación original no cambia.
    assert _analizar_con(SPEC, "sentadilla_lateral_poco_profunda")["puntaje"] == 70


def test_ajustes_vacios_devuelven_la_misma_especificacion():
    assert SPEC.con_ajustes(None) is SPEC
    assert SPEC.con_ajustes({}) is SPEC


def test_esqueleto_muestreado_solo_con_tamano_de_cuadro():
    # Los fixtures no traen tamaño de cuadro: no hay esqueleto aunque se pida.
    r = _analizar_con(SPEC, "curl_frontal_correcto", registrar_esqueleto=True)
    assert "esqueleto" not in r
    fx, fotogramas = _cargar(DIR_FIXTURES / "curl_frontal_correcto.json")
    a = Analizador(SPEC, fx["ejercicio"], registrar_esqueleto=True)
    for f in fotogramas:
        f.ancho, f.alto = 720, 1280
        a.procesar(f)
    esq = a.resultado()["esqueleto"]
    assert esq["aspecto"] == round(720 / 1280, 4)
    assert len(esq["t_ms"]) == len(esq["puntos"])
    assert all(b - a_ >= 100 for a_, b in zip(esq["t_ms"], esq["t_ms"][1:], strict=False))
    assert len(esq["puntos"][0]) == 3 * len(esq["indices"])
    assert all(0 <= v <= 1.2 for v in esq["puntos"][0][0::3])
