# Starter — stack monolítico de 3 ambientes

Este directorio es tu punto de partida. Copia TODO el contenido a `/tmp/tf-08-01/` y trabaja ahí:

```bash
rm -rf /tmp/tf-08-01
mkdir -p /tmp/tf-08-01
cp -R starter/. /tmp/tf-08-01/
cd /tmp/tf-08-01
```

El subdirectorio `monolith/` contiene el stack monolítico que vas a refactorizar. Su `main.tf` crea los recursos de los tres ambientes en un único state y repite valores hardcodeados — ese es exactamente el *anti-patrón* que debes dejar atrás.

Tu objetivo final (sin tocar `monolith/`):

```
/tmp/tf-08-01/
├── monolith/              # el starter — lo ignorarás tras entender el problema
├── modules/
│   └── app/               # TODO: crear
└── envs/
    ├── dev/               # TODO: crear
    ├── stg/               # TODO: crear
    └── prod/              # TODO: crear
```

Lee `../README.md` para las instrucciones completas.
