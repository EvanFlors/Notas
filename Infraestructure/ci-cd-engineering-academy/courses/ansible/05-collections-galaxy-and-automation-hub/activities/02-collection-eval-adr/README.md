# Actividad 02 — Escribir un ADR comparando community.aws vs amazon.aws

## 1. Identificación

- **ID:** `ans-05-02-collection-eval-adr`
- **Tecnología:** `ansible`
- **Módulo:** `ans-05-collections-galaxy-and-automation-hub`
- **Dificultad:** intermediate
- **Duración estimada:** 70–80 min
- **Tipo:** independent (sin dependencia de la actividad 01)

## 2. Contexto

Tu organización está empezando a estandarizar los playbooks AWS y hay dos candidatos naturales para la mayoría de tareas: la collection comunitaria **`community.aws`** y la certified **`amazon.aws`**. Ambas cubren un dominio parecido con solapamiento parcial; ninguna cubre todo. Tienes contratada **Red Hat Ansible Automation Platform (AAP)**, así que Automation Hub está disponible.

El Platform Lead te pide un **ADR** (Architecture Decision Record) corto, versionado, que un ingeniero que no estuvo en la discusión pueda leer y entender la decisión. Debe comparar las dos collections con **6 criterios explícitos** y proponer una regla operativa: "usamos X por defecto, caemos a Y cuando...".

**Importante**: no se consume ninguna collection ni se publica nada. El entregable es un documento Markdown.

## 3. Objetivos

Al terminar deberías poder, **sin consultar la lección**:

- Nombrar los 6 criterios de adopción (mantenimiento activo, namespace / propietario, cobertura, dependencias upstream, licencia, alternativa certificada).
- Diferenciar una collection certified (firmada, soportada por vendor) de una comunitaria (ni firmada ni soportada).
- Defender la regla operativa que propones ante alguien que pregunte "¿y si community.aws tiene el módulo que me falta?".
- Explicar por qué `amazon.aws` tiende a ser la elección por defecto en una org con AAP.

## 4. Prerrequisitos

- Haber leído `../../theory/lesson.md` completo (§5, §8 y §9).
- Haber recorrido `../../examples/03-automation-hub-walkthrough/`.
- Herramientas: `bash` y un editor Markdown. **Nada más**.

**Costos**: ninguno.

## 5. Instrucciones

### 5.1 Preparar el directorio de trabajo

```bash
mkdir -p /tmp/ans-05-02
cd /tmp/ans-05-02
```

Puedes usar otro directorio, pero entonces pásaselo al validador: `bash tests/validate.sh /tu/ruta`.

### 5.2 Escribe `ADR-COLLECTION-ADOPTION.md`

Formato que debes seguir:

```
# ADR 002 — Adopcion de collections AWS (community.aws vs amazon.aws)

## Estado
Propuesto | Aceptado | Reemplazado por ADR XXX

## Contexto
(2-4 parrafos: que decides, por que ahora, que constraints hay —
tenemos AAP, estamos en Europa, ya consumimos amazon.aws en un repo)

## Decision
(La regla operativa: "usamos X por defecto, caemos a Y cuando...".
Incluye una tabla de comparacion de las dos collections contra los
6 criterios de adopcion.)

## Consecuencias
(Que ganas, que pierdes, que se vuelve mas facil, que mas caro.
Debe cubrir tanto positivas como negativas.)

## Alternativas descartadas
(Al menos 2 alternativas: p. ej. "usar solo community.aws",
"escribir modulos propios en una collection interna", "boto3 directo
desde Python". Por que no.)
```

### 5.3 Contenido mínimo obligatorio (el validador lo exige)

Secciones Markdown (`^#+ ...`):

1. **`# ADR`** (encabezado con la palabra "ADR").
2. **`## Estado`** (o `Status`).
3. **`## Contexto`** (o `Context`).
4. **`## Decision`** o `## Decisión` (o `Decision`).
5. **`## Consecuencias`** (o `Consequences`).
6. **`## Alternativas`** (o `Alternatives` — al menos 2 descartadas).

Contenido:

- Mención explícita de **ambas** collections: `amazon.aws` **y** `community.aws`.
- Mención de **`ansible-core`** (justificando el pin / rango).
- Mención de **Automation Hub** (o `AAP` / `Red Hat Automation Platform`).
- Mención de **Galaxy** (público) como fallback.
- Al menos **6 criterios** de adopción nombrados textualmente. El validador busca estos tokens (en castellano o inglés, uno de cada):
  - `mantenimiento` o `maintenance`
  - `cobertura` o `coverage`
  - `dependencias` o `dependencies` (upstream)
  - `licencia` o `license`
  - `certificad` o `certified`
  - `namespace` o `propietario` o `owner`
- Mención del **patrón de rollback** vía pin de versión (palabras: `pin`, `rollback`, `fijar version` — el validador acepta cualquiera).
- Una **tabla Markdown** (líneas con `|`) comparando ambas collections.
- Al menos **2 alternativas** descartadas (sub-headings o items numerados).

### 5.4 Entregable

Un archivo:

```
/tmp/ans-05-02/ADR-COLLECTION-ADOPTION.md
```

## 6. Resultado esperado

- `ADR-COLLECTION-ADOPTION.md` existe y es coherente.
- El validador estructural pasa en verde.
- Un ingeniero externo puede leerlo y entender **cuál collection usas por defecto** y **cuándo caes a la otra**.

## 7. Criterios de aceptación

- **Funcionalidad**: validador estructural pasa.
- **Calidad**: cada criterio está justificado, no solo listado.
- **Mantenibilidad**: Markdown válido, tabla legible.

## 8. Validación

```bash
bash tests/validate.sh /tmp/ans-05-02
```

El validador comprueba **estructura y palabras clave**, no semántica. Compara tu ADR con `solution/REFERENCE.md` después de haberlo hecho para autoevaluarte.

## 9. Preguntas de reflexión

1. Si Red Hat deja de certificar `amazon.aws`, ¿cómo cambia tu decisión?
2. ¿Qué pasa si un módulo que necesitas vive **solo** en `community.aws`? ¿Fork? ¿Contribuir upstream? ¿Reescribir?
3. Si otra org te pregunta "¿por qué no `boto3` directo desde un `script` module?", ¿qué contestas?
4. ¿Cómo pruebas que la decisión sigue siendo buena dentro de 1 año? ¿Qué métricas revisas?
5. Si pierdes la subscripción AAP, ¿tu ADR sigue en pie?

## 10. Extensiones

- Añade una tabla con las últimas 3 releases de cada collection y las breaking changes de cada una.
- Añade un apartado "Fase 2" previendo qué pasa cuando aparezca una tercera collection (p. ej. `aws.cloud` hipotética).
- Añade una SCP del flujo de aprobación interno: "cómo se añade una collection nueva al `requirements.yml`".

## 11. Limpieza

```bash
rm -rf /tmp/ans-05-02
```

No hay infraestructura que detener.
