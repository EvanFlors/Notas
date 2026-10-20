# Starter — gl-07-02-approval-rule-prod

Esta actividad no provee archivos de arranque. Partes desde cero y produces:

```
/tmp/gl-07-02-approval-prod/
├── protected-environment.yaml
├── approval-rules.yaml
└── ADR-APPROVAL-PROD.md
```

Pasos sugeridos:

1. `mkdir -p /tmp/gl-07-02-approval-prod && cd /tmp/gl-07-02-approval-prod`.
2. Lee `../README.md` seccion 5 y `../../../examples/03-protected-env-approval/README.md`.
3. Escribe los dos YAML. Valida parsing:

   ```bash
   python3 -c 'import yaml; yaml.safe_load(open("protected-environment.yaml"))' && echo PE-OK
   python3 -c 'import yaml; yaml.safe_load(open("approval-rules.yaml"))' && echo AR-OK
   ```

4. Escribe el ADR.
5. Corre `bash ../tests/validate.sh /tmp/gl-07-02-approval-prod`.

Si te atascas, mira `../solution/REFERENCE.md` **despues** de intentarlo.
