# Guía: Graphify + CodeGraph + Obsidian en GitHub Copilot

> Entorno verificado: Windows · Mac · Linux · VS Code · GitHub Copilot · Python 3.12 · Node.js 20+  
> Última actualización: 2026-05-25

---

## ¿Por qué esta combinación?

| Herramienta | Rol | Sin ella... |
|---|---|---|
| **Graphify** | Construye un grafo de conocimiento semántico de todo el proyecto (nodos = símbolos, edges = relaciones) y lo expone como servidor MCP | Copilot no tiene visión estructural del proyecto — responde en base a contexto de ventana |
| **CodeGraph** | Indexa símbolos TypeScript/Java con sus callers, callees y firmas. Lo expone también como MCP | Copilot no puede navegar dependencias ni calcular impacto de cambios |
| **Obsidian** | Vault de notas enlazadas generado desde el grafo — cada comunidad/nodo del proyecto se convierte en una nota conectada | El conocimiento del grafo queda solo en JSON. Obsidian lo hace explorable visualmente y editable por humanos |

En conjunto: **Copilot pregunta al grafo → recibe contexto estructural → responde con conocimiento real del codebase**.

---

## Requisitos previos

- [x] Python 3.10+ instalado (`python --version`)
- [x] Node.js 18+ + npm instalado (`node --version`)
- [x] VS Code con extensión **GitHub Copilot** activa
- [x] Workspace abierto en VS Code

---

## Parte 1 — Instalar Graphify

### 1.1 Instalar el paquete

Se recomienda usar un entorno virtual para aislar las dependencias:

