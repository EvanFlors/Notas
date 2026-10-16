# Ejemplo 03 — Rotar → notificar → reescribir historia

Guión paso a paso cuando el scanner detecta un secreto **real** en la historia. El orden importa.

## Escenario

CI acaba de reportar que `config/prod.yaml` del commit `a1b2c3d` (hace 11 días) contiene:

```
STRIPE_SECRET_KEY: sk_fake_live_FAKEstripe00000000000000demo
```

(El valor aquí es obviamente ficticio. En la realidad sería una clave viva.)

## Paso 0 — Confirmar que no es FP

- ¿El valor coincide con el formato real del proveedor? (Stripe keys reales empiezan por `sk_live_`.)
- ¿Está en un path de fixture/test? (Si sí: allowlist y stop.)
- Si tienes dudas, intenta usarla contra el API del proveedor **tú** antes que un atacante.

## Paso 1 — ROTAR primero

En el dashboard del proveedor (Stripe, AWS, GitHub, ...):

- Revoca la clave actual.
- Emite una nueva.
- Publícala en el gestor de secretos (SOPS, Vault, External Secrets, GitHub Encrypted Secrets).
- Despliega el servicio con la nueva clave.

Hasta aquí el secreto filtrado ya es **inútil**. Esto es irreversible. Todo lo demás es higiene.

## Paso 2 — Notificar

- Equipo de seguridad: fecha de exposición (commit date), fecha de rotación, scope.
- Si procede: incident response, legal, comms.
- Si hay regulación aplicable (PCI, HIPAA, GDPR), activar el proceso correspondiente.

## Paso 3 — Buscar evidencia de abuso

- Logs del proveedor entre `commit_date` y `rotation_date` — ¿llamadas desde IPs inesperadas?
- Audit log de la cuenta — ¿creación de recursos, cambio de permisos?
- Si hay evidencia de abuso, el incidente escala.

## Paso 4 — Reescribir la historia

Con `git filter-repo` (herramienta canónica, reemplaza al deprecated `git filter-branch`):

```bash
# 1. clonar fresh (NUNCA ejecutar filter-repo en tu copia principal)
git clone --mirror git@github.com:org/repo.git repo-cleanup.git
cd repo-cleanup.git

# 2. preparar lista de reemplazos
cat > /tmp/replacements.txt <<'EOF'
sk_fake_live_FAKEstripe00000000000000demo==>REMOVED
EOF

# 3. ejecutar
git filter-repo --replace-text /tmp/replacements.txt

# 4. verificar que el string ya no aparece en ninguna revisión
git log -p | grep -c "sk_fake_live_FAKEstripe" || echo "clean"

# 5. force-push (coordinar con todo el equipo — romperás clones existentes)
git push --force
```

Alternativa — **BFG Repo-Cleaner** (más rápido en repos grandes):

```bash
java -jar bfg.jar --replace-text replacements.txt repo-cleanup.git
cd repo-cleanup.git && git reflog expire --expire=now --all && git gc --prune=now --aggressive
```

## Paso 5 — Coordinar re-clone del equipo

Toda copia local existente **sigue teniendo el commit viejo**. Si alguien hace `git pull` sin cuidar, puede reintroducir el secreto. Mitigación:

- Anunciar en el canal: "force-push a `main`. **No hagan `git pull`.** Backup su rama local, borren el clon, re-clonen."
- Protecciones temporales en la branch protection para bloquear pushes mientras ocurre.

## Paso 6 — Invalidar cachés externas

- GitHub conserva algunas referencias (fork network, Pull Request snapshots). Para repos públicos, pedir soporte: `support@github.com` con el commit hash.
- CDNs/mirrors internos que puedan tener el repo cacheado.

## Paso 7 — Post-mortem

Preguntas:

1. ¿Por qué el pre-commit no lo atrapó? (No estaba instalado / `--no-verify` / repo pre-existe al hook.)
2. ¿Por qué el CI no lo atrapó antes? (`fetch-depth` ≠ 0 / workflow no corría en esta rama.)
3. ¿La rotación fue dolorosa? Si sí, es señal de que ese secreto estaba demasiado acoplado al código.
4. ¿Qué prevención añadir? (Push protection, scanner adicional, revisión de allowlist.)

## Anti-patrones comunes

| Anti-patrón | Por qué está mal |
|-------------|------------------|
| `git rm config/prod.yaml && git commit -m "fix: remove secret"` | El blob sigue accesible por hash en toda la historia |
| Reescribir historia **sin** rotar primero | El secreto ya se asumió comprometido; limpiar la historia no lo despubica |
| `git commit --amend` | Solo arregla el último commit, no los 11 días anteriores |
| Borrar el repo y re-crearlo | Pierdes historia útil; los clones ajenos (y los forks) siguen teniéndola |
| Omitir el post-mortem | Garantiza que el próximo leak sea idéntico |
