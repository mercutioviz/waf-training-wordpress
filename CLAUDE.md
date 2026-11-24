# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A throwaway Docker lab ("TechGear Pro") that stands up WordPress + WooCommerce
seeded with content engineered to trip WAF rules — product names like
`15" MacBook Pro`, forms that accept stack traces, order notes containing `OR`.
Analysts put a WAF in front of it and practice telling false positives from
attacks. Nothing here is production code; the deliberately weak credentials and
`WORDPRESS_DEBUG=1` are the point, not oversights.

## Commands

Bring-up is a three-step sequence, and the order matters — nginx will not start
without the certs, and `setup.sh` needs WordPress already answering:

```bash
./generate-certs.sh              # writes certs/ (gitignored); --force to regenerate
docker-compose up -d
docker-compose exec wpcli bash /setup.sh   # 5-10 min
```

Site on http://localhost:8080 and https://localhost:8443 (self-signed, expect a
browser warning), phpMyAdmin on :8081.

`setup.sh` is **step-addressable** — pass one or more function names from its
`ALL_STEPS` array to re-run just those instead of the whole pass. A full cold
run took ~47 minutes on a clean volume, dominated by `install_plugins` (16
plugins) and `add_product_images` (49 Unsplash downloads); the README's "5-10
minutes" is optimistic. Step mode is the main iteration loop for seeded content:

```bash
docker-compose exec wpcli bash /setup.sh import_products create_comments
docker-compose exec wpcli bash /setup.sh nonexistent_step   # prints all step names
```

**After editing `setup.sh`, `products.csv`, `forms-config.json` or `wp-cli.yml`,
recreate the wpcli container before re-running a step:**

```bash
docker-compose up -d --force-recreate wpcli
```

Those four are *single-file* bind mounts, and Docker pins them to the file's
inode. Any editor that writes a temp file and renames over the original —
`sed -i`, vim, most IDEs — leaves the host with a new inode while the container
keeps serving the old contents indefinitely. The symptom is an edit that seems
to do nothing: the step runs, reports success, and executes the previous
version of the code. Confirm with
`docker-compose exec wpcli stat -c %i /setup.sh` against `stat -c %i setup.sh`.
A `restart` is not enough; the container must be recreated.

There is no unit test suite or linter. `test-waf.sh` is the closest thing: it
replays about two dozen legitimate-but-suspicious requests through a shared
`test_request` helper and prints a results table. `BLOCKED` (HTTP 403/406) means
the WAF under test produced a false positive — so unlike a normal test suite, a
clean run is all `PASS` and any red row is a finding about the WAF, not about
this repo. Two checks sit outside the helper and invert that reading: the
sqlmap-User-Agent probe records `PASS` when the WAF *does* block it, and the
rate-limit check fires ten rapid requests.

```bash
./test-waf.sh                            # defaults to http://localhost:8080
./test-waf.sh https://localhost:8443     # already passes --insecure
VERBOSE=1 ./test-waf.sh <url>
```

TLS key logging for Wireshark decryption (off by default, see below):

```bash
./setup-keylog.sh on|off|status|clear
```

Full reset (destroys both volumes and all seeded content):

```bash
docker-compose down -v && docker-compose up -d
```

## Architecture

**Traffic path:** nginx (`techgear/nginx-keylog`, built from `nginx/Dockerfile`)
terminates :80 and :443, serves static files from a read-only mount of the
WordPress volume, and forwards `.php` to the `wordpress:fpm` container over
FastCGI on :9000. MySQL and phpMyAdmin sit behind on `techgear_network`. The
`wpcli` container idles on `tail -f /dev/null` purely so you can `exec` into it.

**HTTP is deliberately not redirected to HTTPS.** Both schemes serve the same
site so an analyst can replay one request over each and diff what the WAF logs.
Don't "fix" this by adding a redirect.

**Scheme propagation is a four-link chain, and all four must agree** or
WordPress emits `http://` links behind a TLS-terminating WAF, producing mixed
content and redirect loops:

1. `nginx.conf` — `map $http_x_forwarded_proto $client_scheme` prefers the
   client's real scheme (what an upstream WAF reports) over nginx's own.
2. `nginx.conf` — `map $client_scheme $fastcgi_https` reduces that to the
   CGI-style `on`/empty flag PHP expects.
