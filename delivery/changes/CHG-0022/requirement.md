---
id: "REQ-M5-003"
name: "系统功能与参数配置"
content: "建立平台统一功能开关（Feature Config）和系统参数（System Parameter）管理能力：配置模型与明确类型、安全默认值、mall-admin 后台维护与 M1 RBAC、高风险 Secret 边界、Redis 配置缓存与失效、动态生效（区分热生效与重启生效）、配置版本与变更审计、跨服务统一 Config Access 边界（SystemConfigClient/FeatureFlagService）、前端公开安全配置 API（前端隐藏 + 后端拒绝）。"
source: requirement-doc
created-at: "2026-09-18T10:37:01.573Z"
---

# Requirement

> 原始需求全文归档于 `references/M5.md`（M5 三 REQ + Integration Gate 七场景 + DoD），本文件记录本 Change（REQ-M5-003）的输入边界。

## 需求描述

**阶段：** M5 搜索与系统配置
**类型：** 平台配置需求
**优先级：** P1
**前置依赖：** REQ-M1-002、REQ-M1-003
**主要服务：** mall-system
**主要前端：** mall-admin
**基础设施：** MySQL、Redis

### 一、需求目标

建立平台统一功能开关和系统参数管理能力，避免后续"是否开启 AI 导购、是否允许游客购物车、订单默认配置、搜索默认参数"等系统行为全部硬编码在代码中。完成后应能够通过后台维护 Feature Config + System Parameter，并通过缓存和配置读取机制使相关服务使用。

### 二、配置分类

1. **Feature Config** — 控制功能是否启用，例如 `ai.shopping.enabled`、`ai.rag.enabled`、`mall.guest-cart.enabled`、`search.enabled`。
2. **System Parameter** — 控制功能运行参数，例如 `cart.max-item-quantity`、`order.default-timeout-minutes`、`search.default-page-size`、`ai.max-tool-calls`。

具体参数在后续 Requirement 需要时逐步增加，M5 不需要一次预定义整个项目所有参数。

### 三、配置模型

至少需要表达：

```text
configKey
configValue
configType
category
description
enabled
version
updatedAt
```

具体模型由 Design 决定。要求 configKey 稳定且唯一。

### 四、配置类型

配置值应支持明确类型：

```text
STRING
INTEGER
DECIMAL
BOOLEAN
JSON
```

读取配置时按声明类型解析，不要让所有配置最终都变成 String、业务代码到处自己解析。

### 五、配置默认值

业务代码使用配置时必须有明确策略：配置存在 → 使用配置值；配置不存在 → 使用安全默认值/明确失败。不能因为数据库暂时缺少一条非关键配置就导致整个服务无法启动。Required Config 与 Optional Config 由 Design 区分。

### 六、后台配置管理

mall-admin 至少提供：功能开关列表、开启/关闭功能、系统参数列表、修改参数、参数分类、参数说明。必须接入 M1 RBAC，可规划 `system:config:read`、`system:config:update`（具体权限码由 Design 确定）。

### 七、高风险配置限制

Database Password、Redis Password、JWT Secret、LLM API Key、Cloud Secret、MinIO Secret Key 等不能作为普通动态系统参数，仍应由 Environment Variable / Secret Management 管理。系统配置模块不能演变成所有 Secret 的数据库仓库。

### 八、Redis 配置缓存

为避免每次业务请求都查询 mall-system DB，需要建立 Redis 配置缓存：

```text
Business Service
↓
Config Client
↓
Redis
```

或者通过确定的内部配置服务机制实现。具体跨服务读取模式由 Design 决定。

### 九、缓存失效

修改配置后：

```text
Database Update
↓
Cache Invalidate / Refresh
↓
后续读取使用新配置
```

必须避免数据库已经修改、Redis 永久还是旧值。

### 十、动态生效

允许动态生效的配置需在合理时间内反映到业务系统（如 AI 导购开关 ON→后台改 OFF→入口/服务按设计关闭），但需要区分 Dynamic Config 与 Restart Required Config，不是所有底层技术参数都适合热修改。

### 十一、Feature Flag

