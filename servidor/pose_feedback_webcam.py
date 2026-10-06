"""Prueba en vivo del motor de análisis con la webcam del computador.

Usa exactamente el mismo motor que la API (motor/), por lo que sirve para
calibrar umbrales de compartido/ejercicios.json antes de llevarlos a la app.

Teclas: 1-6 cambian de ejercicio · R reinicia el conteo · ESC sale.
Al salir imprime el resultado completo de la sesión en formato JSON.
"""

from __future__ import annotations

import json
import os
import time
import unicodedata

import cv2
import mediapipe as mp

from motor import Analizador, Fotograma, cargar_especificacion

DIR = os.path.dirname(os.path.abspath(__file__))
MODELO = os.getenv("MODELO_POSE", os.path.join(DIR, "pose_landmarker_full.task"))
VENTANA = "Proyecto Movimiento - prueba en vivo"
CAMARA_MAX_INDICE = 10
try:
    CAMARA_PREFERIDA = int(os.getenv("CAMERA_INDEX", "1"))
except ValueError:
    CAMARA_PREFERIDA = 1

CONEXIONES = [
    (11, 12), (11, 13), (13, 15), (12, 14), (14, 16),
    (11, 23), (12, 24), (23, 24), (23, 25), (25, 27), (24, 26), (26, 28),
]  # fmt: skip

COLOR_OK = (90, 200, 90)
COLOR_AVISO = (0, 170, 255)
COLOR_ERROR = (60, 60, 230)
COLOR_TEXTO = (255, 255, 255)

BaseOptions = mp.tasks.BaseOptions
PoseLandmarker = mp.tasks.vision.PoseLandmarker
PoseLandmarkerOptions = mp.tasks.vision.PoseLandmarkerOptions
RunningMode = mp.tasks.vision.RunningMode


def sin_tildes(texto: str) -> str:
    """OpenCV no dibuja tildes ni eñes: se transliteran."""
    return unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode("ascii")


def abrir_camara(preferida: int, max_indice: int):
    def intentar(indice: int):
        for backend in (cv2.CAP_DSHOW, cv2.CAP_ANY):
            cap = cv2.VideoCapture(indice, backend)
            if cap.isOpened():
                lecturas = sum(1 for _ in range(3) if cap.read()[0])
                if lecturas >= 2:
                    return cap
            cap.release()
        return None

    for indice in [preferida] + [i for i in range(max_indice + 1) if i != preferida]:
        cap = intentar(indice)
        if cap is not None:
            return cap, indice
    raise RuntimeError("No se pudo abrir ninguna cámara. Pruebe con CAMERA_INDEX=0, 1, 2...")


def panel(cuadro, x, y, ancho, titulo, lineas, color_titulo=COLOR_TEXTO):
    alto = 40 + 28 * len(lineas)
    capa = cuadro.copy()
    cv2.rectangle(capa, (x, y), (x + ancho, y + alto), (20, 20, 20), -1)
    cv2.addWeighted(capa, 0.55, cuadro, 0.45, 0, cuadro)
    cv2.putText(cuadro, sin_tildes(titulo), (x + 12, y + 28), cv2.FONT_HERSHEY_SIMPLEX, 0.75, color_titulo, 2)
    for i, linea in enumerate(lineas):
        texto, color = linea if isinstance(linea, tuple) else (linea, COLOR_TEXTO)
        cv2.putText(cuadro, sin_tildes(texto), (x + 12, y + 60 + 28 * i), cv2.FONT_HERSHEY_SIMPLEX, 0.62, color, 2)


