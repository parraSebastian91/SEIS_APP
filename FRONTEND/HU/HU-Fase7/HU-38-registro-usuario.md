# HU-38 — Registro de Usuario + `NoOrganizationGate`

> **Fase**: 2 (complemento) — `app-login` (puerto 8082) | **Rol**: usuario no registrado | **Refs**: §9.0

---

## Historias de Usuario

- **`US-R01`** — Como nuevo usuario, quiero elegir mi rol antes de registrarme, para entender desde el inicio si soy cedente o ejecutivo.
- **`US-R02`** — Como nuevo usuario, quiero ver la validación de mi RUT en tiempo real mientras lo escribo, para saber si es correcto sin esperar al envío del formulario.
- **`US-R03`** — Como nuevo usuario, quiero verificar mi email con un código OTP, para no depender de que el link llegue al dispositivo correcto.
- **`US-R04`** — Como nuevo usuario, quiero ver un estado intermedio claro si no pertenezco a ninguna organización, para saber exactamente qué debo hacer antes de poder operar.

---

## Contexto técnico

El registro vive en `app-login` junto con el login (HU-15) y la recuperación de contraseña (HU-17). El flujo de registro tiene **dos fases independientes**:

```
Fase 1 — Cuenta personal (durante el registro)
  └─► Bifurcación de rol → Wizard 3 pasos → OTP email → Portal vacío

Fase 2 — Organización (primer login post-registro)
  ├─► Crear nueva organización (wizard HU-19)
  └─► Unirse a organización existente (ingresando código de org)
```

Esta separación permite que el onboarding de organización pueda **interrumpirse y retomarse** en el próximo login, y que un usuario pueda pertenecer a múltiples organizaciones cedentes sin rehacer su cuenta personal.

**Endpoints:**
- `POST /api/auth/register` — crea la cuenta personal con rol seleccionado.
- `POST /api/auth/verify-email` con `{ otp: string }` — verifica el email.
- `POST /api/auth/resend-otp` — reenvía el código OTP.
- `POST /api/core/org/join` con `{ accessCode: string }` — unirse a org existente.

---

## Criterios de Aceptación

### CA-01 · Layout general

Mismo patrón que el login (HU-15):
- **Desktop (`md+`)**: panel izquierdo fijo con ilustración/value proposition de la plataforma; panel derecho con el formulario.
- **Mobile (`xs–md`)**: panel izquierdo oculto; solo el formulario centrado en pantalla completa.

### CA-02 · Paso 0 — Bifurcación de rol (`RoleSelectionStep`)

Pantalla previa al wizard. No es un paso numerado — es la entrada al flujo:

