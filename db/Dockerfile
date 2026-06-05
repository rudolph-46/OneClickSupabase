# Pinned to exact SHA — never use :latest, it will silently break.
# Check https://hub.docker.com/r/supabase/postgres/tags for updates.
# Always test a new pin in staging before updating production.
FROM supabase/postgres:15.8.1.060

# Railway assigns a random PORT. Postgres must listen on it.
ENV PGPORT=${PORT:-5432}

# Expose the port Railway will route to
EXPOSE ${PORT:-5432}
