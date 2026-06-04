# HU-24 — Lista de Facturas y Componente `factura-view`

---

## Historia de Usuario

**Yo como** cliente cedente (`CLIENTE_CEDENTE` o `ADMIN_CEDENTE`),
**Quiero** ver todas mis facturas como paneles expandibles con su estado actual, editar los datos y tomar acciones directamente desde la lista,
**Para** gestionar el ciclo de vida de mis operaciones sin necesidad de navegar a páginas separadas.

---

## Contexto técnico

Esta es la pantalla principal del `mfe-publicador-facturas`, accesible en la ruta `/publicador`. La pantalla carga en cuanto el usuario autenticado con rol cedente accede al Portal.

El `factura-view` es el componente central — un expansion panel con 2 estados (colapsado/expandido). El formulario editable de campos es in-place (no navega a otra ruta para editar).

Endpoints:
- `GET /api/core/factura?page=N&size=N&estado[]=...` — lista paginada con filtros
- `PATCH /api/core/factura/:id/campo` — actualizar un campo individual de la factura
- `DELETE /api/core/factura/:id` — eliminar una factura en `PENDIENTE_AUTORIZACION` o `RECHAZADA`
- Suscripción SSE/WS: canal `usuario:{userId}` para recibir eventos de OCR completado, cambios de estado, nuevas ofertas

---

## Criterios de Aceptación

### CA-01 · Layout de la lista

- Lista vertical de `factura-view` en expansion panels.
- Orden por defecto: más reciente primero (`createdAt DESC`).
- Paginación: cargar más al hacer scroll (infinite scroll) o botón `"Cargar más"`.
- **Barra de acciones superior**:
  - Botón `"+ Nueva Factura"` — abre el `InvoiceUploadModal` (HU-23).
  - Chips de filtro por estado (selección múltiple): `PROCESANDO` · `PENDIENTE_AUTORIZACION` · `PUBLICADA` · `FINANCIADA` · `RECHAZADA` · `VENCIDA`. Chip `"Todas"` para limpiar filtros.
- **Empty state** (ninguna factura): icono de documento + texto `"Aún no tienes facturas. ¡Sube tu primera factura para comenzar!"` + botón `"+ Nueva Factura"`.

### CA-02 · Suscripción a eventos en tiempo real

Al montar el componente `InvoiceList`:
- Suscribirse al canal del usuario (SSE o WebSocket).
- Eventos que se manejan:
  - `factura.ocr_completado`: actualiza la `factura-view` skeleton con los datos reales + notas OCR.
  - `factura.estado_cambiado`: actualiza el badge de estado en la `factura-view` correspondiente con animación pulse.
  - `oferta.nueva`: actualiza el `OfferNotificationIcon` en la `factura-view` correspondiente.
- Al desmontar el componente: cancelar la suscripción.

### CA-03 · `factura-view` — Estado colapsado (header del panel)

```
┌─────────────────────────────────────────────────────────┐
│  ● PUBLICADA   #00123   Razón Social Deudor   [🔔]  [▼] │
└─────────────────────────────────────────────────────────┘
```

- **`InvoiceStatusBadge`**: color dinámico según el estado. Animación pulse al cambiar de estado. Pulse continuo mientras está en `PROCESANDO`.

| Estado | Color sugerido |
|--------|---------------|
| `PROCESANDO` | Azul (pulse continuo) |
| `PENDIENTE_AUTORIZACION` | Amarillo |
| `PUBLICADA` | Verde |
| `FINANCIADA` | Púrpura |
| `RECHAZADA` | Rojo |
| `VENCIDA` | Gris |

- **Número de factura** (folio).
- **Razón social del deudor**.
- **`OfferNotificationIcon`** (`🔔`): visible solo si existen ofertas nuevas no revisadas. Al hacer clic: despliega el sidebar de notificaciones de la factura.
- **Chevron** `[▼]`/`[▲]` para expandir/colapsar.

### CA-04 · `factura-view` — Estado expandido: encabezado

Al expandir el panel, se muestra un encabezado dentro del contenido:

