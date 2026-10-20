# Actividad cap-12-03 — Debug policy-check (conftest + opa)

## Sintoma

El pipeline `policy-check.yml` falla en main con dos sintomas raros:

1. El fixture `bad.yaml` (que mete hostPath y `privileged: true`) pasa como "OK".
2. `opa test` reporta un `test_denies_hostpath` que falla.

Alguien tocó una Rego "para simplificar" y la rompio. Encuentra el bug, arreglalo, deja todo verde.

## Instrucciones

1. Copia starter:
   ```bash
   cp -R starter/ /tmp/cap-12-03
   ```
2. Lee `no_privileged.rego`. Hay un bug claro (hint: uno de los `deny` esta mal armado — fijate en la asignacion y en el `some`).
3. Corrige la Rego.
4. Si tienes `opa` instalado:
   ```bash
   opa test /tmp/cap-12-03/policies -v
   ```
5. Si tienes `conftest`:
   ```bash
   conftest test /tmp/cap-12-03/fixtures/bad.yaml -p /tmp/cap-12-03/policies
   # debe reportar violacion
   conftest test /tmp/cap-12-03/fixtures/good.yaml -p /tmp/cap-12-03/policies
   # debe pasar
   ```
6. Corre `bash tests/validate.sh /tmp/cap-12-03`.

## Qué chequea el validator

- Que `no_privileged.rego` ya no tenga el patron roto conocido.
- Que `opa test` pase (si opa esta instalado).
- Que `conftest` rechace `bad.yaml` y acepte `good.yaml` (si conftest esta instalado).
- Que las policies declaren `package main`.
