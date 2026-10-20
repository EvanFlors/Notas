# Solución de referencia — jk-07-01-harden-fresh-jenkins

> No es "la" solución; es una. Hay varios YAML válidos para los requisitos de la actividad.

## Archivos

- `jenkins.yaml` — ejemplo completo que pasa el validador.
- `HARDENING-NOTES.md` — ejemplo de documento justificativo con las 5 secciones.

## Puntos clave de autoevaluación

1. **Roles asignados a grupos**, nunca a usuarios. Si tu YAML tiene `user:` en algún `entries:`, replantéalo.
2. **`anonymous` sin role**. Verifícalo buscando literal `anonymous` en tu YAML — no debería aparecer.
3. **`allowsSignup: false`** en el realm local.
4. **CSRF explícitamente on** vía `crumbIssuer.standard`.
5. **Secretos solo via `${ENV_VAR}`**. Un `grep -E 'ghp_|AKIA|-----BEGIN RSA' jenkins.yaml` no debe devolver nada en Git — ni en tu demo.
6. **`approvedSignatures` concretas**, sin `invoke` o `evaluate` como catch-all.
7. **Patrones `items.pattern` anclados** con `^` y `.*` para evitar ambigüedad (`^team-a/.*` no `team-a`).

## Red flags clásicas a buscar en tu propio YAML

| Patrón | Por qué está mal |
|--------|------------------|
| `password: "s3cret!"` literal | Secreto en Git. |
| `entries: [ { group: "anonymous" } ]` | Lectura sin login. |
| `approvedSignatures: [ "method ... invoke ..." ]` | Sandbox desactivado. |
| `items.pattern: ".*"` | Equivale a global role. |
| Un rol `developer` con `Overall/Administer` | "Developer" ya no significa lo que crees. |

## Cómo ir más allá

- Añade un bloque `jenkins.remotingSecurity` o nota en "pendiente" sobre deshabilitar la CLI remota si no se usa.
- Añade un `tool:` block con herramientas pinneadas (JDK, Maven) — también parte de la reproducibilidad.
- Añade un comentario con el *schema* esperado (`# @see https://jenkins.io/doc/book/managing/configuration-as-code/`) para que el próximo editor sepa dónde mirar.
