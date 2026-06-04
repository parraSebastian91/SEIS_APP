# HU-19 — Wizard de Creación de Organización (Cedente y Financiera)

---

## Historia de Usuario

**Yo como** usuario recién registrado que aún no pertenece a ninguna organización,
**Quiero** crear mi organización siguiendo un wizard guiado de 4 pasos con guardado incremental,
**Para** poder operar en la plataforma como cedente (cliente) o como ejecutivo (financiera) sin perder progreso si interrumpo el proceso.

---

## Contexto técnico

El wizard vive en `mfe-gestion-usuario` bajo la ruta `/usuario/organizaciones/nueva`. Es el mismo wizard para cedentes y financieras — el tipo de participación (`tipoParticipacion`) se determina automáticamente desde el rol del usuario autenticado. El paso 3 tiene una pequeña variación según el tipo (ver CA-05).

Guardado incremental: cada paso completado persiste en el backend — si el usuario cierra el navegador y vuelve, el wizard retoma desde donde lo dejó.

---

## Criterios de Aceptación

### CA-01 · Estructura del wizard

- **Stepper horizontal** en `lg+` con 4 pasos numerados y labels.
- **Stepper vertical** en `xs–md`.
- Indicador de progreso: paso actual marcado como activo, pasos completados con check `✓`, pasos futuros en gris.
- CTA por paso: `"Siguiente →"` (avanzar) + `"← Anterior"` (retroceder sin perder datos).
- Los pasos anteriores permanecen editables — el usuario puede volver sin perder lo que llenó.
- Guardado automático al avanzar al siguiente paso (no solo al finalizar).

| Paso | Título | Bloqueante |
|------|--------|-----------|
| 1 | Identidad legal | ✅ Requerido |
| 2 | Dirección tributaria | ✅ Requerido |
| 3 | Cuenta bancaria / Contacto operativo | ✅ Requerido para operar |
| 4 | Presentación | ❌ Opcional (`"Completar después"`) |

### CA-02 · Paso 1 — Identidad legal

Campos:

| Campo | Tipo | Requerido | Notas |
|-------|------|-----------|-------|
| RUT empresa | Input con máscara `XX.XXX.XXX-X` | ✅ | Al completar DV válido → dispara lookup SII (HU-22) |
| Razón social | Input texto | ✅ | Pre-rellenado desde SII. Editable. |

- **Máscara RUT**: formateo automático mientras el usuario escribe. Valida dígito verificador antes de llamar al SII.
- **Resultado del lookup SII** embebido debajo del campo RUT (ver HU-22 para detalle completo):
  - ✅ Verde: `"Contribuyente activo con Factura Electrónica."` + razón social pre-rellenada.
  - ⚠️ Amarillo: advertencia tributaria — permite continuar.
  - ❌ Rojo: bloquea el avance al siguiente paso.
- Spinner inline en el campo RUT mientras el lookup está en curso.

### CA-03 · Paso 2 — Dirección tributaria

Formulario de dirección con todos los campos del modelo:

| Campo | Tipo | Requerido |
|-------|------|-----------|
| Calle | Texto | ✅ |
| Número | Texto | ✅ |
| Depto / Oficina | Texto | ❌ |
| País | Select | ✅ |
| Región | Select (depende de País) | ✅ |
| Provincia | Select (depende de Región) | ✅ |
| Ciudad | Texto | ✅ |
| Comuna | Select (depende de Provincia) | ✅ |
| Código postal | Texto | ❌ |
| Referencia | Textarea | ❌ |
| Tipo de dirección | Enum pre-seleccionado como `TRIBUTARIA` | ✅ |

- Los selects de región/provincia/comuna son **dependientes en cascada**: al cambiar País se vacían y recargan Región, y así sucesivamente.
- `tipo_direccion` viene pre-seleccionado como `TRIBUTARIA` y puede cambiarse (opciones: `TRIBUTARIA`, `CASA_MATRIZ`, `SUCURSAL`, `BODEGA`, `ATENCION`).
- Al completar el paso: texto informativo `"Podrás agregar más direcciones desde el perfil de tu organización."`.

### CA-04 · Paso 3a — Cuenta bancaria (Cedente, `tipoParticipacion: CEDENTE`)

> *"Para recibir los fondos al ceder tus facturas"* — mostrar este texto explicativo junto al formulario.

| Campo | Tipo | Notas |
|-------|------|-------|
| Banco | Select con logos de bancos chilenos | Lista configurable |
| Tipo de cuenta | Select: `Corriente` / `Vista` / `Ahorro` | |
| Número de cuenta | Input numérico | Solo dígitos |
| Nombre del titular | Texto | Puede diferir del RUT de la empresa |
| RUT del titular | Input con máscara `XX.XXX.XXX-X` | Valida DV |

