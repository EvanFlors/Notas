# Starter — argo-01-01-identify-gitops-washing

Esta actividad es **independent / análisis**: no hay starter de código. El entregable es `MAP.md` que tú escribes en `/tmp/argo-01-washing/`.

## Pasos rápidos

```bash
mkdir -p /tmp/argo-01-washing
cd /tmp/argo-01-washing
# edita MAP.md con tu editor preferido
```

Esqueleto sugerido (no obligatorio copiarlo tal cual — el validador solo chequea estructura mínima):

```markdown
# MAP — GitOps o GitOps-washing: auditoria de 5 escenarios

## Seccion 1 — Principios OpenGitOps

1. Declarative — ...
2. Versioned and Immutable — ...
3. Pulled Automatically — ...
4. Continuously Reconciled — ...

## Seccion 2 — Auditoria por escenario

### Escenario A — Acme Classic

| Principio | Cumple? | Nota |
|-----------|:-------:|------|
| 1 Declarative | ? | ... |
| 2 Versioned & Immutable | ? | ... |
| 3 Pulled Automatically | ? | ... |
| 4 Continuously Reconciled | ? | ... |

**Veredicto**: ...
**Principio(s) violado(s)**: ...
**Consecuencia operativa**: ...
**Correccion minima**: ...

### Escenario B — Acme Argo
...

### Escenario C — Acme Pull But Not Continuous
...

### Escenario D — Acme Scripted
...

### Escenario E — Acme S3 Pivot
...

## Seccion 3 — Preguntas obligatorias

1. ...
2. ...
3. ...
4. ...
5. ...
6. ...
7. ...
```

Valida con:

```bash
bash tests/validate.sh /tmp/argo-01-washing
```
