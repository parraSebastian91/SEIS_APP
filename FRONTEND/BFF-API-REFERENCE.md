# BFF SEIS App — Referencia Técnica de Endpoints para Agente IA

> Servicio: `bff_seis_app` | Puerto: `3002` (configurable vía `PORT`)
> Última actualización: 2026-06-03

---

## Modelo de Autenticación

**Mecanismo:** Cookie de sesión `auth.session` (HttpOnly, firmada).  
El guard global `AuthGuard` extrae el `sessionId` de la cookie, lo valida contra Redis/ms-auth y popula `req["user"]` con la sesión activa.

**Cabeceras requeridas en todos los endpoints protegidos:**

| Header | Requerido | Descripción |
|---|---|---|
| `Cookie: auth.session=<valor>` | Sí | Sesión activa firmada |
| `X-Correlation-Id: <uuid>` | Recomendado | Trazabilidad distribuida (expuesto en respuesta) |

**Roles disponibles:**
- `USR_STD` — usuario autenticado base
- `CLIENTE_CEDENTE` — empresa emisora de facturas
- `ADMIN_CEDENTE` — administrador de empresa cedente
- `EJECUTIVO_FINANCIADORA` — ejecutiva de factoring
- `ADMIN_FINANCIADORA` — administrador de financiadora
- `SUPER_ADMIN` — acceso total

**Endpoints públicos** (sin cookie): `/health`, `/liveness`

---

## Envolvente de Respuesta Estándar (`ApiResponse<T>`)

Todos los endpoints protegidos retornan esta estructura, salvo indicación contraria:

```json
{
  "status": 200,
  "message": "Descripción del resultado",
  "data": { }
}
```

| Campo | Tipo | Descripción |
|---|---|---|
| `status` | `number` | Código HTTP del resultado |
| `message` | `string` | Mensaje legible del resultado |
| `data` | `T \| null` | Payload de respuesta (puede ser `null`) |

---

## Endpoints por Controlador

---

### 1. HealthCheck — `/` (público)

#### `GET /health`

Verifica el estado de las dependencias críticas (Redis, Vault).

**Auth:** Ninguna.

**Respuesta `200`:**
```json
{
  "status": "ok",
  "timestamp": "2026-06-03T12:00:00.000Z",
  "checks": {
    "redis": { "status": "up" },
    "vault": { "status": "up" }
  }
}
```

| Campo `status` | Valor |
|---|---|
| Todas las dependencias OK | `"ok"` |
| Alguna dependencia falla | `"error"` |

---

#### `GET /liveness`

Probe de liveness básico para orquestadores de contenedores.

**Auth:** Ninguna.

**Respuesta `200`:** `OK` (texto plano)

---

### 2. Facturas — `/facturas`

#### `GET /facturas/list/:organizacionUUID`

Obtiene la lista de facturas de una organización y un resumen estadístico.

**Roles requeridos:** `USR_STD`

**Path params:**

| Param | Tipo | Descripción |
|---|---|---|
| `organizacionUUID` | `string (UUID)` | UUID de la organización consultada |

**Respuesta `200`:** `ApiResponse<FactuasDTO>`

```json
{
  "status": 200,
  "message": "Extracción exitosa",
  "data": {
    "facturas": [
      {
        "id": "uuid",
        "assetURL": "string",
        "folio": "string",
        "deudor": "string",
        "monto_total": 1500000,
        "estado": "PUBLICADA",
        "organizacionUuid": "uuid",
        "ofertas_count": 3,
        "fecha_publicacion": "2026-06-01T00:00:00.000Z",
        "fecha_vencimiento": "2026-07-01T00:00:00.000Z",
        "url_factura": "string"
      }
    ],
    "resumen": {
      "total_publicado": 5,
      "ofertas_pendientes": 2
    }
  }
}
```

---

#### `POST /facturas`

Publica una nueva factura en el marketplace.

**Roles requeridos:** `CLIENTE_CEDENTE`, `EJECUTIVO_FINANCIADORA`, `ADMIN_FINANCIADORA`, `ADMIN_CEDENTE`, `SUPER_ADMIN`

**Body (`application/json`):**

```json
{
  "facturaId": "uuid",
  "ownerUUID": "uuid-organizacion",
  "numeroFactura": "F-001234",
  "rutDeudor": "12345678-9",
  "nombreDeudor": "Empresa Deudora SpA",
  "correlationId": "uuid-correlacion",
  "montoTotal": 1500000,
  "fechaVencimiento": "2026-07-01T00:00:00.000Z",
  "status": "PUBLICADA",
  "gestor": {
    "uuid": "uuid-usuario",
    "username": "john.doe"
  }
}
```

