# Actividad 01 — Custom role de mínimo privilegio para leer blobs

## 1. Identificación

- **ID:** `az-02-01-least-privilege-storage-reader`
- **Tecnología:** `azure`
- **Módulo:** `az-02-entra-id-rbac-managed-identities`
- **Dificultad:** beginner
- **Duración estimada:** 70–80 min
- **Tipo:** independent (sin dependencia de la actividad 02)

## 2. Contexto

El equipo de Security te pide definir un **custom role** mínimo que permita a un workload leer blobs de **una** storage account concreta (`stcheckoutprod001`) y **nada más**. El built-in `Storage Blob Data Reader` es casi suficiente, pero el equipo quiere:

1. Un role **auditado** con nombre y descripción propios para dejar claro el propósito en los role assignments.
2. Una **variante** que incluya una `condition` para limitar la lectura a un *prefix* específico dentro del container (ensayo de scoping fino con [ABAC conditions](https://learn.microsoft.com/azure/role-based-access-control/conditions-overview)).
3. Un **documento** que justifique cada decisión y diga en qué scope asignar el role en Fase 4.

**Importante**: no hay subscription Azure. No se asigna nada. El entregable son 2 archivos JSON + 1 README.

## 3. Objetivos

Al terminar deberías poder:

- Escribir un custom role JSON válido con `Actions`, `DataActions`, `NotActions`, `NotDataActions` y `AssignableScopes`.
- Explicar por qué "leer un blob" va en `DataActions` y nunca en `Actions`.
- Escribir una variante del role con `condition` sintácticamente correcta.
- Justificar por escrito en qué `scope` asignar el role (storage account vs RG vs subscription) y por qué.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` (§4, §6, §7).
- Haber recorrido `../../examples/03-custom-role-json/`.
- Herramientas: `bash`, `jq` (parser JSON), `python3` (opcional, validación extra). Un editor de texto.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/az-02-role
cd /tmp/az-02-role
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe los 2 archivos JSON

Nombres **exactos** (el validador los busca):

1. `role-storage-blob-reader.json` — role base, mínimo privilegio.
2. `role-storage-blob-reader-with-condition.json` — misma idea pero con `condition` que restringe el `read` a blobs cuyo `path` empiece por `public/`.

#### Requisitos — `role-storage-blob-reader.json`

- JSON válido (parsea con `jq .`).
- Objeto raíz con todas las claves top-level: `Name`, `Description`, `Actions`, `NotActions`, `DataActions`, `NotDataActions`, `AssignableScopes`.
- `Name`: string descriptivo (p. ej. `"Checkout Blob Reader"`).
- `Description`: string no vacío.
- `Actions`: array **vacío** (`[]`). El workload no necesita operaciones del management plane.
- `DataActions`: array con **exactamente** la acción `"Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"` (nada más).
- `NotActions`: `[]`.
- `NotDataActions`: `[]`.
- `AssignableScopes`: array con **al menos un** scope de forma `/subscriptions/<SUB>` o `/subscriptions/<SUB>/resourceGroups/<RG>` o `/subscriptions/<SUB>/resourceGroups/<RG>/providers/Microsoft.Storage/storageAccounts/<SA>`. **No pongas UUIDs reales** — usa placeholders tipo `<SUB-UUID-PLACEHOLDER>`.
- **No debe** contener `"*"`, `"Microsoft.Storage/storageAccounts/listKeys/action"`, `"Microsoft.Authorization/roleAssignments/write"` ni ninguna variante de `write`/`delete` en ninguna lista. El validador lo comprueba.

#### Requisitos — `role-storage-blob-reader-with-condition.json`

- Igual que el anterior, más:
- Cada entrada de `DataActions` que incluya `blobs/read` debe ir dentro de un objeto con `condition` y `conditionVersion`. El formato soportado por Azure para custom roles con condition requiere expresar las acciones condicionadas como objetos; a efectos de este validador basta con:
  - El JSON tiene una clave `Condition` **o** una clave `condition` en algún nivel.
  - El JSON tiene `ConditionVersion` (o `conditionVersion`) con valor string `"2.0"`.
  - La condition es un string que contiene `StringEquals` o `StringStartsWith` y menciona `blobs` o `path`.

Sugerencia de condition válida (patrón oficial Azure ABAC):

```
(
 !(ActionMatches{'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read'})
 OR
 @Resource[Microsoft.Storage/storageAccounts/blobServices/containers/blobs:path] StringStartsWith 'public/'
)
```

### 5.3 Escribe `README-INTENT.md`

Secciones obligatorias (el validador las busca):

- `## role-storage-blob-reader` — explica, en lenguaje humano, qué hace el role, por qué `Actions` está vacío y `DataActions` tiene solo esa línea, y en qué scope lo asignarías (storage account / RG / sub).
- `## role-storage-blob-reader-with-condition` — explica qué añade la condition y cuándo usarías la variante en lugar del role base.
- `## Decisión de scope` — párrafo justificando el scope elegido para el role assignment en Fase 4.
- Mención explícita a **DataActions** y a **Managed Identity** (contexto: típicamente este role se asigna a una MI).

> **No llames al archivo `ANALYSIS.md`** — otros validadores del repo tratan ese nombre con convenciones especiales. Usa `README-INTENT.md`.

### 5.4 Entregables

```
/tmp/az-02-role/
├── role-storage-blob-reader.json
├── role-storage-blob-reader-with-condition.json
└── README-INTENT.md
```

## 6. Resultado esperado

- Los 2 JSONs parsean con `jq .`.
- El validador pasa en verde (ver §8).
- Un revisor puede leer `README-INTENT.md` y entender exactamente dónde y por qué asignar este role.

## 7. Criterios de aceptación

- **Funcionalidad**: validador pasa.
- **Correctitud sintáctica**: JSON válido.
- **Correctitud conceptual** (autoevaluación): comparar con `solution/`.
- **Mínimo privilegio**: ni un `Action`/`DataAction` de más.

## 8. Validación

```bash
bash tests/validate.sh /tmp/az-02-role
```

El validador comprueba sintaxis JSON, presencia de claves obligatorias, ausencia de acciones excesivas y las secciones del README. **No** comprueba que, aplicado a un tenant real, el role haga exactamente lo que dice el README — eso se verificaría en Fase 4 con `az role assignment create` y un `GET /blobs` real.

## 9. Preguntas de reflexión

1. ¿Qué diferencia operativa hay entre asignar este role en scope del **container** vs scope de la **storage account**?
2. ¿Por qué `AssignableScopes` no sustituye al scope del role assignment?
3. ¿Qué le pasa a un `GET /blobs` si pones esa acción en `Actions` en lugar de `DataActions`? ¿Y por qué el management plane sí la "ve" pero el data plane no?
4. ¿Cuándo preferirías el built-in `Storage Blob Data Reader` sobre este custom role?
5. ¿Qué le añadirías al JSON si quisieras permitir **también** descargar índices (`list`) de blobs?

## 10. Extensiones

- Añade un tercer archivo `role-storage-blob-reader-and-lister.json` que además permita `.../containers/blobs/read` + `.../containers/read` (listar) sin dar escritura.
- Documenta en `README-INTENT.md` cómo exportar un built-in a JSON (`az role definition list --name "Storage Blob Data Reader"`) y comparar con tu custom.
- Dibuja un diagrama (ASCII, dentro de un code fence) mostrando MI → role assignment → scope → data-plane blob.

## 11. Limpieza

```bash
rm -rf /tmp/az-02-role
```

No hay infraestructura que detener.
