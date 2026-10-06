"""Genera los íconos de Android e iOS a partir de los PNG de 1024 px que dibuja
test_capturas/icono_test.dart (el mismo logo que se ve en la app).

    flutter test test_capturas/icono_test.dart --update-goldens
    python tool/generar_iconos.py

Requiere Pillow.
"""

import json
from pathlib import Path

from PIL import Image

RAIZ = Path(__file__).resolve().parent.parent
ICONOS = RAIZ / "tool" / "icono"
RES = RAIZ / "android" / "app" / "src" / "main" / "res"
IOS = RAIZ / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"

DENSIDADES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

FONDO_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- Fondo del ícono adaptable: el mismo degradado de la app. -->
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient
        android:angle="315"
        android:startColor="#14285E"
        android:centerColor="#2F6FED"
        android:endColor="#12B5A5"
        android:type="linear" />
</shape>
"""

ADAPTABLE_XML = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_fondo" />
    <foreground android:drawable="@mipmap/ic_launcher_frente" />
    <monochrome android:drawable="@mipmap/ic_launcher_frente" />
</adaptive-icon>
"""


def redimensionar(origen: Image.Image, lado: int) -> Image.Image:
    return origen.resize((lado, lado), Image.Resampling.LANCZOS)


def android() -> None:
    heredado = Image.open(ICONOS / "icono_redondeado.png").convert("RGBA")
    frente = Image.open(ICONOS / "icono_frente.png").convert("RGBA")
    for nombre, factor in DENSIDADES.items():
        carpeta = RES / f"mipmap-{nombre}"
        carpeta.mkdir(parents=True, exist_ok=True)
        redimensionar(heredado, round(48 * factor)).save(carpeta / "ic_launcher.png", optimize=True)
        redimensionar(frente, round(108 * factor)).save(carpeta / "ic_launcher_frente.png", optimize=True)
    (RES / "drawable").mkdir(exist_ok=True)
    (RES / "drawable" / "ic_launcher_fondo.xml").write_text(FONDO_XML, encoding="utf-8")
    (RES / "mipmap-anydpi-v26").mkdir(exist_ok=True)
    (RES / "mipmap-anydpi-v26" / "ic_launcher.xml").write_text(ADAPTABLE_XML, encoding="utf-8")


def ios() -> None:
    # iOS no admite transparencia en el ícono: se guarda en RGB.
    cuadrado = Image.open(ICONOS / "icono_cuadrado.png").convert("RGB")
    contenido = json.loads((IOS / "Contents.json").read_text(encoding="utf-8"))
    for img in contenido["images"]:
        base = float(img["size"].split("x")[0])
        escala = int(img["scale"].rstrip("x"))
        lado = round(base * escala)
        redimensionar(cuadrado, lado).save(IOS / img["filename"], optimize=True)


if __name__ == "__main__":
    android()
    ios()
    print("Íconos generados.")
