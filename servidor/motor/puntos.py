"""Representación de un fotograma con los 33 puntos corporales de BlazePose.

MediaPipe (servidor) y ML Kit (app) usan el mismo orden de 33 puntos, por lo que
el motor es idéntico en ambos lados.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional, Sequence

import numpy as np

NUM_PUNTOS = 33

NARIZ = 0
HOMBRO = (11, 12)  # (izquierdo, derecho)
CODO = (13, 14)
MUNECA = (15, 16)
CADERA = (23, 24)
RODILLA = (25, 26)
TOBILLO = (27, 28)

GRUPOS = {
    "cara": (NARIZ,),
    "hombros": HOMBRO,
    "codos": CODO,
    "munecas": MUNECA,
    "caderas": CADERA,
    "rodillas": RODILLA,
    "tobillos": TOBILLO,
}

# Puntos que se devuelven para revisar el movimiento (igual que la app).
INDICES_ESQUELETO = (0, 11, 12, 13, 14, 15, 16, 23, 24, 25, 26, 27, 28, 31, 32)

# Margen (normalizado) fuera de la imagen a partir del cual un punto se descarta.
MARGEN_FUERA_DE_CUADRO = 0.05


@dataclass
class Fotograma:
    """Puntos de un instante.

    imagen: matriz (33, 4) con x, y, z en píxeles (misma escala en ambos ejes) y
            la visibilidad [0, 1]. None si no se detectó una persona.
    mundo:  matriz (33, 3) opcional en metros (MediaPipe world landmarks). Si
            existe, los ángulos articulares se calculan en 3D con ella.
    """

    t_ms: int
    imagen: Optional[np.ndarray] = None
    mundo: Optional[np.ndarray] = None
    # Tamaño del cuadro en píxeles (para normalizar el esqueleto que se devuelve).
    ancho: Optional[int] = None
    alto: Optional[int] = None

    @classmethod
    def desde_listas(
        cls,
        t_ms: int,
        puntos: Optional[Sequence[Sequence[float]]],
        mundo: Optional[Sequence[Sequence[float]]] = None,
    ) -> "Fotograma":
        imagen = None
        if puntos is not None:
            imagen = np.zeros((NUM_PUNTOS, 4), dtype=np.float64)
            for i, p in enumerate(puntos):
                imagen[i, : len(p)] = p
                if len(p) < 4:
                    imagen[i, 3] = 1.0
        mundo_np = np.asarray(mundo, dtype=np.float64) if mundo is not None else None
        return cls(t_ms=int(t_ms), imagen=imagen, mundo=mundo_np)

    @classmethod
    def desde_mediapipe(cls, t_ms: int, landmarks, world_landmarks, ancho: int, alto: int) -> "Fotograma":
        """Convierte landmarks normalizados de MediaPipe a píxeles.

        Importante: x e y normalizados tienen escalas distintas (ancho vs alto);
        sin esta conversión los ángulos 2D se deforman según la relación de aspecto.
        """
        imagen = np.zeros((NUM_PUNTOS, 4), dtype=np.float64)
        for i, lm in enumerate(landmarks[:NUM_PUNTOS]):
            vis = float(lm.visibility) if lm.visibility is not None else 1.0
            fuera = not (
                -MARGEN_FUERA_DE_CUADRO <= lm.x <= 1 + MARGEN_FUERA_DE_CUADRO
                and -MARGEN_FUERA_DE_CUADRO <= lm.y <= 1 + MARGEN_FUERA_DE_CUADRO
            )
            imagen[i] = (lm.x * ancho, lm.y * alto, lm.z * ancho, 0.0 if fuera else vis)
        mundo = None
        if world_landmarks:
            mundo = np.array([(w.x, w.y, w.z) for w in world_landmarks[:NUM_PUNTOS]], dtype=np.float64)
        return cls(t_ms=int(t_ms), imagen=imagen, mundo=mundo, ancho=ancho, alto=alto)
