# Actividad 03 — Publicar una action y pinnearla a SHA desde otro repo

## 1. Identificación

- **ID:** `gha-12-03-publish-and-pin`
- **Tecnología:** `github-actions`
- **Módulo:** `gha-12-authoring-custom-actions`
- **Dificultad:** intermediate
- **Duración estimada:** 45–60 min
- **Tipo:** guided-lab

## 2. Contexto

Ya sabes **escribir** una action. Ahora toca **operar su ciclo de vida**:

1. Taggearla con `v1.0.0` + mover `v1` para que apunte a esa SHA.
2. "Publicarla" (en modo local: push a un bare remoto; en live: push a GitHub).
3. Consumirla desde **otro repo**, pinneando a la **SHA de 40 caracteres**, con un comentario de la versión equivalente.

Como `gh-05` y `gha-08`, soportamos:

- **`MODE=local`** (default): dos repos `--bare` en `/tmp/` simulan "repo de la action" y "repo consumidor". Sin GitHub.
- **`MODE=live`**: `gh repo create` crea los repos reales en tu cuenta (requiere `gh auth`).

El validador comprueba las mismas invariantes en ambos modos: tags presentes, `v1` apunta a la SHA correcta, el workflow del consumidor hace `uses: owner/repo@<40-char-SHA>`.

## 3. Objetivos

Al terminar:
- Taggeas una action con `v1.0.0` + `v1` móvil.
- Resuelves la SHA larga (`git rev-parse v1.0.0`) y la **pinneas** desde el consumidor.
- Comprendes por qué el consumidor **no** debe usar `@v1` ni `@main` en producción.
- Validas el estado end-to-end.

## 4. Prerrequisitos

- `gha-04` (pin a SHA, Dependabot) y `gha-12` actividades 01-02.
- Bash, Git, `python3`.
- Modo `live` (opcional): `gh auth status` OK.

**Costos**: ninguno en local; $0 en live (repos free).

## 5. Instrucciones

### 5.1 Preparar (local, default)

```bash
MODE=local bash starter/bootstrap.sh /tmp/publish-and-pin
```

Esto crea:

```
/tmp/publish-and-pin/
├── publisher/                # working repo de "mi action"
│   ├── action.yml            # composite ya escrita
│   └── .git/
├── publisher.git/            # bare remote (simula github.com/you/greet-action)
├── consumer/                 # working repo que consumirá la action
│   ├── .github/workflows/ci.yml   # PLACEHOLDER: aquí tienes que pinnear
│   └── .git/
└── consumer.git/             # bare remote (simula github.com/you/some-consumer)
```

### 5.2 Publisher: tag `v1.0.0` y mover `v1`

```bash
cd /tmp/publish-and-pin/publisher
git log --oneline
# verás 1 commit "feat: greet-action v1.0.0"

git tag -a v1.0.0 -m "v1.0.0 - initial release"
git tag -f v1 v1.0.0           # v1 móvil apunta al mismo commit (por ahora)

git push origin main
git push origin v1.0.0
git push origin v1 --force     # el 'v1' va a moverse en el futuro

# Capturar el SHA que vas a usar como pin:
PUBLISHER_SHA="$(git rev-parse v1.0.0)"
echo "pin to this SHA: $PUBLISHER_SHA"
```

### 5.3 Consumer: pinnear a SHA en `.github/workflows/ci.yml`

Edita `/tmp/publish-and-pin/consumer/.github/workflows/ci.yml`. En `MODE=local` el campo `uses:` **tiene** que ser un path al repo publicado por bundle en la bare — pero como queremos enseñar el patrón real de pin, usamos la convención completa `owner/repo@SHA`.

Reemplaza los **tres `PLACEHOLDER_*`** por los valores correctos:

```yaml
name: ci
on: [push]
jobs:
  greet:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@PLACEHOLDER_CHECKOUT_SHA  # v4.2.2
      - id: greet
        uses: demo-owner/greet-action@PLACEHOLDER_GREET_SHA  # v1.0.0
        with:
          who: ci
      - run: echo "got ${{ steps.greet.outputs.greeting }}"
```

El starter ya tiene `actions/checkout@a81bbbf8298c0fa03ea29cdc473d45769f953675  # v4.2.2` como ejemplo correcto. Tú solo tienes que:

