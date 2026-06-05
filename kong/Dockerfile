# Kong is the only service that gets a public Railway domain.
# All other services communicate over Railway private networking.
FROM kong:3.6.1

# Railway routes external traffic to $PORT
ENV KONG_PROXY_LISTEN="0.0.0.0:${PORT:-8000}"
ENV KONG_PROXY_LISTEN_SSL="0.0.0.0:8443 ssl"
ENV KONG_ADMIN_LISTEN="127.0.0.1:8001"

EXPOSE ${PORT:-8000}
