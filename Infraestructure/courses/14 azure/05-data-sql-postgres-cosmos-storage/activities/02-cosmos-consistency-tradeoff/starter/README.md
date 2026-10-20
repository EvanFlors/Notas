# Starter — az-05-02-cosmos-consistency-tradeoff

Pasos (ver `../README.md` para el detalle).

1. Carpeta de trabajo:
   ```bash
   mkdir -p /tmp/az-05-cosmos
   cp model.py /tmp/az-05-cosmos/model.py
   ```
2. (Opcional) levantar emuladores:
   ```bash
   docker run -d --name az05-cosmos \
     -p 8081:8081 -p 10250-10255:10250-10255 \
     mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-preview

   docker run -d --name az05-azurite \
     -p 10000:10000 -p 10001:10001 -p 10002:10002 \
     mcr.microsoft.com/azure-storage/azurite
   ```
3. Ejecutar:
   ```bash
   cd /tmp/az-05-cosmos
   python3 model.py | tee run.log
   ```
   Sin emuladores el script sale 0 con `SKIP: Cosmos emulator not available` y/o `SKIP: Azurite not available`.
4. Escribir `/tmp/az-05-cosmos/CONSISTENCY.md` con 4 secciones:
   A patrones (>=3, palabra `Patron`),
   B modelo single-container (PK/SK/GSI o single-container, query, GetItem, projection),
   C eleccion consistencia + hot partition + sharding,
   D mapping DynamoDB -> Cosmos + evidencia emuladores (cita LocalStack).
5. Validar:
   ```bash
   bash ../tests/validate.sh /tmp/az-05-cosmos
   ```
6. Limpieza:
   ```bash
   docker rm -f az05-cosmos az05-azurite 2>/dev/null || true
   rm -rf /tmp/az-05-cosmos
   ```
