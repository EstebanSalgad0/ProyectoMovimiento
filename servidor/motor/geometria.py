"""Utilidades geométricas del motor."""

from __future__ import annotations

import math

import numpy as np


def angulo_vectores(v1: np.ndarray, v2: np.ndarray) -> float:
    """Ángulo en grados entre dos vectores (2D o 3D)."""
    n1 = float(np.linalg.norm(v1))
    n2 = float(np.linalg.norm(v2))
    if n1 < 1e-9 or n2 < 1e-9:
        return float("nan")
    coseno = float(np.dot(v1, v2)) / (n1 * n2)
    return math.degrees(math.acos(max(-1.0, min(1.0, coseno))))


def angulo_articular(a: np.ndarray, b: np.ndarray, c: np.ndarray) -> float:
    """Ángulo interior en el punto b formado por a-b-c (180 = extendido)."""
    return angulo_vectores(a - b, c - b)


def inclinacion_desde_vertical(inferior: np.ndarray, superior: np.ndarray) -> float:
    """Grados entre el segmento inferior→superior y la vertical de la imagen (y hacia abajo)."""
    dx = float(superior[0] - inferior[0])
    dy = float(superior[1] - inferior[1])
    if abs(dx) < 1e-9 and abs(dy) < 1e-9:
        return float("nan")
    return math.degrees(math.atan2(abs(dx), -dy))


def inclinacion_desde_horizontal(a: np.ndarray, b: np.ndarray) -> float:
    """Grados [0, 90] entre la línea a-b y la horizontal de la imagen."""
    dx = abs(float(b[0] - a[0]))
    dy = abs(float(b[1] - a[1]))
    if dx < 1e-9 and dy < 1e-9:
        return float("nan")
    return math.degrees(math.atan2(dy, dx))


def distancia(a: np.ndarray, b: np.ndarray) -> float:
    return float(np.linalg.norm(a - b))


def redondear(x: float) -> int:
    """Redondeo 'mitad hacia arriba', idéntico al de la app (Dart).

    Python usa redondeo bancario en round(); para que ambos motores entreguen el
    mismo puntaje se usa floor(x + 0.5).
    """
    return int(math.floor(x + 0.5))
