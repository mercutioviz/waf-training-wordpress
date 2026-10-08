# nginx + an optional TLS key-logging shim for WAF training captures.
#
# The shim is always built into the image but is INERT unless both LD_PRELOAD
# and SSLKEYLOGFILE are set at runtime (see docker-compose.yml). With them
# unset the container behaves exactly like stock nginx:alpine.

ARG NGINX_VERSION=alpine

# ── Build stage: compile the shim, then throw the toolchain away ─────────
FROM nginx:${NGINX_VERSION} AS build

RUN apk add --no-cache gcc musl-dev

COPY sslkeylog.c /build/sslkeylog.c
RUN gcc /build/sslkeylog.c -shared -o /build/libsslkeylog.so -fPIC -ldl -O2 -Wall -Wextra

# ── Runtime stage: stock nginx plus the compiled .so ─────────────────────
FROM nginx:${NGINX_VERSION}

COPY --from=build /build/libsslkeylog.so /usr/local/lib/libsslkeylog.so

# Workers drop to uid 101 (nginx) after master start, so the keylog directory
# must be writable by that uid. Without this the shim opens nothing and the
# file silently stays empty - a confusing failure mode worth pre-empting.
# A bind mount over this path inherits the host directory's ownership instead,
# which is why setup-keylog.sh chowns the host side to 101:101 as well.
RUN mkdir -p /keylog && chown 101:101 /keylog && chmod 750 /keylog

VOLUME ["/keylog"]
