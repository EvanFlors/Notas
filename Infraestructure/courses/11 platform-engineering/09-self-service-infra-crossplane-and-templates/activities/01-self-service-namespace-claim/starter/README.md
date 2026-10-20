# starter/ — plat-09-01

Completa los `REPLACE_ME` en los 3 YAMLs. Luego ejecuta `bash ../tests/setup.sh`.

## Archivos

- `xrd.yaml` — contrato (completa `pattern` del name y `enum` del tier).
- `composition.yaml` — receta (completa el patch `tier → requests.cpu/memory`).
- `claim.yaml` — ejemplo que crearía un developer (completa name/tier/env).

Pistas:

- El validador espera que el claim resulte en namespace **`student-ns`** y claim **`student-claim`** en namespace **`team-student`**.
- `tier=small` debe traducirse a `requests.cpu=2` y `requests.memory=4Gi`.
