# Ejercicio operativo — Jenkins

Materiales de inicio y validación estructural. **No se requiere servidor Jenkins** para corregir ni para que el candidato autovalide. La corrección cualitativa (naming, comentarios, `NOTES.md`) se superpone a los chequeos automáticos.

## Estructura

```
operative/
  starter/
    workflow-reference.yml    # workflow GHA que el Jenkinsfile debe portar
    service-context.md        # contexto del servicio payments-api
  submission/                 # el candidato crea esta carpeta con su entregable
    Jenkinsfile
    jenkins.yaml
    NOTES.md
  validate/
    check-jenkinsfile.sh      # reglas R1..R9 sobre Jenkinsfile
    check-jcasc.sh            # reglas J1..J7 sobre jenkins.yaml (requiere python3+pyyaml)
    check-no-secrets.sh       # detector heurístico de secretos literales
```

## Cómo autovalida el candidato

Desde `operative/`:

```bash
bash validate/check-jenkinsfile.sh submission/Jenkinsfile
bash validate/check-jcasc.sh       submission/jenkins.yaml
bash validate/check-no-secrets.sh  submission/
```

Los tres scripts deben salir con exit code 0. Dependencias: `bash`, `grep` (con `-P`), `python3`, `pyyaml` (`pip3 install pyyaml`).

## Qué cubren los scripts y qué no

**Sí cubren** (automatizable):

- Presencia de `pipeline { }`, `agent none`, `agent { kubernetes { yaml ... } }` multi-container.
- Stages mínimos (lint/test/build/publish/deploy), `parallel`, `when branch 'main'`, `post always`.
- `input` fuera de un `node { }`.
- Uso de `withCredentials` o `credentials('id')`.
- `@Library('name@vX.Y.Z')` con pin.
- JCasC: parseo YAML, `securityRealm`, `authorizationStrategy` (`roleBased`/`projectMatrix`), `remotingSecurity.enabled`, credenciales con `${VAR}`, `globalLibraries` pinneada, jobs seed.
- Secretos literales (AWS keys, GitHub PATs, llaves privadas, pares `password: "..."`).

**No cubren** (corrección manual con rúbrica):

- Calidad del `NOTES.md` (justificación, trade-offs, próximos pasos).
- Elección de imágenes de agent apropiadas al workload.
- Nombres de stages consistentes con el dominio.
- Comentarios en JCasC por sección.
- Rationale sobre OIDC como siguiente paso.