```
Factura: #00123  │  Nombre Cedente · RUT Cedente · Gestor: usuario_gestor
```

- `Gestor` es el usuario que subió la factura al sistema (puede ser diferente al usuario autenticado en organizaciones con múltiples usuarios).

### CA-05 · `factura-view` — Formulario editable (tabla de campos)

**Layout en `lg+` si hay imagen disponible:**
```
[ Imagen de la factura (1/2) ]  │  [ Tabla de campos (1/2) ]
```
**Layout sin imagen o en `xs–md`:** solo la tabla a ancho completo.

La tabla contiene los siguientes campos:

| Campo | Control | Editable en estados |
|-------|---------|:------------------:|
| N° Factura | Input texto | `PENDIENTE_VALIDACION`, `PENDIENTE_AUTORIZACION`, `RECHAZADA` |
| RUT Deudor | Input con máscara `XX.XXX.XXX-X` | Ídem |
| Razón Social Deudor | Input texto | Ídem |
| Monto Total | Input numérico con máscara CLP | Ídem |
| Fecha Vencimiento | Datepicker | Ídem |

En todos los demás estados los campos son **solo lectura**.

**Comportamiento del control `SmartField`:**
- Si el backend devuelve múltiples valores posibles para un campo (ej. `"dato1;dato2"` del OCR): el control renderiza un `<select>` con las opciones en lugar de un input.
- El datepicker para Fecha Vencimiento no permite seleccionar fechas pasadas.
- El input de Monto Total solo acepta dígitos. Se formatea automáticamente con separadores de miles y prefijo `$`.

**Comportamiento de edición por fila:**
- Al hacer clic en una fila (o en un botón de lápiz `✏` al final de la fila): la fila entra en modo edición.
- Aparecen dos botones en la columna de acción: `✓ Guardar` y `✕ Cancelar`.
- Al guardar: `PATCH /api/core/factura/:id/campo` con `{campo, valor}` → spinner en el botón → al éxito: la fila vuelve a modo lectura con el nuevo valor.
- Al cancelar: la fila vuelve a modo lectura con el valor anterior sin llamar al backend.
- Solo puede haber **una fila en modo edición** al mismo tiempo.

**Destacado visual de filas con nota OCR pendiente:**
- Las filas que tienen una nota OCR no atendida tienen un fondo de color de alerta (ej. amarillo suave).
- El fondo de alerta desaparece en cuanto el usuario interactúa con el campo (entra en modo edición), independientemente del valor que guarde. El ejecutivo hará la segunda validación.

### CA-06 · `factura-view` — Sección de Notas OCR

Visible debajo de la tabla de campos mientras existan notas pendientes.

```
┌─────────────────────────────────────────────────────────────┐
│  ⚠ Notas del sistema (2 pendientes)                        │
│  ─────────────────────────────────────────────────────────  │
│  Campo "RUT Deudor"                                         │
│  Se detectaron múltiples valores: 12.345.678-9 / 98.765.432-1 │
│  Selecciona el valor correcto.                              │
│  ─────────────────────────────────────────────────────────  │
│  Campo "Número Factura"                                     │
│  El formulario indica #123 pero el PDF muestra #456.        │
│  Verifica el valor correcto.                                │
└─────────────────────────────────────────────────────────────┘
```

- Cada nota identifica el campo afectado y describe la incongruencia.
- Una nota se descarta visualmente cuando el usuario modifica el campo asociado.
- Cuando no quedan notas pendientes: la sección se oculta completamente.

### CA-07 · `factura-view` — Footer del panel (botón de acción principal)

| Estado de la factura | Texto del botón | Condición de habilitación | Acción al pulsar |
|----------------------|-----------------|:------------------------:|-----------------|
| `PENDIENTE_AUTORIZACION` con notas OCR pendientes | "Validar y publicar" | ❌ Deshabilitado | — |
| `PENDIENTE_AUTORIZACION` sin notas OCR pendientes | "Validar y publicar" | ✅ | Abre `TermsAndConditionsModal` (HU-25) |
| `RECHAZADA` | "Corregir y reenviar" | ✅ | Habilita edición de campos + permite re-envío |
| Resto de estados | — | — | Botón oculto |

