"""API de análisis de movimiento (FastAPI).

Ejecutar:  uvicorn servidor:app --reload --host 0.0.0.0 --port 8000

Endpoints:
- GET  /                      Estado (compatibilidad con la app v1).
- GET  /salud                 Estado detallado.
- GET  /v1/ejercicios         Especificación de ejercicios (catálogo + umbrales).
- POST /v1/analisis/video     Analiza un video (multipart: video, ejercicio).
- POST /v1/analisis/puntos    Analiza puntos ya detectados en el dispositivo (JSON).
- POST /analizar              Alias de /v1/analisis/video (compatibilidad v1).

La respuesta conserva los campos de la v1 (ejercicio, puntaje, feedback,
metricas) y agrega repeticiones, hallazgos, aciertos, serie y calidad.
"""

from __future__ import annotations

import json
import os
import tempfile
import threading
from pathlib import Path
from typing import Annotated, Any, Dict, List, Optional

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

from motor import Analizador, Fotograma, cargar_especificacion

DIR = Path(__file__).resolve().parent
VERSION_API = "2.0.0"

ESPECIFICACION = cargar_especificacion(os.getenv("RUTA_ESPECIFICACION") or None)
MODELO_POSE = os.getenv("MODELO_POSE", str(DIR / "pose_landmarker_full.task"))
MAX_MB_VIDEO = float(os.getenv("MAX_MB_VIDEO", "200"))
MAX_ANALISIS_CONCURRENTES = int(os.getenv("MAX_ANALISIS_CONCURRENTES", "2"))
ESPERA_COLA_S = float(os.getenv("ESPERA_COLA_S", "120"))
MAX_FOTOGRAMAS = 20_000
EXTENSIONES_VIDEO = {".mp4", ".mov", ".m4v", ".avi", ".webm", ".mkv", ".3gp"}
ORIGENES_CORS = [o.strip() for o in os.getenv("ORIGENES_CORS", "*").split(",") if o.strip()]

# Limita análisis simultáneos: MediaPipe usa CPU intensivamente. Para escalar se
# recomienda una cola de trabajos (ver docs/PLAN_IMPLEMENTACION.md).
_cupos = threading.BoundedSemaphore(MAX_ANALISIS_CONCURRENTES)

app = FastAPI(title="Proyecto Movimiento API", version=VERSION_API)
app.add_middleware(
    CORSMiddleware,
    allow_origins=ORIGENES_CORS,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)


def _error(status: int, codigo: str, mensaje: str) -> JSONResponse:
    # "error" se mantiene por compatibilidad con la app v1.
    return JSONResponse(status_code=status, content={"error": mensaje, "codigo": codigo})


def _validar_ejercicio(ejercicio: str) -> Optional[JSONResponse]:
    if ejercicio not in ESPECIFICACION.ejercicios:
        return _error(400, "EJERCICIO_INVALIDO", f"Ejercicio no válido. Opciones: {ESPECIFICACION.ids}")
    return None


@app.get("/")
def raiz():
    return {"status": "Servidor MediaPipe corriendo", "version": VERSION_API}


@app.get("/salud")
def salud():
    return {
        "estado": "ok",
        "version": VERSION_API,
        "especificacion": ESPECIFICACION.version,
        "modelo_pose": Path(MODELO_POSE).name,
        "ejercicios": ESPECIFICACION.ids,
    }


@app.get("/v1/ejercicios")
def ejercicios():
    return ESPECIFICACION.crudo


def _leer_ajustes(texto: Optional[str]):
    """Objetivos personales enviados por la app (JSON). Devuelve (ajustes, error)."""
    if not texto:
        return None, None
    try:
        datos = json.loads(texto)
    except ValueError:
        return None, _error(422, "AJUSTES_INVALIDOS", "El campo 'ajustes' no es un JSON válido")
    if not isinstance(datos, dict):
        return None, _error(422, "AJUSTES_INVALIDOS", "El campo 'ajustes' debe ser un objeto")
    return datos, None


