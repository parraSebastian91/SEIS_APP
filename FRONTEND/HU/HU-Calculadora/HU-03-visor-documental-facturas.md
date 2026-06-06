# HU-03 — Visor Documental de Facturas con Panzoom

---

## Historia de Usuario

**Yo como** Ejecutiva Financiera de la mesa de dinero,
**Quiero** poder visualizar el documento físico de la factura directamente en la pantalla, con capacidad de zoom y movimiento libre,
**Para** verificar visualmente los timbres, firmas y sellos de recepción del deudor sin necesidad de descargar el archivo ni abrir otra herramienta.

---

## Criterios de Aceptación

### CA-01 · Carga del documento al seleccionar factura
- Cuando la ejecutiva hace clic sobre una tarjeta del marketplace, el visor **debe cargar automáticamente** la imagen del documento de esa factura.
- Mientras el documento se descarga desde el almacenamiento, el sistema debe mostrar un **Skeleton Screen animado** (silueta gris parpadeante) para indicar que la carga está en progreso.
- Si la carga **falla**, se muestra un mensaje de error con botón para reintentar: `"No se pudo cargar el documento. Reintentar."`.

### CA-02 · Aspecto visual del lienzo
- El fondo del visor debe ser **gris oscuro (#1e1e1e)** para generar contraste con la factura blanca y reducir la fatiga visual durante jornadas largas.
- La factura se renderiza centrada al cargarse por primera vez.

### CA-03 · Control de zoom con rueda del mouse
- Girar la rueda del mouse hacia arriba: **acerca (zoom in)** centrado en la posición actual del cursor.
- Girar la rueda del mouse hacia abajo: **aleja (zoom out)** centrado en la posición actual del cursor.
- El zoom debe tener **límites**: no puede alejar más de la vista completa del documento ni acercar más de un nivel en que el texto resulte pixelado (ej: máximo 5x el tamaño original).

### CA-04 · Paneo libre del documento
- Al mantener presionado el **clic izquierdo del mouse y arrastrar**, el documento se mueve libremente dentro del lienzo (paneo).
- El cursor debe cambiar visualmente a un ícono de mano (`grab`) cuando se está paneando.

### CA-05 · Barra de herramientas flotante
- Siempre visible sobre el visor, en la **parte inferior central**, una barra con botones semitransparentes:
  - **Zoom +**: incrementa el zoom en un paso fijo.
  - **Zoom −**: reduce el zoom en un paso fijo.
  - **Reset View**: vuelve el documento al tamaño y posición originales (centrado, sin zoom).
  - **Rotar 90°**: rota el documento 90° en sentido horario con cada clic. Útil cuando el cliente subió la imagen en orientación incorrecta.

### CA-06 · Cambio de factura en el visor
- Cuando la ejecutiva selecciona una factura diferente en el listado, el visor **resetea automáticamente el zoom y la posición** antes de cargar el nuevo documento (no hereda el zoom de la factura anterior).

---

## Casos de Borde (Edge Cases) — Para validar con el equipo

| # | Escenario | Pregunta a resolver |
|---|---|---|
| EB-01 | **Documento multipágina** | ¿Las facturas pueden ser documentos de varias páginas (ej: PDF con 3 páginas)? Si es así, ¿el visor tiene controles de paginación? ¿O solo se muestra la primera página? |
| EB-02 | **Formato del archivo** | ¿El sistema siempre almacena las facturas como imágenes (JPG/PNG) o también acepta PDFs? El comportamiento del panzoom es diferente para cada formato. |
| EB-03 | **Documento demasiado grande** | Si la factura es una imagen de alta resolución (ej: 20 MB), ¿se sirve una versión comprimida para el visor y la original se descarga aparte? ¿Hay un límite de tamaño? |
| EB-04 | **Factura sin documento adjunto** | ¿Puede existir una factura en el marketplace que fue cargada sin imagen adjunta? ¿Qué muestra el visor en ese caso? |
| EB-05 | **Dispositivos táctiles** | ¿El sistema debe funcionar en tablets (pantallas táctiles) donde el paneo y zoom se hacen con gestos de pellizco (pinch-to-zoom) y no con mouse? |
| EB-06 | **Rotación y reset** | Si la ejecutiva rotó la imagen 90°, ¿al presionar "Reset View" también se deshace la rotación, o el reset solo aplica al zoom y posición? |
| EB-07 | **Expiración del enlace de descarga** | Si el enlace firmado (presigned URL) de MinIO expira mientras la ejecutiva está revisando el documento, ¿el sistema renueva el enlace automáticamente o muestra error? |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- Implementar con la librería **`@anvaka/panzoom`** (ya referenciada en la especificación funcional) o equivalente compatible con Angular.
- Los documentos se almacenan en **MinIO**. El backend debe proveer URLs firmadas de tiempo limitado para la descarga segura.
- El componente debe llamarse `app-image-viewer` según la nomenclatura definida en la especificación.

---

*Creada: 2026-05-18 | Estado: Por refinar | Equipo: Factor Fintech*
