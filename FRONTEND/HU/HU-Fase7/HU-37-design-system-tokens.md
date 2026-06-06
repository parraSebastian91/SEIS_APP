# HU-37 — Sistema de Diseño: Tokens, Tipografía y Temas

> **Fase**: 7 — `seis-portal` + `shared-utils` (global) | **Aplica a**: todos los MFEs | **Refs**: §3.3

---

## Descripción

El sistema de diseño establece los fundamentos visuales de la plataforma: paleta de colores, tokens semánticos, sistema de temas (dark/light), personalización por organización y escala tipográfica. **Debe implementarse antes que cualquier componente visual** de los MFEs — es la capa base de la que todo lo demás depende.

Esta HU no tiene lógica de negocio. Es una HU de infraestructura de UI.

---

## Criterios de Aceptación

### CA-01 · Arquitectura de tres capas de tokens (CSS custom properties)

| Capa | Quién la define | Personalizable | Scope |
|------|----------------|:--------------:|-------|
| **Capa 1 — Paleta de referencia** (`--ref-*`) | Factor (inmutable) | ❌ | Global |
| **Capa 2 — Tokens semánticos** (`--color-*`) | Tema activo (dark / light) | ❌ | Redefinidos en `[data-theme]` |
| **Capa 3 — Tokens de organización** (`--org-*`) | Organización activa | ✅ (3 tokens) | Inyectados en runtime |

**Regla estricta**: los componentes **solo consumen tokens semánticos** (`--color-*`) y nunca la paleta de referencia (`--ref-*`) directamente. Esta regla garantiza que el sistema sea coherente y extensible.

### CA-02 · Paleta de referencia (inmutable, `--ref-*`)

```css
:root {
  --ref-navy-deep:      #0D1655;
  --ref-navy:           #1A237E;
  --ref-navy-mid:       #1E2A8A;
  --ref-teal:           #00BFA5;
  --ref-teal-dim:       #00897B;
  --ref-teal-bright:    #64FFDA;
  --ref-white:          #FFFFFF;
  --ref-ink:            #0A0D1A;
  --ref-surface-light:  #F5F5F0;
  --ref-gray-100:       #F0F2F5;
  --ref-gray-300:       #C7CDD8;
  --ref-gray-500:       #8E97A8;
  --ref-gray-700:       #4A5568;
}
```

Estos tokens nunca se usan directamente en componentes — solo sirven como fuente de los tokens semánticos.

### CA-03 · Tokens semánticos por tema (`[data-theme]`)

Los componentes consumen estos tokens. Al cambiar el `data-theme` del elemento raíz, todos los tokens semánticos se redefinen automáticamente:

```css
[data-theme="dark"] {
  --color-bg-base:           #0D1655;
  --color-bg-surface:        #1A237E;
  --color-bg-elevated:       #1E2A8A;
  --color-text-primary:      #FFFFFF;
  --color-text-secondary:    rgba(255, 255, 255, 0.55);
  --color-text-disabled:     rgba(255, 255, 255, 0.25);
  --color-border:            rgba(255, 255, 255, 0.08);
  --color-brand-primary:     #00BFA5;
  --color-brand-primary-dim: #00897B;
  --color-brand-on-primary:  #0A0D1A;
}

[data-theme="light"] {
  --color-bg-base:           #F0F2F5;
  --color-bg-surface:        #FFFFFF;
  --color-bg-elevated:       #FFFFFF;
  --color-text-primary:      #0A0D1A;
  --color-text-secondary:    #4A5568;
  --color-text-disabled:     #C7CDD8;
  --color-border:            rgba(0, 0, 0, 0.10);
  --color-brand-primary:     #00897B;
  --color-brand-primary-dim: #1A237E;
  --color-brand-on-primary:  #FFFFFF;
}
```

### CA-04 · Tokens de estado (constantes en ambos temas)

```css
:root {
  --color-success: #22C55E;  /* Confirmaciones, estados completados */
  --color-warning: #F59E0B;  /* Alertas, notas OCR pendientes */
  --color-error:   #EF4444;  /* Errores, logout, acciones destructivas */
  --color-info:    #3B82F6;  /* Notificaciones informativas */
}
```

Estos tokens nunca cambian entre temas. No pueden ser personalizados por organización.

### CA-05 · Tokens de organización (Capa 3, personalización)

La organización activa puede sobreescribir **solo estos 3 tokens**:

```css
/* Defaults — marca Factor */
:root {
  --org-brand-primary:      var(--ref-teal);
  --org-brand-primary-dim:  var(--ref-teal-dim);
  --org-brand-on-primary:   var(--ref-ink);
}
```

`--color-brand-primary` referencia `--org-brand-primary`. El override de organización afecta el sistema de forma controlada sin romper los tokens semánticos.

**Validación de contraste**: antes de persistir un color de organización, el frontend debe verificar que el par `--org-brand-primary` / `--org-brand-on-primary` cumple mínimo WCAG AA (ratio ≥ 4.5:1 para texto normal). Si el color no pasa el umbral, rechazar con aviso al usuario.

**Inyección en runtime**: al cambiar `activeOrganizationId`, el Shell lee los tokens de la org desde `SessionService` y los aplica con `element.style.setProperty('--org-brand-primary', value)` en el elemento raíz. Si la org no tiene tokens personalizados, se usan los defaults.

