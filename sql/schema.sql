-- Hermes 数据库 Schema（身份与访问管理数据）
-- PostgreSQL 18 语法
-- 注意：session、authorization_code、refresh_token 都存储在 Redis 中
-- 注意：域签名密钥仍从配置文件或密钥服务读取，不存库
-- 注意：IDP 的凭证（app_id/secret）存储在 t_domain_idp_credential 和 t_application_idp_config 中

-- ==================== 数据库初始化 ====================

SELECT 'CREATE DATABASE hermes'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'hermes')\gexec
\connect hermes

-- ============================================================================
-- 一、平台配置层（Domain > Application > Service）
-- ============================================================================

-- ==================== 域表 ====================
-- 域元数据及该域允许的 IDP 列表（签名密钥从配置/密钥服务读取）

CREATE TABLE IF NOT EXISTS t_domain (
    domain_id     VARCHAR(32)   NOT NULL,
    name          VARCHAR(128)  NOT NULL,
    description   VARCHAR(512)  DEFAULT NULL,
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (domain_id)
);

COMMENT ON TABLE t_domain IS '域（元数据）';
COMMENT ON COLUMN t_domain.domain_id IS '域标识：consumer/platform 等';
COMMENT ON COLUMN t_domain.name IS '域名称';
COMMENT ON COLUMN t_domain.description IS '域描述';

-- ==================== 域允许的 IDP 表 ====================
-- 每个域下允许使用的 IDP 类型，应用添加 IDP 时只能从此列表选

CREATE TABLE IF NOT EXISTS t_domain_idp (
    domain_id     VARCHAR(32)   NOT NULL,
    idp_type      VARCHAR(32)   NOT NULL,
    created_at    TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (domain_id, idp_type),
    CONSTRAINT fk_domain_idp_domain FOREIGN KEY (domain_id) REFERENCES t_domain(domain_id) ON DELETE CASCADE
);

COMMENT ON TABLE t_domain_idp IS '域允许的 IDP';
COMMENT ON COLUMN t_domain_idp.idp_type IS 'IDP 类型：github/google/user/staff/wxmp 等';

-- ==================== 应用表 ====================
-- OAuth2 客户端应用，属于某个 Domain

