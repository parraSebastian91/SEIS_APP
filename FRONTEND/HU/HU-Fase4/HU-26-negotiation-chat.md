# HU-26 — `NegotiationChat` (Chat de Negociación en Tiempo Real)

---

## Historia de Usuario

**Yo como** cliente cedente o ejecutivo financiero,
**Quiero** chatear en tiempo real con mi contraparte sobre una oferta específica y ver el historial completo de la negociación,
**Para** ajustar las condiciones de la oferta de forma ágil sin salir de la plataforma.

---

## Contexto técnico

`NegotiationChat` es un componente **compartido** implementado en `shared-utils` que se consume en dos MFEs:

| Consumidor | Dónde se muestra | Cómo se abre |
|------------|-----------------|-------------|
| **MFE Publicador** (HU-25) | Panel lateral derecho en `/publicador/factura/:id` | Botón `"Ver chat ▶"` de una oferta |
| **MFE Ofertador** (Fase 5, §7) | Panel lateral derecho en el marketplace | `"Ver chat"` sobre una factura donde el ejecutivo tiene oferta activa |

El canal de comunicación WebSocket está scoped por oferta: `offer:{offerId}`. Solo los dos participantes de la oferta tienen acceso al canal.

Endpoints:
- `GET /api/core/oferta/:offerId/mensajes?cursor=...` — historial paginado del chat
- `WS /ws` con evento `join:offer:{offerId}` — suscribirse al canal
- `WS /ws` con evento `message:offer:{offerId}` — enviar y recibir mensajes
- `WS /ws` con evento `read:offer:{offerId}` — marcar mensajes como leídos

---

## Criterios de Aceptación

### CA-01 · Apertura y comportamiento responsivo

| Breakpoint | Comportamiento |
|------------|---------------|
| `md+` | Panel lateral fijo dentro del layout de la pantalla. Ancho fijo (~400px). Altura completa del viewport menos el header del shell. |
| `xs–md` | Se abre como Full Screen (`position: fixed; inset: 0`). Barra de navegación de regreso `← Volver` en el header fijo. |

- Al abrir: cargar historial de mensajes + suscribirse al canal WS.
- Al cerrar: cancelar la suscripción al canal WS.
- Al abrir en el cliente: todos los mensajes no leídos de esta oferta se marcan como leídos.

### CA-02 · Header del chat

Contenido del header (fijo, no hace scroll):

```
[avatar]  Carlos Soto — Financiera XYZ
          Anticipo: $9.250.000 · Tasa: 2.10%
          Vigencia: 5 días restantes
```

- **Avatar**: del interlocutor (la contraparte). El cliente ve al ejecutivo; el ejecutivo ve al cliente.
- **Nombre completo** + financiera (si aplica al ejecutivo).
- **Resumen inline de la oferta**: monto anticipado, tasa mensual, días de vigencia restantes.
- **Días en rojo** cuando quedan ≤ 2 días.

### CA-03 · Tarjeta de contexto (fija al tope del área de mensajes)

La tarjeta es **fija** encima del área de scroll — no forma parte del historial de mensajes.

**Estado colapsado:**
```
Factura #4521 · Oferta de Carlos Soto          [▲ Ver]
```

**Estado expandido (dos bloques separados por divisor):**

*Bloque factura:*
- Número de factura, nombre del cedente, nombre del deudor, monto total de la factura, fecha de vencimiento + días restantes.

*Bloque oferta:*
- Nombre del ejecutivo, monto anticipado (importe + porcentaje), tasa mensual, gastos operacionales, líquido a recibir (anticipo − gastos), fecha de vigencia.

**Reglas de estado inicial:**
- **Primera vez** (sin mensajes en el hilo): expandida.
- **Con historial previo**: colapsada (el contexto ya fue leído).
- La preferencia se persiste por `offerId` en `localStorage`.

**Transición**: animación de altura suave (`height` + `overflow: hidden`).

**Formato numérico**: todos los valores monetarios usan fuente monoespaciada con `font-variant-numeric: tabular-nums`.

### CA-04 · Área de mensajes (scrollable)

- Los mensajes más recientes quedan al fondo (convención de chat).
- Al abrir: el scroll se posiciona automáticamente en el mensaje más reciente.
- Separadores de fecha entre grupos de mensajes de días distintos (ej. `── 3 jun 2026 ──`).
- **Mensajes propios** alineados a la derecha; **mensajes del interlocutor** a la izquierda.
- **Empty state** (sin mensajes): texto sutil bajo la tarjeta de contexto: `"Sin mensajes aún. Inicia la negociación."`.

**Tipos de mensaje:**

