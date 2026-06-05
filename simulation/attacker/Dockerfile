FROM ghcr.io/zaproxy/zaproxy:stable

USER root
RUN pip3 install --break-system-packages --no-cache-dir zapcli

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER zap

ENTRYPOINT ["/entrypoint.sh"]