**Mac / Linux:**
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install graphifyy
```

**Windows:**
```powershell
python -m venv .venv
.venv\Scripts\Activate.ps1
pip install graphifyy
```

> El paquete en PyPI se llama `graphifyy` (doble y). El módulo Python se importa como `graphify`.
> Activa el venv en cada sesión nueva antes de usar graphify.

### 1.2 Instalar el SDK de MCP (obligatorio para el servidor)

```powershell
pip install "mcp[cli]"
```

Sin esto el servidor falla con `ModuleNotFoundError: No module named 'mcp'`.

### 1.3 Verificar instalación

```powershell
python -m graphify --help
```

---

## Parte 2 — Instalar CodeGraph

### 2.1 Instalar globalmente via npm

```powershell
npm install -g @colbymchenry/codegraph
```

### 2.2 Verificar ruta del binario

**Windows:**
```powershell
Get-ChildItem "$env:APPDATA\npm" -Filter "codegraph*"
```
Deberías ver `codegraph.cmd`. Anota la ruta completa — la necesitarás en el paso de configuración MCP.

**Mac / Linux:**
```bash
which codegraph
```
En Mac/Linux el binario queda en el PATH directamente (ej. `/usr/local/bin/codegraph`). No necesitas la ruta absoluta.

### 2.3 Inicializar el índice en el proyecto

Desde la raíz del workspace:

```powershell
npx @colbymchenry/codegraph init -i
```
o 
```powershell
npx @colbymchenry/codegraph index
```
para indexar nuevamente

Esto genera la carpeta `.codegraph/` con `codegraph.json` indexado.

---

## Parte 3 — Configurar los filtros de exclusión

### 3.1 Filtros para Graphify — `.graphifyignore`

Crea el archivo `.graphifyignore` en la raíz del proyecto. Excluye todo lo que no es código tuyo:

```gitignore
# Dependencias
**/node_modules/**
**/dist/**
**/build/**
**/target/**
**/.gradle/**
**/.m2/**

# Configs de framework (no aportan semántica)
tsconfig*.json
nest-cli.json
angular.json
ng-package.json
proxy.conf*.json
firebase*.json
*.lock
package-lock.json

# Herramientas internas
.vscode/
.codegraph/
graphify-out/
**/.git/**

# Snapshots y reportes generados
snapshot_*.json
dependency-report.json

# Binarios y assets
*.png
*.jpg
*.svg
*.woff
*.ttf
*.ico

# Java wrapper scripts
mvnw
mvnw.cmd

# Infraestructura / monitoreo (no es código de dominio)
monitoring/
vault/respaldo/
```

### 3.2 Filtros para CodeGraph — `.codegraph/config.json`

Crea o edita el archivo `.codegraph/config.json` en la raíz (y en cada sub-proyecto si usas monorepo):

```json
{
  "version": 1,
  "include": ["**/*.ts", "**/*.java"],
  "exclude": [
    "**/.git/**",
    "**/node_modules/**",
    "**/dist/**",
    "**/build/**",
    "**/target/**",
    "**/coverage/**",
    "**/.nyc_output/**",
    "**/__pycache__/**",
    "**/.gradle/**",
    "**/.m2/**",
    "**/graphify-out/**",
    "**/.codegraph/**",
    "**/*.min.js",
    "**/*.bundle.js",
    "**/*.spec.ts",
    "**/*.e2e.ts",
    "**/snapshot_*.json",
    "**/dependency-report.json"
  ],
  "languages": [],
  "frameworks": [],
  "maxFileSize": 1048576,
  "extractDocstrings": true,
  "trackCallSites": true
}
```

> **Importante:** Los arrays `languages` y `frameworks` deben estar vacíos (`[]`), no con strings. Valores no reconocidos causan error `Invalid configuration format`.

---

## Parte 4 — Ejecutar el pipeline de Graphify

Graphify necesita un LLM para el análisis semántico. Hay **dos modos** — elige el que aplica a tu caso:

| Modo | Requiere | Recomendado para |
|---|---|---|
| **Skill (GitHub Copilot)** | Solo VS Code + Copilot activo | Primera vez, sin API key externa |
| **CLI con Ollama** | Ollama instalado localmente | Mac/Linux sin API key externa |
| **CLI con API key** | `OPENAI_API_KEY` o `ANTHROPIC_API_KEY` | CI/CD, automatización |

---

### 4.1 Modo Skill — GitHub Copilot (recomendado, sin API key)

Este modo usa el LLM del chat de Copilot directamente. No llama APIs externas ni necesita Ollama.

**Paso 1 — Instalar el skill en VS Code:**
```bash
python -m graphify vscode install
```
Esto escribe la configuración del skill en `.github/copilot-instructions.md` y lo registra en VS Code.

**Paso 2 — Ejecutar desde el chat de Copilot:**

Abre el chat de GitHub Copilot en VS Code y escribe:
```
/graphify
```
Copilot leerá los archivos del proyecto, hará el análisis semántico y escribirá `graphify-out/graph.json` automáticamente.

> El comando `python -m graphify run .` **solo funciona dentro del skill** (modo agente). En terminal standalone no existe — usa `extract` en su lugar.

---

### 4.2 Modo CLI con Ollama (Mac/Linux, sin API key)

**Paso 1 — Instalar Ollama:**

```bash
# Mac
brew install ollama

# Linux
curl -fsSL https://ollama.com/install.sh | sh

# Windows — descarga el instalador desde https://ollama.com
```

**Paso 2 — Descargar modelo e iniciar el servicio:**

```bash
# Mac (con brew)
brew services start ollama

# Linux / Windows
ollama serve &

# Descargar el modelo (una sola vez)
ollama pull llama3.2
```

**Paso 3 — Ejecutar graphify:**

```bash
python -m graphify extract . --backend ollama --model llama3.2 --max-concurrency 1
```

> `--max-concurrency 1` es importante en local para no saturar la RAM con múltiples chunks en paralelo.

---

### 4.3 Modo CLI con API key externa

```bash
# Setear la key (Mac/Linux)
export ANTHROPIC_API_KEY="sk-ant-..."
export OPENAI_API_KEY="sk-..."

# Setear la key (Windows PowerShell)
$env:ANTHROPIC_API_KEY = "sk-ant-..."