> **Nota**: en el Caso 1 (formulario sin respaldo), el `TermsAndConditionsModal` se levanta automáticamente desde el flujo de creación (ver HU-23). El footer en `PENDIENTE_AUTORIZACION` aplica a los Casos 2 y 3 donde el cliente debe revisar datos OCR primero.

### CA-08 · `factura-view` — Botones de acciones secundarias

Tres botones debajo del formulario:

| # | Botón | Condición de habilitación | Acción |
|---|-------|:------------------------:|--------|
| 1 | `📄 Ver foto` | Existe imagen adjunta | En `lg+`: divide la vista en 2 columnas (imagen + tabla). En `xs–md`: abre la imagen en pantalla completa. |
| 2 | `📎 Subir respaldo` | La factura fue subida por formulario manual (Caso 1 o 2) o por agente (futuro). Deshabilitado si fue por OCR automático (Caso 3). | Abre un dropzone inline para reemplazar o agregar el PDF de respaldo. |
| 3 | `🔔 Notificaciones` | Siempre visible | Abre el `InvoiceNotificationSidebar` (ver CA-09). Muestra badge numérico si hay notificaciones no leídas. |

### CA-09 · `InvoiceNotificationSidebar` (panel lateral)

Panel lateral deslizante (`position: fixed; right: 0`) con las notificaciones de la factura. Organizado en secciones:

**Sección "Ofertas"**: lista de ofertas recibidas con:
- Avatar + nombre del ejecutivo.
- Nombre de la financiera.
- Monto de anticipo + tasa.
- Estado de la oferta (badge).
- Botón `"Ver oferta"` que navega a `/publicador/factura/:id` (HU-25).

**Sección "Actividad"**: timeline de cambios de estado de la factura:
- Cada evento: icono de estado + texto descriptivo + timestamp relativo (ej. `"Hace 2 horas"`).

**Sección "Mensajes"**: lista de hilos de chat (uno por oferta con mensajes):
- Avatar del ejecutivo + nombre + último mensaje + hora.
- Badge de mensajes no leídos.

- Al abrir el sidebar: las notificaciones de esta factura se marcan como leídas (el badge del botón 3 desaparece).
- Botón `[✕]` o clic fuera del panel para cerrar.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **`factura-view` en skeleton por más de 5 minutos** | Ver HU-23 EB-02. El skeleton debe tener un timeout y mostrar un estado de error recuperable. |
| EB-02 | **El usuario edita un campo mientras otro usuario de la misma org lo edita simultáneamente** | El backend devuelve el nuevo valor al guardar — la fila se actualiza con el valor guardado. No se requiere detección de conflictos en MVP. |
| EB-03 | **Paginación + nuevas facturas en tiempo real** | Si llega un evento `factura.ocr_completado` para una factura que está en página 2 (no visible), ¿se actualiza igual? Sí — el estado del componente se actualiza por ID aunque no esté visible. |
| EB-04 | **El cliente tiene 0 facturas (primer acceso)** | Mostrar empty state con CTA de subida. Nunca mostrar una lista vacía sin orientación. |
| EB-05 | **Múltiples facturas en `PROCESANDO` al mismo tiempo** | Cada skeleton es independiente. Los eventos SSE/WS se correlacionan por `facturaId`. |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- El `SmartField` debe ser un componente standalone reutilizable. Su lógica de adaptación (input / select / datepicker) se controla por el tipo del campo y la presencia del separador `";"` en el valor devuelto por el OCR.
- El `PATCH /api/core/factura/:id/campo` actualiza de a un campo — no es un PUT completo de la factura. Esto permite que el backend valide individualmente y devuelva errores específicos por campo.
- El sidebar de notificaciones (`InvoiceNotificationSidebar`) reutiliza el modelo de `NotificationItem` del sistema de notificaciones global (§10), pero filtrado por `facturaId`.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 4 — mfe-publicador-facturas*
