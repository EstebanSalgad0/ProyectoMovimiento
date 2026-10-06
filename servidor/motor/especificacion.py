"""Carga y validación de la especificación compartida de ejercicios.

La especificación (compartido/ejercicios.json) es la fuente única de umbrales,
códigos de hallazgo y mensajes. La app Flutter usa una copia idéntica para el
análisis en tiempo real, así ambos motores evalúan con las mismas reglas.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

RUTA_POR_DEFECTO = Path(__file__).resolve().parents[2] / "compartido" / "ejercicios.json"

TIPOS_VERIFICACION = {
    "pico_max",
    "pico_min",
    "rep_max",
    "rep_rango_max",
    "reposo_min",
    "reposo_max",
    "asimetria_pico",
    "duracion_min",
}
TIPOS_QUE_FALLAN_POR_MENOR = {"pico_min", "reposo_min", "duracion_min"}
SEVERIDADES = ("info", "leve", "moderada", "alta")
FASES_DURACION = {"excentrica", "concentrica", "total"}
GRUPOS_VALIDOS = {"cara", "hombros", "codos", "munecas", "caderas", "rodillas", "tobillos"}


class EspecificacionInvalida(ValueError):
    pass


@dataclass(frozen=True)
class Senal:
    metrica: str
    nombre: str
    unidad: str
    direccion: str
    inicio: float
    fin: float
    minimo_rep: float

    @property
    def signo(self) -> int:
        return 1 if self.direccion == "ascendente" else -1


@dataclass(frozen=True)
class Verificacion:
    codigo: str
    tipo: str
    umbral: float
    severidad: str
    zona: str
    titulo: str
    mensaje: str
    metrica: Optional[str] = None
    metricas: Optional[Tuple[str, str]] = None
    fase: Optional[str] = None
    vistas: Optional[Tuple[str, ...]] = None
    mensaje_ok: Optional[str] = None

    @property
    def falla_por_menor(self) -> bool:
        return self.tipo in TIPOS_QUE_FALLAN_POR_MENOR


@dataclass(frozen=True)
class Ejercicio:
    id: str
    nombre: str
    vista_recomendada: str
    puntos_requeridos: Tuple[str, ...]
    fases: Dict[str, str]
    senal: Senal
    verificaciones: Tuple[Verificacion, ...]
    datos: Dict[str, Any] = field(repr=False, default_factory=dict)


@dataclass(frozen=True)
class ParametrosGlobales:
    visibilidad_minima: float
    fps_analisis: float
    suavizado: Dict[str, float]
    reinicio_filtro_s: float
    umbral_frontal: float
    umbral_lateral: float
    penalizacion: Dict[str, float]
    penalizacion_incompleta: float
    penalizacion_incompleta_max: float
    porcentaje_validos_minimo: float
    duracion_minima_rep_s: float
    puntos_serie_max: int


@dataclass(frozen=True)
class Especificacion:
    version: str
    globales: ParametrosGlobales
    ejercicios: Dict[str, Ejercicio]
    crudo: Dict[str, Any] = field(repr=False, default_factory=dict)

    def ejercicio(self, ejercicio_id: str) -> Ejercicio:
        try:
            return self.ejercicios[ejercicio_id]
        except KeyError as exc:
            raise KeyError(f"Ejercicio no soportado: {ejercicio_id}") from exc

    @property
    def ids(self) -> List[str]:
        return list(self.ejercicios.keys())


def _validar_senal(ej_id: str, s: Senal) -> None:
    if s.direccion not in ("ascendente", "descendente"):
        raise EspecificacionInvalida(f"{ej_id}: dirección inválida '{s.direccion}'")
    # Con la señal orientada (signo), debe cumplirse fin < inicio < minimo_rep.
    fin, inicio, minimo = s.signo * s.fin, s.signo * s.inicio, s.signo * s.minimo_rep
    if not (fin < inicio < minimo):
        raise EspecificacionInvalida(
            f"{ej_id}: umbrales de señal incoherentes (fin={s.fin}, inicio={s.inicio}, minimo_rep={s.minimo_rep})"
        )


def _crear_verificacion(ej_id: str, datos: Dict[str, Any]) -> Verificacion:
    tipo = datos.get("tipo")
    if tipo not in TIPOS_VERIFICACION:
        raise EspecificacionInvalida(f"{ej_id}: tipo de verificación desconocido '{tipo}'")
    if datos.get("severidad") not in SEVERIDADES:
        raise EspecificacionInvalida(f"{ej_id}/{datos.get('codigo')}: severidad inválida")
    metricas = datos.get("metricas")
    if tipo == "asimetria_pico":
        if not metricas or len(metricas) != 2:
            raise EspecificacionInvalida(f"{ej_id}/{datos['codigo']}: asimetria_pico requiere 2 métricas")
    elif tipo == "duracion_min":
        if datos.get("fase") not in FASES_DURACION:
            raise EspecificacionInvalida(f"{ej_id}/{datos['codigo']}: fase de duración inválida")
    elif not datos.get("metrica"):
        raise EspecificacionInvalida(f"{ej_id}/{datos['codigo']}: falta 'metrica'")
    vistas = datos.get("vistas")
    return Verificacion(
        codigo=datos["codigo"],
        tipo=tipo,
        umbral=float(datos["umbral"]),
        severidad=datos["severidad"],
        zona=datos.get("zona", "general"),
        titulo=datos["titulo"],
        mensaje=datos["mensaje"],
        metrica=datos.get("metrica"),
        metricas=tuple(metricas) if metricas else None,
        fase=datos.get("fase"),
        vistas=tuple(vistas) if vistas else None,
        mensaje_ok=datos.get("mensaje_ok"),
    )


def desde_dict(crudo: Dict[str, Any]) -> Especificacion:
    g = crudo["parametros_globales"]
    globales = ParametrosGlobales(
        visibilidad_minima=float(g["visibilidad_minima"]),
        fps_analisis=float(g["fps_analisis"]),
        suavizado={k: float(v) for k, v in g["suavizado"].items()},
        reinicio_filtro_s=float(g["reinicio_filtro_s"]),
        umbral_frontal=float(g["vista"]["umbral_frontal"]),
        umbral_lateral=float(g["vista"]["umbral_lateral"]),
        penalizacion={k: float(v) for k, v in g["penalizacion"].items()},
        penalizacion_incompleta=float(g["penalizacion_incompleta"]),
        penalizacion_incompleta_max=float(g["penalizacion_incompleta_max"]),
        porcentaje_validos_minimo=float(g["porcentaje_validos_minimo"]),
        duracion_minima_rep_s=float(g["duracion_minima_rep_s"]),
        puntos_serie_max=int(g["puntos_serie_max"]),
    )
    ejercicios: Dict[str, Ejercicio] = {}
    for e in crudo["ejercicios"]:
        s = e["senal"]
        senal = Senal(
            metrica=s["metrica"],
            nombre=s["nombre"],
            unidad=s.get("unidad", ""),
            direccion=s["direccion"],
            inicio=float(s["inicio"]),
            fin=float(s["fin"]),
            minimo_rep=float(s["minimo_rep"]),
        )
        _validar_senal(e["id"], senal)
        grupos = tuple(e.get("puntos_requeridos", ()))
        desconocidos = set(grupos) - GRUPOS_VALIDOS
        if desconocidos:
            raise EspecificacionInvalida(f"{e['id']}: grupos de puntos desconocidos {desconocidos}")
        codigos = [v["codigo"] for v in e["verificaciones"]]
        if len(codigos) != len(set(codigos)):
            raise EspecificacionInvalida(f"{e['id']}: códigos de verificación duplicados")
        ejercicios[e["id"]] = Ejercicio(
            id=e["id"],
            nombre=e["nombre"],
            vista_recomendada=e.get("vista_recomendada", "frontal"),
            puntos_requeridos=grupos,
            fases=dict(e.get("fases", {"ida": "Ida", "vuelta": "Vuelta"})),
            senal=senal,
            verificaciones=tuple(_crear_verificacion(e["id"], v) for v in e["verificaciones"]),
            datos=e,
        )
    return Especificacion(version=crudo["version"], globales=globales, ejercicios=ejercicios, crudo=crudo)


def cargar_especificacion(ruta: Optional[Path] = None) -> Especificacion:
    ruta = Path(ruta) if ruta else RUTA_POR_DEFECTO
    with open(ruta, encoding="utf-8") as f:
        return desde_dict(json.load(f))