Feature Flag 应支持 Enabled / Disabled。后续可扩展环境、用户、灰度比例，但 M5 不建设复杂 Feature Flag SaaS。首期重点：平台功能能够无需修改代码完成启停。

### 十二、配置版本

重要配置变更应具备 version / updatedAt 等版本语义，防止旧缓存或旧消息覆盖较新配置。

### 十三、配置审计

关键配置变更需要记录：谁、修改了什么、从什么值改为什么值、什么时候修改。尤其 Feature Flag 和重要运行参数，不得出现"配置突然变了但完全不知道谁改的"。

### 十四、服务使用方式

业务服务不得到处直接 `SELECT system_config`，也不得每个服务实现一套 Config DAO，应形成统一 Config Access 边界，例如 SystemConfigClient、FeatureFlagService，具体设计由 SDD Design 确定。

### 十五、前端功能开关

部分 Feature Config 可能影响 mall-web、mall-admin 页面显示（如 AI 导购是否展示），可通过后端公开安全配置 API 返回。但前端隐藏不能成为真正的安全控制：关闭敏感功能时 Frontend Hide + Backend Reject 都需要生效。

### 十六、验收标准

- 可以创建/维护 Feature Config；
- 可以创建/维护 System Parameter；
- configKey 唯一；
- 支持明确配置类型；
- 配置可以查询；
- 配置可以修改；
- mall-admin 页面可管理配置；
- 接口受 RBAC 控制；
- 配置能够缓存到 Redis；
- 修改后缓存能够正确失效；
- 动态配置能够按照设计生效；
- 功能关闭后相关后端行为正确；
- Secret 不进入普通系统参数；
- 配置变更能够审计；
- 配置相关测试通过。

### 十七、非本需求范围

- Nacos 全量配置中心迁移；
- Secret Manager；
- 复杂灰度发布；
- A/B Test 平台；
- 多租户配置。

## 补充信息

- 优先级：P1；与 REQ-M5-001 可完全并行，不依赖搜索域。
- 前置依赖：REQ-M1-002、REQ-M1-003（M1 RBAC：权限码/菜单/后端方法授权/权限缓存体系已交付）。
- 主要仓库：repo-1（backend：mall-system 从空骨架交付，8108，mall_system 库已预建；mall-common 新增统一 Config Client/FeatureGate 基础；其他服务按需接入）、repo-2（frontend：mall-admin 配置管理页面 + mall-web/mall-admin 公开开关显隐）。
- 产品知识依据：product/11-权限与功能配置.md 已给出细案——FeatureConfig/SystemParameter 双模型字段、权限码（system:feature:list / system:feature:update / system:parameter:list / system:parameter:update / system:config-history:list）、Redis Key 规范（aimall:{env}:system:feature|parameter:{configKey}、public-features 聚合键）、缓存层级与 TTL（Redis 10 分钟、本地 1~5 分钟）、类型（STRING/INTEGER/LONG/DECIMAL/BOOLEAN/DURATION）、version 乐观锁、配置历史字段、安全默认值（高风险写能力默认关闭）、FeatureGate/SystemParameterProvider 接口；PRD/Design 与需求原文的统一模型/JSON 类型描述做收敛。
- 端口/路由（product/08 已规划）：mall-system 8108；`/api/admin/feature-configs/**`、`/api/admin/system-parameters/**`、`/api/admin/operation-logs/**`（ADMIN+权限码）、`/api/mall/public-features`（游客可访问，仅 publicFlag 项）；内部配置查询端点走 `/api/internal/**`（SERVICE 身份，网关 denyAll）。
- 技术约束：Java 21 + Spring Boot 3.5.x + MyBatis-Plus + Flyway + Redis；M5 配置变更通知采用缓存失效 + TTL +（可选）Redis Pub/Sub 轻量通知，不引入 RocketMQ（M7 再升级配置变更事件）；中文注释。
- M5 首期种子配置：以需求点名的 search.enabled、mall.guest-cart.enabled 等少量当前阶段实际消费的开关/参数为准，产品文档 11 中 AI/退款等未来配置键只建机制不强制启用。
