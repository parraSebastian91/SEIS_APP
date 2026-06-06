# HU-22 — Lookup KYC SII al Registrar Organización

---

## Historia de Usuario

**Yo como** usuario que está creando una organización en la plataforma,
**Quiero** que al ingresar el RUT de la empresa se valide automáticamente contra el SII y se pre-rellene la razón social,
**Para** confirmar que la empresa existe y está habilitada para operar con Factura Electrónica, sin tener que salir de la plataforma ni ingresar datos que ya están registrados.

---

## Contexto técnico

Esta funcionalidad es una parte del Paso 1 del wizard de creación de organización (HU-19). Se documenta como HU separada por su peso técnico y por ser reutilizable en otros flujos futuros (ej. validación de deudor en el visor de facturas).

**Regla de seguridad crítica**: la llamada al endpoint del SII se realiza **exclusivamente desde el backend de Factor** (BFF o ms-core), nunca directamente desde el frontend. Esto evita:
- Exponer la URL del SII en el bundle del cliente.
- Ser bloqueados por CORS.
- Perder control de rate limiting y caché.

Endpoint del backend que el frontend llama:
```
GET /api/core/organizacion/sii/lookup?rut=77908337&dv=3
```

El BFF hace la llamada al SII, parsea la respuesta y devuelve un DTO simplificado.

---

## Criterios de Aceptación

### CA-01 · Trigger del lookup

- El lookup se dispara **al completar el campo RUT** con un DV válido (evento `blur` del campo + validación del dígito verificador).
- No se dispara al cada keystroke (evitar llamadas excesivas mientras el usuario escribe).
- No se dispara si el DV es inválido — mostrar primero el error de formato `"RUT inválido."`.
- No se dispara si el campo está vacío.

### CA-02 · Estado de carga (spinner)

- Mientras el lookup está en proceso: spinner inline en el campo RUT (reemplaza el ícono de estado).
- El botón `"Siguiente →"` queda deshabilitado mientras hay un lookup en curso.
- Timeout: si el backend no responde en 10 segundos, mostrar `"No se pudo consultar el SII en este momento. Puedes continuar igualmente."` y habilitar el avance.

### CA-03 · Resultado del lookup — UX visual

```
┌─────────────────────────────────────────────────────────┐
│  RUT empresa    [ 77.908.337 - 3 ]     ✅               │
│                                                         │
│  Razón Social   [ SEIS SPA           ]  ← pre-rellenado │
│                                           (editable)    │
│                                                         │
│  ✅ Contribuyente activo con Factura Electrónica.       │
└─────────────────────────────────────────────────────────┘
```

El bloque de resultado se muestra debajo del campo de RUT, dentro del Paso 1 del wizard.

### CA-04 · Estados posibles del lookup y comportamiento

| Condición de la respuesta | Estado visual | Mensaje | ¿Bloquea avance? |
|--------------------------|:-------------:|---------|:----------------:|
| `registrado: false` | ❌ Rojo | "RUT no encontrado en el SII. Verifica el número ingresado." | ✅ Sí |
| `inicioActividades: false` | ❌ Rojo | "Este RUT no tiene inicio de actividades en el SII." | ✅ Sí |
| Sin timbraje `"0033"` | ⚠️ Amarillo | "Este RUT no tiene habilitada la emisión de Facturas Electrónicas. Debes tramitarlo en el SII antes de operar en Factor." | ✅ Sí |
| `cumpleObligacionTributaria: "NO"` | ⚠️ Amarillo | "Este RUT tiene observaciones tributarias en el SII. Puedes continuar, pero tu cuenta quedará sujeta a revisión." | ❌ No — permite continuar con advertencia |
| Todo válido | ✅ Verde | "Contribuyente activo con Factura Electrónica." | ❌ No |
| Error de red / timeout | 🔵 Info | "No se pudo consultar el SII en este momento. Puedes continuar igualmente." | ❌ No |

### CA-05 · Pre-relleno de la razón social

- Si el lookup devuelve `nombre`, se pre-rellena automáticamente en el campo `Razón social`.
- El campo permanece **editable** — el usuario puede corregirlo si hay discrepancia (ej. nombre abreviado vs. razón social legal completa).
- Si el usuario ya había ingresado una razón social manualmente antes del lookup: mostrar el valor del SII en un hint `"El SII registra: NOMBRE SII"` sin sobreescribir lo que el usuario escribió. El usuario puede hacer clic para aceptar el valor sugerido.

