# Ejemplo 02 — El mismo workflow en 3 formas: `@main`, `@v4`, `@<SHA>`

## Concepto que demuestra

El **mismo** workflow escrito con **tres estrategias de referencia** distintas, para que puedas compararlas lado a lado y entender por qué el pin a SHA es la única que te protege de un tag/branch reescrito.

## Contexto

El 100% de los repos que ves por ahí usan alguna variante de estas tres. Este ejemplo las vuelve explícitas en código para que puedas señalar la diferencia en una PR review.

## Objetivo

Al terminar:
- Reconoces de un vistazo las 3 formas de pinnear.
- Puedes explicar qué pasa (y qué no) cuando el maintainer upstream reescribe `v4`.
- Sabes qué comando corre para resolver `v4` → SHA.

## Los tres archivos

En `files/`:

- `workflow-unsafe.yml` — usa `@main` (branch). **Peligroso**: cada run trae HEAD.
- `workflow-tag.yml` — usa `@v4` (tag mayor). **Mediano**: cómodo pero mutable.
- `workflow-safe.yml` — usa `@<SHA40>  # v4.2.2`. **Seguro + legible**.

Los tres hacen lo mismo (checkout + imprimen una línea), lo que cambia es el pin.

## Cómo compararlos

```bash
cd /Users/efloresp06/Desktop/Courses/Python/Notas/Infraestructure/ci-cd-engineering-academy/courses/github-actions/04-marketplace-actions-and-basics-of-reuse/examples/02-pin-to-sha
diff files/workflow-unsafe.yml files/workflow-safe.yml
diff files/workflow-tag.yml   files/workflow-safe.yml
```

La única diferencia material es la línea del `uses:`.

## Cómo resolverías un tag a su SHA

Equivalencia (al momento de redactar este módulo):

```bash
# gh (recomendado si estás auth)
gh api repos/actions/checkout/git/refs/tags/v4.2.2 --jq '.object.sha'
# -> 11bd71901bbe5b1630ceea73d27597364c9af683

# git ls-remote (sin auth)
git ls-remote https://github.com/actions/checkout.git refs/tags/v4.2.2
```

Toma ese SHA y escríbelo con el comentario:

```yaml
- uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683  # v4.2.2
```

## Narrativa del ataque "tag reescrito"

Imagina que a las 03:17 UTC el maintainer de una action que usas con `@v4` publica una versión comprometida y re-apunta el tag `v4`:

```
antes:
  v4 ──► commit abc123   (código legítimo)

ahora:
  v4 ──► commit badf00d  (exfiltra GITHUB_TOKEN a un webhook)
```

A las 03:19, tu PR dispara el workflow. `workflow-tag.yml` resuelve `v4` → `badf00d` y lo ejecuta en tu runner con tus permisos. Entre `03:17` y el momento en que GitHub revoque el tag, decenas de workflows pueden haber corrido código malicioso.

`workflow-safe.yml` pinneado a SHA `11bd719...` sigue bajando `abc123`. No te afecta.

Esto no es hipotético — se ha visto en producción (p. ej. incidente `tj-actions/changed-files`, marzo 2025).

## Verificación

```bash
# Los 3 son YAML válido:
for f in files/*.yml; do
  python3 -c "import yaml; yaml.safe_load(open('$f'))" && echo "$f OK"
done
```

## Preguntas de reflexión

1. ¿Qué comando usarías para listar todas las `uses:` **no** pinneadas en un repo?
2. Si Dependabot abre un PR que te sube de `v4.2.2` → `v5.0.0`, ¿lo mergeas directo? ¿Qué miras antes?
3. Un `uses: owner/action@v4.2.2` (tag exacto, no mayor) ¿es tan seguro como un SHA? Argumenta.
4. ¿Qué pasa si pinneas al **SHA del tag object** anotado en vez del SHA del commit? Prueba con `git ls-remote URL refs/tags/<tag>` vs `... refs/tags/<tag>^{}`.
