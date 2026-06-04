# HU-28 — KPIs del Cliente/Deudor (Sección 2) y Visor de Factura + OCR (Sección 3)

---

## Historia de Usuario (KPIs)

**Yo como** ejecutivo financiero,
**Quiero** ver métricas del cliente y del deudor al seleccionar una factura del marketplace,
**Para** evaluar el riesgo de la operación en segundos sin salir de la pantalla.

## Historia de Usuario (Visor PDF)

**Yo como** ejecutivo financiero,
**Quiero** leer el PDF de la factura directamente en pantalla junto a las notas del sistema OCR,
**Para** verificar visualmente los datos antes de comprometer una oferta.

---

## Contexto técnico

Estas dos secciones forman parte del layout del `mfe-ofertador-facturas` (ruta `/ofertador`). Se activan cuando el ejecutivo hace clic en una factura de la Columna 1 (HU-27).

- **Sección 2** (header de pantalla): visible al seleccionar una factura, arriba de las secciones 3 y 4.
- **Sección 3** (columna central, ~2/5 del ancho restante): visor de PDF + notas OCR.

Endpoints:
- `GET /api/core/marketplace/factura/:id` — datos completos + PDF URL + notas OCR
- `GET /api/core/ejecutivo/historial/:clienteId` — KPIs del historial del ejecutivo con ese cliente
- `GET /api/core/deudor/:rutDeudor/cupo` — datos de cupo del deudor

---

## Criterios de Aceptación — Sección 2: Header de KPIs

### CA-01 · Estado inicial del header

- **Antes de seleccionar una factura**: el header muestra un estado vacío o placeholder `"Selecciona una factura para ver los datos del cliente y deudor."`.
- **Al seleccionar**: se muestra un skeleton de carga y luego se puebla con los datos.

### CA-02 · Bloque A — KPIs del cliente y del deudor

| KPI | Fuente | Notas |
|-----|--------|-------|
| Nombre del cliente (cedente) | Perfil de la organización cedente | |
| RUT del cliente | Org cedente | |
| Nombre del deudor | Factura | |
| RUT del deudor | Factura | |
| Días al vencimiento | `fechaVencimiento − hoy` calculado en el cliente | Se actualiza cada minuto o al recibir evento WS |
| Operaciones cerradas con este ejecutivo | `GET /api/core/ejecutivo/historial/:clienteId` | Solo operaciones de **este** ejecutivo con este cliente |
| Monto promedio financiado | Ídem | Solo operaciones de este ejecutivo |
| Tasa promedio pactada | Ídem | Solo operaciones de este ejecutivo |

> **Regla de privacidad**: los KPIs históricos muestran **únicamente** datos de operaciones entre este ejecutivo y este cliente. Nunca se muestran datos de operaciones con otros ejecutivos.

- Si el ejecutivo no tiene historial con ese cliente: mostrar `"Primera operación con este cliente."` en lugar de los KPIs numéricos.
- **Calificación del deudor**: ❌ No implementar en MVP. El espacio puede reservarse con un placeholder `"Próximamente"`.

### CA-03 · Bloque B — Cupo del deudor

| Dato | Descripción |
|------|-------------|
| Cupo total asignado | Límite máximo habilitado para el deudor |
| Cupo disponible | `cupoTotal − cupoUtilizado` |
| Cupo utilizado | Monto en operaciones activas con este deudor |

Visualización sugerida: barra de progreso horizontal con el porcentaje de cupo utilizado + los tres valores debajo.

- Si `cupoDisponible < montoAnticipado` calculado en la Sección 4: se activa el `CupoExceededAlert` (CA-04).
- Los datos de cupo son sensibles — solo visibles para ejecutivos autenticados.

### CA-04 · Alerta de cupo excedido (`CupoExceededAlert`)

Se muestra como alerta inline en el bloque B del header cuando el monto anticipado calculado supera el cupo disponible del deudor:

