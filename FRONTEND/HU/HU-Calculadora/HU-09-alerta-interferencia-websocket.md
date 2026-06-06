# HU-09 — Alerta de Interferencia por Cambio de Datos en Tiempo Real

---

## Historia de Usuario

**Yo como** Ejecutiva Financiera que está simulando una oferta sobre una factura,
**Quiero** recibir una alerta inmediata y visible cuando los datos de la factura que estoy revisando cambien (porque el cliente la modificó o el sistema actualizó el plazo),
**Para** no enviar una oferta calculada sobre información desactualizada que podría generar pérdidas o errores en la operación.

---

## Criterios de Aceptación

### CA-01 · Detección del cambio en tiempo real
- El sistema debe detectar automáticamente, vía WebSocket, cuando ocurre cualquiera de los siguientes eventos en la factura actualmente seleccionada en la Columna 2:
  - El **cliente retira la factura** del marketplace.
  - El **monto de la factura** es corregido.
  - La **fecha de vencimiento** cambia (por rectificación del cliente o actualización del OCR).
  - El **plazo de la operación** cambia.

### CA-02 · Bloqueo de la calculadora con overlay
- En el momento en que se detecta el cambio, la **Columna 3 (Calculadora)** debe bloquearse visualmente con un **overlay semitransparente** que cubra todo el panel.
- El overlay debe mostrar el mensaje:
  > `"Los datos de la factura han cambiado. Recalculando parámetros..."`
- Durante este estado bloqueado, los campos del formulario no deben ser editables y el botón de "Enviar Oferta Firme" debe estar deshabilitado.

### CA-03 · Actualización automática y desbloqueo
- Una vez que el sistema recibe los datos actualizados, debe:
  1. Actualizar silenciosamente todos los campos de la Columna 2 con los nuevos datos de la factura.
  2. **Recalcular automáticamente** la Pre-Liquidación con los mismos parámetros de tasa y gastos que la ejecutiva había ingresado, pero con el nuevo monto/plazo.
  3. **Quitar el overlay** y devolver el control del formulario a la ejecutiva.
  4. Mostrar brevemente un aviso no intrusivo (toast/notificación inferior): `"Los datos de la factura fueron actualizados. Verifica la nueva liquidación antes de ofertar."`.

### CA-04 · Caso de factura retirada por el cliente
- Si el evento es que el **cliente retiró la factura**, el comportamiento es diferente al recálculo:
  - El overlay debe mostrar: `"Esta factura ya no está disponible. El cliente la ha retirado del marketplace."`.
  - Los botones de oferta deben permanecer **bloqueados permanentemente** para esta factura.
  - La tarjeta en la Columna 1 debe **desaparecer de la lista** automáticamente.

### CA-05 · Preservación del trabajo de la ejecutiva
- Al recalcular tras un cambio, los parámetros que la ejecutiva había ingresado (**tasa, porcentaje de anticipo, comisiones**) deben **preservarse** en el formulario. El sistema solo actualiza los datos de la factura (monto, plazo), no los parámetros de la oferta de la ejecutiva.

---

## Casos de Borde (Edge Cases) — Para validar con el equipo

| # | Escenario | Pregunta a resolver |
|---|---|---|
| EB-01 | **Cambio durante el modal de confirmación** | Si la ejecutiva ya abrió el Modal de Doble Confirmación (HU-10) y en ese momento llega un cambio en los datos, ¿el modal se cierra automáticamente, o la oferta se envía con los datos viejos? |
| EB-02 | **Múltiples cambios en ráfaga** | Si llegan 3 eventos de cambio en 2 segundos (el sistema está inestable), ¿el overlay aparece y desaparece 3 veces o el sistema los agrupa y solo muestra el estado final? |
| EB-03 | **Cambio menor sin impacto financiero** | Si el cambio es de un campo que no afecta la calculadora (ej: corrección ortográfica en la razón social del deudor), ¿se dispara igual el overlay o el sistema hace una diferenciación inteligente? |
| EB-04 | **Tiempo máximo de espera del overlay** | Si el overlay aparece y el backend tarda en responder los datos nuevos, ¿hay un tiempo máximo de espera? ¿Qué pasa si después de 10 segundos no llegan los datos actualizados? |
| EB-05 | **Log de cambios** | ¿Se guarda un registro de qué cambió y cuándo en la factura, para que la ejecutiva pueda revisar el historial de modificaciones del documento? |
| EB-06 | **Alerta de cambio mientras no hay conexión** | Si la ejecutiva se desconectó del WebSocket brevemente y al reconectarse hay datos nuevos, ¿el sistema detecta el delta y dispara la alerta aunque no haya recibido el evento en tiempo real? |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- El sistema debe suscribirse a un **canal de eventos por `facturaId`** en el WebSocket para escuchar únicamente los cambios de la factura actualmente seleccionada.
- Al cambiar la factura seleccionada (clic en otra tarjeta), el sistema debe **desuscribirse del canal anterior** y suscribirse al nuevo `facturaId`.
- El overlay debe implementarse como un componente de Angular con `position: absolute` sobre la Columna 3, controlado por una Signal de estado.

---

*Creada: 2026-05-18 | Estado: Por refinar | Equipo: Factor Fintech*
