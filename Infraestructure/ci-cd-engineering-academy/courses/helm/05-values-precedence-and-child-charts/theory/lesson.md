# Lesson — Values precedence y child charts

## 1. Contexto y motivación

Un chart maduro vive en varios entornos (dev, staging, prod), es consumido por operadores distintos y a menudo compone **subcharts** de terceros. El valor final de cualquier clave de `.Values` nace de la suma de **múltiples fuentes**: defaults del chart, overrides del padre sobre subcharts, varios archivos `-f` y una batería de `--set` en la CLI. Si el orden de precedencia no está claro en la mente del operador, el chart se vuelve impredecible y los bugs aparecen en el entorno equivocado (clásico: "en dev funciona").

Este módulo convierte esa "cadena de merges" en un modelo mental explícito y entrena el diseño del *contrato de values*: qué es público, qué está en `global`, qué se expone vía `import-values` y qué simplemente no debe duplicarse.

## 2. Las cuatro fuentes y su orden

Helm resuelve `.Values` mergeando, **de menor a mayor prioridad**:

1. **`values.yaml`** del chart raíz (defaults).
2. **Overrides del padre a subcharts**: en el `values.yaml` del padre, una clave con el nombre del subchart (`subchart:`) sobreescribe los defaults del subchart. Aplica solo cuando hay dependencias.
3. **`-f` / `--values`** en la CLI, procesados **en el orden en que aparecen**. El último `-f` gana sobre los anteriores.
4. **`--set` / `--set-string` / `--set-file` / `--set-json`** en la CLI. Entre varios `--set`, el último gana.

Regla operativa simple: **lo que viene a la derecha en la CLI gana**. Y sobre todas las fuentes, `--set` gana sobre `-f`.

Un punto a menudo olvidado: cuando se escriben dos `-f` con el mismo valor para la misma clave, el segundo gana aunque esté en un archivo "menos específico" por nombre. Helm no interpreta nombres de archivo, solo orden.

## 3. Merge semantics: mapas vs listas

El merge es *deep merge* para **mapas**, pero **reemplazo total** para **listas**:

```yaml
# defaults
containers:
  env:
    - name: LOG_LEVEL
      value: info
    - name: PORT
      value: "8080"

# override via -f
containers:
  env:
    - name: LOG_LEVEL
      value: debug
```

Resultado: `env` queda con **un solo elemento** (`LOG_LEVEL=debug`). `PORT` se perdió. Esto es una fuente común de bugs al "parchar" listas. Las dos salidas sanas:

- Diseñar los defaults como mapas (keys estables) cuando se quiere parchar fácil.
- Redefinir **toda** la lista en el override cuando se quiere cambiar un elemento.

## 4. Multi-document values con `-f` múltiples

El patrón canónico multi-entorno:

```bash
helm template myapp ./chart \
  -f values.yaml \
  -f values-prod.yaml \
  -f values-prod-us-east.yaml \
  --set image.tag=1.42.0
```

Capas típicas (más generales a más específicas):

1. `values.yaml` — defaults seguros (dev-ish, replicas=1, resources moderados).
2. `values-<env>.yaml` — overrides por entorno (dev/stg/prod).
3. `values-<env>-<region>.yaml` — overrides por sitio/región.
4. `--set` — overrides ad-hoc del pipeline (típicamente `image.tag` del artefacto que se está desplegando).

Cada capa debe ser **mínima**: solo las claves que cambian. Si un `values-prod.yaml` reescribe el 80% del archivo base, el contrato está mal diseñado.

## 5. Overrides por entorno: diseño del contrato

Un buen contrato tiene tres propiedades:

- **Simetría**: las mismas claves existen en los tres entornos (aunque algunas valgan `null`). Facilita diffs.
- **Mínimo override**: solo lo que es distinto. `values-dev.yaml` no repite lo que ya está en `values.yaml`.
- **Previsibilidad**: un operador que lee solo `values-prod.yaml` entiende qué hace prod sin reconstruir el merge mental.

Antipatrón: `values-dev.yaml` que contiene **todo** el chart "pero cambiando dos cosas". Al cambiar un default, los overrides quedan desincronizados silenciosamente.

Un `values.schema.json` ayuda a esto: define *qué claves son válidas* y bloquea errores de typo en cualquiera de los `-f`.

## 6. Scoping de values en subcharts

Cada subchart ve su **propio** `.Values`. Si el chart padre tiene:

```yaml
# parent/values.yaml
foo: bar
subchart:
  foo: baz
```

Entonces, dentro del subchart, `.Values.foo` vale `baz`, no `bar`. El namespace está aislado. El padre puede alcanzar valores del subchart como `.Values.subchart.foo`, pero el subchart **no** puede ver `.Values.foo` del padre.

Esto es deliberado: evita que un subchart dependa de la "forma" del padre. Un subchart publicado debe funcionar standalone y ser consumible desde cualquier padre.

## 7. `global:` — la única zona compartida

`global:` es un sub-árbol especial. Lo que el padre pone bajo `.Values.global` queda disponible como `.Values.global` dentro de **cada subchart**. Es el único canal de comunicación "oficial" entre padre e hijos.

```yaml
# parent/values.yaml
global:
  imageRegistry: ghcr.io/acme
  storageClass: fast-ssd
```

