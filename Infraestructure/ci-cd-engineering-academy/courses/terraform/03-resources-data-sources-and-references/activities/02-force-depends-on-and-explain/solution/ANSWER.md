# tf-03-02 — Respuestas (modelo)

## Escenario A — depends_on redundante

- **¿Qué depends_on quité y por qué?** El `depends_on = [tls_self_signed_cert.srv]` del
  `docker_container.nginx`. El bloque `env` ya referencia
  `tls_self_signed_cert.srv.subject[0].common_name`, lo que crea una arista implícita
  del cert hacia el contenedor en el DAG.
- **¿Qué arista implícita ya existía?** `tls_self_signed_cert.srv -> docker_container.nginx`,
  derivada de la interpolación en `env`. Añadir `depends_on` sobre la misma pareja no
  cambia el grafo; es ruido.

## Escenario B — depends_on necesario

- **¿Por qué el bind mount con host_path literal no crea una arista en el DAG?**
  Porque `host_path = "/tmp/tf-03-02/scenario-B-marker.txt"` es un string constante.
  Terraform construye aristas solo cuando ve una **referencia** a otro recurso. Un
  string literal no referencia nada, aunque semánticamente apunte a un archivo que
  otro recurso crea.
- **¿Qué pasaría exactamente en un primer apply sin el depends_on?** El
  `docker_container.app` y el `null_resource.marker` son nodos independientes en el
  grafo. Terraform puede crearlos en paralelo. Si el contenedor arranca primero,
  Docker ve que `/tmp/tf-03-02/scenario-B-marker.txt` no existe y, dependiendo de la
  versión del daemon, o bien falla el bind mount o bien crea un directorio vacío con
  ese nombre y lo monta — en ambos casos, el `cat /data/marker` del command rompe o
  da salida vacía.
- **¿Por qué no basta con reordenar los bloques en el archivo?** Porque el orden
  textual del HCL **no influye** en el DAG. Terraform construye el grafo a partir de
  referencias, no de posiciones.

## Regla práctica

Preferir siempre expresar la dependencia por **referencia** (un atributo del padre
que viaja al hijo). Si no es posible (dependencia operacional lateral, provisioner
que toca el host, política IAM que condiciona a otro recurso sin viajar por
HCL...), usar `depends_on` con un **comentario** que explique qué dependencia
operacional estás codificando. Sin el comentario, en 6 meses nadie entenderá por
qué está ahí.
