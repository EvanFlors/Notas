# Starter — k8s-17-01

El starter es intencionadamente mínimo: no hay manifests prefabricados.

Lo que debes construir tú (ver `../README.md` §5):

1. Cluster kind `k8s-17-lab`.
2. MinIO en namespace `minio` con bucket `velero`.
3. Velero instalado con `node-agent` y backend MinIO.
4. Namespace `demo` con PVC `data` y Deployment `writer` escribiendo `RESTORED-OK` a `/data/payload.txt`.
5. Backup `demo-backup`.
6. Delete + restore.

Si quieres acelerar, mira `../solution/run-solution.sh` **después de haberlo intentado**.
