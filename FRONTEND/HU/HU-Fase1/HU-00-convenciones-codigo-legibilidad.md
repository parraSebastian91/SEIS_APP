# HU-00 — Convenciones de Código: Legibilidad y Baja Carga Cognitiva

> **Fase**: 1 — Fundamentos | **Aplica a**: todos los proyectos del monorepo `seis-app-frontend` | **Tipo**: HU de infraestructura de equipo

---

## Historia de Usuario

**Yo como** desarrollador del equipo frontend,
**Quiero** que el código del proyecto siga convenciones explícitas de nombrado y estructura,
**Para** poder leer, revisar y modificar cualquier archivo del monorepo sin necesidad de preguntar al autor qué hace cada función.

---

## Principio guía

> **El código se lee 10 veces por cada vez que se escribe.** Optimizar para lectura es optimizar para velocidad de equipo.

Baja carga cognitiva significa: al leer una función, un nombre de variable o un componente, el lector no necesita pausar para inferir la intención. El nombre ya la comunica.

---

## Criterios de Aceptación

### CA-01 · Nombres de funciones: verbos que describen la acción completa

**Regla**: una función debe poder leerse como una oración. Si no puedes describirla en una frase corta, la función hace demasiado.

| ❌ Evitar | ✅ Usar |
|-----------|---------|
| `process()` | `parseOcrNotesFromResponse()` |
| `handle()` | `handleInvoiceUploadError()` |
| `update()` | `updateActiveOrganizationInSession()` |
| `check()` | `checkIfOfferExceedsDeudorLimit()` |
| `data()` | `fetchInvoiceDetailsById()` |
| `doStuff()` | — (eliminar, siempre) |

**Verbos permitidos por tipo de operación:**

| Operación | Verbos recomendados |
|-----------|-------------------|
| Lectura/consulta | `get`, `fetch`, `find`, `load`, `read`, `select` |
| Escritura/mutación | `set`, `save`, `update`, `create`, `delete`, `remove`, `clear` |
| Transformación | `parse`, `format`, `map`, `convert`, `normalize`, `build` |
| Validación | `validate`, `check`, `is`, `has`, `can` |
| Manejo de eventos | `handle`, `on` + evento (ej. `onInvoiceSelected`) |
| Cálculo | `calculate`, `compute`, `sum`, `derive` |

### CA-02 · Nombres booleanos: siempre prefijados con `is`, `has`, `can`, `should`

Un booleano mal nombrado obliga al lector a inferir su valor semántico.

| ❌ Evitar | ✅ Usar |
|-----------|---------|
| `loading` | `isLoading` |
| `valid` | `isFormValid` |
| `offer` | `hasActiveOffer` |
| `admin` | `isUserAdmin` |
| `cupo` | `hasSufficientDeudorCupo` |
| `modal` | `isConfirmModalOpen` |

### CA-03 · Nombres de Signals y computeds: descriptivos del valor que contienen

```typescript
// ❌
const s = signal(false);
const c = computed(() => s() && x());

// ✅
const isCalculatorInterferenceActive = signal(false);
const canSendOffer = computed(() =>
  !isCalculatorInterferenceActive() &&
  isFormValid() &&
  hasSelectedInvoice()
);
```

Los `computed()` deben nombrase con lo que **derivan**, no con cómo lo calculan.

### CA-04 · Regla de la función de una sola responsabilidad (≤ 20 líneas como guía)

- Una función hace **una sola cosa**. Si su nombre requiere una conjunción ("y", "o"), debe dividirse.
- **Guía** (no regla absoluta): si una función supera las 20 líneas, revisar si puede extraerse lógica a funciones auxiliares con nombre.
- Los `computed()` con más de 3 operaciones encadenadas deben extraerse a funciones `private` con nombre descriptivo.

```typescript
// ❌ — hace dos cosas
function validateAndSubmitOffer() { ... }

// ✅ — cada función hace una sola cosa
function validateOfferForm(): boolean { ... }
function submitOffer(): Observable<Offer> { ... }
```

### CA-05 · Variables locales: nunca abreviadas salvo convención universal

| ❌ Evitar | ✅ Usar |
|-----------|---------|
| `inv` | `invoice` |
| `idx` | `index` (o `i` en un `for` clásico — excepción permitida) |
| `org` | `organization` (salvo como sufijo de tipo: `activeOrg` es aceptable) |
| `res` | `response` |
| `err` | `error` |
| `cb` | `callback` |
| `e` en event handlers | `event` |

**Excepciones universalmente aceptadas** (el equipo las entiende sin contexto):
`i`, `j` en bucles numéricos cortos · `id` · `url` · `api` · `dto` · `http` · `css` · `rx` (RxJS)

### CA-06 · Componentes Angular: nombres que reflejan su responsabilidad

El nombre del componente debe comunicar **qué muestra o qué hace**, no dónde vive.

