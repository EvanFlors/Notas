# syntax=docker/dockerfile:1.7
# Base pineada por digest (image index de alpine:3.20). Buildx resuelve la variante
# por plataforma del builder; el digest del INDEX es inmutable.
FROM alpine:3.20@sha256:d9e853e87e55526f6b2917df91a2115c36dd7c696a35be12163d44e6e2a4b6bc

# Env determinista: TZ y LC fijos (algunos tools embeben esto).
ENV TZ=UTC LC_ALL=C.UTF-8

# Payload fijo (no 'RUN date', no 'uuidgen'; valor literal).
RUN echo "reproducible build" > /payload.txt
CMD ["cat", "/payload.txt"]