1. Resolver el SHA de `v1.0.0` del publisher con `git rev-parse` (como arriba).
2. Reemplazar `PLACEHOLDER_GREET_SHA` por esa SHA de 40 caracteres **y añadir** el comentario `# v1.0.0` al lado.

Commit + push al bare `consumer.git`:

```bash
cd /tmp/publish-and-pin/consumer
git add .github/workflows/ci.yml
git commit -m "ci: pin greet-action to v1.0.0 SHA"
git push -u origin main
```

### 5.4 Validar

```bash
MODE=local bash tests/validate.sh /tmp/publish-and-pin
```

El validador comprueba:

- Publisher: tag `v1.0.0` existe, tag `v1` existe, ambos apuntan al mismo commit.
- Publisher bare remoto: tiene `refs/tags/v1.0.0` y `refs/tags/v1`.
- Consumer: `.github/workflows/ci.yml` referencia `demo-owner/greet-action@<SHA de 40 chars>`.
- El SHA del consumer coincide con `git rev-parse v1.0.0` del publisher.
- Tiene comentario con la versión al lado (buena práctica para Dependabot).

### 5.5 Opcional: cómo movería `v1` cuando saco `v1.0.1`

```bash
cd /tmp/publish-and-pin/publisher
# ... hacer cambio, commit ...
git tag -a v1.0.1 -m "v1.0.1 - patch"
git tag -f v1 v1.0.1
git push origin v1.0.1
git push origin v1 --force
```

Los consumidores con `uses: ...@v1` reciben la actualización automática.
Los consumidores con `uses: ...@<SHA>` **no** — hasta que Dependabot abra un PR con el nuevo SHA, el humano revise, y el humano merjee.

### 5.6 Modo live (opcional)

```bash
MODE=live bash starter/bootstrap.sh /tmp/publish-and-pin
# Crea publisher-<timestamp> y consumer-<timestamp> en tu cuenta GitHub.
# Luego sigue los mismos pasos; validate.sh verifica también vía gh api.
```

## 6. Resultado esperado

- Publisher con tags `v1.0.0` + `v1` apuntando al mismo commit.
- Bare `publisher.git` tiene esos refs.
- Consumer workflow con `uses: demo-owner/greet-action@<40-char-SHA>  # v1.0.0`.
- Validador OK.

## 7. Criterios de aceptación

- [ ] `publisher`: `git tag` muestra `v1.0.0` y `v1`.
- [ ] `publisher.git` tiene ambos refs.
- [ ] `consumer/.github/workflows/ci.yml` referencia la action **a SHA** (40 chars hex), no a tag ni a branch.
- [ ] El SHA pinneado = `git rev-parse v1.0.0` en el publisher.
- [ ] Comentario al lado del `uses:` con la versión equivalente.

## 8. Validación

```bash
MODE=local bash tests/validate.sh /tmp/publish-and-pin
MODE=live  bash tests/validate.sh /tmp/publish-and-pin
```

## 9. Preguntas de reflexión

1. ¿Por qué `@v1` no es seguro aunque sea muy conveniente? Da un ejemplo concreto de ataque.
2. ¿Qué tiene que pasar para que el consumidor reciba `v1.0.1` del publisher si pinneó a SHA? Describe el flujo con Dependabot.
3. ¿Qué pasa si el publisher **retag`ea** `v1.0.0` para apuntar a otro commit (`git tag -f v1.0.0 <otro>`)? ¿El consumidor con pin a SHA se ve afectado? ¿Y el consumidor con `@v1.0.0`?
4. En el modo local, ¿qué parte es Git puro y qué parte es la convención de GitHub que estamos simulando? ¿Qué cambia realmente si pasas a modo live?
5. Discusión de política: si fueras el platform team, ¿harías obligatorio el pin a SHA en toda la org? ¿Cómo lo auditarías? (Pista: `gha-15`.)

## 10. Extensiones (opcional)

- **E1** — En el publisher, publica un `v1.0.1` con un cambio real, mueve `v1`, y actualiza el consumer al nuevo SHA con un commit propio.
- **E2** — Añade `.github/dependabot.yml` en el consumer que escanee `github-actions` semanalmente.
- **E3** — Publica un `v2.0.0` con un cambio breaking (cambia el nombre de un input). El consumer con `@v1` no se rompe; verifica.

## 11. Limpieza

```bash
rm -rf /tmp/publish-and-pin
# live:
# gh repo delete publisher-xxx --yes
# gh repo delete consumer-xxx --yes
```
