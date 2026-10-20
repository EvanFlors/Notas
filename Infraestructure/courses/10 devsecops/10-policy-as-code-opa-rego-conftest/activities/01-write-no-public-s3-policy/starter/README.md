# Starter — sec-10-01-write-no-public-s3-policy

No hay código a copiar: todo lo escribes tú. Pasos:

1. Lee `../README.md` completo.
2. Prepara el directorio de trabajo:
   ```bash
   mkdir -p /tmp/sec-10-01-no-public-s3/policy
   cd /tmp/sec-10-01-no-public-s3
   ```
3. Crea `policy/s3.rego` con `package terraform.s3`, `import rego.v1` y **al menos 2** reglas `deny contains msg if { ... }` (ver §5.2 del README).
4. Crea `policy/s3_test.rego` con **al menos 3** tests `test_*` (ver §5.3 del README).
5. Ejecuta `opa test -v policy/` (si tienes `opa`).
6. Valida la estructura:
   ```bash
   bash <ruta-repo>/courses/devsecops/10-policy-as-code-opa-rego-conftest/activities/01-write-no-public-s3-policy/tests/validate.sh /tmp/sec-10-01-no-public-s3
   ```
7. Compara tu solucion con `../solution/REFERENCE.md`.

> El validador salta con gracia los chequeos de `opa` si el binario no está instalado; en ese caso solo verifica estructura.
