"""Extracción de puntos corporales desde un archivo de video con MediaPipe."""

from __future__ import annotations

from typing import Iterator

import cv2
import mediapipe as mp

from .puntos import Fotograma

BaseOptions = mp.tasks.BaseOptions
PoseLandmarker = mp.tasks.vision.PoseLandmarker
PoseLandmarkerOptions = mp.tasks.vision.PoseLandmarkerOptions
RunningMode = mp.tasks.vision.RunningMode

# Los videos de teléfono suelen venir en 1080p o 4K; MediaPipe trabaja a baja
# resolución internamente, así que reducir antes ahorra CPU sin perder precisión.
LADO_MAXIMO_PX = 960


class VideoInvalido(Exception):
    pass


def fotogramas_desde_video(ruta: str, modelo: str, fps_objetivo: float) -> Iterator[Fotograma]:
    opciones = PoseLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=modelo),
        running_mode=RunningMode.VIDEO,
        num_poses=1,
        min_pose_detection_confidence=0.5,
        min_pose_presence_confidence=0.5,
        min_tracking_confidence=0.5,
    )
    cap = cv2.VideoCapture(ruta)
    if not cap.isOpened():
        raise VideoInvalido("No se pudo abrir el video")
    try:
        fps = cap.get(cv2.CAP_PROP_FPS)
        if not fps or fps != fps or fps <= 0 or fps > 240:
            fps = 30.0
        paso = max(1, int(round(fps / fps_objetivo)))
        leidos = 0
        with PoseLandmarker.create_from_options(opciones) as detector:
            idx = 0
            while True:
                ok, cuadro = cap.read()
                if not ok:
                    break
                leidos += 1
                if idx % paso == 0:
                    alto, ancho = cuadro.shape[:2]
                    escala = LADO_MAXIMO_PX / max(alto, ancho)
                    if escala < 1.0:
                        cuadro = cv2.resize(
                            cuadro, (int(ancho * escala), int(alto * escala)), interpolation=cv2.INTER_AREA
                        )
                        alto, ancho = cuadro.shape[:2]
                    rgb = cv2.cvtColor(cuadro, cv2.COLOR_BGR2RGB)
                    t_ms = int(idx * 1000 / fps)
                    resultado = detector.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), t_ms)
                    if resultado.pose_landmarks:
                        mundo = resultado.pose_world_landmarks[0] if resultado.pose_world_landmarks else None
                        yield Fotograma.desde_mediapipe(t_ms, resultado.pose_landmarks[0], mundo, ancho, alto)
                    else:
                        yield Fotograma(t_ms=t_ms, ancho=ancho, alto=alto)
                idx += 1
        if leidos == 0:
            raise VideoInvalido("El video no contiene cuadros legibles")
    finally:
        cap.release()