# Ejecutar — graphify detecta automáticamente qué key está seteada
python -m graphify extract .
```

---

### 4.4 Actualizaciones incrementales (sin LLM)

Una vez que el grafo existe, las actualizaciones de archivos modificados **no necesitan LLM**:

```bash
# Solo re-extrae los archivos que cambiaron desde la última vez
python -m graphify update .

# Si borraste clases o hiciste un refactor grande, fuerza la reconstrucción
python -m graphify update . --force
```

---

### 4.5 Explorar el grafo visualmente

```bash
# Windows
start graphify-out\graph.html

# Mac
open graphify-out/graph.html

# Linux
xdg-open graphify-out/graph.html
```

Abre el grafo interactivo en el navegador. Zoom, clusters, nodos dios resaltados.

### 4.3 Explorar el grafo visualmente

```bash
# Windows
start graphify-out\graph.html

# Mac
open graphify-out/graph.html

# Linux
xdg-open graphify-out/graph.html
```

Abre el grafo interactivo en el navegador. Zoom, clusters, nodos dios resaltados.

---

## Parte 5 — Configurar el servidor MCP en VS Code

Crea o edita `.vscode/mcp.json` en la raíz del workspace:

**Windows** (usa rutas absolutas — el PATH de VS Code puede diferir del terminal):
```json
{
    "servers": {
        "codegraph": {
            "command": "C:\\Users\\TU_USUARIO\\AppData\\Roaming\\npm\\codegraph.cmd",
            "args": ["serve", "--mcp"],
            "type": "stdio"
        },
        "graphify": {
            "command": "C:\\Python312\\python.exe",
            "args": ["-m", "graphify.serve", "C:\\ruta\\al\\proyecto\\graphify-out\\graph.json"],
            "type": "stdio"
        }
    }
}
```
> Obtén la ruta de Python con: `(Get-Command python).Source`

**Mac / Linux** (los binarios están en el PATH — usa nombres cortos):
```json
{
    "servers": {
        "codegraph": {
            "command": "codegraph",
            "args": ["serve", "--mcp"],
            "type": "stdio"
        },
        "graphify": {
            "command": "python3",
            "args": ["-m", "graphify.serve", "/ruta/al/proyecto/graphify-out/graph.json"],
            "type": "stdio"
        }
    }
}
```
> Obtén la ruta con: `which python3`

### 5.1 Verificar el servidor de graphify

```bash
# Windows
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | python -m graphify.serve ".\graphify-out\graph.json"

# Mac / Linux
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | python3 -m graphify.serve "./graphify-out/graph.json"
```

Respuesta esperada: `{"jsonrpc":"2.0","id":1,"result":{"serverInfo":{"name":"graphify",...}}}`

### 5.2 Verificar el servidor de codegraph

```bash
# Windows
echo '{}' | C:\Users\TU_USUARIO\AppData\Roaming\npm\codegraph.cmd serve --mcp

# Mac / Linux
echo '{}' | codegraph serve --mcp
```

Respuesta esperada: JSON-RPC con error de formato (confirma que el servidor arrancó).

### 5.3 Activar en VS Code

`Ctrl+Shift+P` → **Developer: Reload Window**

Los servidores MCP se registran automáticamente al abrir el chat de Copilot.

---

## Parte 6 — Integración con Obsidian

### ¿Por qué Obsidian?

El grafo de graphify es un archivo JSON — potente para máquinas, opaco para humanos. Obsidian convierte cada nodo/comunidad en una **nota Markdown enlazada** con `[[wikilinks]]`, lo que permite:

- **Explorar el proyecto como si fuera una wiki** — navegar de `FacturaViewComponent` → sus dependencias → los módulos que la usan
- **Anotar sobre el código** — agregar contexto de negocio, decisiones de diseño, deuda técnica directamente en las notas
- **Graph View nativo de Obsidian** — visualización de relaciones igual que el `graph.html` pero editable
- **Búsqueda full-text** — encontrar cualquier símbolo, módulo o concepto en segundos
- **Sincronización con CLAUDE.md** — el vault es el complemento visual del documento de arquitectura

El vault vive **fuera del repositorio** para no contaminar el historial de git con metadatos de workspace.

### 6.1 Generar el vault desde el grafo

Graphify no incluye un comando `obsidian` nativo. El proyecto incluye un script propio en `scripts/generate-obsidian-vault.py`:

```bash
# Windows / Mac / Linux — mismo comando
python scripts/generate-obsidian-vault.py \
  --graph graphify-out/graph.json \
  --vault ../MI_PROYECTO_VAULT
