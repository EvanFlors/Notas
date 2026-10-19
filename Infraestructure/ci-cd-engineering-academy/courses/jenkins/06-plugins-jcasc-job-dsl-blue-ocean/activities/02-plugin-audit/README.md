# Actividad 02 — Audit de plugins de un Jenkins legacy

## 1. Identificación

- **ID:** `jk-06-02-plugin-audit`
- **Tecnología:** `jenkins`
- **Módulo:** `jk-06-plugins-jcasc-job-dsl-blue-ocean`
- **Dificultad:** advanced
- **Duración estimada:** 50–70 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Heredas un Jenkins legacy con **más de 20 plugins instalados sin pinning**. El equipo de Security pide una auditoría: qué plugins hay, cuáles son necesarios, cuáles son candidatos a eliminación, cuáles tienen advisories vigentes, y qué pasa con Blue Ocean. El entregable es un *audit* escrito + un `plugins-current.txt` (estado actual) + un `plugins-target.txt` (estado destino con pinning y menos plugins).

**Importante**: no hay Jenkins real. Trabajas con la lista hipotética provista en `starter/plugins-current-raw.txt` (o construyes la tuya si prefieres).

## 3. Objetivos

Al terminar deberías poder:

- Leer un listado de plugins instalados y clasificarlos como `keep` / `replace` / `remove`.
- Escribir `plugins-current.txt` (puede ser el raw del starter).
- Escribir `plugins-target.txt` **con pinning estricto** y **menos plugins** que el current.
- Documentar en `plugin-audit.md` las decisiones, CVE awareness, estado de Blue Ocean y cadencia de updates.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` §2 (plugin ecosystem) y §5 (Blue Ocean).
- Herramientas: `bash`, editor de texto.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/jk-06-02
cd /tmp/jk-06-02
```

Si quieres partir del listado raw, copia:

```bash
cp /ruta/al/repo/courses/jenkins/06-plugins-jcasc-job-dsl-blue-ocean/activities/02-plugin-audit/starter/plugins-current-raw.txt \
   /tmp/jk-06-02/plugins-current.txt
```

### 5.2 Escribe los 3 archivos

Nombres **exactos**:

1. `plugins-current.txt` — estado actual (puede llevar `plugin` sin versión; refleja el legacy).
2. `plugins-target.txt` — estado destino. **Toda** línea no-comentario debe tener `nombre:version` (pinning estricto). Debe tener **menos** plugins no-comentario que `plugins-current.txt`.
3. `plugin-audit.md` — el documento del audit.

#### Requisitos de `plugins-target.txt`

- Al menos 5 líneas no-comentario.
- **Todas** pinneadas (`nombre:version`, nunca `:latest`).
- Debe incluir obligatoriamente `configuration-as-code` y `job-dsl` (son la base para gestionar la vida futura del controller).
- Debe tener estrictamente **menos** líneas no-comentario que `plugins-current.txt` (la auditoría reduce).

#### Secciones obligatorias en `plugin-audit.md`

El validador busca por heading:

- `## Inventario`
- `## Clasificación` (acepta `Clasificacion` sin tilde)
- `## Plan`
- `## Blue Ocean`
- `## CVE`

Además, el documento debe mencionar al menos una vez:

- `pinning` o `version` (contexto de plugins).
- `cadencia` o `cadence` (ritmo de updates).
- `CloudBees` o `advisory` o `security` (fuente de CVE awareness).

### 5.3 Entregables

```
/tmp/jk-06-02/
├── plugins-current.txt
├── plugins-target.txt
└── plugin-audit.md
```

## 6. Resultado esperado

- Validador pasa en verde.
- `plugins-target.txt` tiene estrictamente menos plugins que `plugins-current.txt` (reducción real).
- `plugins-target.txt` 100% pinneado.
- `plugin-audit.md` cubre inventario, clasificación, plan, Blue Ocean, CVE.

## 7. Criterios de aceptación

- **Estructura**: validador pasa.
- **Reducción**: `target` < `current` en cantidad de plugins.
- **Pinning**: `target` 100% pinneado.
- **Correctitud conceptual** (autoevaluación): comparar con `solution/`.

## 8. Validación

```bash
bash tests/validate.sh /tmp/jk-06-02
```

El validador comprueba:

- Existencia de los 3 archivos.
- `plugins-target.txt` 100% pinneado y con `configuration-as-code` + `job-dsl`.
- `plugins-target.txt` tiene **menos** líneas no-comentario que `plugins-current.txt`.
- `plugin-audit.md` tiene las 5 secciones y las menciones mínimas.

## 9. Preguntas de reflexión

1. ¿Qué métrica usarías para medir el progreso de reducción de plugins mes a mes?
2. Si un plugin solo lo usa un job legacy, ¿lo quitas, lo marcas deprecated, o esperas a migrar el job?
3. ¿Cómo detectas en runtime si un plugin "instalado" realmente se está usando?
4. ¿Qué política aplicas para plugins sin releases en los últimos 24 meses?
5. ¿Dónde publicarías el `plugin-audit.md` para que no se pierda tras el merge?

## 10. Extensiones

- Añade una columna "último release conocido" al inventario.
- Marca con etiqueta `[deprecated-upstream]` los plugins que están archivados en jenkins.io.
- Escribe un `plan-rollout.md` con fases (quincenal) para pasar de `current` a `target` sin ventanas de downtime.

## 11. Limpieza

```bash
rm -rf /tmp/jk-06-02
```
