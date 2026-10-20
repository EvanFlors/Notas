# Validación operativa — Local

```bash
./run.sh ../solution-path
```

El script usa solo `bash`/`grep`/`awk`. Si `actionlint` o `zizmor` están
en `$PATH`, también se ejecutan. No requiere acceso a GitHub ni a AWS.

Códigos de salida:
- `0`: todo OK.
- `1`: una o más validaciones duras fallaron (incluye red flags).
- `2`: entregable incompleto (no existe `.github/workflows/ci.yml`).

El resumen final imprime `pass | fail | warn`. El evaluador debe cruzarlo
con la rúbrica de `../../EXAM.md §5`.