def _analizar_video(video: UploadFile, ejercicio: str, ajustes: Optional[str] = None, esqueleto: bool = False):
    error = _validar_ejercicio(ejercicio)
    if error:
        return error
    ajustes_dict, error = _leer_ajustes(ajustes)
    if error:
        return error
    especificacion = ESPECIFICACION.con_ajustes(ajustes_dict)

    sufijo = Path(video.filename or "").suffix.lower()
    if sufijo not in EXTENSIONES_VIDEO:
        sufijo = ".mp4"
    limite = int(MAX_MB_VIDEO * 1024 * 1024)

    with tempfile.NamedTemporaryFile(delete=False, suffix=sufijo) as tmp:
        ruta = tmp.name
        total = 0
        while True:
            bloque = video.file.read(1024 * 1024)
            if not bloque:
                break
            total += len(bloque)
            if total > limite:
                break
            tmp.write(bloque)
    try:
        if total > limite:
            return _error(413, "VIDEO_MUY_GRANDE", f"El video supera el máximo de {MAX_MB_VIDEO:.0f} MB")
        if total == 0:
            return _error(422, "VIDEO_VACIO", "El archivo de video está vacío")
        if not _cupos.acquire(timeout=ESPERA_COLA_S):
            return _error(503, "SERVIDOR_OCUPADO", "El servidor está ocupado, inténtalo en unos segundos")
        try:
            # Importación diferida: permite usar la API de puntos sin MediaPipe/OpenCV.
            from motor.video import VideoInvalido, fotogramas_desde_video

            analizador = Analizador(especificacion, ejercicio, registrar_esqueleto=esqueleto)
            try:
                for f in fotogramas_desde_video(ruta, MODELO_POSE, especificacion.globales.fps_analisis):
                    analizador.procesar(f)
            except VideoInvalido as exc:
                return _error(422, "VIDEO_INVALIDO", f"No se pudo leer el video: {exc}")
            return analizador.resultado()
        finally:
            _cupos.release()
    finally:
        try:
            os.unlink(ruta)
        except OSError:
            pass


# Endpoints síncronos (def): FastAPI los ejecuta en un pool de hilos y así el
# procesamiento pesado no bloquea el event loop.
@app.post("/v1/analisis/video")
def analizar_video_v1(
    video: Annotated[UploadFile, File()],
    ejercicio: Annotated[str, Form()] = "sentadilla",
    ajustes: Annotated[Optional[str], Form(description="Objetivos personales (JSON)")] = None,
    esqueleto: Annotated[bool, Form(description="Incluir el esqueleto muestreado")] = True,
):
    return _analizar_video(video, ejercicio, ajustes, esqueleto)


@app.post("/analizar")
def analizar_video_legado(video: Annotated[UploadFile, File()], ejercicio: Annotated[str, Form()] = "sentadilla"):
    return _analizar_video(video, ejercicio)


class FotogramaEntrada(BaseModel):
    t_ms: int = Field(ge=0)
    puntos: Optional[List[Optional[List[float]]]] = Field(
        default=None, description="33 puntos [x, y, z, visibilidad] en píxeles; null si no hay persona"
    )
    mundo: Optional[List[List[float]]] = Field(default=None, description="33 puntos [x, y, z] en metros (opcional)")


class SolicitudPuntos(BaseModel):
    ejercicio: str
    fotogramas: List[FotogramaEntrada]
    ajustes: Optional[Dict[str, Dict[str, Dict[str, Any]]]] = Field(
        default=None, description="Objetivos personales: {ejercicio: {codigo: {umbral, activa}}}"
    )


@app.post("/v1/analisis/puntos")
def analizar_puntos(solicitud: SolicitudPuntos):
    error = _validar_ejercicio(solicitud.ejercicio)
    if error:
        return error
    if len(solicitud.fotogramas) > MAX_FOTOGRAMAS:
        return _error(413, "DEMASIADOS_FOTOGRAMAS", f"Máximo {MAX_FOTOGRAMAS} fotogramas por solicitud")
    analizador = Analizador(ESPECIFICACION.con_ajustes(solicitud.ajustes), solicitud.ejercicio)
    t_anterior = -1
    for f in solicitud.fotogramas:
        if f.t_ms <= t_anterior:
            return _error(422, "TIEMPOS_NO_CRECIENTES", "Los t_ms deben ser estrictamente crecientes")
        t_anterior = f.t_ms
        puntos = None
        if f.puntos is not None:
            if len(f.puntos) != 33 or any(p is not None and not 3 <= len(p) <= 4 for p in f.puntos):
                return _error(422, "PUNTOS_INVALIDOS", "Cada fotograma debe tener 33 puntos [x, y, z, visibilidad]")
            puntos = [p if p is not None else [0.0, 0.0, 0.0, 0.0] for p in f.puntos]
        mundo = f.mundo
        if mundo is not None and (len(mundo) != 33 or any(len(p) != 3 for p in mundo)):
            return _error(422, "PUNTOS_INVALIDOS", "'mundo' debe tener 33 puntos [x, y, z]")
        analizador.procesar(Fotograma.desde_listas(f.t_ms, puntos, mundo))
    return analizador.resultado()
