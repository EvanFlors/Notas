# Ejemplo 01 — CRD `Echo` + esqueleto de controller

Muestra lo mínimo imprescindible para entender un operador: una **CRD** y el **esqueleto** del controller que la reconciliaría.

El objetivo es **leer y entender**, no desplegar. La actividad `01-write-echo-operator-with-kubebuilder` es donde se construye el operador real.

## Archivos

- `crd-echo.yaml` — CustomResourceDefinition `Echo` (apiVersion `demo.academy.io/v1alpha1`).
- `echo-sample.yaml` — un CR de ejemplo.
- `reconcile-pseudocode.md` — el `Reconcile` en pseudocódigo, línea a línea.
- `demo.sh` — opcional: crea un kind, aplica la CRD y el CR, muestra `kubectl get echoes`. Verifica que la CRD existe y que el apiserver acepta el CR, aunque *no haya controller*.

## Qué observar

1. La CRD define `spec.message` y `status.observedMessage`.
2. `subresources.status: {}` separa escrituras.
3. `additionalPrinterColumns` hace útil `kubectl get echoes`.
4. Sin controller, el CR se queda tal cual: el apiserver lo almacena pero nadie actúa. Esa es la lección central: **CRD sin controller = JSON tipado en etcd**.

## Ejecutar el demo (opcional)

Requiere `kind` y `kubectl` instalados. Crea un cluster temporal, aplica la CRD y limpia:

```bash
bash demo.sh
```

Si no tienes `kind`, lee los YAMLs y el pseudocódigo. Es suficiente.
