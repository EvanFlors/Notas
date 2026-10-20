# Actividad 01 — Desplegar la API en una nube gestionada

## 1. Identificacion

- **ID:** `cap-07-01-deploy-fastapi-to-one-cloud`
- **Tecnologia:** `capstone`
- **Modulo:** `07-cloud-deploy-ecs-cloudrun-aca`
- **Dificultad:** intermediate
- **Duracion estimada:** 90-120 min
- **Tipo:** guided-lab

## 2. Contexto

Llevas la imagen de la API, construida y **firmada con cosign** en la etapa 5,
hasta su primer runtime cloud. Eliges **una** de tres plataformas gestionadas y
levantas el minimo viable: contenedor + Postgres gestionado + secreto en el
secret manager + identidad del runtime.

En esta actividad **no tocas la nube real**. Completas los `TODO` del modulo
elegido y pasas el validador estructural. El `apply` queda como ejercicio
opcional guiado por el `README.md` de la etapa.

## 3. Objetivos

- Elegir UNA plataforma (`aws` | `gcp` | `azure`) y completar su modulo.
- Pinnar la imagen por `@sha256:...`, no por `:latest`.
- Separar la identidad que *pullea* la imagen y lee secretos de la identidad
  que asume el proceso de tu app.
- Nunca escribir una contrasena de BD en `terraform.tfvars`.

## 4. Prerrequisitos

- Haber recorrido el `README.md` de la etapa 07.
- Herramientas locales: `bash`, `jq`, `terraform` >= 1.5.
- **Sin** credenciales cloud reales: la validacion es estructural.

## 5. Instrucciones

### 5.1 Preparar el directorio

```bash
mkdir -p /tmp/cap-07-01
cp -r starter/* /tmp/cap-07-01/
cd /tmp/cap-07-01
```

Puedes trabajar en otra ruta pasandola al validador:
`bash tests/validate.sh /tu/ruta`.

### 5.2 Elegir la plataforma

Abre `starter/choice.txt` y escribe exactamente **una** linea con `aws`, `gcp`
o `azure`. El validador leera ese archivo para decidir que directorio inspeccionar.

### 5.3 Completar el modulo

Edita `terraform/<cloud>/<servicio>/main.tf`. Los TODO marcados `// TODO N` son:

- **TODO 1** — pinar `image_digest` por `@sha256:...` (no por tag).
- **TODO 2** — crear la identidad del runtime (task role, runtime SA o
  user-assigned identity segun el cloud).
- **TODO 3** — crear el secreto (vacio o con DSN derivada) en el secret
  manager y dar permiso de lectura a la identidad del runtime.
- **TODO 4** — inyectar el secreto al contenedor como variable de entorno
  `APP_DB_DSN`, nunca por `env.value` en claro.

### 5.4 Validar

```bash
cd /tmp/cap-07-01
bash <ruta-al-repo>/activities/01-deploy-fastapi-to-one-cloud/tests/validate.sh /tmp/cap-07-01
```

Opcional (requiere red para descargar el provider):

```bash
RUN_TERRAFORM=1 bash tests/validate.sh /tmp/cap-07-01
```

## 6. Resultado esperado

- `choice.txt` tiene una sola linea con `aws`, `gcp` o `azure`.
- El modulo del cloud elegido no deja `TODO` sin resolver.
- El validador imprime `RESULT: 0 issue(s).` y sale con codigo 0.

## 7. Criterios de aceptacion

- **Funcionalidad:** validador estructural pasa.
- **Calidad:** `image_digest` por `@sha256:`; identidad de runtime declarada;
  secreto creado en secret manager con permiso de lectura a esa identidad;
  variable `APP_DB_DSN` llega al contenedor por referencia al secreto.
- **Reproducibilidad:** cualquiera clona el starter y reproduce la entrega.
- **Mantenibilidad:** tags/labels `capstone=07` presentes para que el script
  de cleanup funcione.

## 8. Validacion

```bash
bash tests/validate.sh /tmp/cap-07-01
```

## 9. Preguntas de reflexion

1. Si el task role (AWS) o runtime SA (GCP) o managed identity (Azure)
   tuvieran los mismos permisos que la identidad que pullea la imagen,
   ¿que riesgo concreto introduces?
2. ¿Por que pinar la imagen por digest y no por tag rompe menos la cadena de
   firma de cosign?
3. ¿Que pasa con el valor del secreto si ejecutas `terraform destroy` sin
   antes exportarlo? ¿Es recuperable?
4. ¿Que gana la aplicacion al leer la DSN desde el secret manager en vez de
   recibirla por `env.value` en el `container_definitions`?

## 10. Extensiones

- Anadir una regla de budget alert del cloud elegido antes del `apply`.
- Cambiar `desired_count`/`min_replicas` para que la app sobreviva a la caida
  de una zona (requiere subredes en >= 2 AZ y plan de costos actualizado).
- Rotar la contrasena de BD regenerando `random_password` y verificando que
  el secret manager publica una nueva version.

## 11. Limpieza

Esta actividad **no** crea infraestructura real. Para limpiar artefactos
locales:

```bash
rm -rf /tmp/cap-07-01
```

Si hiciste `terraform apply`, usa el script del cloud correspondiente:

```bash
bash scripts/cleanup-aws.sh      # o cleanup-gcp.sh / cleanup-azure.sh
```
