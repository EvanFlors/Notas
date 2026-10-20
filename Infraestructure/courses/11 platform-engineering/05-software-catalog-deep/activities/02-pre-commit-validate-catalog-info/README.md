# Actividad 02 — Hook pre-commit que valida `catalog-info.yaml`

## 1. Identificación

- **ID:** `plat-05-02-pre-commit-validate-catalog-info`
- **Tecnología:** `platform-engineering`
- **Módulo:** `plat-05-software-catalog-deep`
- **Dificultad:** intermediate
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

El catálogo degrada cuando `catalog-info.yaml` rotos entran a `main`: el `GithubEntityProvider` falla al parsearlos, la entidad desaparece, y el equipo descubre el problema cuando alguien pregunta por su servicio y no está. Un **hook pre-commit** es la defensa barata: rechaza el commit **antes** del push si el YAML no cumple el mínimo (sintaxis + kind + metadata.name + spec.owner + 2 annotations para Components).

Esta actividad produce un hook en Bash reusable (reutilizable como starter en un template de Scaffolder más adelante). El validador de la actividad comprueba que tu hook:

1. **Rechaza** fixtures malos (YAML roto, falta de owner, pocas annotations, etc.).
2. **Acepta** un fixture bueno.
3. Es ejecutable y tiene shebang.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Articular por qué el hook pre-commit es la *primera* defensa (no la única) para que el catálogo no se degrade.
- Escribir un hook Bash que use `python3` + `pyyaml` para validar sintaxis y mínimos.
- Diseñar fixtures que cubren los errores más habituales (ver §4 del `theory/lesson.md`).
- Instalar el hook en un repo real (snippet para `.pre-commit-config.yaml` **o** `.git/hooks/pre-commit`).

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (en particular §9 y la tabla de errores de §11).
- Haber recorrido `examples/01-catalog-info-skeleton/`.
- Herramientas: `bash`, `python3` ≥ 3.9 con `pyyaml`.

**Costos**: ninguno (todo local).

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/plat-05-precommit/fixtures
cd /tmp/plat-05-precommit
```

Puedes usar otro directorio, pero entonces debes pasárselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Qué debes producir

Archivos esperados bajo `/tmp/plat-05-precommit/`:

```
/tmp/plat-05-precommit/
├── validate-catalog-info.sh         # tu hook (ejecutable, shebang bash)
├── install.md                       # como instalarlo en un repo real
└── fixtures/
    ├── good-component.yaml          # pasa validacion
    ├── bad-missing-owner.yaml       # falla: sin spec.owner
    ├── bad-too-few-annotations.yaml # falla: <2 annotations
    ├── bad-broken-yaml.yaml         # falla: YAML malformado
    └── bad-missing-name.yaml        # falla: sin metadata.name
```

### 5.3 Contrato del hook `validate-catalog-info.sh`

- Debe aceptar **1+ argumentos**: paths a archivos `.yaml`.
- Debe salir con exit code **0** si todos pasan, **1** si al menos uno falla.
- Debe imprimir, por cada archivo, `OK <path>` o `FAIL <path>: <razon>`.
- Debe tener shebang (`#!/usr/bin/env bash` o similar).
- Debe ser **ejecutable** (`chmod +x validate-catalog-info.sh`).

### 5.4 Reglas que el hook debe aplicar

Para cada archivo `.yaml` recibido:

1. YAML parseable (sin excepción de `yaml.safe_load_all`).
2. Cada documento con `apiVersion`, `kind`, `metadata.name`, `spec` presentes.
3. `metadata.name` matchea `^[a-z0-9]([-a-z0-9]*[a-z0-9])?$`.
4. Si `kind` es `Component`, `API`, `Resource` o `System`: `spec.owner` existe y empieza por `group:` o `user:`.
5. Si `kind` es `Component`: `metadata.annotations` tiene ≥ 2 claves.

### 5.5 Fixtures: ejemplos esperados

`fixtures/good-component.yaml` (debe pasar):

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: orders-api
  annotations:
    github.com/project-slug: acme/orders-api
    backstage.io/techdocs-ref: dir:.
