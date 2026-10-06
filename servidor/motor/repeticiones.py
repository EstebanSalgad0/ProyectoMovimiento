"""Detección de repeticiones con máquina de estados e histéresis.

La señal principal (p. ej. ángulo de rodilla) se orienta con 'signo' para que
el movimiento siempre "suba": d = signo * valor. Así la misma lógica sirve para
ejercicios descendentes (sentadilla) y ascendentes (press).

    reposo --(d > inicio)--> movimiento --(d < fin)--> reposo  => repetición

Una repetición es válida si su pico alcanzó 'minimo_rep'; si no, se cuenta como
incompleta. Movimientos más cortos que 'duracion_minima_s' se descartan (ruido).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

from .especificacion import Senal

REPOSO = "reposo"
IDA = "ida"
VUELTA = "vuelta"

# Margen (en unidades de la señal) para pasar de 'ida' a 'vuelta'.
HISTERESIS_FASE = 4.0


@dataclass(frozen=True)
class EventoRepeticion:
    valida: bool
    idx_reposo: int
    idx_inicio: int
    idx_pico: int
    idx_fin: int
    t_inicio_s: float
    t_pico_s: float
    t_fin_s: float


class DetectorRepeticiones:
    def __init__(self, senal: Senal, duracion_minima_s: float):
        self.signo = senal.signo
        self.inicio = self.signo * senal.inicio
        self.fin = self.signo * senal.fin
        self.minimo = self.signo * senal.minimo_rep
        self.duracion_minima_s = duracion_minima_s
        self.estado = REPOSO
        self._d_actual: Optional[float] = None
        self._d_reposo: Optional[float] = None
        self._idx_reposo = 0
        self._idx_inicio = 0
        self._t_inicio = 0.0
        self._d_pico = 0.0
        self._idx_pico = 0
        self._t_pico = 0.0

    @property
    def fase(self) -> str:
        if self.estado == REPOSO or self._d_actual is None:
            return REPOSO
        return VUELTA if self._d_pico - self._d_actual > HISTERESIS_FASE else IDA

    def actualizar(self, idx: int, t_s: float, valor: Optional[float]) -> Optional[EventoRepeticion]:
        if valor is None:
            return None
        d = self.signo * valor
        self._d_actual = d
        if self.estado == REPOSO:
            if self._d_reposo is None or d < self._d_reposo:
                self._d_reposo, self._idx_reposo = d, idx
            if d > self.inicio:
                self.estado = "movimiento"
                self._idx_inicio, self._t_inicio = idx, t_s
                self._d_pico, self._idx_pico, self._t_pico = d, idx, t_s
            return None

        if d > self._d_pico:
            self._d_pico, self._idx_pico, self._t_pico = d, idx, t_s
        if d >= self.fin:
            return None

        evento = EventoRepeticion(
            valida=self._d_pico >= self.minimo,
            idx_reposo=self._idx_reposo,
            idx_inicio=self._idx_inicio,
            idx_pico=self._idx_pico,
            idx_fin=idx,
            t_inicio_s=self._t_inicio,
            t_pico_s=self._t_pico,
            t_fin_s=t_s,
        )
        self.estado = REPOSO
        self._d_reposo, self._idx_reposo = d, idx
        if t_s - self._t_inicio < self.duracion_minima_s:
            return None
        return evento
