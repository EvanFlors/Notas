# syntax=docker/dockerfile:1.7
FROM alpine:3.20
RUN echo "hello from $(uname -m)" > /hello.txt
CMD ["cat", "/hello.txt"]
