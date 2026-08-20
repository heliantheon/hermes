<p align="center">
  <img src="./assets/brand/hero-ice.png" width="256" alt="Hermes logo" />
</p>

<h1 align="center">Hermes</h1>

Hermes 是负责「数据」的那个服务：身份、应用、服务、域、凭证、用户组，以及它们之间的授权关系，都统一维护在这里。对外它开两套接口——给管理流程用的 HTTP API，和给 Aegis 用的 gRPC API。协议契约本身也归这个仓库所有，用独立版本发布，不跟代码版本绑在一起。

Hermes owns the identity, application, service, domain, credential, group, and relationship data. It exposes HTTP APIs for management workflows and gRPC APIs for Aegis, and it owns the protocol contract itself, versioned independently from the code.