```
┌──────────────────────────────────────────────────────────┐
│  ¿Qué describe mejor tu situación?                       │
│                                                          │
│  ┌─────────────────────────┐  ┌────────────────────────┐ │
│  │  🏢                     │  │  🏦                    │ │
│  │  Soy empresa cedente    │  │  Soy ejecutivo de      │ │
│  │  Vendo facturas         │  │  financiera            │ │
│  │                         │  │  Ofrezco financiamiento│ │
│  └─────────────────────────┘  └────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

- La selección de rol es **vinculante y permanente** — no puede modificarse después del registro.
- Al seleccionar una opción: se resalta visualmente y aparece un botón `"Continuar"`.
- No hay confirmación adicional — el botón `"Continuar"` abre el Wizard (Paso 1).

### CA-03 · Wizard — Barra de progreso

- 3 pasos numerados con indicadores visuales: `1 · Tus datos` / `2 · Tu contraseña` / `3 · Verificar email`.
- El paso activo está resaltado. Los pasos completados muestran un ícono de check.
- El usuario **no puede navegar hacia atrás** libremente (avance unidireccional). Puede volver al paso anterior con el botón `"Atrás"`.

### CA-04 · Paso 1 — Datos personales (`PersonalDataStep`)

| Campo | Tipo | Validación |
|-------|------|-----------|
| Nombre | texto | Requerido. Mínimo 2 caracteres. |
| Apellido | texto | Requerido. Mínimo 2 caracteres. |
| RUT personal | texto con máscara | Ver CA-05 |
| Email | email | Formato válido. Requerido. |
| Teléfono | numérico | Prefijo `+56` fijo (no editable). Campo numérico para los 9 dígitos restantes. |

- Botón `"Continuar"` habilitado solo cuando todos los campos son válidos.
- Errores de validación inline bajo cada campo (no toast).

### CA-05 · `RutInput` — Validación de RUT en tiempo real

- Máscara automática con el formato `XX.XXX.XXX-K` (puntos de miles y guion antes del dígito verificador).
- La máscara se aplica mientras el usuario escribe — no al perder el foco.
- Validación del **dígito verificador** (algoritmo módulo 11) en tiempo real:
  - Mientras el usuario escribe dígitos (antes de completar el DV): sin indicador.
  - Al completar el campo con un DV válido: `✅` a la derecha del campo.
  - Al completar con DV inválido: campo en estado error con mensaje `"RUT inválido"`.
- El componente `RutInput` es reutilizable — también se usa en el wizard de creación de organización (HU-19, campo RUT de la empresa).

### CA-06 · Paso 2 — Credenciales (`CredentialsStep`)

| Campo | Validación |
|-------|-----------|
| Contraseña | Mínimo 8 caracteres. Medidor de fortaleza visual (CA-07). Toggle para mostrar/ocultar. |
| Confirmar contraseña | Debe coincidir con el campo de contraseña. Validación en tiempo real (al escribir en este campo). |
| Acepto los T&C | Checkbox obligatorio. Sin él, el botón `"Continuar"` permanece deshabilitado. El texto `"Términos y Condiciones"` es un link que abre el documento en un modal o nueva pestaña. |

- Botón `"Continuar"`: habilitado solo cuando la contraseña es válida, los campos coinciden y el checkbox está marcado.
- Al presionar `"Continuar"`: `POST /api/auth/register` con todos los datos de Pasos 0, 1 y 2. Si el email ya existe: error inline `"Este email ya tiene una cuenta registrada."`.

### CA-07 · `PasswordStrengthMeter` — Medidor de fortaleza

Barra visual con 4 niveles de color basados en la entropía/complejidad de la contraseña:

| Nivel | Criterios | Color |
|-------|-----------|-------|
| **Muy débil** | Solo letras o solo números, < 8 caracteres | Rojo (`--color-error`) |
| **Débil** | 8+ caracteres, un solo tipo de carácter | Naranja |
| **Media** | Letras + números o letras + símbolos | Amarillo (`--color-warning`) |
| **Fuerte** | Letras + números + símbolos, 12+ caracteres | Verde (`--color-success`) |

- La barra se actualiza en tiempo real mientras el usuario escribe.
- Etiqueta de texto junto a la barra: `"Muy débil"` / `"Débil"` / `"Media"` / `"Fuerte"`.
- El componente `PasswordStrengthMeter` es reutilizable — también se usa en HU-17 (reseteo de contraseña).

### CA-08 · Paso 3 — Verificación de email (`EmailVerificationStep`)

- Mensaje: `"Te enviamos un código a {email}. Ingrésalo para activar tu cuenta."`.
- **`OtpInput`**: grid de **6 inputs individuales** de un dígito cada uno.
  - Al escribir un dígito: el foco se mueve automáticamente al siguiente campo.
  - `Backspace` en un campo vacío: el foco retrocede al campo anterior.
  - Permite pegar el código completo desde el portapapeles (detectar paste en cualquier campo y distribuir los 6 dígitos automáticamente).
  - Solo acepta dígitos numéricos (bloquear letras y símbolos).
- Al completar los 6 dígitos: `POST /api/auth/verify-email` automáticamente (sin botón de envío).
  - Éxito: redirige al portal (`seis-portal`) → se dispara la lógica de `NoOrganizationGate` (CA-09).
  - Error (código incorrecto): campos se sacuden (animación shake) + se limpian + mensaje `"Código incorrecto. Inténtalo de nuevo."`.
  - Error (código expirado): mensaje `"El código expiró. Solicita uno nuevo."` + botón `"Reenviar"` activo.
- **Botón "Reenviar código"**: disponible con un **countdown de 60 segundos** al cargar el paso. Mientras el countdown corre: botón deshabilitado con texto `"Reenviar en 45s"`. Al llegar a 0: botón habilitado. Al presionar: `POST /api/auth/resend-otp` y el countdown reinicia.

### CA-09 · `NoOrganizationGate` — Estado intermedio post-registro

Cuando el usuario autenticado **no pertenece a ninguna organización** al ingresar al portal (situación post-registro, o si fue removido de todas sus orgs), se muestra esta pantalla en lugar del dashboard:

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│  Para comenzar, configura tu organización.          │
│                                                     │
│  [ + Crear nueva organización ]                     │
│  [ Unirme a una organización existente ]            │
│                                                     │
└─────────────────────────────────────────────────────┘
```

