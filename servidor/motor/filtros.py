"""Filtro One Euro para suavizar señales con poco retardo.

Referencia: Casiez, Roussel y Vogel (2012), "1€ Filter: A Simple Speed-based
Low-pass Filter for Noisy Input in Interactive Systems".
"""

from __future__ import annotations

import math
from typing import Optional


class FiltroOneEuro:
    def __init__(self, min_cutoff: float = 1.0, beta: float = 0.0, d_cutoff: float = 1.0):
        self.min_cutoff = min_cutoff
        self.beta = beta
        self.d_cutoff = d_cutoff
        self.reiniciar()

    def reiniciar(self) -> None:
        self._x: Optional[float] = None
        self._dx = 0.0
        self._t: Optional[float] = None

    @staticmethod
    def _alpha(cutoff: float, dt: float) -> float:
        tau = 1.0 / (2.0 * math.pi * cutoff)
        return 1.0 / (1.0 + tau / dt)

    def __call__(self, x: float, t_s: float) -> float:
        if self._x is None or self._t is None:
            self._x, self._t = x, t_s
            return x
        dt = t_s - self._t
        if dt <= 0:
            return self._x
        dx = (x - self._x) / dt
        a_d = self._alpha(self.d_cutoff, dt)
        dx_suave = a_d * dx + (1.0 - a_d) * self._dx
        cutoff = self.min_cutoff + self.beta * abs(dx_suave)
        a = self._alpha(cutoff, dt)
        x_suave = a * x + (1.0 - a) * self._x
        self._x, self._dx, self._t = x_suave, dx_suave, t_s
        return x_suave

    @property
    def ultimo_t(self) -> Optional[float]:
        return self._t
