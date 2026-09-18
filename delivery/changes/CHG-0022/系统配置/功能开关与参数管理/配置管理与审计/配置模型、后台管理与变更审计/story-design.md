---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-006-01-01-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §2.0/§2.1/§2.2/§4
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0022
- Story ID: STORY-006-01-01-01
- 状态流转: specified → designed
- 相关仓库: repo-1（mall-system/mall-identity/mall-gateway）、repo-2（mall-admin）
- 需要 Migration: yes
- 数据变更概要: mall_system 库 Flyway V1（feature_config/system_parameter/system_config_history 三表 + 4 键种子 DML）；mall-identity V10（五权限码+三菜单）

## 1. 模块改动（Module Changes）

### repo-1 mall-system（DU-BE-507）

- com.ai.mall.system 按既有分层：domain.config（FeatureConfig/SystemParameter/ConfigHistory 实体+枚举 ParameterType/EffectType+端口）、application.config（*ApplicationService）、infrastructure.persistence（Mapper/PO 转换）、interfaces.rest.admin。
- V1__init_system_config.sql：
  - feature_config：id PK、config_key varchar(100) UK、feature_name varchar(100)、config_group varchar(50)、enabled tinyint(1)、public_flag tinyint(1)、built_in tinyint(1)、version int default 0、description varchar(500)、created_at/updated_at；
  - system_parameter：id PK、config_key varchar(100) UK、parameter_name varchar(100)、config_group varchar(50)、parameter_type varchar(20)、config_value varchar(1000)、default_value varchar(1000)、min_value varchar(64)、max_value varchar(64)、effect_type varchar(20)、built_in/version/description/时间戳；
  - system_config_history：id PK、config_type varchar(16)（FEATURE/PARAMETER）、config_key、old_value/text、new_value/text、change_reason varchar(500)、operator varchar(64)、created_at、索引 idx_type_key(config_type,config_key,id)；
  - 种子 DML 4 键（search.enabled=true/public；mall.guest-cart.enabled=true/public；search.default-page-size=20 INTEGER min1 max100；cart.max-item-quantity=99 INTEGER min1 max999）。
- 应用服务规则：
  - CAS 更新：update ... where id=? and version=?；影响行 0 → B0604 VERSION_CONFLICT(409)，成功 version+1 并写 history；
  - built_in=true：禁止删除、禁止改 config_key（其他可改）；删除非内置 → B0603? 冻结：B0602 CONFIG_KEY_DUPLICATE(409 UK 冲突)、B0603 CONFIG_NOT_FOUND(404)、B0604 VERSION_CONFLICT；
  - 参数保存按 parameter_type 校验类型与 min/max（INTEGER/LONG/DECIMAL/BOOLEAN/JSON）；非法 → B0601 PARAMETER_VALUE_INVALID(400)。
- Admin 接口（/api/admin/feature-configs、/api/admin/system-parameters CRUD + /api/admin/config-history 分页查询，支持 configType/configKey 过滤）。
- mall-gateway：三组 Path → lb://mall-system，走 ADMIN 鉴权。
- mall-identity V10__system_config_permissions.sql：权限码 system:feature:list/update、system:parameter:list/update、system:config-history:list + 3 菜单项，授予超管角色。

### repo-2 mall-admin（DU-FE-503）

- views/config/FeatureConfigsView.vue（列表/分组/开关切换/编辑弹窗含 key 禁改内置规则提示/版本号乐观锁冲突提示）；
- views/config/SystemParametersView.vue（按类型渲染表单：boolean switch/number 范围/string/json 校验）；
- views/config/ConfigHistoryView.vue（类型+key 筛选、变更前后对比、操作人/原因/时间）；
- api/config.ts 与路由/菜单按既有范式。

## 2. 接口契约细化

| 方法 | 路径 | 权限码 |
| --- | --- | --- |
| GET/POST/PUT/DELETE | /api/admin/feature-configs[...] | system:feature:list / update |
| GET/POST/PUT/DELETE | /api/admin/system-parameters[...] | system:parameter:list / update |
| GET | /api/admin/config-history | system:config-history:list |

更新请求体带 version；响应 UnifyResult 包裹；409 body code=B0604；history 不可写不可删。

## 3. 数据变更

见 §1 三表 DDL + 种子 + V10。

## 4. 错误处理

B0601 参数值非法(400) / B0602 key 冲突(409) / B0603 不存在(404) / B0604 版本冲突(409)；删除内置 → B0601? 冻结为 B0601 message"内置配置不可删除"。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-507 | repo-1 | mall-system 配置垂直（三表/服务/三端点）+V1+V10+网关 | AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007 | — |
| DU-FE-503 | repo-2 | mall-admin 三管理页 | AC-008 | DU-BE-507 |

## 6. 测试策略

- Mapper/迁移测试：V1 三表与 4 键种子；
- 服务单测：CAS 成功/冲突、内置禁删/禁改 key、类型与 min/max 校验、history 留痕；
- MockMvc：权限码 403、各错误码；
- 前端 Vitest：表单校验、409 提示、history 对比渲染。
