<h1 align="center">Waddle On</h1>

<p align="center">
  Un pingüino en tu escritorio. Sigue pingüineando con IA.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/plataforma-macOS-black?style=flat-square&logo=apple" alt="Para macOS">
  <img src="https://img.shields.io/badge/estado-en%20desarrollo-blue?style=flat-square" alt="En desarrollo">
</p>

Waddle On es un proyecto de compañero de escritorio para macOS inspirado en Club Penguin. La idea es tener un pingüino que puedas mover por la pantalla, que camine con sus animaciones y que responda a tus mensajes en globos de diálogo. Una barra de escritura flotante, al estilo del juego, conecta la conversación con una IA.

## Estado actual

Primera versión nativa ejecutable para macOS, implementada con Swift, AppKit y SwiftUI. Incluye sprites originales, movimiento con Option + clic, barra azul de chat, historial desplegable, globos y conexión a APIs compatibles con OpenAI.

La compilación release y las 7 pruebas automatizadas de red/configuración pasan. La app se ha iniciado desde su bundle local; la interacción visual entre pantallas/Spaces y la conversación con un proveedor real requieren verificación manual.

## Experiencia

- Pingüino sobre el escritorio, sin marco ni fondo visible.
- Arrastre para colocarlo donde quieras.
- Movimiento animado hacia el lugar donde haces **Option (⌥) + clic**, incluso fuera de la app.
- Barra de escritura flotante en la parte inferior de la pantalla.
- Respuestas de la IA en globos encima del personaje.
- Globos desplazables para respuestas largas e historial completo desplegable con la flecha de la barra.
- Las zonas transparentes dejan pasar los clics a las aplicaciones de debajo.
- El teclado se enfoca en el chat cuando activas la barra de escritura.
- Acceso desde la barra de menús para mostrar, ocultar y configurar el compañero.

## Requisitos

macOS 13 o posterior y herramientas de desarrollo de Apple con Swift 5.9 o posterior (Xcode o Command Line Tools). No hay dependencias externas ni se necesita Flash en tiempo de ejecución.

## Compilar

Desde la raíz del repositorio:

```sh
make app
```

La aplicación se genera con firma ad hoc local en:

```text
build/Waddle On.app
```

## Ejecutar

Compilar y abrir:

```sh
make run
```

## Instalar compilación local

Instalar en Aplicaciones:

```sh
make install
```

Compilará e instalará la aplicación en `/Applications/Waddle On.app`.

## Recursos del pingüino

Se inspeccionaron las copias locales de Wand y Yukon en `../clubpenguin/`; sus carpetas de medios no contenían el pingüino base. Se recuperó el SWF original desde un mirror y se extrajo con FFDec un atlas PNG transparente: ocho poses de pie y ocho cuadros de caminata por cada una de las ocho direcciones.

Consulta [procedencia y extracción](docs/assets.md) para URL, checksums y limitaciones. El atlas se incluye en la app y se carga sin conexión. El personaje es azul; la respiración en reposo es una transformación sutil de la pose original.

## Configurar la IA

1. Abre el engranaje de la barra azul o **Configuración…** en el menú 🐧.
2. Indica la **URL base**, por ejemplo `https://api.openai.com/v1` o la URL de tu servidor compatible.
3. Escribe el identificador del **modelo**, la **API key** y, opcionalmente, las instrucciones del sistema.
4. Guarda, escribe en la barra y pulsa Enter.

La clave se guarda en el **Llavero de macOS**; el resto de la configuración usa UserDefaults. Los servidores locales sin autenticación admiten una clave vacía. El cliente envía `POST /chat/completions`, incluye el contexto de la conversación y permite cancelar. Las respuestas se muestran al terminar la petición, sin streaming en esta versión.

El historial de conversación vive en memoria y se reinicia al cerrar la app. Option + clic se observa sin consumir el clic: la aplicación que está debajo también lo recibe. Puedes arrastrar el pingüino, hacer clic sobre él para mostrar/ocultar el chat y usar el menú 🐧 para recuperar su posición o salir.

## Detalles de implementación

El proyecto se organiza en:

- `Sources/WaddleOn/Character/` y `Resources/`: sprites y animación direccional.
- `Sources/WaddleOn/Desktop/`: paneles transparentes, movimiento, globos y menú.
- `Sources/WaddleOn/UI/`: barra azul, historial y configuración.
- `Sources/WaddleOn/AI/`: cliente HTTP y almacenamiento de credenciales.
- `Sources/WaddleOn/App/`: ciclo de vida e integración.

## Pruebas

```sh
make test
```

Las pruebas usan URLProtocol para verificar endpoints, historial, autenticación, errores sin secretos y cancelación; no realizan llamadas a proveedores reales. La guía de [verificación manual](docs/manual-testing.md) cubre clics, foco, pantallas, Spaces y configuración.

## Plan de desarrollo

- [x] Crear el repositorio y definir la experiencia inicial.
- [x] Localizar y validar los sprites y animaciones del pingüino.
- [x] Elegir la tecnología y crear una ventana transparente en macOS.
- [x] Mostrar el personaje y permitir arrastrarlo.
- [x] Implementar la caminata hacia un destino.
- [x] Añadir la barra flotante, historial y globos.
- [x] Conectar la IA con configuración de proveedor y credenciales.
- [ ] Añadir respuestas por streaming.
- [ ] Verificar clics, foco, Spaces y pantallas completas.
- [x] Implementar `make app`, `make run` y `make install`.
- [x] Compilar, ejecutar pruebas y abrir la primera versión local.
- [ ] Verificar conversación real con el proveedor elegido.

## Inspiración

- **Club Penguin:** el personaje, la caminata y la experiencia visual del chat.
- **Yukon y Wand:** referencias para el cliente y los recursos del juego.
- **Focnotes:** presentación del repositorio y flujo de compilación e instalación de una app para Mac.

<p align="center"><em>Waddle on!</em> 🐧</p>
