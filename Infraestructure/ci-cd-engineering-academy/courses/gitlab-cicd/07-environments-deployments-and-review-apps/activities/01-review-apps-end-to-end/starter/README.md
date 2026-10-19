# Starter — gl-07-01-review-apps-end-to-end

Esta actividad no provee archivos de arranque. Partes desde cero y produces:

```
/tmp/gl-07-01-review-apps/
├── .gitlab-ci.yml       (tu pipeline con build + review + stop_review)
└── ADR-REVIEW-APPS.md   (tu ADR con las 6 secciones)
```

Pasos sugeridos:

1. `mkdir -p /tmp/gl-07-01-review-apps && cd /tmp/gl-07-01-review-apps`.
2. Lee `../README.md` seccion 5 (Instrucciones) y `../../../examples/02-review-apps-on-mr/README.md`.
3. Escribe primero el `.gitlab-ci.yml` y validalo parsing con:

   ```bash
   python3 -c 'import yaml,sys; yaml.safe_load(open(".gitlab-ci.yml"))' && echo OK
   ```

4. Escribe el ADR siguiendo el formato de la seccion 5.3.
5. Corre `bash ../tests/validate.sh /tmp/gl-07-01-review-apps`.

Si te atascas, mira `../solution/REFERENCE.md` **despues** de intentarlo.
