"""Cálculo de métricas biomecánicas por fotograma.

Reglas:
- Ángulos articulares en 3D (puntos 'mundo' si existen; si no, x/y/z en píxeles).
- Medidas de alineación en 2D (píxeles), normalizadas por el tamaño corporal
  (ancho de cadera o largo de tronco) para no depender de la distancia a la cámara.
- Un punto con visibilidad menor al mínimo se considera ausente: la métrica que
  lo necesita queda en None y no se usa (antes se usaban puntos no visibles).
"""

from __future__ import annotations

import math
from typing import Dict, List, Optional, Sequence

import numpy as np

from .geometria import (
    angulo_articular,
    distancia,
    inclinacion_desde_horizontal,
    inclinacion_desde_vertical,
)
from .puntos import CADERA, CODO, GRUPOS, HOMBRO, MUNECA, NARIZ, RODILLA, TOBILLO, Fotograma

LADOS = ("izq", "der")
BASES_BILATERALES = ("rodilla", "cadera", "codo", "hombro")

# Vista de cámara
FRONTAL = "frontal"
LATERAL = "lateral"
OBLICUA = "oblicua"


def _limpio(x: float) -> Optional[float]:
    return None if x is None or math.isnan(x) else float(x)


class _Contexto:
    def __init__(self, f: Fotograma, vmin: float):
        self.img = f.imagen
        self.tres_d = f.mundo if f.mundo is not None else (f.imagen[:, :3] if f.imagen is not None else None)
        self.vmin = vmin

    def visible(self, *indices: int) -> bool:
        return all(self.img[i, 3] >= self.vmin for i in indices)

    def p2(self, i: int) -> np.ndarray:
        return self.img[i, :2]

    def p3(self, i: int) -> np.ndarray:
        return self.tres_d[i]


def _largo_tronco(c: _Contexto) -> Optional[float]:
    if c.visible(*HOMBRO, *CADERA):
        hombros = (c.p2(HOMBRO[0]) + c.p2(HOMBRO[1])) / 2
        caderas = (c.p2(CADERA[0]) + c.p2(CADERA[1])) / 2
        largo = distancia(hombros, caderas)
        return largo if largo > 1e-6 else None
    for k in (0, 1):
        if c.visible(HOMBRO[k], CADERA[k]):
            largo = distancia(c.p2(HOMBRO[k]), c.p2(CADERA[k]))
            return largo if largo > 1e-6 else None
    return None


def _referencia_tronco(c: _Contexto):
    """Puntos (cadera, hombro) para medir la inclinación del tronco."""
    if c.visible(*HOMBRO, *CADERA):
        return (c.p2(CADERA[0]) + c.p2(CADERA[1])) / 2, (c.p2(HOMBRO[0]) + c.p2(HOMBRO[1])) / 2
    for k in (0, 1):
        if c.visible(HOMBRO[k], CADERA[k]):
            return c.p2(CADERA[k]), c.p2(HOMBRO[k])
    return None


def _valgo(c: _Contexto, k: int, tronco: Optional[float]) -> Optional[float]:
    """Desplazamiento medial de la rodilla respecto de la línea cadera-tobillo.

    Positivo = rodilla hacia la línea media (valgo). Normalizado por el ancho de
    cadera. Solo tiene sentido con vista frontal.
    """
    otra = 1 - k
    if not c.visible(CADERA[k], RODILLA[k], TOBILLO[k], CADERA[otra]):
        return None
    cadera, rodilla, tobillo = c.p2(CADERA[k]), c.p2(RODILLA[k]), c.p2(TOBILLO[k])
    otra_cadera = c.p2(CADERA[otra])
    ancho = abs(float(cadera[0] - otra_cadera[0]))
    if ancho < 1e-6 or (tronco is not None and ancho < 0.15 * tronco):
        return None  # caderas superpuestas: vista lateral, no se puede medir
    dy = float(tobillo[1] - cadera[1])
    if abs(dy) < 1e-6:
        return None
    t = float(rodilla[1] - cadera[1]) / dy
    linea_x = float(cadera[0]) + t * float(tobillo[0] - cadera[0])
    medio_x = float(cadera[0] + otra_cadera[0]) / 2
    direccion = 1.0 if medio_x >= linea_x else -1.0
    return (float(rodilla[0]) - linea_x) * direccion / ancho


