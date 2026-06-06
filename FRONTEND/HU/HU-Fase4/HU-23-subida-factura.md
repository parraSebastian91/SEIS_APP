# HU-23 — Subida de Factura (Modal con Flujos OCR y Manual)

---

## Historia de Usuario

**Yo como** cliente cedente (`CLIENTE_CEDENTE` o `ADMIN_CEDENTE`),
**Quiero** subir una factura para financiamiento usando un modal con dos vías (automática por PDF o manual por formulario),
**Para** iniciar el proceso de factoring sin importar si tengo el PDF disponible en ese momento.

---

## Contexto técnico

Este modal vive en `mfe-publicador-facturas` y se activa desde el botón `"+ Nueva Factura"` en la lista de facturas (HU-24). Es el punto de entrada para las 3 variantes del flujo de publicación:

| Caso | Vía | PDF en Paso 1 | OCR |
|------|-----|:-------------:|:---:|
| **Caso 1** | Manual sin respaldo | ❌ | ❌ |
| **Caso 2** | Manual con respaldo | ✅ (opcional en Paso 2) | ✅ |
| **Caso 3** | Automática | ✅ (requerido) | ✅ |

Endpoints:
- `POST /api/core/factura` — crea el registro de factura (manual y automática)
- `PUT /api/core/factura/:id/archivo` — sube el PDF de respaldo (presigned URL)
- `GET /api/core/factura/tnc` — obtiene el contenido de T&C para el modal de aceptación

El backend emite eventos SSE/WebSocket al canal del usuario cuando el OCR finaliza. El frontend se suscribe a este canal al abrir la lista de facturas, no al abrir el modal.

---

## Criterios de Aceptación

### CA-01 · Apertura y cierre del modal

- El modal se abre desde el botón `"+ Nueva Factura"` en la lista de facturas.
- **Responsive**:
  - `xs–md`: Full Screen (100% viewport, `position: fixed; inset: 0`).
  - `md+`: ventana centrada con overlay de fondo oscuro.
- Al cerrar (`[✕]` o `Escape`): si hay datos ingresados, mostrar confirmación inline `"¿Abandonar la factura? Los datos no se guardarán."` → CTA `"Sí, abandonar"` / `"Continuar editando"`.
- El modal tiene **dos pestañas** en el encabezado: `"Automática"` y `"Manual"`.

### CA-02 · Pestaña Automática — Caso 3 (OCR desde PDF)

**Flujo:**

1. Área de `DropzoneUploader`:
   - Acepta solo archivos `application/pdf`.
   - Tamaño máximo: 10 MB.
   - Soporta drag & drop y clic para abrir el file picker.
   - Muestra hint: `"Arrastra tu factura aquí o haz clic para seleccionar (PDF, máx. 10 MB)."`.

2. Al seleccionar un archivo válido:
   - Muestra el nombre del archivo con preview de tamaño.
   - Botón `"Subir factura"` se habilita.

3. Al confirmar la subida:
   - `POST /api/core/factura` con el PDF (multipart/form-data).
   - El modal **se cierra inmediatamente** — sin esperar a que el OCR finalice.
   - En la lista de facturas aparece una nueva `factura-view` en estado skeleton (`PROCESANDO`).

4. Si el PDF no es legible o el backend detecta que no es una factura:
   - El modal permanece abierto con el mensaje de error y un CTA para elegir otro archivo o cambiar a la pestaña Manual.

**Validaciones:**
- Solo PDF. Si el usuario sube un archivo que no es PDF: `"Solo se aceptan archivos en formato PDF."`.
- Si el PDF excede 10 MB: `"El archivo supera el límite de 10 MB."`.

### CA-03 · Pestaña Manual — Paso 1: Formulario de datos

El formulario contiene:

| Campo | Control | Validación |
|-------|---------|-----------|
| N° Factura (folio) | Input texto | Requerido |
| RUT Deudor | Input con máscara `XX.XXX.XXX-X` | Requerido. Valida DV. |
| Razón Social Deudor | Input texto | Requerido |
| Monto Total | Input numérico con máscara CLP | Requerido. Solo positivos. |
| Fecha Emisión | Datepicker | Requerido. No puede ser futura. |
| Fecha Vencimiento | Datepicker | Requerido. Debe ser posterior a Fecha Emisión. |