Dentro del subchart:

```yaml
image: {{ .Values.global.imageRegistry }}/myservice:1.0
```

Reglas de disciplina:

- `global` debe contener solo lo que **todos** o **la mayoría** de los subcharts realmente usan.
- No usarlo como "cajón de sastre" (termina siendo un objeto gigante opaco).
- Documentar explícitamente qué claves espera el chart padre en `global`.

Un override vía `-f` sobre `global.imageRegistry` se propaga a todos los subcharts automáticamente — ideal para cambios transversales (migración de registry, cambio de zona).

## 8. `import-values` y `exports`

Problema: un subchart "sabe" algunas cosas (p. ej. el puerto de su Service, un hostname interno) que el padre quiere exponer o reutilizar sin **replicar** la estructura del subchart.

Solución: `import-values` en `Chart.yaml` del padre, combinado con `exports` en el subchart.

Modo **child-parent** (explícito, el más predecible):

```yaml
# parent/Chart.yaml
dependencies:
  - name: backend
    version: 0.1.0
    repository: "file://../backend"
    import-values:
      - child: service
        parent: backendService
```

El subtree `.Values.service` del subchart `backend` se copia a `.Values.backendService` del padre. El padre puede ahora leer `.Values.backendService.port` sin tener que escribir `backend.service.port`.

Modo **implícito** usando `exports`: el subchart declara en su `values.yaml`:

```yaml
exports:
  service:
    port: 8080
```

Y el padre:

```yaml
import-values:
  - service   # busca .Values.exports.service en el subchart
```

El modo child-parent es más legible y menos "mágico"; es el recomendado para charts internos.

## 9. Convivencia con `values.schema.json`

El `values.schema.json` describe el **contrato público** del chart raíz. Cuando hay subcharts:

- Normalmente **no** se re-valida el árbol completo del subchart desde el schema del padre: cada subchart puede tener su propio `values.schema.json`.
- Lo que vive bajo `global:` **sí** entra en el schema del padre, porque el padre lo expone al operador.
- Si se usa `import-values`, lo importado también debe estar en el schema del padre (ahora es parte de su contrato).

Antipatrón: copiar el schema del subchart al schema del padre. Se desincroniza al día siguiente. Mejor: schema del padre valida solo lo que es público *del padre*, y confía en que el subchart valide su propio sub-árbol.

## 10. Predecir el valor final — modelo mental

Para cualquier clave `.Values.a.b.c`, resolver mentalmente en este orden:

1. ¿Hay un `--set` para esa clave? → ese es el valor (el último `--set` entre varios).
2. ¿Hay un `-f`? → recorrer los `-f` **de derecha a izquierda**, el primero que define la clave gana.
3. ¿Hay un override del padre (si es subchart)? → valor del padre.
4. Default del propio `values.yaml`.

Para el subchart, insertar antes del paso 2 que el chart padre puede introducir valores adicionales via `global` o `import-values`, pero esos son fuentes **distintas**: `global.x` no sobrescribe `x`.

Herramienta clave: `helm template --debug ...` imprime cómo quedó el merge final (sin instalar nada). Para auditar un valor: añadir temporalmente al template `# DEBUG: {{ .Values.a.b.c }}` y correr `helm template`.

## 11. Antipatrones y errores comunes

- **Lista parchada**: override reemplaza toda la lista — el equipo cree que agregó un env var, en realidad borró todos los demás.
- **Overrides "copia completa"**: `values-prod.yaml` es un fork del `values.yaml` default; se desincronizan silenciosamente al editar defaults.
- **`global` como vertedero**: todo lo transversal termina ahí; después nadie se atreve a tocarlo.
- **Nombre del subchart olvidado**: el padre define `database:` esperando sobrescribir el subchart `db` — no funciona, la clave debe coincidir con `name` o `alias`.
- **Confiar en el orden de los `--set`**: si dos pipelines diferentes concatenan `--set`s en órdenes distintos, pueden producir releases divergentes.
- **No usar `--debug`**: operar a ciegas con cuatro `-f` encadenados es la receta para bugs intermitentes.
- **Duplicar `values.yaml` ↔ `values.schema.json`**: default *y* schema definen lo mismo con pequeñas diferencias. Mantener el schema **mínimo** (solo restricciones) y los defaults en `values.yaml`.

## 12. Cuándo usar cada mecanismo

| Caso | Mecanismo | Por qué |
|---|---|---|
| Un valor usado por padre y varios subcharts (p. ej. registry) | `global:` | Un solo override, se propaga a todos. |
| Un valor del subchart que el padre necesita leer (p. ej. puerto) | `import-values` child-parent | Padre no replica la estructura del hijo. |
| Un valor que cambia por entorno pero solo lo usa el padre | `values-<env>.yaml` | Simetría, mínimo override. |
| Un valor que cambia por release/deploy (p. ej. `image.tag`) | `--set` en el pipeline | Lo gana al final de la cadena, no se olvida en archivos. |
| Un valor que solo el subchart conoce y nadie más usa | Dejarlo en el subchart | No tocar nada en el padre. |

Guía final: **mínima superficie pública**, **merges predecibles**, **nada duplicado**. Si el equipo discute "¿de dónde salió este valor?", el contrato está mal diseñado.
