"""Genera secuencias sintéticas de puntos corporales con resultado conocido.

Cada fixture describe un ejercicio con ángulos controlados (p. ej. sentadilla a
95° con tronco a 30°) y el resultado que AMBOS motores (Python y Dart) deben
entregar. Así se verifica que el análisis en tiempo real de la app y el del
servidor son equivalentes.

Uso:  python compartido/fixtures/generar_fixtures.py
"""

from __future__ import annotations

import json
import math
from pathlib import Path

DIR = Path(__file__).resolve().parent
FPS = 12
ESCALA = 400.0  # px por metro
CENTRO = (360.0, 900.0)  # px (x, y del suelo)
VIS = 0.99

# Medidas corporales (m)
PIERNA, MUSLO, TRONCO = 0.43, 0.45, 0.52
BRAZO, ANTEBRAZO = 0.30, 0.27


def _suave(a: float, b: float, u: float) -> float:
    """Interpolación coseno de a→b con u en [0, 1]."""
    return a + (b - a) * (1 - math.cos(math.pi * max(0.0, min(1.0, u)))) / 2


def _linea_tiempo(reposo: float, picos, ida: float, sosten: float, vuelta: float, pausa: float):
    """Devuelve una función t→valor con repeticiones reposo→pico→reposo."""
    tramos = []
    t = pausa
    for pico in picos:
        tramos.append((t, ida, sosten, vuelta, pico))
        t += ida + sosten + vuelta + pausa
    total = t

    def valor(tt: float) -> float:
        for inicio, d_ida, d_sosten, d_vuelta, pico in tramos:
            if inicio <= tt < inicio + d_ida:
                return _suave(reposo, pico, (tt - inicio) / d_ida)
            if inicio + d_ida <= tt < inicio + d_ida + d_sosten:
                return pico
            if inicio + d_ida + d_sosten <= tt < inicio + d_ida + d_sosten + d_vuelta:
                return _suave(pico, reposo, (tt - inicio - d_ida - d_sosten) / d_vuelta)
        return reposo

    return valor, total


def _proyectar(puntos3d, con_mundo=False):
    """Puntos {idx: (x, y_arriba, z)} en metros → listas de imagen (px) y mundo."""
    imagen, mundo = [], []
    for i in range(33):
        if i in puntos3d:
            x, y, z = puntos3d[i]
            imagen.append(
                [round(CENTRO[0] + ESCALA * x, 1), round(CENTRO[1] - ESCALA * y, 1), round(ESCALA * z, 1), VIS]
            )
            mundo.append([round(x, 4), round(-y, 4), round(z, 4)])
        else:
            imagen.append(None)
            mundo.append([0.0, 0.0, 0.0])
    return imagen, (mundo if con_mundo else None)


def _sumar(p, v, k=1.0):
    return tuple(a + k * b for a, b in zip(p, v, strict=True))


# ----------------------------------------------------------------- poses
def pose_sentadilla_lateral(rodilla: float, tronco: float):
    a = b = math.radians((180 - rodilla) / 2)
    t = math.radians(tronco)
    p = {}
    for lado, z in ((0, 0.1), (1, -0.1)):
        tob = (0.0, 0.08, z)
        rod = _sumar(tob, (math.sin(a), math.cos(a), 0), PIERNA)
        cad = _sumar(rod, (-math.sin(b), math.cos(b), 0), MUSLO)
        hom = _sumar(cad, (math.sin(t), math.cos(t), 0), TRONCO)
        codo = _sumar(hom, (0.28, -0.05, 0))
        mun = _sumar(codo, (0.27, 0.0, 0))
        p[27 + lado], p[25 + lado], p[23 + lado], p[11 + lado] = tob, rod, cad, hom
        p[13 + lado], p[15 + lado] = codo, mun
    hom_medio = p[11]
    p[0] = _sumar(hom_medio, (math.sin(t) * 0.2 + 0.08, math.cos(t) * 0.22, -0.1))
    return p


def pose_sentadilla_frontal(rodilla: float, valgo: float, tronco: float = 20.0):
    a = b = math.radians((180 - rodilla) / 2)
    t = math.radians(tronco)
    p = {}
    for lado, s in ((0, 1.0), (1, -1.0)):
        tob = (0.15 * s, 0.08, 0.0)
        rod = (0.15 * s - valgo * s, tob[1] + PIERNA * math.cos(a), -PIERNA * math.sin(a))
        cad = (0.12 * s, rod[1] + MUSLO * math.cos(b), rod[2] + MUSLO * math.sin(b))
        hom = (0.19 * s, cad[1] + TRONCO * math.cos(t), cad[2] - TRONCO * math.sin(t))
        codo = _sumar(hom, (0.0, -0.05, -0.28))
        mun = _sumar(codo, (0.0, 0.0, -0.27))
        p[27 + lado], p[25 + lado], p[23 + lado], p[11 + lado] = tob, rod, cad, hom
        p[13 + lado], p[15 + lado] = codo, mun
    p[0] = (0.0, p[11][1] + 0.22, p[11][2] - 0.08)
    return p


