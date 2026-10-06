"""Motor de análisis de movimiento (v2).

Uso típico:

    from motor import cargar_especificacion, Analizador
    spec = cargar_especificacion()
    analizador = Analizador(spec, "sentadilla")
    for fotograma in fotogramas:
        estado = analizador.procesar(fotograma)
    resultado = analizador.resultado()
"""

from .analizador import Analizador, EstadoFotograma, RepeticionEvaluada, analizar_fotogramas
from .especificacion import Especificacion, EspecificacionInvalida, cargar_especificacion, desde_dict
from .puntos import Fotograma

__all__ = [
    "Analizador",
    "EstadoFotograma",
    "RepeticionEvaluada",
    "analizar_fotogramas",
    "Especificacion",
    "EspecificacionInvalida",
    "cargar_especificacion",
    "desde_dict",
    "Fotograma",
]