def main():
    spec = cargar_especificacion()
    ids = spec.ids
    actual = ids[0]
    analizador = Analizador(spec, actual)
    ultima_rep = None

    opciones = PoseLandmarkerOptions(
        base_options=BaseOptions(model_asset_path=MODELO), running_mode=RunningMode.VIDEO, num_poses=1
    )
    cap, indice = abrir_camara(CAMARA_PREFERIDA, CAMARA_MAX_INDICE)
    print(f"Cámara activa: índice {indice}")
    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
    cv2.namedWindow(VENTANA, cv2.WINDOW_NORMAL)
    cv2.resizeWindow(VENTANA, 1280, 720)
    inicio = time.time()

    with PoseLandmarker.create_from_options(opciones) as detector:
        try:
            while cap.isOpened():
                ok, cuadro = cap.read()
                if not ok or cuadro is None:
                    print("No se pudo leer la cámara")
                    break
                alto, ancho = cuadro.shape[:2]
                t_ms = int((time.time() - inicio) * 1000)
                rgb = cv2.cvtColor(cuadro, cv2.COLOR_BGR2RGB)
                res = detector.detect_for_video(mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb), t_ms)
                if res.pose_landmarks:
                    mundo = res.pose_world_landmarks[0] if res.pose_world_landmarks else None
                    f = Fotograma.desde_mediapipe(t_ms, res.pose_landmarks[0], mundo, ancho, alto)
                else:
                    f = Fotograma(t_ms=t_ms)
                estado = analizador.procesar(f)
                if estado.nueva_repeticion is not None:
                    ultima_rep = estado.nueva_repeticion

                if f.imagen is not None:
                    color = COLOR_ERROR if ultima_rep and ultima_rep.fallos else COLOR_OK
                    for a, b in CONEXIONES:
                        if f.imagen[a, 3] >= 0.5 and f.imagen[b, 3] >= 0.5:
                            pa = (int(f.imagen[a, 0]), int(f.imagen[a, 1]))
                            pb = (int(f.imagen[b, 0]), int(f.imagen[b, 1]))
                            cv2.line(cuadro, pa, pb, color, 3)

                ej = analizador.ej
                fase = {"reposo": "En reposo", "ida": ej.fases["ida"], "vuelta": ej.fases["vuelta"]}[estado.fase]
                valor = f"{estado.valor_senal:.0f}{ej.senal.unidad}" if estado.valor_senal is not None else "--"
                info = [
                    f"Repeticiones: {estado.repeticiones}   Incompletas: {estado.incompletas}",
                    f"Fase: {fase}",
                    f"{ej.senal.nombre}: {valor}",
                    "Teclas: " + " ".join(f"{i + 1}-{e[:8]}" for i, e in enumerate(ids)),
                ]
                if estado.faltantes:
                    info.append((f"No se ven: {', '.join(estado.faltantes)}", COLOR_AVISO))
                panel(cuadro, 16, 16, min(620, ancho // 2), ej.nombre.upper(), info)

                if ultima_rep is not None:
                    verificaciones = {v.codigo: v for v in ej.verificaciones}
                    lineas = [(verificaciones[c].titulo, COLOR_ERROR) for c in ultima_rep.fallos]
                    if not lineas:
                        lineas = [("Repeticion correcta", COLOR_OK)]
                    panel(
                        cuadro,
                        max(16, ancho - 520),
                        16,
                        500,
                        f"Rep {ultima_rep.numero}: {ultima_rep.puntaje}/100",
                        lineas,
                    )

                cv2.imshow(VENTANA, cuadro)
                if cv2.getWindowProperty(VENTANA, cv2.WND_PROP_VISIBLE) < 1:
                    break
                tecla = cv2.waitKey(1) & 0xFF
                if tecla == 27:
                    break
                if ord("1") <= tecla < ord("1") + len(ids):
                    actual = ids[tecla - ord("1")]
                    analizador, ultima_rep = Analizador(spec, actual), None
                elif tecla in (ord("r"), ord("R")):
                    analizador, ultima_rep = Analizador(spec, actual), None
        except KeyboardInterrupt:
            print("Cierre por teclado")
        finally:
            cap.release()
            cv2.destroyAllWindows()

    print(json.dumps(analizador.resultado(), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