**Opción A — `"+ Crear nueva organización"`**:
- Navega al wizard de creación de organización (HU-19). Al completarlo, el portal carga normalmente.

**Opción B — `"Unirme a una organización existente"`**:
- Muestra un input de **código de acceso** (alfanumérico, ej. `ABCD-1234`).
- Al ingresar y confirmar: `POST /api/core/org/join` con `{ accessCode }`.
  - Éxito: portal carga normalmente con la nueva organización activa.
  - Error (código inválido o expirado): mensaje inline `"Código inválido. Pide al administrador de la organización que te genere un nuevo código."`.

**Comportamiento del gate:**
- El `NoOrganizationGate` se muestra como una pantalla completa (reemplaza el dashboard, no es un modal).
- Los MFEs no están disponibles mientras el gate esté activo.
- Si el usuario cierra sesión sin completar: en el próximo login, el gate vuelve a aparecer.
- El gate se determina en el Shell (`seis-portal`) consultando `SessionService.currentUser.organizations` — si el array está vacío, se redirige a esta pantalla.

---

## Casos de Borde

| # | Escenario | Decisión |
|---|-----------|----------|
| EB-01 | **El email ya tiene una cuenta registrada** | Error inline en el Paso 2 al hacer `POST /api/auth/register`: `"Este email ya tiene una cuenta registrada. ¿Quieres iniciar sesión?"` con link al login. |
| EB-02 | **El usuario cierra el browser en el Paso 3 (antes de verificar el OTP)** | La cuenta queda sin verificar. En el próximo intento de login, el sistema detecta que el email no está verificado y lleva al usuario directamente al Paso 3. |
| EB-03 | **El RUT ingresado ya existe en el sistema** | Error al hacer `POST /api/auth/register`: `"Ya existe una cuenta con este RUT."`. |
| EB-04 | **El usuario pega el código OTP y tiene espacios o guiones** | El `OtpInput` filtra caracteres no numéricos antes de distribuir los dígitos. |
| EB-05 | **El código de acceso a la organización tiene mayúsculas/minúsculas mezcladas** | El input normaliza a mayúsculas automáticamente al escribir (o el backend acepta case-insensitive). Confirmar con backend cuál aplica. |
| EB-06 | **Un ejecutivo usa el `NoOrganizationGate` y crea una organización cedente por error** | El wizard de creación (HU-19) detecta el rol del usuario y solo ofrece crear una organización del tipo correspondiente al rol (`tipoParticipacion` autodetectado). |

---

## Componentes

| Componente | Ubicación | Descripción |
|------------|-----------|-------------|
| `RegistrationPageComponent` | `app-login` | Contenedor del flujo completo de registro |
| `RoleSelectionStepComponent` | `app-login` | Pantalla de bifurcación cedente / ejecutivo |
| `PersonalDataStepComponent` | `app-login` | Paso 1: datos personales |
| `CredentialsStepComponent` | `app-login` | Paso 2: contraseña + T&C |
| `EmailVerificationStepComponent` | `app-login` | Paso 3: OTP de 6 dígitos |
| `RutInputComponent` | `shared-utils` | Input con máscara y validación DV en tiempo real (reutilizable en HU-19 y otros) |
| `PasswordStrengthMeterComponent` | `shared-utils` | Medidor de fortaleza visual (reutilizable en HU-17) |
| `OtpInputComponent` | `app-login` | Grid de 6 inputs con auto-foco, paste, y backspace |
| `NoOrganizationGateComponent` | `seis-portal` | Pantalla intermedia: crear org / unirse a org |

---

*Creada: 2026-06-03 | Estado: Por implementar | App: app-login + seis-portal | Refs: §9.0, HU-15, HU-17, HU-19*
