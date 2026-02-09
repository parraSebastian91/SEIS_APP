# 🏗️ Arquitectura de Microfrontends (MFE) con Kong

## 📐 Diagrama de Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                         NAVEGADOR                            │
│                  http://localhost:8000                       │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      KONG API GATEWAY                        │
│                    Puerto: 8000, 8001                        │
├──────────────────┬──────────────────┬───────────────────────┤
│   /api/auth      │   /api/core      │   /login              │
│   /portal        │   /mfe-gestion-usuario                   │
└──────┬───────────┴──────┬───────────┴────┬──────────────────┘
       │                  │                │
       ▼                  ▼                ▼
┌─────────────┐   ┌──────────────┐   ┌─────────────────┐
│ auth-service│   │  ms_core     │   │   app_login     │
│  :3000      │   │  :3001       │   │   :80 (8082)    │
└─────────────┘   └──────────────┘   └─────────────────┘
                                               
       ┌──────────────────────────────┬────────────────────┐
       │                              │                    │
       ▼                              ▼                    ▼
┌─────────────────┐    ┌──────────────────────┐   ┌────────────────┐
│   app_portal    │    │ mfe-gestion-usuario  │   │  Futuros MFE   │
│   :80 (8083)    │    │   :80 (8084)         │   │                │
│   (Shell/Host)  │    │   (Remote)           │   │                │
└─────────────────┘    └──────────────────────┘   └────────────────┘
       │                        ▲
       └────────────────────────┘
         Carga dinámicamente
```

## 🔑 Conceptos Clave

### 1. **Shell (Portal)**
- Es la aplicación principal que actúa como contenedor
- Carga dinámicamente los microfrontends remotos
- Ruta: `/portal` en Kong → `app_portal:80`

### 2. **Remote (MFE)**
- Microfrontends independientes que exponen módulos
- Se cargan dinámicamente en tiempo de ejecución
- Ruta: `/mfe-gestion-usuario` en Kong → `app_mfe_gestion_usuario:80`

### 3. **Kong API Gateway**
- Punto único de entrada para todas las peticiones
- Enrutamiento centralizado
- Manejo de CORS
- Balanceo de carga

## 📁 Configuración de Federation

### Portal (Shell) - `federation.manifest.prod.json`
```json
{
  "seis-mfe-gestion-usuario": "/mfe-gestion-usuario/remoteEntry.json"
}
```

### MFE - `federation.config.js`
```javascript
module.exports = withNativeFederation({
  name: 'seis-mfe-gestion-usuario',
  exposes: {
    './UserProfileRoutingModule': 'projects/seis-mfe-gestion-usuario/src/app/user-profile/user-profile-routing.module.ts',
  }
});
```

## 🛣️ Rutas de Kong Configuradas

| Ruta en Kong              | Servicio de Destino      | Puerto Interno |
|---------------------------|--------------------------|----------------|
| `/api/auth`               | `auth-service`           | 3000           |
| `/api/core`               | `ms_core`                | 3001           |
| `/login`                  | `app_login`              | 80             |
| `/portal`                 | `app_portal`             | 80             |
| `/mfe-gestion-usuario`    | `app_mfe_gestion_usuario`| 80             |

## 🔄 Flujo de Carga de MFE

1. **Usuario accede a** `http://localhost:8000/portal`
2. **Kong enruta a** `app_portal:80`
3. **Portal carga** `federation.manifest.json`
4. **Portal solicita** `http://localhost:8000/mfe-gestion-usuario/remoteEntry.json`
5. **Kong enruta a** `app_mfe_gestion_usuario:80/remoteEntry.json`
6. **MFE devuelve** su manifest con los módulos expuestos
7. **Portal carga dinámicamente** el módulo solicitado
8. **Navegación funciona** entre Shell y Remote

## ⚠️ Por Qué los MFE DEBEN estar en Kong

### Problema sin Kong:
```
❌ Portal en: http://localhost:8000/portal (a través de Kong)
❌ MFE en: http://localhost:8084 (acceso directo)
❌ Resultado: CORS errors, rutas rotas
```

### Solución con Kong:
```
✅ Portal en: http://localhost:8000/portal
✅ MFE en: http://localhost:8000/mfe-gestion-usuario
✅ Resultado: Mismo origen, sin CORS, rutas consistentes
```

## 🚀 Configuración Automática

Ejecuta el script de configuración:

```bash
./scripts/kong-config.sh
```

Este script configura automáticamente:
- Servicios para cada microservicio
- Rutas con `strip_path=true`
- Plugins de CORS para APIs y MFEs
- Timeouts adecuados

## 🔍 Verificación

### Verificar servicios en Kong:
```bash
curl http://localhost:8001/services | jq '.data[].name'
```

### Verificar rutas en Kong:
```bash
curl http://localhost:8001/routes | jq '.data[] | {name, paths}'
```

### Probar acceso:
```bash
# Portal
curl http://localhost:8000/portal

# MFE remoteEntry
curl http://localhost:8000/mfe-gestion-usuario/remoteEntry.json

# APIs
curl http://localhost:8000/api/auth/health
curl http://localhost:8000/api/core/health
```

## 🐛 Debugging

### Ver logs de Kong:
```bash
docker logs kong_gateway -f
```

### Ver configuración de Kong Admin:
```bash
open http://localhost:8001
```

### Verificar CORS:
```bash
curl -X OPTIONS http://localhost:8000/mfe-gestion-usuario/remoteEntry.json \
  -H "Origin: http://localhost:8000" \
  -H "Access-Control-Request-Method: GET" \
  -v
```

## 📚 Referencias

- [Angular Architects - Native Federation](https://github.com/angular-architects/module-federation-plugin)
- [Kong Gateway Documentation](https://docs.konghq.com/gateway/latest/)
- [Microfrontends Pattern](https://micro-frontends.org/)

## 🎯 Mejores Prácticas

1. **Siempre usa rutas relativas** en `federation.manifest.prod.json`
2. **Configura CORS en Kong** para los MFE
3. **Usa `strip_path=true`** en las rutas de Kong
4. **Mantén consistencia** en las rutas entre entornos
5. **Documenta cada MFE** que agregues al sistema
