---
story-id: "STORY-006-01-01-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S1]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.1 [S1]/§4/§5
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0022
- Story ID: STORY-006-01-01-01 配置模型、后台管理与变更审计
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`（S1）

## 1. Story 目标

交付配置管理服务垂直切片：mall-system 从空骨架建成 FeatureConfig/SystemParameter/ConfigHistory 三表与种子、类型/范围/乐观锁/内置保护领域规则、admin 列表/详情/启停/修改/历史端点与五权限码，mall-admin 三个管理页面；缓存分发与统一客户端在后续 Story 交付，本 Story 服务内可直接读库（仅 mall-system 自身）。

## 2. Scope（范围）

### 2.1 包含

- [S1] Flyway V1 三表（字段见 requirement-spec §3.1 [S1]）+ 内置种子（feature：search.enabled=true/public、mall.guest-cart.enabled=true/public；parameter：search.default-page-size=20 INTEGER [1,100]、cart.max-item-quantity=99 INTEGER [1,999]，以最终 design 清单为准，宁少勿滥）。
- [S1] domain.config：FeatureConfig/SystemParameter/ConfigHistory 模型；ConfigType 枚举；ParameterValueValidator（类型与 [min,max]）；version 乐观锁异常。
- [S1] application：FeatureConfigAppService/SystemParameterAppService/ConfigHistoryAppService（分页/分组/启停/更新/建键/删非内置；更新成功发 ConfigChangedApplicationEvent 供后续 Story 缓存监听）。
- [S1] interfaces.rest.admin：FeatureConfigAdminController/SystemParameterAdminController/ConfigHistoryAdminController（/api/admin/feature-configs、/api/admin/system-parameters、/api/admin/config-history）。
- [S1] 安全：SystemSecurityConfiguration ADMIN + 五权限码；mall-identity V9 权限种子 SQL + 菜单（系统配置：功能开关/系统参数/变更历史）。
- [S1] 网关：/api/admin/feature-configs/**、/api/admin/system-parameters/**、/api/admin/config-history/** → 8108 ADMIN 路由。
- [S1] mall-admin：api/system.ts + stores/system.ts + views/system/FeatureConfigsView.vue、SystemParametersView.vue、ConfigHistoryView.vue；接入动态路由/菜单与按钮权限。

### 2.2 不包含

- Redis 缓存与内部配置端点/统一客户端（STORY-006-02-01-01）。
- public-features 公开端点与开关消费接线（STORY-006-02-01-02）；通用操作日志。

## 3. 业务规则

- [唯一性] configKey 两表各自唯一（uk）；键只允许小写字母/数字/点/短横（design 定正则）；创建后不可改 key。
- [内置保护] builtIn=true：禁删除、禁改 key/type/分组；enabled/value 可修改；非内置可整键删除（删除也留一条历史标记 DELETED，design 可简化为仅禁止删除全部——按 design：M5 允许删非内置，历史记录旧值→null）。
- [校验] BOOLEAN 仅 true/false；JSON 需可解析；INTEGER/LONG 整数；DECIMAL 合法小数；数值超 [minValue,maxValue] 拒绝；空值拒绝（参数必有值或默认值）。
- [审计] 启停/改值均写历史；changedBy 取当前管理员用户名；traceId 取链路上下文。
- [分页] 管理列表支持 group/keyword 过滤与分页，沿用既有 admin 分页响应形状。

## 4. 接口与字段规格

- GET /api/admin/feature-configs?group=&keyword=&page=&size；POST（新建非内置）；PUT /{key}（enabled/version，可选 changeReason）；DELETE /{key}（非内置）。
- GET /api/admin/system-parameters（同上过滤）；POST；PUT /{key}（configValue/version/changeReason）；DELETE /{key}。
- GET /api/admin/config-history?configType=&configKey=&page=&size → 分页历史。
- 错误：400 类型/范围非法；409 CONFIG_VERSION_CONFLICT；403 权限；404 键不存在。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | V1 迁移成功，种子键存在且 builtIn=true、默认值/范围正确；重复启动迁移不重复播种 |
| AC-002 | 开关分页/分组查询、启停、新建、删除非内置流程可用；重复 key 创建被唯一约束拒绝并返回明确错误 |
| AC-003 | 参数类型校验四例（INTEGER 写 abc、JSON 写非法 JSON、超 min/max、BOOLEAN 写 yes）均 400 且值不变 |
| AC-004 | 用过期 version 更新 → 409 CONFIG_VERSION_CONFLICT；用最新 version 成功 |
| AC-005 | 删除/改 key 内置键被拒绝；删非内置成功且历史留痕 |
| AC-006 | 每次改值/启停产生一条历史，含旧值/新值/操作人/traceId/时间；历史按 key 过滤分页正确，无修改/删除历史的接口 |
| AC-007 | 仅具备对应 update 权限的管理员可写（403 反向验证）；菜单与按钮权限在 mall-admin 生效 |
| AC-008 | mall-admin 三页面 CRUD/启停/历史筛选可用，构建/类型检查/lint/单测通过 |
