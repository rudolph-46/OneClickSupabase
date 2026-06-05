FROM alpine:3.19

RUN apk add --no-cache openssl bash

COPY generate_keys.sh /generate_keys.sh
RUN chmod +x /generate_keys.sh

# This container runs once and exits — it just prints the keys to logs.
# Railway will show the output in the deploy logs. Copy the values from there
# into your Shared Variables, then redeploy.
CMD ["/generate_keys.sh"]
