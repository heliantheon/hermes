<p align="center">
  <img src="./assets/brand/hero-ice.png" width="256" alt="Hermes logo" />
</p>

<h1 align="center">Hermes</h1>

Hermes 是 Helios 里负责"数据"的那个服务：身份、应用、服务、域、凭证、用户组，以及它们之间的授权关系，都统一在这里维护。对外它开两套接口——给管理流程用的 HTTP API，和给 Aegis 用的 gRPC API。协议契约本身也归这个仓库所有。

Hermes owns Helios' identity, application, service, domain, credential, group, and relationship data. It exposes HTTP APIs for management workflows and gRPC APIs consumed by Aegis, and it owns the language-neutral protocol contract itself.

## 本地运行

需要 PostgreSQL：

```bash
cp example.toml config.toml
make run
```

schema 和迁移在 [`sql/`](sql/) 目录下。部署相关的种子数据不进这个仓库。

## 协议 Schema

公共契约放在 `proto/v1`，Protobuf 包名是 `hermes.v1`。Schema 的版本用独立标签（如 `schema/v1.0.0`）发布，和代码版本解耦。

```text
proto/v1/*.proto          公开的、语言无关的 Schema
internal/grpc/v1/*.pb.go  私有的 Go 服务端绑定
```

生成并校验已提交的服务端绑定：

```bash
make proto-lint
make generate
make check-generate
```

消费方拿一份公开仓库 + 固定 Schema 标签，自己去生成绑定，而不是引入 Hermes 的 Go API module：

```yaml
inputs:
  - git_repo: https://github.com/heliantheon/hermes.git
    tag: schema/v1.0.0
    subdir: proto
```

## 开发

```bash
make test
make lint
make build
```