| Campo | Tipo | Descripción |
|---|---|---|
| `facturaId` | `string` | ID del documento factura |
| `ownerUUID` | `string` | UUID de la organización propietaria |
| `numeroFactura` | `string` | Folio / número de documento |
| `rutDeudor` | `string` | RUT del deudor |
| `nombreDeudor` | `string` | Razón social del deudor |
| `correlationId` | `string` | ID de correlación distribuida |
| `montoTotal` | `number` | Monto en CLP |
| `fechaVencimiento` | `Date ISO` | Fecha límite de la factura |
| `status` | `facturaEstado` | Estado inicial de la factura |
| `gestor.uuid` | `string` | UUID del usuario gestor |
| `gestor.username` | `string` | Username del gestor |

**Respuesta `201`:** `ApiResponse<FacturaResponseDTO>` — `"Creación exitosa"`

---

#### `PATCH /facturas`

Actualiza un campo específico de una factura existente.

**Roles requeridos:** `CLIENTE_CEDENTE`, `EJECUTIVO_FINANCIADORA`, `ADMIN_FINANCIADORA`, `ADMIN_CEDENTE`, `SUPER_ADMIN`

**Body (`application/json`):**

```json
{
  "id": "uuid-factura",
  "ownerUUID": "uuid-organizacion",
  "gestor": "uuid-usuario",
  "campoEditado": {
    "nombre": "montoTotal",
    "valor": "2000000"
  }
}
```

**Campos editables (`CampoFactura` enum):**

| Valor | Campo afectado |
|---|---|
| `"numeroFactura"` | Número de folio |
| `"rutDeudor"` | RUT del deudor |
| `"nombreRazonSocialDeudor"` | Nombre deudor |
| `"montoTotal"` | Monto total |
| `"fechaVencimiento"` | Fecha de vencimiento |
| `"asset_id"` | ID del asset en storage |
| `"INVALIDO"` | (uso interno — rechazado) |

**Respuesta `200`:** `ApiResponse<?>` — `"Actualización exitosa"`

---

#### `POST /facturas/autorizacion`

Registra la autorización explícita del usuario sobre los términos y condiciones antes de publicar una factura.

**Roles requeridos:** `CLIENTE_CEDENTE`, `ADMIN_CEDENTE`, `SUPER_ADMIN`

**Body (`application/json`):**

```json
{
  "facturaId": "uuid-factura",
  "versionTerminosId": "uuid-version",
  "acepto": true,
  "correlationId": "uuid-opcional"
}
```

| Campo | Tipo | Requerido | Descripción |
|---|---|---|---|
| `facturaId` | `string` | Sí | UUID de la factura a autorizar |
| `versionTerminosId` | `string` | Sí | Versión de T&C aceptada |
| `acepto` | `boolean` | Sí | `true` = aceptación explícita |
| `correlationId` | `string` | No | ID de trazabilidad |

**Respuesta `201`:** `ApiResponse<null>` — `"Autorización registrada"`

```json
{ "status": 201, "message": "Autorización registrada", "data": null }
```

---

### 3. Usuario — `/usuario`

#### `GET /usuario/profile`

Retorna el perfil completo del usuario autenticado.

**Auth:** Cookie de sesión (cualquier rol autenticado).

**Respuesta `200`:** `ApiResponse<UserProfileReqResDTO>`

```json
{
  "status": 200,
  "message": "Informacion del usuario obtenida correctamente",
  "data": {
    "username": "john.doe",
    "usuarioUUID": "uuid",
    "nombreCompleto": "John Doe Smith",
    "nombre": {
      "nombres": "John",
      "apellidoPaterno": "Doe",
      "apellidoMaterno": "Smith"
    },
    "datosContacto": {
      "tipoContacto": "string",
      "correo": "john@empresa.cl",
      "telefono": "+56912345678",
      "ubicacion": "Santiago, Chile",
      "documento": {
        "tipo": "RUT",
        "numero": "12345678-9"
      }
    },
    "rrss": [
      { "tipo": "linkedin", "enlace": "https://linkedin.com/in/john" }
    ],
    "telefono": "+56912345678",
    "ubicacion": "Santiago, Chile"
  }
}
```

---

#### `PUT /usuario/profile`

Actualiza el perfil del usuario autenticado.

**Body:** `UserProfileReqResDTO` (mismo esquema que la respuesta del GET)

**Respuesta `200`:** `ApiResponse<UserProfileReqResDTO>` — perfil actualizado.

