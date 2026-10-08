/*
 * sslkeylog.c - dump TLS session secrets in NSS Key Log Format
 *
 * Loaded into nginx via LD_PRELOAD so that TLS streams captured with tcpdump
 * can be decrypted in Wireshark. nginx links libssl.so.3 dynamically, which is
 * what makes this interception possible.
 *
 * Why this is needed at all:
 *   - nginx's own ssl_key_log directive (1.27.2+) is NGINX Plus commercial-only.
 *   - OpenSSL 3.4+ honours $SSLKEYLOGFILE natively, but only when built with
 *     enable-sslkeylog, which the official nginx images are not.
 *   - The server private key cannot decrypt these streams: nginx.conf pins
 *     ECDHE cipher suites and TLS 1.3, so forward secrecy applies.
 *
 * We hook SSL_CTX_new and SSL_CTX_new_ex and register OpenSSL's keylog
 * callback on every context nginx creates. OpenSSL 3.x routes through
 * SSL_CTX_new_ex, so hooking only SSL_CTX_new silently produces nothing.
 *
 * Build: gcc sslkeylog.c -shared -o libsslkeylog.so -fPIC -ldl
 *
 * SECURITY: the resulting file decrypts every TLS session this nginx serves.
 * Treat it as equivalent to the private key. Training-lab use only.
 */

#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>

/* Opaque - we never dereference these, so we avoid pulling in OpenSSL headers
 * and the build stays independent of the installed -dev package. */
typedef struct ssl_st SSL;
typedef void SSL_CTX;

static void (*real_set_keylog_callback)(SSL_CTX *, void (*)(const SSL *, const char *));
static FILE *keylog_fp;

static void keylog_callback(const SSL *ssl, const char *line)
{
    (void) ssl;

    if (keylog_fp == NULL) {
        const char *path = getenv("SSLKEYLOGFILE");

        /* nginx scrubs its environment before forking workers, so this is NULL
         * unless nginx.conf carries a top-level `env SSLKEYLOGFILE;`. */
        if (path == NULL || *path == '\0') {
            return;
        }

        /* Append mode: worker processes each hold their own handle, and O_APPEND
         * keeps their short single-line writes from interleaving. */
        keylog_fp = fopen(path, "a");
        if (keylog_fp == NULL) {
            return;
        }
        setvbuf(keylog_fp, NULL, _IOLBF, 0);
    }

    fprintf(keylog_fp, "%s\n", line);
    fflush(keylog_fp);
}

static void attach_keylog(SSL_CTX *ctx)
{
    if (ctx == NULL) {
        return;
    }

    if (real_set_keylog_callback == NULL) {
        real_set_keylog_callback = dlsym(RTLD_NEXT, "SSL_CTX_set_keylog_callback");
    }

    if (real_set_keylog_callback != NULL) {
        real_set_keylog_callback(ctx, keylog_callback);
    }
}

SSL_CTX *SSL_CTX_new(const void *method)
{
    static SSL_CTX *(*real_new)(const void *);
    SSL_CTX *ctx;

    if (real_new == NULL) {
        real_new = dlsym(RTLD_NEXT, "SSL_CTX_new");
        if (real_new == NULL) {
            return NULL;
        }
    }

    ctx = real_new(method);
    attach_keylog(ctx);
    return ctx;
}

SSL_CTX *SSL_CTX_new_ex(void *libctx, const char *propq, const void *method)
{
    static SSL_CTX *(*real_new_ex)(void *, const char *, const void *);
    SSL_CTX *ctx;

    if (real_new_ex == NULL) {
        real_new_ex = dlsym(RTLD_NEXT, "SSL_CTX_new_ex");
        if (real_new_ex == NULL) {
            return NULL;
        }
    }

    ctx = real_new_ex(libctx, propq, method);
    attach_keylog(ctx);
    return ctx;
}