- El titular puede ser una persona natural o jurídica distinta a la empresa. Mostrar hint: `"La cuenta no necesita estar a nombre de la empresa."`.

### CA-05 · Paso 3b — Contacto operativo (Financiera, `tipoParticipacion: FINANCIERA`)

> Financieras no necesitan cuenta bancaria para recibir pagos en esta versión. En su lugar se registran datos de contacto operativo.

| Campo | Tipo | Requerido |
|-------|------|-----------|
| Teléfono operaciones | Input `+56...` | ✅ |
| Email operaciones | Input email | ✅ |

> ⚠️ El detalle completo de este paso para financieras queda pendiente de definición con el equipo de negocio. Los campos anteriores son una propuesta inicial.

### CA-06 · Paso 4 — Presentación (opcional)

| Campo | Tipo |
|-------|------|
| Logo | Dropzone / input file. `image/*`, máx 5 MB |
| Banner | Dropzone / input file. `image/*`, máx 5 MB |
| Descripción | Textarea libre |

- CTA principal: `"Finalizar"` — guarda los datos y redirige al perfil de la nueva organización.
- CTA secundario: `"Completar después"` — guarda los pasos 1–3 y crea la organización en estado `ONBOARDING_INCOMPLETO`. Redirige al perfil de org igualmente.
- Subida de logo y banner vía presigned URL (mismo flujo que HU-18 CA-05/CA-06 con `objectType = ORG_LOGO` / `ORG_BANNER`).

### CA-07 · Guardado incremental y recuperación de progreso

- Al avanzar cada paso: `POST` o `PATCH` al endpoint de creación de org con los datos del paso actual.
- Si el usuario sale y vuelve a `/usuario/organizaciones/nueva`: verificar si existe un org en estado `ONBOARDING_INCOMPLETO` → retomar el wizard en el último paso guardado.
- Si no hay org en progreso: iniciar wizard desde el paso 1.

### CA-08 · Determinación automática del tipo de participación

- El wizard **no pregunta** el tipo de organización al usuario.
- Se determina desde el rol del usuario autenticado:

| Rol del usuario | `tipoParticipacion` |
|-----------------|:-----------------:|
| `CLIENTE_CEDENTE`, `ADMIN_CEDENTE` | `CEDENTE` |
| `EJECUTIVO_FINANCIADORA`, `ADMIN_FINANCIADORA` | `FINANCIERA` |
| `ADMIN_BROKER`, `EJECUTIVO_BROKER` | `BROKER` |

- El tipo se envía automáticamente al backend en el Paso 1.

### CA-09 · Listado de organizaciones del usuario

Antes de mostrar el botón `"Crear organización"`, verificar si el usuario ya tiene organizaciones:
- Si tiene: mostrar listado de sus orgs con botón para crear una nueva (cedentes pueden tener múltiples).
- Si no tiene: mostrar directamente el CTA de creación.

Ruta del listado: `/usuario/organizaciones`.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **RUT de empresa ya registrado en la plataforma** | ¿El backend devuelve error si el RUT ya tiene una org? Si es así, mostrar mensaje: `"Ya existe una organización con ese RUT en la plataforma. Si perteneces a ella, solicita unirte desde su perfil."` |
| EB-02 | **El usuario abandona en el Paso 2** | La org queda en estado `ONBOARDING_INCOMPLETO` con solo el RUT y razón social guardados. Al volver, retoma desde Paso 2. |
| EB-03 | **Cascada de selects región/provincia/comuna** | Si los datos de geolocación chilena son extensos, considerar lazy loading de las opciones de select al cambiar el nivel superior (no cargar todas las comunas del país al inicio). |
| EB-04 | **Cuenta bancaria con RUT de persona natural** | El RUT del titular puede ser de formato persona natural (con DV de letra, ej. `12.345.678-9`). El validador de DV debe cubrir ambos formatos. |
| EB-05 | **`tipoParticipacion: BROKER`** | El flujo de BROKER no está completamente definido. Si el usuario tiene rol `ADMIN_BROKER` o `EJECUTIVO_BROKER`, mostrar el wizard genérico con `tipoParticipacion: BROKER` y sin paso 3 específico hasta que se defina. |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- Los selects de bancos chilenos deben cargarse desde el backend (no hardcodeados en el frontend) para facilitar actualizaciones.
- Los selects de región/provincia/comuna pueden usar la API de geolocación pública de Chile o un endpoint del BFF que los sirva. Confirmar con el equipo backend cuál es la fuente.
- El wizard usa el mismo formulario de dirección que se reutilizará en §9.4 (perfil de org) para agregar más direcciones. Extraer el formulario de dirección como componente reutilizable (`AddressForm`) en `shared-utils`.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 3 — mfe-gestion-usuario*
