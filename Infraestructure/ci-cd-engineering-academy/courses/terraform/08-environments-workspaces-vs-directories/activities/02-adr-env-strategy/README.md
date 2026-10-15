# tf-08-02 — ADR: estrategia de ambientes

## 1. Identificación

- **ID:** `tf-08-02-adr-env-strategy`
- **Tecnología:** terraform
- **Módulo:** `08-environments-workspaces-vs-directories`
- **Dificultad:** intermediate
- **Duración estimada:** 75 min
- **Tipo:** independent (ADR)

## 2. Contexto

Vas a redactar un **Architecture Decision Record** (ADR) decidiendo cómo modelar los ambientes `dev`, `stg`, `prod` (y feature envs efímeros) para la siguiente organización ficticia:

> **Shoply S.A.** — e-commerce mediano. Un repo monorepo de infra. Equipo de 8 ingenieros (5 app, 2 SRE, 1 líder). Nube: AWS, una sola cuenta por ambiente — ya existen cuentas `shoply-dev`, `shoply-stg`, `shoply-prod` separadas. Pipeline GitHub Actions. Hoy: todo vive en un único root module con workspaces (`default`, `stg`, `prod`), un bucket S3 compartido para los tres states. Nadie confía en apretar `apply` desde su laptop. Ha habido un incidente: un ingeniero corrió `terraform destroy` creyendo estar en `stg`, estaba en `prod`.

Tu trabajo: proponer una estrategia nueva como ADR y defenderla. El validador comprueba la **estructura** del ADR y la presencia de secciones y decisiones mínimas — **no** evalúa tu criterio por ti; eso lo hace tu revisor humano (lead/SRE) en una lectura.

> No reveles aquí la "respuesta correcta". El ADR es tu respuesta; se discute en revisión.

## 3. Objetivos

Al terminar deberías poder:

- Redactar un ADR con contexto, decisión, consecuencias y alternativas.
- Elegir conscientemente entre workspaces, directorios y Terragrunt-like, enumerando trade-offs.
- Justificar **al menos tres riesgos específicos** de la configuración actual (un workspace por ambiente, backend compartido).
- Diseñar la transición (migración incremental, no "big bang").

## 4. Prerrequisitos

- Haber leído `theory/lesson.md` completo.
- Haber hecho `tf-08-01-split-stack-into-three-envs`.
- Un editor de texto. Nada que instalar.
- Sin coste.

## 5. Instrucciones

1. Copia la plantilla:

   ```bash
   mkdir -p /tmp/tf-08-02
   cp activities/02-adr-env-strategy/starter/ADR-env-strategy.md /tmp/tf-08-02/ADR-env-strategy.md
   ```

2. Edítala. Rellena **cada sección**. La plantilla te marca qué va en cada una.

3. Para la sección "Decisión", elige **uno** de los patrones principales:

   - A) Directorios separados por ambiente con módulos locales compartidos.
   - B) Directorios separados por ambiente con módulos remotos versionados (git tags).
   - C) Terragrunt-like.
   - D) Workspaces (si eliges esto, el ADR debe justificar extraordinariamente bien por qué).

4. Para la sección "Riesgos del status quo" enumera **≥ 3 riesgos concretos** del esquema actual (workspace único + backend compartido). Pueden ser los que vimos en la lección (§6) u otros que detectes.

5. Para la sección "Plan de migración" describe los pasos sin perder prod — p. ej., bootstrap de nuevos backends, `terraform state mv` o `import`, cómo cortar el tráfico de IaC, cómo rollback.

6. Valida la estructura:

   ```bash
   bash activities/02-adr-env-strategy/tests/validate.sh /tmp/tf-08-02/ADR-env-strategy.md
   ```

## 6. Resultado esperado

- Un archivo `/tmp/tf-08-02/ADR-env-strategy.md` que:
  - Tiene las 9 secciones de la plantilla.
  - Declara una decisión explícita (una línea comenzando con `**Decisión:**`).
  - Enumera ≥ 3 riesgos del status quo.
  - Enumera ≥ 2 alternativas descartadas con razón.
  - Contiene un plan de migración con ≥ 3 pasos.

## 7. Criterios de aceptación

- Un lector no familiarizado con Shoply puede entender el *contexto*, la *decisión* y las *consecuencias* en < 10 min.
- La decisión es defendible contra los riesgos del status quo listados.
- El plan de migración no tiene pasos "big bang" (p. ej. "borramos todo y empezamos").
- El ADR respeta el formato Markdown (encabezados jerárquicos, listas donde corresponde).

## 8. Validación

```bash
bash courses/terraform/08-environments-workspaces-vs-directories/activities/02-adr-env-strategy/tests/validate.sh /tmp/tf-08-02/ADR-env-strategy.md
```

## 9. Preguntas de reflexión

1. ¿Qué cambiaría tu decisión si Shoply tuviera 80 ingenieros en 10 equipos, cada uno con sus propios módulos?
2. ¿Qué cambiaría si Shoply fuera multi-cloud (AWS + GCP)?
3. ¿Qué cambiaría si en vez de un incidente de `destroy` hubieran tenido un incidente de **credencial filtrada**?
4. ¿Tu ADR permite que un developer pruebe su rama sin coordinar con nadie? ¿Es eso un objetivo?

## 10. Extensiones

- Convierte tu ADR en un diagrama (mermaid) adjunto que muestre el flujo PR → plan → apply.
- Añade una sección "métricas de éxito" con cómo medirías 90 días después si la estrategia funcionó.
- Redacta un segundo ADR complementario sobre **secretos** por ambiente (dónde viven, cómo los consume Terraform).

## 11. Limpieza

```bash
rm -rf /tmp/tf-08-02
```