CREATE TABLE IF NOT EXISTS t_application (
    _id                BIGSERIAL PRIMARY KEY,
    -- 业务字段
    domain_id          VARCHAR(32)   NOT NULL,
    app_id             VARCHAR(64)   NOT NULL,
    name               VARCHAR(128)  NOT NULL,
    description        VARCHAR(512)  DEFAULT NULL,
    logo_url           VARCHAR(512)  DEFAULT NULL,
    redirect_uris                   VARCHAR(2048) DEFAULT NULL,
    allowed_origins                 VARCHAR(1024) DEFAULT NULL,
    allowed_logout_uris             VARCHAR(1024) DEFAULT NULL,
    id_token_expires_in             INTEGER NOT NULL DEFAULT 3600,
    refresh_token_expires_in        INTEGER NOT NULL DEFAULT 604800,
    refresh_token_absolute_expires_in INTEGER NOT NULL DEFAULT 0,
    -- 时间戳
    created_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE t_application IS 'OAuth2 应用';
COMMENT ON COLUMN t_application.domain_id IS '所属域：consumer/platform';
COMMENT ON COLUMN t_application.app_id IS '应用唯一标识';
COMMENT ON COLUMN t_application.logo_url IS '应用 Logo URL';
COMMENT ON COLUMN t_application.redirect_uris IS '重定向 URI 列表（JSON 数组）';
COMMENT ON COLUMN t_application.allowed_origins IS '允许的跨域源（JSON 数组）';
COMMENT ON COLUMN t_application.allowed_logout_uris IS '登出后允许跳转的 URI（JSON 数组）';
COMMENT ON COLUMN t_application.id_token_expires_in IS 'ID Token 有效期（秒）';
COMMENT ON COLUMN t_application.refresh_token_expires_in IS 'Refresh Token 沉寂有效期（秒）';
COMMENT ON COLUMN t_application.refresh_token_absolute_expires_in IS 'Refresh Token 绝对有效期（秒），0=不限制';

CREATE UNIQUE INDEX uk_app_id ON t_application (app_id);

-- ==================== IDP 密钥表 ====================
-- 全局存储第三方 IDP 凭证，(idp_type, t_app_id) 唯一

CREATE TABLE IF NOT EXISTS t_idp_key (
    _id          BIGSERIAL PRIMARY KEY,
    -- 业务字段
    idp_type     VARCHAR(32)   NOT NULL,
    t_app_id     VARCHAR(256)  NOT NULL,
    t_secret     TEXT          NOT NULL,
    -- 时间戳
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE t_idp_key IS 'IDP 密钥';
COMMENT ON COLUMN t_idp_key.idp_type IS 'IDP 类型：github/google/wxmp/ttmp 等';
COMMENT ON COLUMN t_idp_key.t_app_id IS '第三方 IDP 的 App ID / Client ID';
COMMENT ON COLUMN t_idp_key.t_secret IS '加密 JSON（AES-GCM），含 secret/private_key 等';

CREATE UNIQUE INDEX uk_idp_app ON t_idp_key (idp_type, t_app_id);

-- ==================== 域 IDP 配置表 ====================
-- 域级别的 IDP 默认配置，引用 t_idp_key 中的 t_app_id

CREATE TABLE IF NOT EXISTS t_domain_idp_config (
    _id          BIGSERIAL PRIMARY KEY,
    -- 业务字段
    domain_id    VARCHAR(32)   NOT NULL,
    idp_type     VARCHAR(32)   NOT NULL,
    priority     INTEGER       NOT NULL DEFAULT 0,
    strategy     VARCHAR(256)  DEFAULT NULL,
    delegate     VARCHAR(256)  DEFAULT NULL,
    "require"    VARCHAR(256)  DEFAULT NULL,
    t_app_id     VARCHAR(256)  NOT NULL,
    -- 时间戳
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_idp_cfg_domain FOREIGN KEY (domain_id) REFERENCES t_domain(domain_id) ON DELETE CASCADE
);

COMMENT ON TABLE t_domain_idp_config IS '域 IDP 配置';
COMMENT ON COLUMN t_domain_idp_config.priority IS '排序优先级（值越大越靠前）';
COMMENT ON COLUMN t_domain_idp_config.strategy IS '认证方式：password,webauthn';
COMMENT ON COLUMN t_domain_idp_config.delegate IS '可替代主认证的独立验证方式（email-code,totp,webauthn）';
COMMENT ON COLUMN t_domain_idp_config."require" IS '前置条件（captcha 等）';
COMMENT ON COLUMN t_domain_idp_config.t_app_id IS '引用 t_idp_key 的 t_app_id';

CREATE UNIQUE INDEX uk_domain_idp_type ON t_domain_idp_config (domain_id, idp_type);
CREATE INDEX idx_domain_priority ON t_domain_idp_config (domain_id, priority DESC);

-- ==================== 应用 IDP 配置表 ====================
-- 应用级别的 IDP 配置，可选覆盖 t_app_id（NULL=使用域默认）

CREATE TABLE IF NOT EXISTS t_application_idp_config (
    _id          BIGSERIAL PRIMARY KEY,
    -- 业务字段
    app_id       VARCHAR(64)   NOT NULL,
    "type"       VARCHAR(32)   NOT NULL,
    priority     INTEGER       NOT NULL DEFAULT 0,
    strategy     VARCHAR(256)  DEFAULT NULL,
    delegate     VARCHAR(256)  DEFAULT NULL,
    "require"    VARCHAR(256)  DEFAULT NULL,
    t_app_id     VARCHAR(256)  DEFAULT NULL,
    -- 时间戳
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE t_application_idp_config IS '应用 IDP 配置';
COMMENT ON COLUMN t_application_idp_config.app_id IS '应用 ID';
COMMENT ON COLUMN t_application_idp_config."type" IS 'IDP 类型：github/google/wxmp/user/staff';
COMMENT ON COLUMN t_application_idp_config.t_app_id IS '引用 t_idp_key 的 t_app_id（NULL=使用域默认）';

CREATE UNIQUE INDEX uk_app_type ON t_application_idp_config (app_id, "type");
CREATE INDEX idx_app_priority ON t_application_idp_config (app_id, priority DESC);

-- ==================== 服务表 ====================
-- 业务服务定义，每个服务有独立的密钥和 Token 配置

CREATE TABLE IF NOT EXISTS t_service (
    _id                       BIGSERIAL PRIMARY KEY,
    -- 业务字段
    domain_id                 VARCHAR(32)   NOT NULL,
    service_id                VARCHAR(32)   NOT NULL,
    name                      VARCHAR(128)  NOT NULL,
    description               VARCHAR(512)  DEFAULT NULL,
    logo_url                  VARCHAR(512)  DEFAULT NULL,
    access_token_expires_in   INTEGER       NOT NULL DEFAULT 7200,
    required_identities       VARCHAR(512)  DEFAULT NULL,
    -- 时间戳
    created_at                TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE t_service IS '业务服务';
COMMENT ON COLUMN t_service.domain_id IS '所属域：consumer/platform；- 表示跨域（底层约定，不在 API 暴露）';
COMMENT ON COLUMN t_service.service_id IS '服务标识：hermes/zwei/order';
COMMENT ON COLUMN t_service.access_token_expires_in IS 'Access Token 有效期（秒），由服务控制';
COMMENT ON COLUMN t_service.required_identities IS '访问需要的身份类型（JSON 数组）';

CREATE INDEX idx_service_domain_cursor ON t_service (domain_id, _id);
CREATE UNIQUE INDEX uk_service_id ON t_service (service_id);

-- ==================== 密钥表 ====================
-- Application / Service 的签名密钥，支持多密钥轮换

CREATE TABLE IF NOT EXISTS t_key (
    _id            BIGSERIAL PRIMARY KEY,
    -- 业务字段
    owner_type     VARCHAR(16)   NOT NULL,
    owner_id       VARCHAR(64)   NOT NULL,
    encrypted_key  VARCHAR(256)  NOT NULL,
    expired_at     TIMESTAMP     DEFAULT NULL,
    -- 时间戳
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE t_key IS '签名密钥';
COMMENT ON COLUMN t_key.owner_type IS '所属类型：application / service';
COMMENT ON COLUMN t_key.owner_id IS '所属 ID：app_id / service_id';
COMMENT ON COLUMN t_key.encrypted_key IS '加密密钥（AES-GCM 加密的 48B seed，Base64 编码）';
COMMENT ON COLUMN t_key.expired_at IS '过期时间，NULL=当前主密钥';

CREATE INDEX idx_owner ON t_key (owner_type, owner_id, created_at DESC);

-- ==================== 服务 Challenge 配置表 ====================
-- 服务级别的 Challenge 配置（限流等），覆盖全局默认

CREATE TABLE IF NOT EXISTS t_service_challenge_setting (
    _id          BIGSERIAL PRIMARY KEY,
    -- 业务字段
    service_id   VARCHAR(32)  NOT NULL,
    "type"       VARCHAR(64)  NOT NULL,
    expires_in   INTEGER      NOT NULL DEFAULT 300,
    limits       JSONB        NOT NULL,
    -- 时间戳
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE t_service_challenge_setting IS '服务 Challenge 配置';
COMMENT ON COLUMN t_service_challenge_setting.service_id IS '服务 ID';
COMMENT ON COLUMN t_service_challenge_setting."type" IS 'Challenge 类型[:场景]，如 email-code / email-code:login';
COMMENT ON COLUMN t_service_challenge_setting.expires_in IS 'Challenge 有效期（秒）';
COMMENT ON COLUMN t_service_challenge_setting.limits IS '限流配置，如 {"1m": 1, "24h": 10}';

CREATE UNIQUE INDEX uk_service_type ON t_service_challenge_setting (service_id, "type");

-- ==================== 应用服务关系表 ====================
-- 定义应用可以访问哪些服务的哪些关系

CREATE TABLE IF NOT EXISTS t_application_service_relation (
    _id          BIGSERIAL PRIMARY KEY,
    -- 业务字段
    app_id       VARCHAR(64)  NOT NULL,
    service_id   VARCHAR(32)  NOT NULL,
    relation     VARCHAR(32)  NOT NULL DEFAULT '*',
    -- 时间戳
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE t_application_service_relation IS '应用服务关系';
COMMENT ON COLUMN t_application_service_relation.relation IS '允许的关系，* 表示全部';

CREATE UNIQUE INDEX uk_app_service_relation ON t_application_service_relation (app_id, service_id, relation);

-- ============================================================================
-- 二、用户层（User、Identity、Credential）
-- ============================================================================

-- ==================== 用户表 ====================
-- 用户基本信息
-- openid = 该域下 global 身份的 t_openid，即对外用户标识
-- 一个物理用户在不同域下有不同的 openid，对应不同的 t_user 记录

CREATE TABLE IF NOT EXISTS t_user (
    _id              BIGSERIAL PRIMARY KEY,
    -- 业务字段
    openid           VARCHAR(64)   NOT NULL,
    status           SMALLINT      NOT NULL DEFAULT 0,
    username         VARCHAR(64)   DEFAULT NULL,
    password_hash    VARCHAR(256)  DEFAULT NULL,
    email_verified   BOOLEAN       NOT NULL DEFAULT FALSE,
    nickname         VARCHAR(128)  DEFAULT NULL,
    picture          VARCHAR(512)  DEFAULT NULL,
    email            VARCHAR(256)  DEFAULT NULL,
    phone            VARCHAR(64)   DEFAULT NULL,
    phone_cipher     VARCHAR(256)  DEFAULT NULL,
    -- 时间戳
    last_login_at    TIMESTAMP     DEFAULT NULL,
    created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE t_user IS '用户';
COMMENT ON COLUMN t_user.openid IS '用户标识（= global identity 的 t_openid）';
COMMENT ON COLUMN t_user.status IS '状态：0=active, 1=disabled';
COMMENT ON COLUMN t_user.password_hash IS '密码哈希（bcrypt）';
COMMENT ON COLUMN t_user.email_verified IS '邮箱是否已验证';
COMMENT ON COLUMN t_user.phone IS '手机号哈希（SHA256，用于查询）';
COMMENT ON COLUMN t_user.phone_cipher IS '手机号密文（AES-GCM）';
COMMENT ON COLUMN t_user.last_login_at IS '最后登录时间';

CREATE UNIQUE INDEX uk_openid ON t_user (openid);
CREATE UNIQUE INDEX uk_email ON t_user (email);
CREATE UNIQUE INDEX uk_phone ON t_user (phone);
CREATE UNIQUE INDEX uk_username ON t_user (username);

-- ==================== 用户身份表 ====================
-- 用户与 IDP 的绑定关系，每个身份归属一个域（consumer/platform）
-- idp=global 的身份为该域下的对外标识（token 中的 sub）

CREATE TABLE IF NOT EXISTS t_user_identity (
    _id          BIGSERIAL PRIMARY KEY,
    -- 业务字段
    domain       VARCHAR(16)   NOT NULL,
    uid          VARCHAR(64)   NOT NULL,
    idp          VARCHAR(64)   NOT NULL,
    t_openid     VARCHAR(256)  NOT NULL,
    raw_data     TEXT          DEFAULT NULL,
    -- 时间戳
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE t_user_identity IS '用户身份';
COMMENT ON COLUMN t_user_identity.domain IS '身份所属域：consumer/platform';
COMMENT ON COLUMN t_user_identity.uid IS '用户内部标识（关联 t_user.openid）';
COMMENT ON COLUMN t_user_identity.idp IS 'IDP 标识：global/user/staff/github/wxmp/google 等';
COMMENT ON COLUMN t_user_identity.t_openid IS 'IDP 侧用户标识（global 为域级对外标识，第三方为 IDP 返回的 openid）';
COMMENT ON COLUMN t_user_identity.raw_data IS 'IDP 返回的原始数据（JSON）';

CREATE UNIQUE INDEX uk_domain_idp_t_openid ON t_user_identity (domain, idp, t_openid);
CREATE INDEX idx_uid ON t_user_identity (uid);
CREATE INDEX idx_domain_uid_idp ON t_user_identity (domain, uid, idp);

ALTER TABLE t_user_identity
ADD CONSTRAINT fk_identity_user FOREIGN KEY (uid) REFERENCES t_user(openid) ON DELETE CASCADE;

-- ==================== 用户凭证表 ====================
-- 用户安全凭证（MFA：TOTP、WebAuthn、Passkey）

CREATE TABLE IF NOT EXISTS t_user_credential (
    _id              BIGSERIAL PRIMARY KEY,
    -- 业务字段
    openid           VARCHAR(64)   NOT NULL,
    "type"           VARCHAR(32)   NOT NULL,
    credential_id    VARCHAR(256)  DEFAULT NULL,
    label            VARCHAR(128)  NOT NULL DEFAULT '',
    secret           VARCHAR(2048) NOT NULL,
    enabled          BOOLEAN       NOT NULL DEFAULT FALSE,
    -- 时间戳
    last_used_at     TIMESTAMP     DEFAULT NULL,
    created_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at       TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE t_user_credential IS '用户安全凭证（MFA）';
COMMENT ON COLUMN t_user_credential.openid IS '用户标识（关联 t_user.openid）';
COMMENT ON COLUMN t_user_credential."type" IS '凭证类型：totp/webauthn/passkey';
COMMENT ON COLUMN t_user_credential.credential_id IS 'WebAuthn 凭证 ID（Base64 编码）';
COMMENT ON COLUMN t_user_credential.label IS '凭证名称，创建时推断，用户可重命名';
COMMENT ON COLUMN t_user_credential.secret IS '凭证数据（AES-GCM 加密，Base64 编码的 JSON）';
COMMENT ON COLUMN t_user_credential.enabled IS '是否已启用';

CREATE UNIQUE INDEX uk_credential_id ON t_user_credential (credential_id);
CREATE INDEX idx_openid_type ON t_user_credential (openid, "type");

-- ============================================================================
-- 三、权限层（Group、Relationship）
-- ============================================================================

-- ==================== 用户组表 ====================
-- 用户组定义

CREATE TABLE IF NOT EXISTS t_group (
    _id          BIGSERIAL PRIMARY KEY,
    -- 业务字段
    group_id     VARCHAR(64)   NOT NULL,
    service_id   VARCHAR(32)   NOT NULL,
    name         VARCHAR(128)  NOT NULL,
    description  VARCHAR(512)  DEFAULT NULL,
    -- 时间戳
    created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE t_group IS '用户组';
COMMENT ON COLUMN t_group.group_id IS '组标识';
COMMENT ON COLUMN t_group.service_id IS '所属服务';

CREATE UNIQUE INDEX uk_group_id ON t_group (group_id);
CREATE INDEX idx_service_id ON t_group (service_id);

-- ==================== 权限关系表 ====================
-- ReBAC 核心表：定义主体与资源之间的关系

CREATE TABLE IF NOT EXISTS t_relationship (
    _id            BIGSERIAL PRIMARY KEY,
    -- 业务字段
    service_id     VARCHAR(32)   NOT NULL,
    subject_type   VARCHAR(32)   NOT NULL,
    subject_id     VARCHAR(64)   NOT NULL,
    relation       VARCHAR(32)   NOT NULL,
    object_type    VARCHAR(32)   NOT NULL,
    object_id      VARCHAR(128)  NOT NULL,
    -- 时间戳
    expires_at     TIMESTAMP     DEFAULT NULL,
    created_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE t_relationship IS '权限关系';
COMMENT ON COLUMN t_relationship.subject_type IS '主体类型：user/group/application';
COMMENT ON COLUMN t_relationship.relation IS '关系：admin/owner/editor/viewer/member';
COMMENT ON COLUMN t_relationship.object_type IS '资源类型：service/recipe/category，* 表示全部';
COMMENT ON COLUMN t_relationship.object_id IS '资源 ID，* 表示全部';
COMMENT ON COLUMN t_relationship.expires_at IS '过期时间（NULL=永不过期）';

CREATE UNIQUE INDEX uk_relationship ON t_relationship (service_id, subject_type, subject_id, relation, object_type, object_id);
CREATE INDEX idx_permission_check ON t_relationship (service_id, subject_type, subject_id, object_type, object_id);
CREATE INDEX idx_group_member ON t_relationship (service_id, object_type, object_id, relation);