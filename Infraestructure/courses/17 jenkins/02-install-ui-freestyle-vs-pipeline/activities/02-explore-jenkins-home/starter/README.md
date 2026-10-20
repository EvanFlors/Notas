# Starter — jk-02-02-explore-jenkins-home

El entregable vive en `/tmp/jk-02-home/INVENTORY.md`. Esta carpeta no contiene codigo precargado: se trata de que escribas el inventario desde cero siguiendo el `README.md` de la actividad.

## Checklist rapido

- [ ] `mkdir -p /tmp/jk-02-home`
- [ ] (Opcional) Explorar `$JENKINS_HOME` con `docker exec jenkins ls /var/jenkins_home`.
- [ ] Escribir `/tmp/jk-02-home/INVENTORY.md` con las 5 secciones obligatorias del README.
- [ ] `bash tests/validate.sh /tmp/jk-02-home` → OK.

## Secciones esperadas en `INVENTORY.md`

```
## JENKINS_HOME layout
## Freestyle
## Pipeline inline vs from SCM
## Growth without retention
## Risks
```

## Menciones literales que el validador exige

- `config.xml`
- `Jenkinsfile`
- `Git` o `SCM`
- `secrets` o `credentials`
