# Ejemplo 03 — Anatomía de un custom role en JSON

> Lectura y análisis. Los IDs son placeholders.

## 1. Cuándo custom vs built-in

Regla práctica: **usa un built-in si existe uno que encaje**. Mantener custom roles es carga operativa (hay que versionarlos, revisarlos cuando Microsoft añade acciones nuevas, etc.). Escribe un custom role cuando:

- Ningún built-in combina las acciones que necesitas sin dar de más.
- Necesitas un corte muy específico (p. ej. "leer blobs **pero no** listar claves de la storage account").
- Necesitas restringir el `scope` donde el role es asignable.

Antipatrón: duplicar un built-in casi idéntico "para tenerlo bajo control". Suele terminar desactualizado.

## 2. Esqueleto

```json
{
  "Name": "Example Custom Role",
  "Description": "Descripción humana de qué hace este role.",
  "Actions": [],
  "NotActions": [],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/<SUB-UUID-PLACEHOLDER>"
  ]
}
```

Campos:

| Campo | Qué contiene | Plano |
|-------|--------------|-------|
| `Actions` | Operaciones permitidas | **Management** (crear/listar recursos, obtener propiedades...) |
| `NotActions` | Substracción de `Actions` | Management |
| `DataActions` | Operaciones permitidas | **Data** (leer un blob, mandar a una queue...) |
| `NotDataActions` | Substracción de `DataActions` | Data |
| `AssignableScopes` | Dónde se *puede* asignar | Jerárquico |

## 3. Management plane vs Data plane — el error típico

```json
{
  "Name": "Puedo leer blobs (MAL)",
  "Actions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
  ],
  "DataActions": [],
  "NotActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/<SUB-UUID-PLACEHOLDER>"
  ]
}
```

Esto parece correcto, pero **no funciona** para leer un blob real. "Leer un blob" es una operación del **data plane** — tiene que ir en `DataActions`, no en `Actions`. El custom role como está te deja ver *metadatos* del contenedor (management-plane) pero el `GET` al endpoint `https://<sa>.blob.core.windows.net/<container>/<blob>` responderá `403`.

La versión correcta:

```json
{
  "Name": "Puedo leer blobs (BIEN)",
  "DataActions": [
    "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read"
  ],
  "Actions": [],
  "NotActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/<SUB-UUID-PLACEHOLDER>"
  ]
}
```

Como regla práctica: operaciones sobre *contenido* (blobs, mensajes, documentos, secretos individuales) → `DataActions`. Operaciones sobre *recursos y configuración* (crear la storage account, listar containers, modificar firewall, obtener keys) → `Actions`.

## 4. `AssignableScopes` — qué es y qué no es

`AssignableScopes` **no** es el scope del role assignment. Es la lista de scopes **donde el role puede ser asignado**.

- `AssignableScopes: ["/subscriptions/<SUB-A>"]` → el role solo puede asignarse dentro de esa subscription. Si intentas asignarlo en otra sub, Azure devuelve error.
- `AssignableScopes: ["/providers/Microsoft.Management/managementGroups/mg-platform"]` → asignable en cualquier scope descendente del MG.

Buena práctica: pon `AssignableScopes` lo más estrecho posible. Si el role es para un workload de un equipo, al RG o a la subscription de ese equipo. No pongas la root del tenant salvo roles corporativos.

## 5. `Actions` + `NotActions` — restar al built-in-like

A veces quieres "casi todo de Storage, excepto una cosa peligrosa":

```json
{
  "Name": "Storage operator (no key access)",
  "Actions": [
    "Microsoft.Storage/*"
  ],
  "NotActions": [
    "Microsoft.Storage/storageAccounts/listKeys/action",
    "Microsoft.Storage/storageAccounts/regenerateKey/action"
  ],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/<SUB-UUID-PLACEHOLDER>"
  ]
}
```

Semántica: `Actions - NotActions` → management-plane de Storage sin las operaciones que entregan la *account key* (compartible, no auditada granularmente).

## 6. Lecturas sugeridas

- Lección §6 (custom roles) y §5 (catálogo de built-in roles útiles).
- Actividad `01-least-privilege-storage-reader/` para escribir uno propio con validator.
