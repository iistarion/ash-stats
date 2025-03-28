FROM alpine:latest

RUN apk update

WORKDIR /app

COPY stats.sh stats.sh

RUN chmod +x stats.sh

ENTRYPOINT [ "./stats.sh" ]
CMD [ "60", "json" ]