FROM alpine:3.20

RUN apk add --no-cache curl

COPY browse-loop.sh /browse-loop.sh
RUN chmod +x /browse-loop.sh

ENTRYPOINT ["/browse-loop.sh"]