---

#### `GET /usuario/profile/img`

Obtiene las URLs/metadata de avatar y banner del usuario.

**Respuesta `200`:** `ApiResponse<ImageProfileResponseDto>`

```json
{
  "status": 200,
  "message": "Imagen del usuario obtenida correctamente",
  "data": {
    "avatar": {
      "small":  { "width": 64,  "height": 64,  "format": "webp", "path": "/public/avatars/uuid/small.webp",  "headers": "..." },
      "medium": { "width": 128, "height": 128, "format": "webp", "path": "/public/avatars/uuid/medium.webp", "headers": "..." }
    },
    "banner": {
      "default": { "width": 1200, "height": 400, "format": "webp", "path": "/public/banners/uuid/banner.webp", "headers": "..." }
    }
  }
}
```

---

#### `GET /usuario/profile/organizacion`

Retorna las organizaciones vinculadas al usuario y su rol en cada una.

**Respuesta `200`:** `ApiResponse<UserOrganizacionProfileResponseDTO>`

```json
{
  "status": 200,
  "message": "Organizacion del usuario obtenida correctamente",
  "data": {
    "nombre_contacto": "John Doe",
    "cargo": "Gerente Finanzas",
    "usuario_uuid": "uuid",
    "username": "john.doe",
    "organizaciones": [
      {
        "razon_social": "Empresa Cedente SpA",
        "organizacion_uuid": "uuid-org",
        "tipo_participante": "CEDENTE"
      }
    ]
  }
}
```

---

### 4. Portal — `/portal`

#### `GET /portal/menu`

Retorna la estructura de navegación del portal según los permisos del usuario.

**Roles requeridos:** `USR_STD`

**Respuesta `200`:** `ApiResponse<SystemNavigationDTO>`

```json
{
  "status": 200,
  "message": "Menu obtenido correctamente",
  "data": {
    "sistemas": [
      {
        "nombre": "Factoring",
        "ruta": "/factoring",
        "descripcion": "Módulo de factoring",
        "icono": "invoice",
        "modulos": [
          {
            "nombre": "Marketplace",
            "ruta": "/factoring/marketplace",
            "descripcion": "Vista de facturas disponibles",
            "icono": "market",
            "organizacionId": ["uuid-org"],
            "funcionalidades": [
              {
                "nombre": "Ver facturas",
                "ruta": "/factoring/marketplace/list",
                "descripcion": "Listado de facturas publicadas",
                "icono": "list",
                "permisos": [
                  { "codigo": "FACT_VIEW", "nombre": "Ver Facturas" }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
}
```

---

### 5. Términos y Condiciones — `/terminos`

#### `GET /terminos/activo`

Retorna la versión activa de los términos y condiciones del sistema.

**Roles requeridos:** `USR_STD`, `CLIENTE_CEDENTE`, `EJECUTIVO_FINANCIADORA`, `ADMIN_FINANCIADORA`, `ADMIN_CEDENTE`, `SUPER_ADMIN`

**Respuesta `200`:** `ApiResponse<TerminosVersionModel>`

```json
{
  "status": 200,
  "message": "Términos obtenidos",
  "data": {
    "id": "uuid-version",
    "version": "1.2.0",
    "contenido": "...",
    "fechaVigencia": "2026-01-01T00:00:00.000Z",
    "activo": true
  }
}
```

> Nota: el schema exacto de `data` depende del modelo interno de `ms-core`. El campo `id` es necesario para `POST /facturas/autorizacion`.

---

### 6. Object Manager — `/object`

Gestión de archivos en MinIO. Los `objectType` válidos se definen en el enum `CATEGORY_PROCESS`.

#### `GET /object/presigned-url/:objectType`

Genera una presigned URL de subida a MinIO para que el frontend pueda cargar directamente.

**Roles requeridos:** `USR_STD`

**Path params:**

| Param | Tipo | Descripción |
|---|---|---|
| `objectType` | `string` | Categoría del objeto (ej: `DOCUMENT_DTE`, `DOCUMENT_DTE_RESPALDO`) |

**Query params:**

| Param | Tipo | Requerido | Descripción |
|---|---|---|---|
| `fileName` | `string` | Sí | Nombre del archivo a subir |
| `fileType` | `string` | Sí | MIME type (ej: `application/pdf`) |
| `userName` | `string` | Sí | Username del propietario |
| `organization` | `string` | Condicional | Requerido para `DOCUMENT_DTE` y `DOCUMENT_DTE_RESPALDO` |
| `idFactura` | `string` | Condicional | Requerido para `DOCUMENT_DTE_RESPALDO` |