def _piernas_sentado(p):
    for lado, s in ((0, 1.0), (1, -1.0)):
        p[23 + lado] = (0.12 * s, 0.5, 0.0)
        p[25 + lado] = (0.14 * s, 0.52, -0.45)
        p[27 + lado] = (0.14 * s, 0.08, -0.47)


def pose_curl_frontal(codo: float):
    theta = math.radians(180 - codo)
    p = {}
    _piernas_sentado(p)
    for lado, s in ((0, 1.0), (1, -1.0)):
        hom = (0.19 * s, 1.02, 0.0)
        c = _sumar(hom, (0.0, -BRAZO, 0.0))
        m = _sumar(c, (0.0, -math.cos(theta), -math.sin(theta)), ANTEBRAZO)
        p[11 + lado], p[13 + lado], p[15 + lado] = hom, c, m
    p[0] = (0.0, 1.24, -0.05)
    return p


def pose_press_frontal(codo: float):
    alfa = math.radians(max(0.0, (codo - 90) / 90 * 75))
    phi = alfa + math.radians(180 - codo)
    p = {}
    _piernas_sentado(p)
    for lado, s in ((0, 1.0), (1, -1.0)):
        hom = (0.19 * s, 1.02, 0.0)
        c = _sumar(hom, (s * math.cos(alfa), math.sin(alfa), 0.0), BRAZO)
        m = _sumar(c, (s * math.cos(phi), math.sin(phi), 0.0), ANTEBRAZO)
        p[11 + lado], p[13 + lado], p[15 + lado] = hom, c, m
    p[0] = (0.0, 1.24, -0.05)
    return p


def pose_elevacion_frontal(abduccion: float):
    a = math.radians(abduccion)
    a2 = math.radians(abduccion + 15)
    p = {}
    for lado, s in ((0, 1.0), (1, -1.0)):
        p[23 + lado] = (0.12 * s, 0.95, 0.0)
        p[25 + lado] = (0.13 * s, 0.52, 0.0)
        p[27 + lado] = (0.14 * s, 0.08, 0.0)
        hom = (0.19 * s, 1.47, 0.0)
        c = _sumar(hom, (s * math.sin(a), -math.cos(a), 0.0), BRAZO)
        m = _sumar(c, (s * math.sin(a2), -math.cos(a2), 0.0), ANTEBRAZO)
        p[11 + lado], p[13 + lado], p[15 + lado] = hom, c, m
    p[0] = (0.0, 1.69, -0.05)
    return p


def pose_sentarse_lateral(s: float):
    """s = 0 sentado, s = 1 de pie."""
    rodilla = 95 + (172 - 95) * s
    a = math.radians(5 - 2 * s)
    b = math.radians(180 - rodilla) - a
    t = math.radians(10 - 7 * s + 35 * math.sin(math.pi * s))
    p = {}
    for lado, z in ((0, 0.1), (1, -0.1)):
        tob = (0.0, 0.08, z)
        rod = _sumar(tob, (math.sin(a), math.cos(a), 0), PIERNA)
        cad = _sumar(rod, (-math.sin(b), math.cos(b), 0), MUSLO)
        hom = _sumar(cad, (math.sin(t), math.cos(t), 0), TRONCO)
        codo = _sumar(hom, (0.12, -0.1, 0))
        mun = _sumar(codo, (-0.05, 0.15, 0))
        p[27 + lado], p[25 + lado], p[23 + lado], p[11 + lado] = tob, rod, cad, hom
        p[13 + lado], p[15 + lado] = codo, mun
    p[0] = _sumar(p[11], (math.sin(t) * 0.2 + 0.08, math.cos(t) * 0.22, -0.1))
    return p


# ------------------------------------------------------------- secuencias
def secuencia(pose_de_valor, valor, total, con_mundo=False):
    fotogramas = []
    n = int(total * FPS) + 1
    for k in range(n):
        t = k / FPS
        imagen, mundo = _proyectar(pose_de_valor(valor(t)), con_mundo)
        fotogramas.append({"t_ms": int(round(t * 1000)), "puntos": imagen, "mundo": mundo})
    return fotogramas


def fixture(nombre, ejercicio, descripcion, fotogramas, esperado):
    return {
        "nombre": nombre,
        "ejercicio": ejercicio,
        "descripcion": descripcion,
        "fotogramas": fotogramas,
        "esperado": esperado,
    }