| Tipo | Quién lo genera | Visualización |
|------|----------------|---------------|
| `text` | Cliente o ejecutivo | Burbuja con texto, nombre del autor abreviado, hora y estado de lectura |
| `system:offer_sent` | Sistema | Línea centrada sin burbuja: `"Oferta enviada por [Ejecutivo]"` |
| `system:offer_accepted` | Sistema | Línea centrada (color success): `"Oferta aceptada por [Cliente]"` |
| `system:offer_rejected` | Sistema | Línea centrada (color error): `"Oferta rechazada"` + motivo si lo hay |
| `system:offer_expired` | Sistema | Línea centrada (color warning): `"Esta oferta venció sin ser aceptada"` |

### CA-05 · Estados de lectura de mensajes

| Ícono | Significado |
|-------|-------------|
| `✓` (un check) | Mensaje enviado al servidor |
| `✓✓` gris | Entregado al servidor / en espera de lectura |
| `✓✓` color acento | Leído por el interlocutor |

- Al recibir un mensaje con el chat abierto: se emite evento `read` al servidor automáticamente → los checks del interlocutor pasan a color acento.
- Si el usuario no está en el chat: el mensaje queda sin leer → incrementa el badge en la `factura-view` / en el marketplace.

### CA-06 · Footer de acciones (solo para el cliente)

Fijo encima del input de mensaje. **Solo visible cuando el usuario es el cliente (cedente):**

```
[ Rechazar oferta ]          [ Aceptar oferta → ]
```

- **"Aceptar oferta"**: abre el `AcceptOfferConfirmDialog` (HU-25 CA-07). Al confirmar: la factura pasa a `FINANCIADA`, el chat queda en modo solo lectura.
- **"Rechazar oferta"**: confirmación inline con campo de motivo opcional → `POST /api/core/oferta/:offerId/rechazar`.
- Ambos botones se deshabilitan si la oferta ya no está en estado `ACTIVA`.
- El **ejecutivo no ve este footer** — solo tiene el input de mensaje.

### CA-07 · Input de mensaje

- `<textarea>` autoexpandible: 1 línea de altura mínima, hasta 4 líneas (luego scroll interno).
- `Enter` envía el mensaje. `Shift+Enter` inserta un salto de línea.
- El botón `"Enviar ▶"` se habilita cuando hay texto (no solo espacios en blanco).
- **Estado deshabilitado**: cuando la oferta está en estado `ACEPTADA`, `RECHAZADA` o `VENCIDA`. Placeholder: `"Chat cerrado."`.
- En mobile (`xs–md`): el teclado virtual empuja el input hacia arriba usando `env(safe-area-inset-bottom)`.

### CA-08 · Tiempo real — WebSocket

1. Al montar el componente: `join:offer:{offerId}`.
2. Nuevo mensaje del interlocutor → aparece con animación de entrada suave en el área de mensajes.
3. Si el usuario está en el chat con scroll al fondo: auto-scroll al nuevo mensaje.
4. Si el usuario ha hecho scroll hacia atrás (leyendo historial): el nuevo mensaje no hace auto-scroll. Aparece un indicador `"⬇ 1 mensaje nuevo"` para volver al fondo.
5. Al desmontar: `leave:offer:{offerId}`.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **El ejecutivo actualiza su oferta con una re-oferta (futuro)** | La tarjeta de contexto debe mostrar siempre los valores de la oferta vigente más reciente. Si hay re-oferta, los valores se actualizan en tiempo real. |
| EB-02 | **El usuario envía un mensaje y pierde conexión** | El mensaje queda en estado `✓` (enviado localmente). Al reconectar, el servidor confirma el envío o el cliente reintenta. Mostrar un indicador de "sin conexión" en el header del chat. |
| EB-03 | **Historial muy largo (>1000 mensajes)** | Paginación por cursor: al hacer scroll hacia arriba se carga más historial. No cargar todos los mensajes al abrir. |
| EB-04 | **El cliente abre múltiples chats al mismo tiempo** | En `lg+` el panel lateral solo muestra un chat a la vez. Al seleccionar otro chat se reemplaza el actual. La suscripción al WS del chat anterior se cancela antes de suscribirse al nuevo. |
| EB-05 | **Oferta vence mientras ambas partes están en el chat** | El evento `system:offer_expired` aparece en el chat. El input queda deshabilitado. El footer de acciones del cliente desaparece. |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- Como componente de `shared-utils`, `NegotiationChat` recibe solo `offerId` como `@Input`. Internamente carga los datos de la oferta y del historial. El componente no asume quién es el cliente y quién el ejecutivo — determina el rol comparando `session().user.id` con `oferta.clienteId`.
- La persistencia del estado de la tarjeta de contexto (colapsada/expandida) en `localStorage` usa la clave `chat_ctx_{offerId}`.
- El WebSocket del chat debe usar el mismo servicio WS global del shell (para no crear múltiples conexiones). Usar un `ChatService` singleton que gestione suscripciones por `offerId`.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 4 — mfe-publicador-facturas (compartido con Fase 5)*
