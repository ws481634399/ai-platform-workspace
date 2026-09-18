---
title: 动态配置与功能开关规范
tags: [backend, config, feature-gate, redis-cache, fail-open, flyway]
related-changes: [CHG-0022]
---

# 动态配置与功能开关规范

> 版本：v0.1
> 类型：后端工程规范
> 作用域：OpenSpec Workspace
> 来源：CHG-0022 系统配置（功能开关与参数管理）

## 1. 配置中心边界

- mall-system（端口 8108）是系统配置的**唯一写者**：管理端写入 MySQL 并回填 Redis。
- 消费服务**只读 Redis / 只读 HTTP 端点 + 本地短 TTL 缓存**，严禁跨服务直连配置库。
- 配置分两类：FEATURE 功能开关（ON/OFF）、PARAMETER 业务参数（STRING/INTEGER/BOOLEAN 等强类型值）。

## 2. Redis 键与 TTL 分层

- 键命名：`aimall:{env}:system:feature:{key}`、`aimall:{env}:system:parameter:{key}`、聚合键 `aimall:{env}:system:public-features`。
- TTL：正常值 600s；查询未命中的**负缓存** 60s（防穿透）；消费端本地缓存 60s。
- 配置值变更的全局生效时延上限 = 本地 TTL（≤60s），任何文档/提示不得写更大口径。

## 3. 变更失效与多实例一致性

- 写库事务 `AFTER_COMMIT` 后精确删键：删单键 + 恒删聚合公开键；缓存删除失败不回滚业务事务（下次 TTL 自然收敛）。
- 多实例靠本地 TTL 有界收敛，**不依赖** Pub/Sub；M5 明确不引入消息通知机制，实例规模或时效要求升级后再专项引入。
- 公开端点只返回状态为 ON 的公开开关，字段为 `{key, enabled}`，不暴露内部参数与关闭项细节。

## 4. FeatureGate 失败策略（fail-open）

- UI 显隐一律 **fail-open**（取不到配置时按"可见"渲染，避免缓存故障锁死界面）。
- 服务端拦截仅对**显式 false** 生效；缓存全故障时默认放行并打 WARN（限频）。
- 每个开关上线前必须逐键评估默认值：存量能力默认 ON，新高风险能力可默认 OFF，但故障态语义均为放行。

## 5. 内部批量查询契约

- 端点 `GET /api/internal/system/config/values`（以设计冻结为准）：`X-Internal-Token` 鉴权 + SERVICE 身份。
- `keys` 必填、去重、数量 ≤100，超出按参数错误拒绝（不做服务端分批）。
- 最小返回 `{values, missingKeys}`，只回键值映射，不回包络数组以外的元数据。
- 参数校验错误码遵循 [framework-standard.md](framework-standard.md) §13.4 的 A 段通用参数码，不复用业务错误码。

## 6. 内置配置播种与并发更新

- 内置配置以 **Flyway 版本化 DML 唯一播种**，禁止运行时 Seeder 类重复播种（不得存在"双保险"播种器）。
- 更新采用乐观锁：更新前预检版本 + 落库时 DB CAS（version 条件 UPDATE），冲突返回 B0603。
- 内置键保护边界：**禁删、禁改 key**（分组/描述等元信息可否改以产品规则为准）。
- 前端持有旧版本更新冲突时引导刷新（B0604），不静默覆盖。

## 7. 错误码与权限

- 错误码：B0601 参数错误、B0602 配置不存在、B0603 版本冲突、B0604 数据已更新需刷新、B0606 配置项已禁用。
- 管理权限 `system:*` 与管理菜单经 identity 权限种子（V10）发放；公开端点游客可访问但只返回 ON 的公开开关。
- 所有管理端变更必须落审计（操作人、前后值、时间、traceId）。

## 8. 安全要求

- 配置键创建面为 ADMIN-only 内网受信，仍须落字符白名单 `[a-z0-9.-]+` 且长度 ≤100：键会拼入 Redis 键路径，非预期字符会造成键空间/日志混淆。
- 内部共享密钥（mall-system `MALL_INTERNAL_SHARED_SECRET`、消费端 `mall.config.internal-token`）**生产环境必须显式注入**，禁止沿用代码默认值；上线部署清单逐项核验。
