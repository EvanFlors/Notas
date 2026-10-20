# Solución — argo-04-02

El valor diferencial de multi-source es **separar la ref inmutable del artefacto de la ref mutable de la configuración**.

- El chart se pinnea a `6.7.1` — así sabes exactamente qué YAML genera.
- El repo de values vive en `main`; cuando quieras promover un cambio, mergeas a `main` y Argo CD reconcilia.
- Para promoción entre ambientes puedes usar branches en el repo de values (`dev`, `stg`, `prod`) y hacer tres Applications multi-source distintas que apunten a la misma chart y distinta branch del repo de values.

Comportamientos que debes haber confirmado:

- Si cambias `ref: values` a `ref: v` sin ajustar `$values/...`, Argo CD reporta "could not resolve `$values` reference".
- Si pones dos sources ambos con `chart:` (dos charts Helm), **Argo CD rechaza** la Application. Esa es una de las limitaciones reales de multi-source: no soporta dos renders Helm concurrentes.
- Comparado con un wrapper chart: multi-source **no requiere mantener un Chart.yaml propio** ni gestionar dependencies, pero **no permite modificar `templates/`**. Si necesitas tocar templates, sigues necesitando fork o wrapper.
