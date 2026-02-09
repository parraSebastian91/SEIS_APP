# 🧭 Guía de Navegación en Arquitectura Module Federation

## 📐 Estructura de Rutas

```
/portal                              (Portal - Shell)
└── /contenedor                      (Contenedor)
    ├── /navbar
    ├── /sidebar
    └── /pages                       (MFE - Cargado dinámicamente)
        ├── /view-profile
        └── /edit-profile
```

## 🛣️ Cómo Navegar

### Opción 1: Rutas Relativas (RECOMENDADO ✅)

Desde dentro del Portal (ContenedorComponent), usa rutas relativas:

```typescript
// En contenedor.component.ts
goTo(ruta: string) {
    this.router.navigate([ruta], { relativeTo: this.activatedRoute });
}
```

```html
<!-- En contenedor.component.html -->
<button (click)="goTo('pages/view-profile')">Ver Perfil</button>
```

**Ventajas:**
- ✅ No asume la ruta base
- ✅ Fácil de refactorizar
- ✅ Funciona correctamente con ActivatedRoute
- ✅ Relativa al contexto actual

**Resultado:** `/portal/contenedor/pages/view-profile`

---

### Opción 2: Rutas Absolutas

Si prefieres especificar la ruta completa:

```typescript
goTo(ruta: string) {
    this.router.navigate([ruta]);
}
```

```html
<button (click)="goTo('/portal/contenedor/pages/view-profile')">Ver Perfil</button>
```

**Desventajas:**
- ❌ Acoplamiento a la estructura de rutas
- ❌ Difícil de refactorizar
- ❌ Menos mantenible

**Resultado:** `/portal/contenedor/pages/view-profile`

---

### Opción 3: Usar `routerLink` Directamente (MÁS LIMPIO)

Sin necesidad de llamar a métodos en TypeScript:

```html
<!-- Con rutas relativas (recomendado) -->
<button mat-menu-item routerLink="pages/view-profile">
    <mat-icon>account_circle</mat-icon>
    <span>Perfil</span>
</button>

<!-- O con rutas absolutas -->
<button mat-menu-item routerLink="/portal/contenedor/pages/view-profile">
    <mat-icon>account_circle</mat-icon>
    <span>Perfil</span>
</button>
```

---

## 🎯 Ejemplo Completo

### ContenedorComponent

```typescript
import { Component } from '@angular/core';
import { Router, ActivatedRoute } from '@angular/router';

@Component({
  selector: 'app-contenedor',
  templateUrl: './contenedor.component.html'
})
export class ContenedorComponent {
  constructor(
    private router: Router,
    private activatedRoute: ActivatedRoute
  ) {}

  // Navegar a rutas del MFE
  verPerfil() {
    this.router.navigate(['pages/view-profile'], { 
      relativeTo: this.activatedRoute 
    });
  }

  editarPerfil() {
    this.router.navigate(['pages/edit-profile'], { 
      relativeTo: this.activatedRoute 
    });
  }
}
```

### Contenedor Template

```html
<button (click)="verPerfil()">Ver Perfil</button>
<button (click)="editarPerfil()">Editar Perfil</button>

<!-- O directamente con routerLink -->
<button routerLink="pages/view-profile">Ver Perfil</button>
```

---

## 🔄 Flujo de Navegación Completo

1. **Usuario en Portal** → `http://localhost:8000/portal`
2. **Hace click en "Perfil"** → `this.router.navigate(['pages/view-profile'], ...)`
3. **Angular Router resuelve**:
   - Ruta relativa `pages/view-profile` 
   - Contexto: `/portal/contenedor`
   - Ruta final: `/portal/contenedor/pages/view-profile`
4. **Portal detecta la ruta `/pages`** en `contenedor-routing.module.ts`
5. **Carga el MFE dinámicamente** desde `seis-mfe-gestion-usuario`
6. **MFE routing resuelve** `view-profile`
7. **Se muestra ViewComponent del MFE**

---

## 📦 Rutas Disponibles en el MFE

El MFE expone las siguientes rutas:

| Ruta | Componente | Descripción |
|------|-----------|-------------|
| `pages/view-profile` | ViewComponent | Ver perfil del usuario |
| `pages/edit-profile` | EditComponent | Editar perfil del usuario |

Acceso desde el navegador:
- `http://localhost:8000/portal/contenedor/pages/view-profile`
- `http://localhost:8000/mfe-gestion-usuario/view-profile` (directo)

---

## ⚠️ Errores Comunes

### ❌ Error: `Cannot match any routes`

```typescript
// MAL: Ruta incorrecta
this.router.navigate(['/mfe-gestion-usuario/view-profile']);
// El Portal no conoce esta ruta

// CORRECTO: Navega a través del Portal
this.router.navigate(['pages/view-profile'], { relativeTo: this.activatedRoute });
```

### ❌ Error: `view-profile no encontrado`

```typescript
// MAL: Olvida 'pages/'
this.router.navigate(['view-profile'], { relativeTo: this.activatedRoute });
// Intenta: /portal/contenedor/view-profile (no existe)

// CORRECTO: Incluye 'pages/'
this.router.navigate(['pages/view-profile'], { relativeTo: this.activatedRoute });
// Va a: /portal/contenedor/pages/view-profile ✅
```

---

## 🚀 Best Practices

1. **Usa rutas relativas** con `relativeTo: this.activatedRoute`
2. **Evita rutas hardcodeadas** en múltiples lugares
3. **Usa constantes** para las rutas si las reutilizas:

```typescript
// routes.constants.ts
export const PORTAL_ROUTES = {
  PERFIL: 'pages/view-profile',
  EDITAR_PERFIL: 'pages/edit-profile'
};

// En el componente:
this.router.navigate([PORTAL_ROUTES.PERFIL], { 
  relativeTo: this.activatedRoute 
});
```

4. **Prefiere `routerLink`** cuando no necesites lógica adicional:

```html
<button [routerLink]="PORTAL_ROUTES.PERFIL" 
        [routerLinkActiveOptions]="{ exact: true }"
        routerLinkActive="active">
  Ver Perfil
</button>
```

---

## 📚 Referencias

- [Angular Router Documentation](https://angular.io/guide/router)
- [Relative Navigation](https://angular.io/guide/router#relative-navigation)
- [ActivatedRoute API](https://angular.io/api/router/ActivatedRoute)
- [Module Federation Pattern](https://webpack.js.org/concepts/module-federation/)