### CA-06 · Caché del resultado

- Si el usuario ingresa el mismo RUT dos veces en la misma sesión del wizard: no volver a llamar al backend. Usar el resultado cacheado en el estado del formulario.
- No cachear resultados de error — si hay un error de red, el próximo blur debe volver a intentar.

### CA-07 · Máscara del campo RUT

- Formato de display: `XX.XXX.XXX-X` con puntos y guión.
- El usuario puede escribir con o sin puntos — el campo formatea automáticamente.
- El RUT se envía al backend **sin puntos y sin guión**: `{rut: "77908337", dv: "3"}`.
- Validación del DV: algoritmo módulo 11 estándar chileno.

---

## Datos expuestos en el perfil de la organización

Campos de la respuesta del SII que se usan más allá del wizard:

| Campo SII | Dónde se usa |
|-----------|-------------|
| `nombre` | Pre-rellena la razón social. Se guarda como `Organization.razonSocial`. |
| `girosNegocio[].descripcion` | Lista de rubros mostrada en el perfil de org (§9.4). Guardada en `Organization.girosNegocio`. |
| `fechaInicioActividades` | Dato informativo — mostrado en la tarjeta de datos de la empresa (§9.4). |
| `cumpleObligacionTributaria` | Si es `"NO"`, marca la org con flag `observacionTributaria: true` (procesado por el backend). |

---

## Contrato del DTO — Respuesta del BFF al frontend

```typescript
interface SiiLookupResult {
  estado: 'VALIDO' | 'ADVERTENCIA' | 'BLOQUEADO' | 'NO_ENCONTRADO' | 'ERROR_RED';
  mensaje: string;                   // Texto listo para mostrar al usuario
  razonSocial?: string;              // Presente si el RUT fue encontrado
  girosNegocio?: string[];           // Descripciones de los rubros
  fechaInicioActividades?: string;   // ISO date string
  tieneFacturaElectronica?: boolean;
  tieneObservacionTributaria?: boolean;
}
```

El frontend no interpreta la respuesta raw del SII — el BFF mapea todo a este DTO. Esto permite que si el SII cambia su API, solo el backend necesita actualizarse.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **RUT de persona natural en lugar de empresa** | Las personas naturales también tienen RUT y pueden tener inicio de actividades en el SII. ¿Se permite registrar una org con RUT persona natural? Confirmar con negocio. Por ahora: el wizard no lo bloquea — el BFF puede agregar una validación si el RUT pertenece a una persona natural. |
| EB-02 | **RUT con cumplimiento tributario `"NO"` y sin timbraje 0033`** | Se aplican ambas condiciones. La condición ❌ (sin timbraje) bloquea sobre la condición ⚠️ (tributaria). Mostrar solo el mensaje bloqueante. |
| EB-03 | **El SII está caído** | El backend debe capturar el error de red o HTTP 5xx del SII y devolver `estado: "ERROR_RED"` al frontend. El usuario puede continuar (no bloquear por falla del SII). |
| EB-04 | **RUT ya registrado en la plataforma** | El lookup SII no sabe si el RUT ya existe en Factor. Esta validación la hace el backend al intentar crear la organización (Paso 1 del wizard). Son dos validaciones separadas. |
| EB-05 | **Cambio de API del SII** | Monitorear: el campo `reToken` se envía como espacio en blanco actualmente. Si el SII activa reCAPTCHA, la integración se romperá. El equipo de backend debe tener una alerta de monitoreo sobre el endpoint del SII. |

---

## Notas para el Equipo Técnico *(No es criterio de aceptación)*

- El BFF debe implementar caché por RUT (TTL: 24h) para no sobrecargar el SII con lookups repetidos del mismo RUT en diferentes sesiones.
- El BFF debe implementar rate limiting: máximo N lookups por IP/minuto para evitar abuso.
- Esta funcionalidad de lookup puede reutilizarse en el visor documental (HU-04, Fase 5) para validar el deudor de una factura antes de publicarla.

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 3 — mfe-gestion-usuario*
