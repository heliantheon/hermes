# Kubernetes deployment contract

`deploy/` is the reusable Kubernetes contract owned by Hermes. It contains no
environment credentials and never tracks the currently promoted image.

- `base/` declares the workload, Service, and dedicated ServiceAccount.
- `config/` declares non-sensitive production defaults and the required Secret keys.
- `ingress/` declares Hermes' `/api` HTTP route. The gRPC port remains cluster-internal.

The private `heliantheon/applications` repository pins this directory at an
immutable Git ref and supplies the release image plus encrypted runtime Secret.
Application CI may update only that repository's `overlay/` directory.