3. `nginx/wordpress-common.conf` — passes `HTTPS` and `REQUEST_SCHEME` to
   PHP-FPM. These lines **must stay after `include fastcgi_params`** in order
   to override what that include already set.
4. `setup.sh:configure_wordpress_constants` — rewrites `wp-config.php` so
   `WP_HOME`/`WP_SITEURL` are computed from `$_SERVER['HTTPS']` and
   `HTTP_HOST` at request time rather than hardcoded.

`wordpress-common.conf` is shared by both server blocks; protocol-specific
directives (`listen`, `ssl_*`) belong in `nginx.conf`, not there.

**TLS key logging** exists because the server private key alone can't decrypt
captures — `nginx.conf` pins ECDHE and TLS 1.3, so forward secrecy applies.
nginx's own `ssl_key_log` is NGINX Plus only, so `nginx/sslkeylog.c` is an
`LD_PRELOAD` shim registering OpenSSL's keylog callback. It ships in the image
but stays inert unless **both** `LD_PRELOAD` and `SSLKEYLOGFILE` are set, which
is why stock runs are unaffected. The `env SSLKEYLOGFILE;` line at the top level
of `nginx.conf` is load-bearing: nginx scrubs its environment before forking
workers, so without it the shim loads and silently logs nothing. It is a config
error inside `http{}`.

**Content seeding** lives in `setup.sh` (~1200 lines, one function per step).
Products come from `products.csv`; the Contact Form 7 forms come from
`forms-config.json`, which `configure_contact_forms` reads in full, creating any
form whose title doesn't already exist (all five: Contact Us, Technical Support,
Product Inquiry, Partnership Request, Developer API Access). Product images are
handled in-script by `add_product_images()`, which resolves products by SKU
(`wp post list --meta_key=_sku`) so it survives a re-import.

`ALL_STEPS` order carries one real dependency: `configure_contact_forms` must
stay ahead of `create_pages`, because the Contact page embeds the Technical
Support form by shortcode ID and `create_pages` resolves that ID by looking the
form up by title. Run `create_pages` alone against a site without the forms and
it warns and emits a formless Contact page rather than failing.

When adding seeded content, make it *plausibly legitimate yet rule-tripping* —
that's the whole design constraint. `FALSE_POSITIVES.md` catalogs which trigger is meant to fire
which rule category; update it alongside any content change.

**Two plugin-API workarounds, because this failure mode keeps recurring.**
`import_products` parses the CSV in PHP since `wp wc product import` was removed
in WooCommerce 10.x. `configure_contact_forms` uses CF7's instance API
(`WPCF7_ContactForm::get_template()` → `set_title()` → `set_properties()` →
`save()`); `save()` is *not* static, and calling it statically is an immediate
PHP fatal. When a plugin's API moves under one of these steps, let the error
surface — **never wrap `wp eval` in `2>/dev/null || print_info "...created"`**.
That idiom runs its fallback on the *failure* path, so it logged "Contact form
created" at exactly the moment creation fatally failed, and `print_info`'s exit 0
made the step report success while creating nothing.

## Gotchas

- `certs/` and `keylog/` are gitignored secrets. A key log decrypts **every**
  TLS session nginx serves while enabled, not just yours — treat it like the
  private key, and leave key logging off unless actively capturing.
- Empty key log while `status` says active is almost always permissions: nginx
  workers are uid 101 and bind mounts keep host ownership. `setup-keylog.sh`
  chowns `keylog/`, falling back to world-writable without sudo.
- Failed decryption despite a populated key log is usually session resumption.
  `ssl_session_tickets off` is already set; add `ssl_session_cache off` during
  capture if sessions still resume.
- Start `tcpdump` *before* generating traffic — a session whose handshake isn't
  in the capture can't be decrypted no matter what keys you have.
- WP-CLI runs as uid 33 with a 512M memory limit; `wp-cli.yml` sets
  `allow-root` and a default URL to suppress `HTTP_HOST` warnings.

## Reference docs

`README.md` is the main document (setup, six training scenarios, WAF
integration patterns, timed exercises). `FALSE_POSITIVES.md` catalogs triggers
by rule category. `TROUBLESHOOTING.md` covers the recurring failures, several
with dedicated scripts: `debug-503.sh`, `diagnose-wordpress.sh`,
`fix-http-host.sh`, `docker-cleanup.sh`. Prefer updating these over restating
them here.
