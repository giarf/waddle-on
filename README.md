<h1 align="center">Waddle On</h1>

<p align="center">Un pingüino en tu escritorio. Sigue pingüineando con IA.</p>

<p align="center">
  <a href="https://github.com/giarf/waddle-on/releases/latest"><img src="https://img.shields.io/github/v/release/giarf/waddle-on?style=flat-square" alt="Última versión"></a>
  <img src="https://img.shields.io/badge/macOS-13%2B-black?style=flat-square&logo=apple" alt="macOS 13 o superior">
  <img src="https://img.shields.io/badge/Swift-5.9-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 5.9">
</p>

<p align="center"><img src="Support/AppIcon.png" width="180" alt="Icono de Waddle On"></p>

Waddle On es un compañero de escritorio para macOS con animaciones de Club Penguin, chat con IA y globos de conversación. Camina detrás del cursor, baila y lanza bolas de nieve.

## Requisitos

- macOS 13 o superior.
- Mac con Apple Silicon o Intel; el DMG incluye un ejecutable universal.
- Un proveedor compatible con OpenAI para conversar (URL base, modelo y API key).

## Instalar

### Homebrew

```sh
brew install --cask giarf/tap/waddle-on
```

El cask verifica el SHA-256 de la descarga y elimina automáticamente la cuarentena de la aplicación instalada, siguiendo el mismo flujo de Focnotes.

### DMG

**[Descargar Waddle On para macOS](https://github.com/giarf/waddle-on/releases/latest/download/Waddle-On.dmg)**

Abre el DMG y arrastra **Waddle On** a **Aplicaciones**.

La aplicación tiene firma ad hoc y no está notarizada por Apple. Si macOS bloquea su apertura, puedes usar **Ajustes del Sistema → Privacidad y seguridad → Abrir igualmente**. Tras comprobar que descargaste el DMG de este repositorio, también puedes ejecutar:

```sh
xattr -dr com.apple.quarantine "/Applications/Waddle On.app"
```

## Primer inicio

- El pingüino aparece bailando, con la barra de escritura oculta.
- Pulsa **⌥ D** para que deje de bailar y siga el cursor.
- Haz clic en el pingüino para mostrar la barra; otro clic oculta la barra y el globo.
- Abre el engranaje o **Configuración…** desde el icono del iglú en la barra de menús.
- Introduce URL base, modelo y API key. Escribe un mensaje y pulsa Enter.

## Comportamiento

- Personaje transparente por encima de las ventanas, visible entre Spaces.
- Seguimiento del cursor a ritmo de pingüino, con distancia de separación y arrastre manual.
- Desactiva **Seguir el cursor** para moverlo con **⌥ Option + clic**. El clic también llega a la aplicación de debajo.
- **⌥ D** inicia o detiene el baile clásico; también está disponible en el menú del iglú. Si otra app usa ese atajo, utiliza el menú.
- Bolas de nieve automáticas configurables entre **5 y 300 segundos**. El intervalo de 20 s produce esperas aleatorias de 15–25 s.
- El personaje se detiene para lanzar y después retoma la caminata. La bola apunta a la posición del cursor al iniciar el gesto.
- Chat azul flotante, historial desplegable, cancelación de peticiones y globos desplazables.
- Fórmulas LaTeX renderizadas localmente con [KaTeX](https://github.com/KaTeX/KaTeX): `\(…\)`, `\[…\]`, `$…$` y `$$…$$`.
- Icono monocromático de iglú en la barra de menús; la app no ocupa un lugar permanente en el Dock.

La configuración y la API key se guardan en preferencias locales **sin cifrado**, sin usar el Llavero. Los servidores locales sin autenticación admiten una clave vacía. El historial vive en memoria y se reinicia al cerrar; las respuestas llegan completas, sin streaming.

## Compilar

Necesitas Xcode Command Line Tools con Swift 5.9 o posterior.

```sh
make app
```

La app queda en `build/Waddle On.app`. Para generar el DMG universal:

```sh
make dmg
```

## Ejecutar

```sh
make run
```

## Instalar compilación local

```sh
make install
```

Instala la app en `/Applications/Waddle On.app`.

## Pruebas

```sh
make test
```

Las pruebas verifican peticiones HTTP simuladas, configuración, animación direccional, trayectoria de nieve y renderizado matemático. La [guía manual](docs/manual-testing.md) cubre interacción visual, pantallas y Spaces; las pruebas automatizadas no requieren una API key real.

## Detalles de implementación

- Swift, AppKit y SwiftUI, con WebKit para fórmulas.
- `Character/` y `Resources/`: sprites y animación direccional, baile y lanzamiento.
- `Desktop/`: ventanas transparentes, movimiento, acciones y atajo global.
- `UI/`: chat, historial y configuración.
- `AI/`: cliente compatible con `POST /chat/completions` y preferencias locales.
- `App/`: ciclo de vida e integración.

Los recursos originales se recuperaron después de comprobar que las carpetas de medios locales de Wand y Yukon estaban vacías. Consulta [procedencia, extracción y limitaciones](docs/assets.md). El arte original conserva sus derechos; KaTeX incluye su licencia MIT. La bola en vuelo y el impacto son gráficos nativos. No se requiere Flash ni conexión para reproducir animaciones o renderizar fórmulas.

<p align="center"><em>Waddle on!</em> 🐧</p>