spec:
  type: service
  lifecycle: production
  owner: group:orders-team
```

`fixtures/bad-missing-owner.yaml` (debe fallar: falta `spec.owner`):

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: orders-api
  annotations:
    github.com/project-slug: acme/orders-api
    backstage.io/techdocs-ref: dir:.
spec:
  type: service
  lifecycle: production
```

(Los demás `bad-*` son variantes análogas; diséñalos tú.)

### 5.6 `install.md`: cómo instalarlo

Un documento corto que explica a un developer cómo enchufar el hook en un repo:

**Opción A — nativo de git:**

```bash
cp validate-catalog-info.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

(Con el detalle de que el hook del repo debe recibir los archivos modificados; muestra cómo listarlos: `git diff --cached --name-only --diff-filter=ACM | grep 'catalog-info.yaml'`.)

**Opción B — framework `pre-commit`:**

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: validate-catalog-info
        name: Validate catalog-info.yaml
        entry: bash validate-catalog-info.sh
        language: system
        files: 'catalog-info\.yaml$'
```

### 5.7 Entregable

El árbol de archivos descrito en §5.2 bajo `/tmp/plat-05-precommit/`, que:

- Pasa `bash tests/validate.sh /tmp/plat-05-precommit`.
- Rechaza correctamente los fixtures malos.
- Acepta el fixture bueno.

## 6. Resultado esperado

- `validate-catalog-info.sh` es ejecutable, tiene shebang, usa `python3` + `pyyaml` para parsear.
- Al correr tu hook contra `fixtures/good-component.yaml` → exit 0.
- Al correr tu hook contra cualquier `fixtures/bad-*.yaml` individualmente → exit 1.
- Al correr tu hook contra la mezcla (bueno + malos juntos) → exit 1.
- `install.md` menciona ambas opciones (git nativo y framework `pre-commit`).

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: el hook es breve (<120 líneas), legible, con mensajes de error que dicen **qué falla y cómo arreglarlo**.
- **Reproducibilidad**: cualquiera que copie `validate-catalog-info.sh` + `install.md` puede instalarlo en 5 minutos.
- **Mantenibilidad**: hook sin dependencias extras aparte de `bash` + `python3` + `pyyaml`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/plat-05-precommit
```

El validador comprueba:

1. Existencia de los archivos listados en §5.2.
2. `validate-catalog-info.sh` es ejecutable y tiene shebang.
3. Al invocar tu hook con el fixture bueno sale 0; con cada fixture malo sale ≠ 0.
4. El `install.md` menciona `pre-commit` o `.git/hooks/pre-commit`.

Compara tu hook con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. ¿Qué parte de la validación **no** puede hacer un pre-commit y requiere un check en CI? (pista: resolución de relaciones cross-repo).
2. Si tu hook falla con el fixture `bad-broken-yaml.yaml`, ¿imprime una traza de Python o un error legible? ¿Qué prefieres y por qué?
3. ¿Qué tan estricto conviene ser con `metadata.annotations` requeridas? ¿Mínimo 2 es suficiente o deberías listar annotations obligatorias por nombre?
4. Si un equipo quiere **excepcionar** su repo del hook, ¿cómo lo diseñarías para que la excepción sea trazable (no silenciosa)?
5. ¿Qué 2 reglas más añadirías cuando tu catálogo crezca a 100+ Components?

## 10. Extensiones

- Añade una **sexta** regla: `metadata.name` debe matchear además un prefix (p. ej., el prefix del system).
- Convierte el hook en un **GitHub Action** reusable que ejecuta la misma validación en PRs.
- Añade un **modo dry-run** (`--check` sin modificar nada) para que CI pueda usar el mismo script.
- Añade **colorización** (si TTY) para que los `OK` sean verdes y los `FAIL` rojos.
- Mide cuánto tarda el hook con 1 archivo vs 50; documenta el límite donde ya no es "pre-commit friendly" (idealmente < 500 ms).

## 11. Limpieza

Para empezar de cero:

```bash
rm -rf /tmp/plat-05-precommit
```

No hay procesos ni contenedores que detener.
