# Actividad 03 — ADR: GitHub App vs PAT vs OIDC

## 1. Identificación

- **ID:** `gh-12-03-github-app-vs-pat`
- **Tecnología:** `git-and-github`
- **Módulo:** `gh-12-github-governance-and-automation`
- **Dificultad:** advanced
- **Duración estimada:** 60 min
- **Tipo:** architecture (independent)

## 2. Contexto

Te asignan diseñar la identidad de una automatización productiva. Debes **elegir y justificar por escrito**:

- Una **GitHub App**, o
- Un **PAT fine-grained** (atado a un bot humano), o
- Un **PAT classic** (desaconsejado, pero debe aparecer en el análisis), o
- **OIDC federation** a una cloud (si aplica).

El entregable es un **ADR** (Architecture Decision Record) corto siguiendo el template clásico.

## 3. Escenario

Tu empresa tiene:

- Una org en GitHub Enterprise con 40 repos.
- Un bot que debe: (a) etiquetar PRs con labels según el path tocado, (b) actualizar un comentario en el PR con el status del despliegue cuando CI termina, (c) tras merge a `main`, subir un artefacto a un bucket S3 en AWS.
- 3 clouds en juego: AWS (prod), GCP (data), on-prem Vault para secretos.
- Compliance exige: *no credenciales > 90 días*, *rotación trazable*, *audit log cross-org*.

Debes escribir un ADR eligiendo la(s) identidad(es) para cumplir (a), (b), (c).

## 4. Objetivos

Al terminar:
- Producir un ADR en el formato estándar (status, context, decision, consequences, alternatives).
- Argumentar basado en: TTL, blast radius, auditabilidad, operabilidad.
- Reconocer cuándo una decisión no es "uno u otro" sino **composición** (GitHub App para GitHub + OIDC para AWS).

## 5. Prerrequisitos

- Haber leído la lección (§2.5, §4.2, §4.3, §8.3, §8.4).
- Ningún permiso ni cuenta — es un ejercicio de diseño.

**Costos**: ninguno.

## 6. Instrucciones

```bash
bash starter/build-scratch.sh /tmp/adr-identity
cd /tmp/adr-identity
# Edita ADR.md siguiendo el template y respondiendo todo lo marcado como <TODO>.
```

El template exige (ver `starter/ADR.md`):

- **Title**: identifica la decisión.
- **Status**: `proposed` / `accepted` / `superseded`.
- **Context**: resumen del problema (puedes copiar del escenario, pero añade tu propia síntesis).
- **Decision**: la elección final, con los componentes (puede ser 2–3 identidades combinadas).
- **Consequences**: positivas y negativas, en términos de **operación**, **seguridad**, **velocidad**.
- **Alternatives considered**: al menos 2 descartadas, con *por qué*.
- **Compliance mapping**: cómo cada requisito del compliance se cumple (o se debe cerrar luego).

Longitud objetivo: **300–600 palabras**. Más corto que eso suele significar "no justifiqué". Más largo, "no decidí".

## 7. Resultado esperado

- `/tmp/adr-identity/ADR.md` lleno (sin `<TODO>` restantes).
- Secciones presentes y nombradas según el template.
- Al menos 2 alternativas descartadas.
- Longitud dentro del rango.

## 8. Criterios de aceptación

- [ ] Formato ADR estándar.
- [ ] Decisión incluye al menos *una* de: GitHub App, OIDC. (Un ADR productivo serio no termina en "PAT classic".)
- [ ] Compliance mapping cubre los 3 requisitos.
- [ ] Alternativas razonadas con trade-offs explícitos.

## 9. Validación

```bash
bash tests/validate.sh /tmp/adr-identity
```

El validador comprueba estructura, longitud, presencia de secciones y palabras clave clave. No evalúa calidad semántica (eso es tu reflexión + un review humano opcional).

## 10. Preguntas de reflexión

1. Si el requisito de compliance pasara de "90 días" a "1 día", ¿cambiaría tu elección? ¿Cómo?
2. ¿En qué escenario defenderías un PAT fine-grained aquí?
3. ¿Qué cambia si en lugar de 1 bot son 10 bots específicos por team?

## 11. Extensiones

- **E1** — Añade un diagrama (ASCII o Mermaid) del flujo de token para cada parte del bot.
- **E2** — Lista 3 controles operativos (dashboards, alertas, revocación) necesarios para operar la decisión.
- **E3** — Escribe un segundo ADR que *supersede* al primero asumiendo que la empresa migra todo a GitLab (ejercicio de contraste).

## 12. Limpieza

```bash
rm -rf /tmp/adr-identity
```
