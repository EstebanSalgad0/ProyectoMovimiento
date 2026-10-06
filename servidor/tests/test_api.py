import json

import numpy as np
import pytest
from conftest import DIR_FIXTURES
from fastapi.testclient import TestClient

import servidor

cliente = TestClient(servidor.app)


def test_raiz_compatible_con_app_v1():
    r = cliente.get("/")
    assert r.status_code == 200
    assert r.json()["status"] == "Servidor MediaPipe corriendo"


def test_salud_y_catalogo():
    salud = cliente.get("/salud").json()
    assert salud["estado"] == "ok"
    catalogo = cliente.get("/v1/ejercicios").json()
    assert {e["id"] for e in catalogo["ejercicios"]} == set(salud["ejercicios"])


def test_puntos_con_fixture():
    fx = json.loads((DIR_FIXTURES / "sentadilla_lateral_poco_profunda.json").read_text(encoding="utf-8"))
    r = cliente.post("/v1/analisis/puntos", json={"ejercicio": fx["ejercicio"], "fotogramas": fx["fotogramas"]})
    assert r.status_code == 200, r.text
    datos = r.json()
    assert datos["puntaje"] == fx["esperado"]["puntaje"]
    assert len(datos["repeticiones"]) == fx["esperado"]["repeticiones"]


def test_puntos_rechaza_ejercicio_invalido():
    r = cliente.post("/v1/analisis/puntos", json={"ejercicio": "volteretas", "fotogramas": []})
    assert r.status_code == 400
    assert r.json()["codigo"] == "EJERCICIO_INVALIDO"


def test_puntos_rechaza_tiempos_no_crecientes():
    fotogramas = [{"t_ms": 100, "puntos": None}, {"t_ms": 100, "puntos": None}]
    r = cliente.post("/v1/analisis/puntos", json={"ejercicio": "sentadilla", "fotogramas": fotogramas})
    assert r.status_code == 422
    assert r.json()["codigo"] == "TIEMPOS_NO_CRECIENTES"


def test_puntos_rechaza_cantidad_incorrecta_de_puntos():
    fotogramas = [{"t_ms": 0, "puntos": [[0, 0, 0, 1]] * 10}]
    r = cliente.post("/v1/analisis/puntos", json={"ejercicio": "sentadilla", "fotogramas": fotogramas})
    assert r.status_code == 422


def test_video_rechaza_ejercicio_invalido():
    r = cliente.post("/analizar", files={"video": ("a.mp4", b"x", "video/mp4")}, data={"ejercicio": "nadar"})
    assert r.status_code == 400
    assert "error" in r.json()


def test_video_ilegible():
    pytest.importorskip("mediapipe")
    r = cliente.post(
        "/analizar", files={"video": ("a.mp4", b"esto no es un video", "video/mp4")}, data={"ejercicio": "sentadilla"}
    )
    assert r.status_code == 422
    assert r.json()["codigo"] == "VIDEO_INVALIDO"


def test_video_sin_persona_recorre_mediapipe(tmp_path):
    """Video real (cuadros negros): ejercita MediaPipe de punta a punta."""
    pytest.importorskip("mediapipe")
    cv2 = pytest.importorskip("cv2")
    ruta = tmp_path / "negro.mp4"
    escritor = cv2.VideoWriter(str(ruta), cv2.VideoWriter_fourcc(*"mp4v"), 24, (320, 240))
    if not escritor.isOpened():
        pytest.skip("OpenCV sin codec mp4v")
    for _ in range(48):
        escritor.write(np.zeros((240, 320, 3), dtype=np.uint8))
    escritor.release()

    with open(ruta, "rb") as f:
        r = cliente.post(
            "/v1/analisis/video", files={"video": ("negro.mp4", f, "video/mp4")}, data={"ejercicio": "sentadilla"}
        )
    assert r.status_code == 200, r.text
    datos = r.json()
    assert datos["puntaje"] == 0
    assert datos["calidad"]["fotogramas"] > 0
    assert {h["codigo"] for h in datos["hallazgos"]} == {"SIN_REPETICIONES", "CALIDAD_BAJA"}


def test_puntos_con_ajustes_personales():
    fx = json.loads((DIR_FIXTURES / "sentadilla_lateral_poco_profunda.json").read_text(encoding="utf-8"))
    ajustes = {"sentadilla": {"SQ_PROFUNDIDAD": {"umbral": 120}, "SQ_TRONCO": {"activa": False}}}
    r = cliente.post(
        "/v1/analisis/puntos",
        json={"ejercicio": fx["ejercicio"], "fotogramas": fx["fotogramas"], "ajustes": ajustes},
    )
    assert r.status_code == 200, r.text
    assert r.json()["puntaje"] == 100


def test_video_rechaza_ajustes_mal_formados():
    r = cliente.post(
        "/v1/analisis/video",
        files={"video": ("a.mp4", b"x", "video/mp4")},
        data={"ejercicio": "sentadilla", "ajustes": "{no es json"},
    )
    assert r.status_code == 422
    assert r.json()["codigo"] == "AJUSTES_INVALIDOS"