| ❌ Evitar | ✅ Usar |
|-----------|---------|
| `CardComponent` | `InvoiceStatusCardComponent` |
| `ModalComponent` | `OfferConfirmModalComponent` |
| `ListComponent` | `MarketplaceInvoiceListComponent` |
| `FormComponent` | `LiquidationCalculatorFormComponent` |
| `ItemComponent` | `OcrNoteItemComponent` |

**Convención de sufijos:**

| Sufijo | Cuándo usarlo |
|--------|--------------|
| `Component` | Todo componente Angular |
| `Service` | Servicios inyectables |
| `Guard` | Route guards |
| `Interceptor` | HTTP interceptors |
| `Pipe` | Angular pipes |
| `Directive` | Directivas Angular |
| `Store` / `Signal` | No usar sufijos propios — usar el nombre del dato |

### CA-07 · Métodos de ciclo de vida: limpios, sin lógica inline

Los métodos `ngOnInit`, `ngOnDestroy`, etc. deben ser **índices** que llaman a funciones nombradas, no bloques de lógica.

```typescript
// ❌
ngOnInit(): void {
  this.invoiceService.getInvoices().pipe(
    takeUntilDestroyed(this.destroyRef),
    tap(invoices => this.invoices = invoices),
    catchError(err => { this.error = err; return EMPTY; })
  ).subscribe();
}

// ✅
ngOnInit(): void {
  this.loadInitialInvoices();
}

private loadInitialInvoices(): void {
  this.invoiceService.getInvoices().pipe(
    takeUntilDestroyed(this.destroyRef),
    tap(invoices => this.invoices.set(invoices)),
    catchError(error => this.handleInvoiceLoadError(error))
  ).subscribe();
}
```

### CA-08 · Comentarios: explican el **por qué**, no el **qué**

El código bien nombrado explica el *qué* por sí mismo. Los comentarios explican el *por qué* cuando la razón no es obvia.

```typescript
// ❌ — comenta lo que el código ya dice
// Calculamos el IVA
const iva = subtotalGastos * 0.19;

// ✅ — explica la regla de negocio no evidente
// IVA 19% aplica SOLO sobre gastos/comisiones, nunca sobre el interés
// (Diferencia de Precio). Regla tributaria chilena vigente.
const iva = subtotalGastos * 0.19;
```

**Casos donde un comentario es obligatorio:**
- Reglas de negocio tributarias o regulatorias (ej. IVA solo en gastos).
- Decisiones de arquitectura con trade-offs no evidentes.
- Workarounds por bugs conocidos de librerías (con link al issue).
- Lógica de módulo 11 para RUT (o referencia a la función que lo implementa).

### CA-09 · Archivos y carpetas: estructura predecible

Dentro de cada MFE, la estructura de carpetas sigue el patrón:

```
mfe-{nombre}/
  src/
    app/
      {feature}/
        components/     ← componentes de presentación de la feature
        services/       ← servicios de la feature (si no van a shared-utils)
        models/         ← interfaces/tipos locales de la feature
        {feature}.routes.ts
        {feature}.component.ts
      shared/           ← componentes compartidos dentro del MFE (no del monorepo)
```

- Un archivo = una clase/componente/servicio/pipe.
- El nombre del archivo refleja exactamente el nombre de la clase: `offer-confirm-modal.component.ts` → `OfferConfirmModalComponent`.
- Sin archivos `utils.ts` genéricos. Si necesitas agrupar utilidades, nómbralas por dominio: `invoice-date.utils.ts`, `rut-validation.utils.ts`.

### CA-10 · Revisión de código (PR): checklist mínimo de legibilidad

Antes de aprobar un PR, el revisor verifica:

- [ ] ¿Puedo entender qué hace cada función leyendo solo su nombre?
- [ ] ¿Los booleanos tienen prefijo `is`, `has`, `can` o `should`?
- [ ] ¿Los `computed()` tienen nombre que describe el valor derivado?
- [ ] ¿Hay alguna función que hace más de una cosa (nombre con "y" / longitud > 30 líneas)?
- [ ] ¿Hay comentarios que solo repiten lo que el código dice? (eliminarlos)
- [ ] ¿Las reglas de negocio críticas (ej. IVA) tienen comentario explicativo?

---

## Notas para el Equipo *(No es criterio de aceptación)*

- Estas convenciones se refuerzan en code review, no con linters — la semántica no se puede automatizar completamente.
- Un linter puede detectar nombres de 1–2 letras fuera de las excepciones (ej. `no-single-letter-var`), pero la calidad del nombrado es responsabilidad del revisor.
- Si un nombre requiere más de 4 palabras para describir la función, es señal de que la función hace demasiado — no de que el nombre deba ser más corto.

---

*Creada: 2026-06-03 | Estado: Vigente desde Fase 1 | Aplica a: todos los proyectos del monorepo | Nota: HU-00 = documento fundacional, precede a la secuencia de implementación HU-11…HU-38*
