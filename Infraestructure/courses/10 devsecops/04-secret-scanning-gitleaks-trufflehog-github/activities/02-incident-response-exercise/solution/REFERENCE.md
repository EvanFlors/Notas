# REFERENCE — sec-04-02

Respuesta de referencia. Léela **después** de haber redactado la tuya.

## Seccion A — Cronologia (0–60 min)

1. **[10:32] Confirmar hallazgo.** Verificar que el valor en `services/billing/config.yaml:14` tiene formato Stripe real (`sk_live_...`) y no es una fixture bajo `tests/`. Si fuera FP, allowlist y stop. En este escenario: confirmado real.
2. **[10:35] Rotar en Stripe.** Dashboard → API keys → *Roll*. Emite nueva, revoca la vieja. Esta acción es irreversible y hace el valor filtrado inútil hacia adelante. **Blast radius futuro: cero.**
3. **[10:45] Desplegar `billing` con la nueva clave.** Publicar en el gestor de secretos (Vault / ESO / GitHub Encrypted Secrets), redeploy del servicio. Verificar health check.
4. **[10:55] Notificar.** Mensaje a `#sec-incidents` con: ventana de exposición (02/10 10:00 → 13/10 10:30), repo, scope, estado de rotación (completada), siguiente paso (investigación).

## Seccion B — Investigacion (2–6 h)

- **Logs Stripe** (retenidos 90 d) en la ventana `02/10 10:00 → 13/10 10:35`: `GET/POST` de la nueva clave vieja, listar IPs origen, UA headers.
- Señales de abuso: llamadas desde IPs fuera del rango de nuestros runners/clusters; patrones de descarga masiva (`GET /v1/customers` con paginación completa); creación de recursos no esperados (nuevos products, prices, payouts a cuentas desconocidas).
- Umbral de escalado a incidente mayor: cualquier evidencia de uso no originado por nuestros servicios → activar incident response, legal/comms, y notificación a clientes si hay posible exposición de datos (PCI scope).

## Seccion C — Limpieza (24–48 h)

```bash
# Clone fresh — nunca filter-repo sobre tu copia principal
git clone --mirror git@github.com:org/repo.git repo-cleanup.git
cd repo-cleanup.git

cat > /tmp/replacements.txt <<'EOF'
sk_fake_live_FAKEstripe00000000000000demo==>REMOVED
EOF

git filter-repo --replace-text /tmp/replacements.txt
git log -p | grep -c "sk_fake_live_FAKEstripe" && echo "still present" || echo "clean"

# Coordinar force-push:
#   1. Anuncio en #eng: "force-push a main a las HH:MM. No hagan git pull."
#   2. Freeze de merges por 30 min.
#   3. git push --force --mirror
#   4. Instrucciones de re-clone para el equipo.

# Forks internos: notificar a cada owner; cada fork debe ser rebase/re-sync
# desde el main reescrito, o abandonado y re-forkeado.
```

## Seccion D — Anti-patrones

1. **`git rm services/billing/config.yaml && git commit`** — el blob queda accesible por hash para siempre; `git show a1b2c3d:services/billing/config.yaml` lo recupera. **No reduce exposición.**
2. **`git commit --amend`** — solo arregla el último commit. El commit `a1b2c3d` tiene 11 días; `--amend` no lo toca.
3. **Reescribir historia **antes** de rotar** — mientras el valor sea válido, está igual de comprometido; el atacante que ya tenga clonado el repo conserva la clave. Rotar es la mitigación real; reescribir es higiene posterior.
4. **Borrar el repo y re-crearlo** — pierdes historia útil, los forks siguen vivos, y los clones ajenos conservan el commit. Peor que inútil.

## Seccion E — Controles preventivos

1. **GitHub push protection** (gratis en public; GHAS en private) — bloquea el push antes de que el commit llegue al servidor. Habría cortado el leak en el `git push` original de Alice.
2. **Pre-commit obligatorio en bootstrap del repo** — `make bootstrap` instala `.git/hooks/pre-commit`; gitleaks local atrapa el commit antes de que exista.
3. **Workflow CI con `fetch-depth: 0`** y `trufflehog --only-verified` en `main` — segunda red; con `--only-verified` cero FP, cualquier hallazgo es verdadero positivo accionable.
4. (bonus) **Migración a secrets manager** (Vault / External Secrets / SOPS) — elimina la razón original para que un YAML tenga la clave en claro.

## Seccion F — Post-mortem (sintesis)

- **Qué pasó:** una PR introdujo `STRIPE_SECRET_KEY` en `config.yaml`. CI lo detectó 11 días después, al mergearse otra PR que modificaba el mismo archivo.
- **Causa raíz:** no había push protection ni pre-commit obligatorio; el workflow `secret-scan` existía pero no corría en la rama de la PR original.
- **Qué cambiamos:** activación de push protection (vía GHAS); `pre-commit install` en el `make bootstrap`; `secret-scan` como check obligatorio en branch protection de todas las ramas; `trufflehog --only-verified` en `main`; proyecto piloto para migrar credenciales de servicio a External Secrets.

## Lecciones transversales

- La rotación es la única acción que reduce blast radius a cero. Todo lo demás es cosmético.
- Un leak de 11 días en un repo privado con 3 forks y 40 clones tiene superficie real: cada clon es una copia perpetua del secreto.
- El post-mortem **no busca culpables**; busca el control que faltaba.