### CA-06 · Fases de implementación del sistema de temas

| Fase | Alcance | Estado en MVP |
|------|---------|:-------------:|
| **MVP** | Tema **dark fijo**. `data-theme="dark"` hardcodeado en el `<html>`. Sin toggle visible. | ✅ Implementar |
| **Post-MVP v1** | Toggle dark/light en preferencias de usuario. Persiste en `currentUser`. | ❌ No en MVP |
| **Post-MVP v2** | Per-org: selector de 3 tokens con validación de contraste WCAG AA. Persiste en el perfil de organización. | ❌ No en MVP |

Para el MVP: establecer `document.documentElement.setAttribute('data-theme', 'dark')` al iniciar la aplicación. Toda la arquitectura de tokens debe estar correctamente definida para facilitar la implementación futura de los toggles.

### CA-07 · Tipografía — Fuentes

**Plus Jakarta Sans** (fuente de UI):
- Variable CSS: `--font-sans`
- Pesos: 300, 400, 500, 700, 800
- Carga: `preload` en el HTML del shell.
- Uso: todo texto de interfaz (labels, body, headings, botones, inputs).
- En contextos de datos: `font-feature-settings: "tnum" 1` para dígitos tabulares uniformes.

**JetBrains Mono** (fuente de datos financieros):
- Variable CSS: `--font-mono`
- Pesos: 400, 500, 700
- Carga: **diferida** (code splitting — solo en módulos con datos financieros densos).
- Uso exclusivo:
  - Importes y tasas en la calculadora de liquidación (HU-29)
  - Columnas de montos en tablas del dashboard (HU-31, HU-33)
  - Montos comparativos en `OfferCompareModal` (HU-25)
  - RUTs y folios en formularios y vistas de factura

### CA-08 · Escala tipográfica

Definida como variables CSS (`--text-{rol}`) o clases de utilidad:

| Rol | Tamaño | Peso | Fuente |
|-----|--------|:----:|:------:|
| `display` | `clamp(2rem, 4vw, 3rem)` | 800 | Sans |
| `heading-1` | `clamp(1.75rem, 3vw, 2.25rem)` | 800 | Sans |
| `heading-2` | `1.5rem` | 700 | Sans |
| `heading-3` | `1.25rem` | 700 | Sans |
| `body-lg` | `1rem` | 400 | Sans |
| `body` | `0.875rem` | 400 | Sans |
| `body-sm` | `0.75rem` | 400 | Sans |
| `label` | `0.75rem` | 700 | Sans — `text-transform: uppercase; letter-spacing: 0.06em` |
| `data-lg` | `1.25rem` | 700 | Mono — `font-variant-numeric: tabular-nums` |
| `data` | `0.875rem` | 500 | Mono — `font-variant-numeric: tabular-nums` |
| `data-sm` | `0.75rem` | 400 | Mono — `font-variant-numeric: tabular-nums` |

### CA-09 · Variable especial del dashboard

El fondo del `PreLiquidacionCard` (HU-29) usa directamente `--ref-navy-deep` (`#0D1655`) como excepción documentada — es un componente de "highlight financiero" con identidad propia que no cambia con el tema.

```css
/* Excepción documentada */
.pre-liquidacion-card {
  background-color: var(--ref-navy-deep); /* #0D1655 — navy-deep */
  /* Este componente no debe adaptarse al toggle de tema */
}
```

---

## Entregables de la HU

- [ ] Archivo `_tokens.scss` (o `tokens.css`) en `shared-utils` con las 3 capas de tokens.
- [ ] Documentación inline de cada token con el comentario de su propósito.
- [ ] `ThemeService` en `shared-utils` que:
  - Aplica `data-theme` al elemento raíz al iniciar (dark en MVP).
  - Expone `applyOrgTokens(orgTokens: OrgBrandTokens)` para inyectar los tokens de organización en runtime.
  - Expone `validateContrast(bg: string, fg: string): boolean` para validación WCAG AA.
- [ ] `@font-face` o carga de fuentes configurada en el Shell para Plus Jakarta Sans y JetBrains Mono.
- [ ] Clases de utilidad tipográfica (o SCSS mixins) correspondientes a la escala de CA-08.
- [ ] Storybook (si existe en el proyecto) o archivo de muestra con todos los tokens y la escala tipográfica renderizados.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **Una org tiene un color de acento con contraste insuficiente** | El frontend valida antes de persistir. Si el contraste WCAG AA no pasa (ratio < 4.5:1), se rechaza con mensaje: `"Este color no cumple los requisitos de contraste mínimo. Elige un tono más oscuro o más claro."` |
| EB-02 | **La fuente JetBrains Mono no carga a tiempo** | Fallback en la pila de fuentes: `'JetBrains Mono', 'Courier New', monospace`. Los dígitos pueden no ser tabulares pero el layout no se rompe. |
| EB-03 | **Un MFE usa directamente un token `--ref-*`** | Es una violación de la regla de la Capa 1. El equipo debe incluir una regla de lint (CSS lint o Stylelint) que prohíba el uso de `--ref-*` fuera del archivo de tokens. |

---

*Creada: 2026-06-03 | Estado: Por implementar | Fase: 7 — global (shared-utils + seis-portal) | Refs: §3.3*