**Respuesta `200`:** `ApiResponse<{ url: string, following: string }>`

```json
{
  "status": 200,
  "message": "Presigned URL obtenida exitosamente",
  "data": {
    "url": "https://minio.seis.cl/private/invoices/uuid/original.pdf?X-Amz-Signature=...",
    "following": "uuid-correlacion"
  }
}
```

---

#### `POST /object/:objectType`

Sube un archivo vía `multipart/form-data` al storage.

**Auth:** Cookie de sesión (sin restricción de rol explícita).

**Headers:** `Content-Type: multipart/form-data`

**Form field:** `file` — archivo binario

**Respuesta `201`:**

```json
{
  "message": "Objeto creado exitosamente",
  "data": { }
}
```

> No envuelve en `ApiResponse`. El campo `data` contiene el objeto creado (schema depende del use case interno).

---

#### `PUT /object/:objectType`

Sube un archivo como stream binario raw (alternativa a multipart).

**Auth:** Cookie de sesión (sin restricción de rol explícita).

**Headers requeridos:**

| Header | Descripción |
|---|---|
| `Content-Type` | MIME type del archivo (ej: `application/pdf`) |
| `X-File-Name` | Nombre del archivo |

**Body:** Binario raw del archivo

**Respuesta `201`:**

```json
{
  "message": "Objeto subido exitosamente",
  "data": { }
}
```

---

## Tabla Resumen de Endpoints

| Método | Ruta | Auth | Roles | Descripción |
|---|---|---|---|---|
| `GET` | `/health` | No | — | Estado de Redis y Vault |
| `GET` | `/liveness` | No | — | Liveness probe |
| `GET` | `/facturas/list/:organizacionUUID` | Cookie | `USR_STD` | Lista facturas de una organización |
| `POST` | `/facturas` | Cookie | Cedente/Admin/SA | Publicar nueva factura |
| `PATCH` | `/facturas` | Cookie | Cedente/Admin/SA | Actualizar campo de factura |
| `POST` | `/facturas/autorizacion` | Cookie | Cedente/Admin/SA | Registrar aceptación de T&C para factura |
| `GET` | `/usuario/profile` | Cookie | Autenticado | Perfil completo del usuario |
| `PUT` | `/usuario/profile` | Cookie | Autenticado | Actualizar perfil del usuario |
| `GET` | `/usuario/profile/img` | Cookie | Autenticado | Avatar y banner del usuario |
| `GET` | `/usuario/profile/organizacion` | Cookie | Autenticado | Organizaciones del usuario |
| `GET` | `/portal/menu` | Cookie | `USR_STD` | Navegación del portal |
| `GET` | `/terminos/activo` | Cookie | Todos los roles | Versión activa de T&C |
| `GET` | `/object/presigned-url/:objectType` | Cookie | `USR_STD` | URL presignada para subir a MinIO |
| `POST` | `/object/:objectType` | Cookie | Autenticado | Subir archivo (multipart) |
| `PUT` | `/object/:objectType` | Cookie | Autenticado | Subir archivo (raw binary) |

---

## Errores Comunes

| HTTP | Causa típica |
|---|---|
| `401 Unauthorized` | Cookie `auth.session` ausente o expirada |
| `403 Forbidden` | Usuario autenticado sin rol suficiente |
| `400 Bad Request` | Parámetro requerido ausente (ej: `userName`, `organization`) |
| `404 Not Found` | Recurso no encontrado en ms-core o ms-auth |
| `500 Internal Server Error` | Error de comunicación con Redis, Vault o microservicios internos |

> Todos los errores son procesados por el filtro global `ErrorHandler` y retornan `ApiResponse` estándar.

---

## Notas para el Agente IA

1. **No hay JWT en headers** — la autenticación es exclusivamente por cookie. El agente debe gestionar cookies entre llamadas.
2. **`correlationId`** se propaga como header `X-Correlation-Id` y también puede incluirse en el body de facturas para trazabilidad end-to-end.
3. **Presigned URL** → el agente debe obtenerla con `GET /object/presigned-url/:objectType` y luego hacer el PUT directamente a MinIO (no a este BFF).
4. **`POST /facturas/autorizacion`** debe llamarse antes o en coordinación con `POST /facturas` cuando el flujo de publicación requiere aceptación de T&C.
5. **El menú del portal** (`GET /portal/menu`) define dinámicamente qué rutas y funcionalidades están disponibles para el usuario — úsalo para construir flujos adaptativos.
