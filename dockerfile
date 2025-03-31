FROM alpine:latest

RUN apk update

WORKDIR /app

COPY stats.sh stats.sh
COPY version.txt version.txt

RUN chmod +x stats.sh

ENTRYPOINT [ "./stats.sh" ]
CMD [ "60", "json" ]