- CTA `"Siguiente →"` avanza al Paso 2.
- CTA `"← Anterior"` desde Paso 2 vuelve al formulario sin perder los datos.

### CA-04 · Pestaña Manual — Paso 2: Respaldo PDF (opcional)

- Muestra el mismo `DropzoneUploader` del Caso 3 con las mismas validaciones.
- El paso es **opcional**: CTA secundario `"Publicar sin respaldo"` permite saltar este paso.
- CTA principal `"Publicar con respaldo"` sube el PDF junto con los datos.

**Flujo Caso 1 (sin respaldo) al confirmar:**
1. `POST /api/core/factura` con los datos del formulario.
2. Al recibir respuesta exitosa (201), el modal se cierra y se levanta inmediatamente el `TermsAndConditionsModal` (HU-25).
3. La factura queda en `PENDIENTE_AUTORIZACION`.
4. Si el cliente cancela el T&C: el modal se cierra, la factura permanece en `PENDIENTE_AUTORIZACION` y aparece en la lista.

**Flujo Caso 2 (con respaldo) al confirmar:**
1. `POST /api/core/factura` con los datos.
2. `PUT /api/core/factura/:id/archivo` con el PDF (presigned URL).
3. El modal se cierra. En la lista aparece la factura en skeleton `PROCESANDO`.
4. Al recibir el evento SSE/WS del backend con el resultado del OCR: la tarjeta sale del skeleton mostrando los datos y las notas de discrepancia.
5. El cliente revisa, resuelve las notas OCR y luego pulsa el botón del footer de `factura-view` para levantar el T&C.

### CA-05 · Comportamiento del stepper (Pestaña Manual)

- Stepper con 2 pasos claramente indicados: `"1 · Datos"` / `"2 · Respaldo PDF"`.
- El botón `"Siguiente"` del Paso 1 está deshabilitado hasta que todos los campos requeridos sean válidos.
- Los campos inválidos muestran su mensaje de error al hacer clic en `"Siguiente"` (no al escribir, para no molestar al usuario mientras teclea).
- Al regresar al Paso 1, los datos del formulario se conservan.

### CA-06 · Indicadores de carga durante la subida

- Al confirmar la subida (cualquier caso): los botones de acción muestran spinner y se deshabilitan.
- El mensaje de carga varía por caso:
  - Caso 1: `"Creando factura..."` (muy rápido).
  - Caso 2 y 3: `"Subiendo PDF..."` → `"Procesando..."` (el modal se cierra antes de que el OCR termine).

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **Error de red al crear la factura** | El modal permanece abierto con el mensaje de error en la parte inferior y los botones rehabilitados para reintentar. |
| EB-02 | **El evento SSE/WS del OCR nunca llega** | Después de X minutos (configurable en el cliente, sugerido: 5 min), la tarjeta skeleton muestra un estado de error `"No se pudo procesar el PDF. Verifica que sea una factura válida o ingresa los datos manualmente."` con CTA para abrir el modal manual con el folio pre-rellenado si pudo extraerse. |
| EB-03 | **El usuario cambia de pestaña (Automática ↔ Manual) con datos ingresados** | Los datos del formulario manual se conservan al cambiar de pestaña. El archivo seleccionado en Automática se descarta si el usuario cambia a Manual sin haber subido. |
| EB-04 | **Subida de archivo en Paso 2 después de que el backend falla** | Si el `PUT` del PDF falla pero el `POST` de los datos ya tuvo éxito: la factura existe en `PENDIENTE_AUTORIZACION` sin PDF. Mostrar el error y dejar la factura en la lista — el usuario puede subir el respaldo desde el botón de `factura-view`. |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- El `DropzoneUploader` es un componente reutilizable que aparece tanto en la Pestaña Automática como en el Paso 2 de la Pestaña Manual. Debe aceptar como `@Input` el tipo de archivo aceptado, el tamaño máximo y los mensajes de error.
- La suscripción SSE/WS para recibir el resultado del OCR **no se gestiona dentro del modal** — se gestiona en el nivel del componente de lista (`InvoiceList`). El modal solo hace el POST y cierra.
- El `TermsAndConditionsModal` (HU-25) se levanta desde el componente padre (`InvoiceList`) al recibir la respuesta exitosa del POST del Caso 1 — el modal de subida ya estará cerrado en ese momento.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 4 — mfe-publicador-facturas*