```

El script genera:
- Una nota `.md` por cada símbolo del grafo (con wikilinks a dependencias)
- Una nota por cada comunidad (con sus nodos ordenados por conectividad)
- Un `INDEX.md` con los nodos dios y el listado de comunidades

Se recomienda que el vault esté **fuera del repositorio** para no contaminar git.

### 6.2 Abrir en Obsidian

1. Instala [Obsidian](https://obsidian.md) (gratuito, disponible en Windows/Mac/Linux)
2. `Abrir carpeta como vault` → selecciona la carpeta generada
3. Activa **Graph View** (`Ctrl+G`) para ver el mapa visual del proyecto

### 6.3 Actualizar el vault

Después de cada `graphify run . --update`, regenera el vault:

```bash
python scripts/generate-obsidian-vault.py --graph graphify-out/graph.json --vault ../MI_PROYECTO_VAULT
```

---

## Resumen de comandos frecuentes

```bash
# Reindexar CodeGraph — igual en todos los OS
npx @colbymchenry/codegraph index

# Actualizar grafo Graphify (sin LLM, solo archivos modificados)
python -m graphify update .      # Windows
python3 -m graphify update .     # Mac / Linux

# Primera extracción completa desde terminal (necesita Ollama o API key)
python -m graphify extract . --backend ollama --model llama3.2 --max-concurrency 1

# Primera extracción completa desde Copilot Chat (sin API key)
# Escribe en el chat: /graphify

# Regenerar vault Obsidian (script propio — graphify no tiene comando nativo)
python scripts/generate-obsidian-vault.py --graph graphify-out/graph.json --vault ../MI_VAULT

# Abrir grafo visual en el navegador
start graphify-out\graph.html

# Ver nodos dios (abstracciones más conectadas)
npx @colbymchenry/codegraph query "nombreFuncion" -j
```

---

## Estructura de archivos generados

```
proyecto/
├── .vscode/
│   └── mcp.json              ← Registro de servidores MCP
├── .codegraph/
│   └── codegraph.json        ← Índice de símbolos (NO commitear)
├── .graphifyignore            ← Exclusiones para graphify
├── graphify-out/
│   ├── graph.json             ← Grafo persistente (NO commitear)
│   ├── graph.html             ← Visualización interactiva
│   ├── GRAPH_REPORT.md        ← Reporte de nodos dios y comunidades
│   └── cost.json              ← Tracker de costo de API
└── CLAUDE.md                  ← Documento de arquitectura (SÍ commitear)
```

> Agrega a `.gitignore`:
> ```
> .codegraph/
> graphify-out/
> ```

---

## Herramientas MCP disponibles en el chat

Una vez activos los servidores, Copilot puede usar:

**Graphify:**
- `query_graph` — búsqueda semántica BFS/DFS en el grafo
- `get_node` — detalles completos de un símbolo
- `get_neighbors` — dependencias directas de un nodo
- `get_community` — todos los nodos de una comunidad/módulo
- `god_nodes` — nodos más conectados (abstracciones críticas)
- `graph_stats` — estadísticas globales del grafo
- `shortest_path` — camino más corto entre dos conceptos

**CodeGraph:**
- Búsqueda de símbolos por nombre
- Callers y callees de funciones
- Cálculo de impacto de cambios (`affected`)
 