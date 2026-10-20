# REFERENCE — cap-13-01-register-in-backstage

Un modelo defendible — no la unica respuesta correcta.

## Por que 4 kinds

El catalogo es un **grafo**, no una lista. `Component` solo mide el servicio
en si; perder `API` y `Resource` significa perder las aristas "quien expone"
y "quien consume". Esas aristas son las que alimentan despues analisis de
impacto, matrices de dependencias y vistas por `System`.

## Por que las annotations son parte del contrato

El plugin de Scorecard no inventa datos. Si tu Component no anota
`image_signed`, el check `image-signed` devuelve `false` por omision y bajas
de nivel. Es el patron de **"schema por convencion"**: el plugin publica los
campos que lee y los productores los proveen.

Mal patron: el equipo del scorecard mete una excepcion por cada servicio
nuevo. Buen patron: el scorecard publica los campos y el template nuevo
los nace con stubs.

## Mi catalog-info.yaml de referencia

Ver `backstage/catalog-info.yaml` en la raiz del stage: 4 docs, 7 anotaciones
del Scorecard en el Component, `providesApis` y `dependsOn` conectando los
cuatro.

## Punto a repetir

> El catalog-info.yaml vive **en el repo del servicio**, no en el repo de
> Backstage. Si vive del otro lado, se desincroniza en una semana.