def construir():
    fx = []

    v, tot = _linea_tiempo(175, [95, 95, 95], ida=1.8, sosten=0.3, vuelta=1.4, pausa=0.8)
    fx.append(
        fixture(
            "sentadilla_lateral_correcta",
            "sentadilla",
            "3 sentadillas a 95° vistas de costado, tronco a 30°.",
            secuencia(lambda r: pose_sentadilla_lateral(r, 30 * (175 - r) / 80), v, tot),
            {"repeticiones": 3, "incompletas": 0, "codigos": [], "puntaje": 100, "vista": "lateral"},
        )
    )

    v, tot = _linea_tiempo(175, [118, 118, 118], ida=1.8, sosten=0.3, vuelta=1.4, pausa=0.8)
    fx.append(
        fixture(
            "sentadilla_lateral_poco_profunda",
            "sentadilla",
            "3 sentadillas a 118° con el tronco inclinado 55°.",
            secuencia(lambda r: pose_sentadilla_lateral(r, 55 * (175 - r) / 57), v, tot),
            {
                "repeticiones": 3,
                "incompletas": 0,
                "codigos": ["SQ_PROFUNDIDAD", "SQ_TRONCO"],
                "puntaje": 70,
                "vista": "lateral",
            },
        )
    )

    v, tot = _linea_tiempo(175, [95, 135, 95], ida=1.8, sosten=0.3, vuelta=1.4, pausa=0.8)
    fx.append(
        fixture(
            "sentadilla_rep_incompleta",
            "sentadilla",
            "2 sentadillas completas y 1 que solo baja a 135°.",
            secuencia(lambda r: pose_sentadilla_lateral(r, 30 * (175 - r) / 80), v, tot),
            {
                "repeticiones": 2,
                "incompletas": 1,
                "codigos": ["REPETICIONES_INCOMPLETAS"],
                "puntaje": 95,
                "vista": "lateral",
            },
        )
    )

    v, tot = _linea_tiempo(175, [95, 95, 95], ida=1.8, sosten=0.3, vuelta=1.4, pausa=0.8)
    fx.append(
        fixture(
            "sentadilla_frontal_valgo",
            "sentadilla",
            "3 sentadillas de frente con las rodillas hacia adentro (8 cm en el punto más bajo).",
            secuencia(lambda r: pose_sentadilla_frontal(r, 0.08 * (175 - r) / 80), v, tot, con_mundo=True),
            {
                "repeticiones": 3,
                "incompletas": 0,
                "codigos": ["SQ_VALGO", "VISTA_RECOMENDADA"],
                "puntaje": 70,
                "vista": "frontal",
            },
        )
    )

    v, tot = _linea_tiempo(165, [45, 45, 45], ida=1.2, sosten=0.2, vuelta=1.4, pausa=0.6)
    fx.append(
        fixture(
            "curl_frontal_correcto",
            "curl_biceps_sentado",
            "3 curls simultáneos de 165° a 45° con codos fijos.",
            secuencia(pose_curl_frontal, v, tot),
            {"repeticiones": 3, "incompletas": 0, "codigos": [], "puntaje": 100, "vista": "frontal"},
        )
    )

    v, tot = _linea_tiempo(85, [147, 147, 147], ida=1.2, sosten=0.3, vuelta=1.4, pausa=0.6)
    fx.append(
        fixture(
            "press_extension_incompleta",
            "press_hombros_sentado",
            "3 press que solo extienden el codo hasta 147°.",
            secuencia(pose_press_frontal, v, tot),
            {"repeticiones": 3, "incompletas": 0, "codigos": ["PR_EXTENSION"], "puntaje": 85, "vista": "frontal"},
        )
    )

    v, tot = _linea_tiempo(5, [58, 58, 58], ida=1.3, sosten=0.3, vuelta=1.5, pausa=0.6)
    fx.append(
        fixture(
            "elevacion_lateral_baja",
            "elevacion_lateral",
            "3 elevaciones laterales que no llegan a la altura de los hombros.",
            secuencia(pose_elevacion_frontal, v, tot),
            {"repeticiones": 3, "incompletas": 0, "codigos": ["LA_ALTURA"], "puntaje": 85, "vista": "frontal"},
        )
    )

    v, tot = _linea_tiempo(0.0, [1.0, 1.0, 1.0], ida=1.2, sosten=0.4, vuelta=1.4, pausa=0.8)
    fx.append(
        fixture(
            "sentarse_pararse_correcto",
            "sentarse_pararse",
            "3 ciclos de sentarse y pararse vistos de costado.",
            secuencia(pose_sentarse_lateral, v, tot),
            {"repeticiones": 3, "incompletas": 0, "codigos": [], "puntaje": 100, "vista": "lateral"},
        )
    )

    fx.append(
        fixture(
            "sin_persona",
            "sentadilla",
            "Video sin ninguna persona detectada.",
            [{"t_ms": int(k * 1000 / FPS), "puntos": None, "mundo": None} for k in range(36)],
            {
                "repeticiones": 0,
                "incompletas": 0,
                "codigos": ["SIN_REPETICIONES", "CALIDAD_BAJA"],
                "puntaje": 0,
                "vista": None,
            },
        )
    )
    return fx


def main():
    for f in construir():
        ruta = DIR / f"{f['nombre']}.json"
        ruta.write_text(json.dumps(f, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        print(f"{ruta.name}: {len(f['fotogramas'])} fotogramas")


if __name__ == "__main__":
    main()
