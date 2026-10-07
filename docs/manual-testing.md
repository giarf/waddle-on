# Verificación de escritorio

Compilar con `make app` y ejecutar con `make run`. Se requiere una sesión gráfica de macOS; las pruebas de red usan respuestas simuladas y no necesitan API key.

## Personaje e integración

- El pingüino aparece sobre el escritorio sin fondo de ventana.
- Arrastrarlo y soltarlo; comprobar que no salte al iniciar el arrastre.
- Mantener Option y hacer clic en otro punto: debe caminar hacia allí y quedar quieto al llegar.
- Probar destinos a ambos lados y arriba/abajo, también con una segunda pantalla situada a la izquierda o arriba de la principal.
- Hacer clic en las aplicaciones detrás de las zonas transparentes: deben recibir el clic.
- Cambiar de Space y probar una aplicación en pantalla completa.
- Desconectar un monitor y comprobar que el personaje y la barra siguen accesibles.
- Ocultar/mostrar desde el menú de Waddle On y salir desde ese mismo menú.

## Chat y configuración

- Abrir configuración desde el engranaje; introducir URL base, modelo y API key de un proveedor compatible con OpenAI.
- Guardar y reabrir: comprobar configuración y clave; esta última se guarda en el Llavero de macOS.
- Escribir en la barra azul y enviar con Enter; verificar estado de espera y globo con respuesta real.
- Enviar una segunda pregunta que dependa de la anterior para verificar contexto.
- Desplegar/cerrar historial con la flecha; comprobar scroll, selección de texto y que no se pierda el borrador.
- Probar una respuesta larga; comprobar lectura del globo y acceso completo desde el historial.
- Cancelar una petición; comprobar que se puede enviar otra.
- Probar URL inválida, modelo inexistente, error de autenticación y servidor desconectado; los errores deben ser legibles y no revelar la clave.
- Cerrar configuración con Cancelar y con el botón de cierre; comprobar reapertura.

Registrar por separado pruebas automatizadas, arranque real y verificaciones visuales/manuales: una compilación correcta no demuestra el comportamiento entre Spaces ni una conversación real con el proveedor.