def calcular_metricas(f: Fotograma, vmin: float) -> Dict[str, Optional[float]]:
    m: Dict[str, Optional[float]] = {}
    if f.imagen is None:
        return m
    c = _Contexto(f, vmin)
    tronco = _largo_tronco(c)

    for k, lado in enumerate(LADOS):
        h, co, mu, ca, r, t = HOMBRO[k], CODO[k], MUNECA[k], CADERA[k], RODILLA[k], TOBILLO[k]
        m[f"rodilla_{lado}"] = _limpio(angulo_articular(c.p3(ca), c.p3(r), c.p3(t))) if c.visible(ca, r, t) else None
        m[f"cadera_{lado}"] = _limpio(angulo_articular(c.p3(h), c.p3(ca), c.p3(r))) if c.visible(h, ca, r) else None
        m[f"codo_{lado}"] = _limpio(angulo_articular(c.p3(h), c.p3(co), c.p3(mu))) if c.visible(h, co, mu) else None
        m[f"hombro_{lado}"] = _limpio(angulo_articular(c.p3(co), c.p3(h), c.p3(ca))) if c.visible(co, h, ca) else None
        m[f"valgo_{lado}"] = _valgo(c, k, tronco)

    for base in BASES_BILATERALES:
        valores = [v for v in (m[f"{base}_izq"], m[f"{base}_der"]) if v is not None]
        m[f"{base}_promedio"] = sum(valores) / len(valores) if valores else None
        m[f"{base}_min"] = min(valores) if valores else None
        m[f"{base}_max"] = max(valores) if valores else None

    valgos = [v for v in (m["valgo_izq"], m["valgo_der"]) if v is not None]
    m["valgo_max"] = max(valgos) if valgos else None
    # Pierna delantera (zancada) = la de menor ángulo de rodilla.
    ri, rd = m["rodilla_izq"], m["rodilla_der"]
    if ri is not None and rd is not None:
        m["valgo_delantera"] = m["valgo_izq"] if ri <= rd else m["valgo_der"]
    else:
        m["valgo_delantera"] = m["valgo_izq"] if ri is not None else (m["valgo_der"] if rd is not None else None)

    ref = _referencia_tronco(c)
    m["tronco_inclinacion"] = _limpio(inclinacion_desde_vertical(ref[0], ref[1])) if ref else None
    m["pelvis_inclinacion"] = (
        _limpio(inclinacion_desde_horizontal(c.p2(CADERA[0]), c.p2(CADERA[1]))) if c.visible(*CADERA) else None
    )
    m["hombros_inclinacion"] = (
        _limpio(inclinacion_desde_horizontal(c.p2(HOMBRO[0]), c.p2(HOMBRO[1]))) if c.visible(*HOMBRO) else None
    )

    munecas = [c.p2(i)[1] for i in MUNECA if c.visible(i)]
    if c.visible(NARIZ) and munecas and tronco:
        m["munecas_sobre_nariz"] = (float(c.p2(NARIZ)[1]) - float(sum(munecas) / len(munecas))) / tronco
    else:
        m["munecas_sobre_nariz"] = None
    return m


def detectar_vista(f: Fotograma, vmin: float, umbral_frontal: float, umbral_lateral: float) -> Optional[str]:
    """Clasifica la vista según la razón ancho de hombros / largo de tronco (2D)."""
    if f.imagen is None:
        return None
    c = _Contexto(f, vmin)
    tronco = _largo_tronco(c)
    if tronco is None:
        return None
    if not c.visible(*HOMBRO):
        return LATERAL
    razon = distancia(c.p2(HOMBRO[0]), c.p2(HOMBRO[1])) / tronco
    if razon >= umbral_frontal:
        return FRONTAL
    if razon <= umbral_lateral:
        return LATERAL
    return OBLICUA


def grupos_faltantes(f: Fotograma, vmin: float, requeridos: Sequence[str]) -> List[str]:
    """Grupos requeridos sin ningún lado visible (para explicar por qué no se evalúa)."""
    if f.imagen is None:
        return list(requeridos)
    faltan = []
    for g in requeridos:
        if not any(f.imagen[i, 3] >= vmin for i in GRUPOS[g]):
            faltan.append(g)
    return faltan
