<p align="center">
  <img src="./assets/brand/mark.svg" width="112" alt="Hermes logo" />
</p>

<h1 align="center">Hermes</h1>

<p align="center">
  <strong>Identity, provisioning, and relationship data for Helios.</strong><br />
  Helios 的身份、资源配置与关系数据服务。
</p>

## Overview / 项目简介

Hermes owns identity, application, service, domain, credential, group, and relationship data. It exposes HTTP APIs for management workflows and gRPC APIs consumed by Aegis.

Hermes 统一维护 Helios 的身份、应用、服务、域、凭证、用户组和授权关系数据，并直接拥有对应的语言无关 Protobuf Schema。

## Run locally

Hermes needs PostgreSQL:

```bash
cp example.toml config.toml
make run
```

The schema and migrations are under [`sql/`](sql/). Deployment-specific seed data is not stored in this repository.

## Protocol Schema

The public contract lives in `proto/v1` and keeps the Protobuf package `hermes.v1`. Schema versions use independent tags such as `schema/v1.0.0`.

```text
proto/v1/*.proto          public, language-neutral Schema
internal/grpc/v1/*.pb.go  private Go server bindings
```

Generate and verify the committed server bindings with:

```bash
make proto-lint
make generate
make check-generate
```

Consumers generate their own bindings from the public Git repository and a fixed Schema tag; they do not import a Hermes Go API module.

```yaml
inputs:
  - git_repo: https://github.com/heliantheon/hermes.git
    tag: schema/v1.0.0
    subdir: proto
```

## Development

```bash
make test
make lint
make build
```
