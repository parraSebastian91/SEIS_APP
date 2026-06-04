# HU-10 — Modal de Doble Confirmación para Envío de Oferta Firme

---

## Historia de Usuario

**Yo como** Ejecutiva Financiera de la mesa de dinero,
**Quiero** ver un resumen claro y en lenguaje humano de mi oferta antes de confirmarla definitivamente,
**Para** evitar errores costosos por clics accidentales y tener un último momento de verificación antes de que la operación quede comprometida legalmente con el cliente.

---

## Criterios de Aceptación

### CA-01 · Activación del modal
- Al presionar el botón **"Enviar Oferta Firme"**, la pantalla debe oscurecerse (overlay con opacidad ~80%) y aparecer un **modal centrado** con el resumen de la operación.
- El botón "Enviar Oferta Firme" solo debe estar habilitado cuando:
  - Se haya seleccionado una factura.
  - El formulario de la Columna 3 esté completo y válido.
  - No haya alertas de interferencia activas (HU-09).
  - No haya alertas de cupo agotado activas (HU-05).

### CA-02 · Contenido del modal en lenguaje humano
El modal debe mostrar el resumen de la operación en oraciones simples, **no en formato tabla de datos técnicos**. Ejemplo de contenido:

> **¿Confirmar oferta firme?**
>
> Vas a **transferir $10.150.413** al cliente por la factura **#45902 de CENCOSUD S.A.**
>
> Dejarás retenidos **$1.875.000** como Excedente hasta que el deudor pague.
>
> Tu mesa ganará **$373.437** en **45 días**.
>
> ¿Estás segura de publicar esta oferta?

Los valores deben ser dinámicos, tomados de la Pre-Liquidación calculada.

### CA-03 · Botones de acción del modal
- **Botón principal (confirmar)**: Texto `"Sí, publicar oferta"`. Color de fondo verde o azul. Al presionarlo, se envía la oferta al servidor y el modal se cierra.
- **Botón secundario (cancelar)**: Texto `"Cancelar"` o `"Volver a revisar"`. Color neutro. Al presionarlo, el modal se cierra y la ejecutiva vuelve al estado de edición **sin perder los datos del formulario**.

### CA-04 · Estado de carga al confirmar
- Al presionar "Sí, publicar oferta", mientras el servidor procesa la solicitud:
  - El botón de confirmar debe mostrar un **spinner de carga** y quedar deshabilitado.
  - El botón cancelar también debe quedar deshabilitado para evitar doble envío.
  - El overlay permanece activo hasta que el servidor responda.

### CA-05 · Confirmación exitosa
- Si el servidor responde con éxito:
  - El modal se cierra.
  - Se muestra un **toast de éxito** (verde, en la esquina superior o inferior de la pantalla): `"¡Oferta enviada! Tu oferta sobre la factura #45902 ha sido publicada exitosamente."`.
  - La factura puede permanecer visible en la Columna 2 en estado "Oferta enviada", o el sistema puede limpiar la Columna 2. **Definir comportamiento con el equipo.**
  - La tarjeta en la Columna 1 debe actualizarse para reflejar la nueva oferta (ya muestra el conteo de ofertas aumentado).

### CA-06 · Error al confirmar
- Si el servidor responde con un error:
  - El modal permanece abierto (no se cierra automáticamente).
  - Se muestra un mensaje de error dentro del modal: `"No se pudo publicar la oferta. Inténtalo de nuevo."` con detalles del error si están disponibles.
  - Ambos botones se rehabilitan para que la ejecutiva pueda reintentar o cancelar.

### CA-07 · Cierre del modal con tecla Escape
- Presionar la tecla `Escape` debe cerrar el modal (equivalente a presionar "Cancelar"), siempre que no esté en estado de carga.

---

## Casos de Borde (Edge Cases) — Para validar con el equipo

| # | Escenario | Pregunta a resolver |
|---|---|---|
| EB-01 | **Oferta duplicada** | Si la ejecutiva presiona "Sí, publicar oferta" y tiene una conexión lenta que demora, y hace doble clic, ¿el servidor tiene protección de idempotencia para no crear dos ofertas iguales? |
| EB-02 | **Sesión expirada al confirmar** | Si la sesión JWT de la ejecutiva expiró entre que abrió el modal y presionó confirmar, ¿el sistema redirige al login o muestra el error dentro del modal? |
| EB-03 | **Factura ganada por otra ejecutiva durante el modal** | Si mientras el modal está abierto otra ejecutiva envía una oferta que "gana" la subasta, ¿la oferta de la primera ejecutiva igual se envía (competencia abierta) o el sistema la bloquea? |
| EB-04 | **Cambio de datos durante el modal** | Si llega un evento WebSocket de cambio de datos (HU-09) mientras el modal está abierto, ¿qué tiene prioridad? ¿El modal se cierra forzadamente o el cambio espera? |
| EB-05 | **Auditoría de la oferta confirmada** | ¿Queda registrado en el sistema exactamente lo que vio la ejecutiva en el modal al momento de confirmar (monto, plazo, giro, margen)? Esto es importante para auditorías y resolución de disputas. |
| EB-06 | **Oferta fuera de horario** | ¿Existe un horario operativo para enviar ofertas? Si una ejecutiva abre el sistema fuera del horario, ¿puede simular pero no enviar? ¿O puede enviar sin restricción? |
| EB-07 | **Límite de ofertas activas por ejecutiva** | ¿Una ejecutiva puede tener 50 ofertas activas simultáneamente? ¿Hay un límite de exposición total por ejecutiva o por mesa? |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- El endpoint POST de la oferta debe implementar **idempotencia** (ej: usando un `offerId` único generado en el frontend y enviado con la solicitud para evitar duplicados por reintentos).
- La confirmación exitosa debe actualizar el estado del marketplace en tiempo real vía el mismo canal WebSocket (emitir evento de "nueva oferta" para que todos los participantes vean el cambio).
- El modal debe ser un componente Angular de tipo **Dialog** (ej: Angular CDK Overlay o el propio modal del design system del proyecto).

---

*Creada: 2026-05-18 | Estado: Por refinar | Equipo: Factor Fintech*
