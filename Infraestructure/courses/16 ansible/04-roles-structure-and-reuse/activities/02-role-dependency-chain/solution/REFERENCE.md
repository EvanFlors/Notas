# Solución de referencia — Chain de 3 roles

Esta solución elige **Opción A: dependencies en `meta/main.yml`**. La opción B (composición explícita en `site.yml`) es igualmente válida — ver `## Trade-offs` abajo.

## Estructura

```
/tmp/ans-04-chain/
├── site.yml                     # Sólo invoca fastapi-app; las deps arrastran al resto
├── README-INTENT.md
└── roles/
    ├── common/                  # No depende de nada
    ├── webserver/               # dependencies: [common]
    └── fastapi-app/             # dependencies: [webserver]
```

Al correr `ansible-playbook site.yml`, Ansible resuelve el grafo:

```
fastapi-app → webserver → common
```

y aplica en orden inverso: `common` primero, `webserver` después, `fastapi-app` al final.

## Por qué Opción A aquí

- La relación es **técnica y obligatoria**: `fastapi-app` sin `webserver` no sirve tráfico; `webserver` sin `common` no tiene usuario `appuser`.
- Un consumidor del role `fastapi-app` no debería tener que recordar añadir `webserver` y `common`; eso se olvida.

## Cuándo preferir Opción B

- Si quisieras un `site-dev.yml` que corre sin `webserver` (dev local con uvicorn directo), con A tendrías que romper la dependency (o duplicar el role sin ella). Con B basta con otro `site.yml` que lista roles distintos.
- Si quieres que el playbook sea **autoexplicativo** sin leer los metas de cada role.

## Decisiones de variables

- `common/defaults/`: `common_timezone`, `common_appuser`. Interno (en vars/): nada por ahora.
- `webserver/defaults/`: `webserver_port`, `webserver_upstream_port`. Interno: `webserver_pkg`, `webserver_service`, `webserver_conf_path`.
- `fastapi-app/defaults/`: `fastapi_app_name`, `fastapi_app_port`, `fastapi_app_user` (= `common_appuser` por conveniencia).

## Correr

```bash
cd /tmp/ans-04-chain
ansible-playbook -i localhost, -c local site.yml --syntax-check
```

Debe pasar. Para un `--check` real necesitarías paquetes del sistema; no es parte de la actividad.

## Autoevaluación

- ¿Cada role tiene una responsabilidad clara? Si al nombrar un role no puedes decir "este hace X" en una frase, descompón.
- ¿Variables prefijadas por role? (`webserver_port` no `port`.)
- ¿READMEs completos? Si falta OS o ejemplo, no es usable por otro equipo.
- ¿`README-INTENT.md` menciona ambas opciones y justifica la elegida?
