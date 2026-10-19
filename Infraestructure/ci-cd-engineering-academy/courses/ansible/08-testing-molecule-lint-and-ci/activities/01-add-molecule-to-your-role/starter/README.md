# Starter — ans-08-01-add-molecule-to-your-role

Copia este starter al directorio de trabajo y añade la capa de testing (Molecule + lint + requirements).

```bash
mkdir -p /tmp/ans-08-01
cp -R . /tmp/ans-08-01/
cd /tmp/ans-08-01
```

## Qué trae el starter

- `tasks/main.yml` — instala y configura nginx para servir una página estática.
- `handlers/main.yml` — handler `Reload nginx`.
- `templates/index.html.j2` — página index parametrizada por `site_name`.
- `defaults/main.yml` — defaults del role.
- `meta/main.yml` — metadata mínima para Galaxy.

## Qué debes añadir

1. `.ansible-lint`
2. `.yamllint`
3. `requirements.txt`
4. `molecule/default/molecule.yml`
5. `molecule/default/converge.yml`
6. `molecule/default/verify.yml`

Consulta `../README.md` para los requisitos exactos, y `../../examples/01-molecule-scenario-default/` como referencia.

## Validación

```bash
bash <ruta-repo>/courses/ansible/08-testing-molecule-lint-and-ci/activities/01-add-molecule-to-your-role/tests/validate.sh /tmp/ans-08-01
```
