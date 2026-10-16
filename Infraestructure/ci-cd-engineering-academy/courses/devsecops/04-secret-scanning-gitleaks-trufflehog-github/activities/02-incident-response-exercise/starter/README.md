# Starter — sec-04-02

No hay código inicial. Crea tu propio `/tmp/sec-04-incident/RESPONSE.md`
siguiendo `../README.md`.

Plantilla sugerida:

```markdown
# RESPONSE — leak Stripe en services/billing/config.yaml

## Seccion A — Cronologia (0–60 min)

1. [10:35] ...
2. [10:40] Rotar clave en Stripe → ...
3. ...

## Seccion B — Investigacion (2–6 h)

- Logs a revisar: ...
- Senal de abuso: ...

## Seccion C — Limpieza (24–48 h)

```bash
git filter-repo --replace-text ...
```

## Seccion D — Anti-patrones

1. `git rm ... && git commit` — por que no sirve.
2. `git commit --amend` — por que no sirve.
3. Reescribir historia antes de rotar — por que es peligroso.

## Seccion E — Controles preventivos

- push protection.
- pre-commit en bootstrap.
- trufflehog --only-verified en main.

## Seccion F — Post-mortem

- Que paso: ...
- Causa raiz: ...
- Que cambiamos: ...
```

Cuando termines:

```bash
bash ../tests/validate.sh /tmp/sec-04-incident
```
