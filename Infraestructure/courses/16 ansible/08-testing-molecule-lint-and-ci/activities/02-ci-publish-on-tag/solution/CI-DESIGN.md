# CI-DESIGN — role-ci.yml

## Matriz

Elegidas **3 distros × 2 versiones de `ansible-core`** = 6 celdas. Suficiente para cubrir el 95% del uso real sin romper el presupuesto de minutos:

- Distros: `ubuntu-22.04`, `debian-12`, `rockylinux-9` (dos familias Debian + una EL).
- `ansible-core`: `2.16.*` (LTS en desuso) y `2.17.*` (actual). Si la org usa `2.18.*`, añadir una tercera columna; evitar la nightly aquí.

`fail-fast: false` para ver los 6 fallos a la vez — si Rocky rompe, no quiero perder la señal de Debian.

## Gate de publicación

El job `publish` solo corre si el ref es un **tag SemVer**:

```yaml
if: startsWith(github.ref, 'refs/tags/v')
```

Razones:

- No quiero publicar una pre-release en cada push a `main`; Galaxy no soporta "unpublish".
- SemVer explicita la intención del release (`v1.2.3`); otros tags (`backup-20260101`) no deben disparar nada.
- `needs: molecule` garantiza que no se publica un role que no pasó la matriz.

## Secretos

`GALAXY_API_KEY` se configura en **Settings → Secrets and variables → Actions** del repo (o de la organization). En el YAML se consume solo donde es imprescindible (`run:` del paso de publicación) con `${{ secrets.GALAXY_API_KEY }}`. Nunca se expone como `env:` global ni se imprime con `echo`. Rotación recomendada: cada 90 días; impacto bajo porque el token solo autoriza publicar roles del namespace del propietario.

## Caché

- **`actions/setup-python` con `cache: pip`**: cachea `~/.cache/pip` por `hashFiles` de los lockfiles. Ahorra 20–30s por job.
- **`actions/cache@v4` para `~/.ansible/collections`**: la clave es `hashFiles('**/requirements.yml')`. Evita descargar collections idénticas en cada run.
- **No cacheamos imágenes Docker**: las `geerlingguy/*-ansible` son grandes pero el runner las tira rápido por la red de GH; cachearlas con `docker save/load` suele salir peor que el pull en frío.