```
⚠️ El monto anticipado ($X.XXX.XXX) supera el cupo disponible del deudor ($X.XXX.XXX).
   Reduce el % de anticipo para continuar.
```

- La alerta se actualiza en tiempo real a medida que el ejecutivo ajusta el % de anticipo en la Sección 4.
- Mientras la alerta está activa: el botón `"Enviar Oferta Firme"` (HU-30) queda deshabilitado.

---

## Criterios de Aceptación — Sección 3: Visor de Factura y Notas OCR

### CA-05 · Visor de PDF

- Visor de PDF **embebido** en la Sección 3 (no abre en nueva pestaña).
- El visor tiene scroll interno para facturas de múltiples páginas.
- Si no hay PDF disponible: empty state `"El cliente no adjuntó respaldo PDF."` con ícono de documento gris.
- Si el PDF está cargando: skeleton de la misma altura que el visor.

**Responsive:**

| Breakpoint | Comportamiento |
|------------|---------------|
| `lg+` | Columna central visible como sección fija. |
| `md` | El visor y las notas OCR se colapsan a un acordeón expandible `"Ver factura y notas OCR"`. |
| `xs–sm` | Pantalla separada accesible desde el flujo secuencial. |

### CA-06 · Notas OCR (solo lectura para el ejecutivo)

Las mismas notas que el cliente gestionó en el MFE publicador. El ejecutivo las ve como **segunda validación** de los datos de la factura.

Debajo del visor de PDF:

```
┌─────────────────────────────────────────────────────────┐
│  ⚠ Notas del sistema (2)                               │
│  ─────────────────────────────────────────────────────  │
│  Campo "RUT Deudor"                                     │
│  Se detectaron múltiples valores: 12.345.678-9 / ...    │
│  ─────────────────────────────────────────────────────  │
│  Campo "Número Factura"                                 │
│  El PDF indica #456, el formulario indica #123.         │
└─────────────────────────────────────────────────────────┘
```

- Las notas son de **solo lectura** para el ejecutivo (no puede descartarlas ni modificar los campos).
- Cada nota identifica el campo afectado y describe la incongruencia.
- Si no hay notas: no se muestra la sección (no renderizar el contenedor vacío).
- Reutiliza el componente `OcrNotesList` creado en la Fase 4 (HU-24), en modo `readOnly: true`.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **El ejecutivo selecciona una factura sin PDF** | El visor muestra el empty state. Las notas OCR tampoco existen en ese caso. El ejecutivo puede igualmente calcular y enviar una oferta (el PDF de respaldo es opcional para el cliente en el Caso 1). |
| EB-02 | **La factura tiene cupo del deudor en cero** | El bloque B muestra `cupoDisponible: $0` con la barra al 100%. La alerta de cupo excedido se activa de inmediato al seleccionar la factura, antes de que el ejecutivo toque la calculadora. |
| EB-03 | **El ejecutivo selecciona una factura diferente con el visor abierto** | El visor y las notas OCR se reemplazan con los datos de la nueva factura. Si hay un skeleton en el header mientras carga la nueva, el visor también muestra skeleton. |
| EB-04 | **Los KPIs de historial no cargan (error de red)** | Mostrar estado de error con retry en el bloque A. El bloque B (cupo) y el visor (Sección 3) no se ven afectados — son llamadas independientes. |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- El visor de PDF puede implementarse con un `<iframe>` apuntando a la URL firmada del PDF (presigned URL de MinIO/S3 sin `withCredentials`), o con una librería como `ng2-pdf-viewer`. Confirmar con el equipo la librería preferida.
- El componente `OcrNotesList` está definido en `shared-utils` (HU-24). En este contexto se usa con `@Input() readOnly: true` — sin el comportamiento de descarte de notas.
- Las tres llamadas de datos de la Sección 2 (factura, historial, cupo) pueden dispararse en paralelo al seleccionar la factura para reducir el tiempo de carga percibido.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 5 — mfe-ofertador-facturas*
