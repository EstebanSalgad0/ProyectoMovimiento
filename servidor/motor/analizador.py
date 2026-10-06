"""Orquestador del análisis: métricas → suavizado → repeticiones → evaluación.

Funciona fotograma a fotograma, por lo que sirve tanto para videos completos
(servidor) como para la cámara en vivo (script de webcam). La app Flutter tiene
un port 1:1 de este archivo en lib/motor/.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Sequence

from .especificacion import Especificacion, Verificacion
from .filtros import FiltroOneEuro
from .geometria import redondear
from .metricas import calcular_metricas, detectar_vista, grupos_faltantes
from .puntos import Fotograma
from .repeticiones import DetectorRepeticiones, EventoRepeticion

VERSION_RESULTADO = "2.0"
ORDEN_SEVERIDAD = {"alta": 0, "moderada": 1, "leve": 2, "info": 3}
NOMBRES_GRUPO = {
    "cara": "la cara",
    "hombros": "los hombros",
    "codos": "los codos",
    "munecas": "las muñecas",
    "caderas": "las caderas",
    "rodillas": "las rodillas",
    "tobillos": "los tobillos",
}
NOMBRES_VISTA = {"frontal": "de frente", "lateral": "de costado", "oblicua": "en diagonal"}


def _mayoria(valores: Sequence[str]) -> Optional[str]:
    """Valor más frecuente; en empate gana el primero que apareció (igual que en Dart)."""
    conteo: Dict[str, int] = {}
    for v in valores:
        conteo[v] = conteo.get(v, 0) + 1
    mejor, mejor_n = None, 0
    for v, n in conteo.items():
        if n > mejor_n:
            mejor, mejor_n = v, n
    return mejor


def _r(x: Optional[float], dec: int = 1) -> Optional[float]:
    return None if x is None else round(float(x), dec)


@dataclass
class FotogramaProcesado:
    t_ms: int
    metricas: Dict[str, Optional[float]]
    vista: Optional[str]
    valido: bool
    faltantes: List[str]


@dataclass
class Evaluacion:
    codigo: str
    valor: float
    falla: bool


@dataclass
class RepeticionEvaluada:
    numero: int
    inicio_ms: int
    pico_ms: int
    fin_ms: int
    excentrica_s: float
    concentrica_s: float
    valor_pico: float
    valor_reposo: float
    vista: Optional[str]
    puntaje: int
    evaluaciones: List[Evaluacion] = field(default_factory=list)
    omitidas_por_vista: List[str] = field(default_factory=list)

    @property
    def duracion_s(self) -> float:
        return (self.fin_ms - self.inicio_ms) / 1000.0

    @property
    def rango(self) -> float:
        return abs(self.valor_reposo - self.valor_pico)

    @property
    def fallos(self) -> List[str]:
        return [e.codigo for e in self.evaluaciones if e.falla]

    def a_dict(self) -> Dict[str, Any]:
        return {
            "numero": self.numero,
            "inicio_ms": self.inicio_ms,
            "pico_ms": self.pico_ms,
            "fin_ms": self.fin_ms,
            "duracion_s": _r(self.duracion_s, 2),
            "excentrica_s": _r(self.excentrica_s, 2),
            "concentrica_s": _r(self.concentrica_s, 2),
            "valor_pico": _r(self.valor_pico),
            "valor_reposo": _r(self.valor_reposo),
            "rango": _r(self.rango),
            "vista": self.vista,
            "puntaje": self.puntaje,
            "fallos": self.fallos,
            "valores": {e.codigo: _r(e.valor, 2) for e in self.evaluaciones},
        }


@dataclass
class EstadoFotograma:
    """Estado tras procesar un fotograma (útil para feedback en vivo)."""

    valido: bool
    valor_senal: Optional[float]
    fase: str
    repeticiones: int
    incompletas: int
    faltantes: List[str]
    nueva_repeticion: Optional[RepeticionEvaluada] = None
    repeticion_incompleta: bool = False


class Analizador:
    def __init__(self, especificacion: Especificacion, ejercicio_id: str):
        self.spec = especificacion
        self.ej = especificacion.ejercicio(ejercicio_id)
        self.g = especificacion.globales
        self.detector = DetectorRepeticiones(self.ej.senal, self.g.duracion_minima_rep_s)
        self.filtros: Dict[str, FiltroOneEuro] = {}
        self.fotogramas: List[FotogramaProcesado] = []
        self.repeticiones: List[RepeticionEvaluada] = []
        self.incompletas = 0

    # ------------------------------------------------------------------ proceso
    def _suavizar(self, metricas: Dict[str, Optional[float]], t_s: float) -> Dict[str, Optional[float]]:
        salida: Dict[str, Optional[float]] = {}
        for nombre, valor in metricas.items():
            if valor is None:
                salida[nombre] = None
                continue
            filtro = self.filtros.get(nombre)
            if filtro is None:
                filtro = FiltroOneEuro(**self.g.suavizado)
                self.filtros[nombre] = filtro
            elif filtro.ultimo_t is not None and t_s - filtro.ultimo_t > self.g.reinicio_filtro_s:
                filtro.reiniciar()
            salida[nombre] = filtro(valor, t_s)
        return salida

    def procesar(self, f: Fotograma) -> EstadoFotograma:
        t_s = f.t_ms / 1000.0
        vmin = self.g.visibilidad_minima
        metricas = self._suavizar(calcular_metricas(f, vmin), t_s)
        vista = detectar_vista(f, vmin, self.g.umbral_frontal, self.g.umbral_lateral)
        senal = metricas.get(self.ej.senal.metrica)
        valido = senal is not None
        faltantes = [] if valido else grupos_faltantes(f, vmin, self.ej.puntos_requeridos)
        idx = len(self.fotogramas)
        self.fotogramas.append(FotogramaProcesado(f.t_ms, metricas, vista, valido, faltantes))

        evento = self.detector.actualizar(idx, t_s, senal)
        nueva: Optional[RepeticionEvaluada] = None
        incompleta = False
        if evento is not None:
            if evento.valida:
                nueva = self._evaluar(evento)
                self.repeticiones.append(nueva)
            else:
                self.incompletas += 1
                incompleta = True
        return EstadoFotograma(
            valido=valido,
            valor_senal=senal,
            fase=self.detector.fase,
            repeticiones=len(self.repeticiones),
            incompletas=self.incompletas,
            faltantes=faltantes,
            nueva_repeticion=nueva,
            repeticion_incompleta=incompleta,
        )

    # --------------------------------------------------------------- evaluación
    def _valor(self, v: Verificacion, ventana, pico, reposo, ev: EventoRepeticion) -> Optional[float]:
        if v.tipo in ("pico_max", "pico_min"):
            return pico.metricas.get(v.metrica)
        if v.tipo in ("reposo_min", "reposo_max"):
            return reposo.metricas.get(v.metrica)
        if v.tipo in ("rep_max", "rep_rango_max"):
            valores = [fr.metricas.get(v.metrica) for fr in ventana]
            valores = [x for x in valores if x is not None]
            if not valores:
                return None
            if v.tipo == "rep_max":
                return max(valores)
            return max(valores) - min(valores) if len(valores) >= 2 else None
        if v.tipo == "asimetria_pico":
            a = pico.metricas.get(v.metricas[0])
            b = pico.metricas.get(v.metricas[1])
            return abs(a - b) if a is not None and b is not None else None
        if v.tipo == "duracion_min":
            if v.fase == "excentrica":
                return ev.t_pico_s - ev.t_inicio_s
            if v.fase == "concentrica":
                return ev.t_fin_s - ev.t_pico_s
            return ev.t_fin_s - ev.t_inicio_s
        return None

    def _evaluar(self, ev: EventoRepeticion) -> RepeticionEvaluada:
        ventana = self.fotogramas[ev.idx_inicio : ev.idx_fin + 1]
        pico = self.fotogramas[ev.idx_pico]
        reposo = self.fotogramas[ev.idx_reposo]
        vista = _mayoria([fr.vista for fr in ventana if fr.vista])
        evaluaciones: List[Evaluacion] = []
        omitidas: List[str] = []
        penalizacion = 0.0
        for v in self.ej.verificaciones:
            if v.vistas and vista not in v.vistas:
                omitidas.append(v.codigo)
                continue
            valor = self._valor(v, ventana, pico, reposo, ev)
            if valor is None or math.isnan(valor):
                continue
            falla = valor < v.umbral if v.falla_por_menor else valor > v.umbral
            evaluaciones.append(Evaluacion(v.codigo, valor, falla))
            if falla:
                penalizacion += self.g.penalizacion.get(v.severidad, 0.0)
        metrica = self.ej.senal.metrica
        return RepeticionEvaluada(
            numero=len(self.repeticiones) + 1,
            inicio_ms=self.fotogramas[ev.idx_inicio].t_ms,
            pico_ms=pico.t_ms,
            fin_ms=self.fotogramas[ev.idx_fin].t_ms,
            excentrica_s=ev.t_pico_s - ev.t_inicio_s,
            concentrica_s=ev.t_fin_s - ev.t_pico_s,
            valor_pico=pico.metricas[metrica],
            valor_reposo=reposo.metricas[metrica],
            vista=vista,
            puntaje=max(0, redondear(100.0 - penalizacion)),
            evaluaciones=evaluaciones,
            omitidas_por_vista=omitidas,
        )

    # ---------------------------------------------------------------- resultado
    def puntaje(self) -> int:
        if not self.repeticiones:
            return 0
        base = sum(r.puntaje for r in self.repeticiones) / len(self.repeticiones)
        castigo = min(self.g.penalizacion_incompleta_max, self.incompletas * self.g.penalizacion_incompleta)
        return max(0, min(100, redondear(base - castigo)))

    def _hallazgos_y_aciertos(self, porcentaje_validos: float, vista_dominante: Optional[str]):
        hallazgos: List[Dict[str, Any]] = []
        aciertos: List[Dict[str, Any]] = []
        evaluadas_alguna_vez = set()
        for v in self.ej.verificaciones:
            evaluadas = [(r.numero, e) for r in self.repeticiones for e in r.evaluaciones if e.codigo == v.codigo]
            if not evaluadas:
                continue
            evaluadas_alguna_vez.add(v.codigo)
            fallidas = [(n, e) for n, e in evaluadas if e.falla]
            if fallidas:
                valores = [e.valor for _, e in fallidas]
                peor = min(valores) if v.falla_por_menor else max(valores)
                hallazgos.append(
                    {
                        "codigo": v.codigo,
                        "severidad": v.severidad,
                        "zona": v.zona,
                        "titulo": v.titulo,
                        "mensaje": v.mensaje,
                        "repeticiones": [n for n, _ in fallidas],
                        "total_evaluadas": len(evaluadas),
                        "valor": _r(peor, 2),
                        "umbral": v.umbral,
                    }
                )
            elif v.mensaje_ok:
                aciertos.append({"codigo": v.codigo, "zona": v.zona, "mensaje": v.mensaje_ok})

        if self.incompletas:
            n = self.incompletas
            hallazgos.append(
                {
                    "codigo": "REPETICIONES_INCOMPLETAS",
                    "severidad": "leve",
                    "zona": "general",
                    "titulo": f"{n} repetición incompleta" if n == 1 else f"{n} repeticiones incompletas",
                    "mensaje": "Algunas repeticiones no alcanzaron el rango mínimo de movimiento.",
                    "repeticiones": [],
                    "total_evaluadas": len(self.repeticiones) + n,
                }
            )
        if not self.repeticiones:
            hallazgos.append(
                {
                    "codigo": "SIN_REPETICIONES",
                    "severidad": "info",
                    "zona": "general",
                    "titulo": "No se detectaron repeticiones completas",
                    "mensaje": "Haz el movimiento completo y verifica que todo tu cuerpo se vea en la cámara.",
                    "repeticiones": [],
                }
            )
        if porcentaje_validos < self.g.porcentaje_validos_minimo:
            grupo = _mayoria([g for fr in self.fotogramas for g in fr.faltantes])
            detalle = f" En la mayor parte no se ven {NOMBRES_GRUPO.get(grupo, grupo)}." if grupo else ""
            hallazgos.append(
                {
                    "codigo": "CALIDAD_BAJA",
                    "severidad": "info",
                    "zona": "general",
                    "titulo": "Cuerpo poco visible",
                    "mensaje": "Gran parte del registro no se pudo evaluar."
                    + detalle
                    + " Aléjate de la cámara y mejora la iluminación.",
                    "repeticiones": [],
                }
            )
        if self.repeticiones and vista_dominante and vista_dominante != self.ej.vista_recomendada:
            nunca = [
                v.titulo.lower()
                for v in self.ej.verificaciones
                if v.codigo not in evaluadas_alguna_vez and v.vistas and self.ej.vista_recomendada in v.vistas
            ]
            if nunca:
                vista_txt = NOMBRES_VISTA.get(self.ej.vista_recomendada, "")
                hallazgos.append(
                    {
                        "codigo": "VISTA_RECOMENDADA",
                        "severidad": "info",
                        "zona": "general",
                        "titulo": f"Grábate {vista_txt} para un análisis completo",
                        "mensaje": "Con esta vista no se pudo evaluar: " + ", ".join(nunca) + ".",
                        "repeticiones": [],
                    }
                )
        hallazgos.sort(key=lambda h: ORDEN_SEVERIDAD.get(h["severidad"], 9))
        return hallazgos, aciertos

    def _serie(self) -> Dict[str, Any]:
        s = self.ej.senal
        total = len(self.fotogramas)
        paso = max(1, math.ceil(total / self.g.puntos_serie_max)) if total else 1
        muestra = self.fotogramas[::paso]
        return {
            "metrica": s.metrica,
            "nombre": s.nombre,
            "unidad": s.unidad,
            "t_ms": [fr.t_ms for fr in muestra],
            "valores": [_r(fr.metricas.get(s.metrica)) for fr in muestra],
        }

    def resultado(self) -> Dict[str, Any]:
        total = len(self.fotogramas)
        validos = sum(1 for fr in self.fotogramas if fr.valido)
        porcentaje = validos / total if total else 0.0
        vista = _mayoria([fr.vista for fr in self.fotogramas if fr.valido and fr.vista])
        hallazgos, aciertos = self._hallazgos_y_aciertos(porcentaje, vista)
        reps = self.repeticiones
        duracion = (self.fotogramas[-1].t_ms - self.fotogramas[0].t_ms) / 1000.0 if total > 1 else 0.0

        metricas: Dict[str, float] = {
            "repeticiones": float(len(reps)),
            "repeticiones_incompletas": float(self.incompletas),
            "duracion_s": round(duracion, 1),
            "porcentaje_validos": round(porcentaje * 100, 1),
        }
        if reps:
            picos = [r.valor_pico for r in reps]
            descendente = self.ej.senal.direccion == "descendente"
            metricas.update(
                {
                    "pico_promedio": round(sum(picos) / len(picos), 1),
                    "pico_mejor": round(min(picos) if descendente else max(picos), 1),
                    "rango_promedio": round(sum(r.rango for r in reps) / len(reps), 1),
                    "duracion_rep_promedio_s": round(sum(r.duracion_s for r in reps) / len(reps), 2),
                    "excentrica_promedio_s": round(sum(r.excentrica_s for r in reps) / len(reps), 2),
                    "concentrica_promedio_s": round(sum(r.concentrica_s for r in reps) / len(reps), 2),
                }
            )

        feedback = [f"{h['titulo']}: {h['mensaje']}" for h in hallazgos] + [a["mensaje"] for a in aciertos]
        return {
            "version": VERSION_RESULTADO,
            "especificacion": self.spec.version,
            "ejercicio": self.ej.id,
            "nombre_ejercicio": self.ej.nombre,
            "puntaje": self.puntaje(),
            "feedback": feedback,
            "metricas": metricas,
            "repeticiones": [r.a_dict() for r in reps],
            "hallazgos": hallazgos,
            "aciertos": aciertos,
            "serie": self._serie(),
            "calidad": {
                "fotogramas": total,
                "fotogramas_validos": validos,
                "porcentaje_validos": round(porcentaje * 100, 1),
                "vista": vista,
                "confianza": round(porcentaje, 2),
            },
            "duracion_s": round(duracion, 1),
        }


def analizar_fotogramas(especificacion: Especificacion, ejercicio_id: str, fotogramas) -> Dict[str, Any]:
    analizador = Analizador(especificacion, ejercicio_id)
    for f in fotogramas:
        analizador.procesar(f)
    return analizador.resultado()
