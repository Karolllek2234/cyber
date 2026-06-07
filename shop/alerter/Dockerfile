FROM alpine:3.20
RUN apk add --no-cache curl jq
COPY check-error-rate.sh send-alert-email.sh alert-loop.sh /alerter/
RUN chmod +x /alerter/*.sh
ENTRYPOINT ["/alerter/alert-loop.sh"]
