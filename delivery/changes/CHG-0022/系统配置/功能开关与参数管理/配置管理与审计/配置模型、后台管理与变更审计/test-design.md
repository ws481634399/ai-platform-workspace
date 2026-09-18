# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0022
- Story ID: STORY-006-01-01-01
- Feature Path: 系统配置 > 功能开关与参数管理 > 配置管理与审计 > 配置模型、后台管理与变更审计
- 状态流转: designed → tasked
- TC 总数: 10

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | 迁移（testcontainers MySQL mall_system）：V1 三表创建、4 种子键存在且 built_in=1/默认值与范围正确；重复迁移幂等不重复播种 | AC-001 | DU-BE-507 | [S1] |
| TC-002 | API：开关分页/分组列表、启停切换、新建、删除非内置全流程 200；重复 configKey 创建 → 409 B0602 | AC-002 | DU-BE-507 | [S1] |
| TC-003 | API：INTEGER 写 "abc"、JSON 写非法串、越 min/max、BOOLEAN 写 "yes" → 均 400 B0601 且库值不变 | AC-003 | DU-BE-507 | [S1] |
| TC-004 | API：用旧 version 更新 → 409 B0604；用最新 version → 200 且 version+1 | AC-004 | DU-BE-507 | [S1] |
| TC-005 | API：DELETE 内置键 → 400 拒绝；PUT 改内置 key → 拒绝；改值允许；删非内置成功且写 history | AC-005 | DU-BE-507 | [S1] |
| TC-006 | API：改值/启停各产生一条 history（old/new/operator/traceId/created_at）；GET config-history 按 type+key 过滤分页；无修改/删除历史端点（404/405） | AC-006 | DU-BE-507 | [S1] |
| TC-007 | 安全：缺 system:feature:update 的 JWT 写 → 403，读 200；config-history 需 config-history:list；identity V10 菜单/权限种子迁移断言 | AC-007 | DU-BE-507 | [S1] |
| TC-008 | API：不存在 id 更新/删除 → 404 B0603 | AC-002, AC-005 | DU-BE-507 | [S1] |
| TC-009 | 前端 Vitest：三页面渲染/开关切换/类型表单（number/json/bool）校验/范围提示/历史筛选/409 冲突提示 | AC-008 | DU-FE-503 | [S1] |
| TC-010 | 构建门禁：mall-admin type-check/lint/test/build 全绿 | AC-008 | DU-FE-503 | [S1] |

## 2. 测试策略

- Flyway 迁移测试 + Service/Mapper 单测覆盖 CAS 与校验；MockMvc 覆盖安全与错误码。
- history 的 operator/traceId 用安全上下文 mock + MDC 注入断言。
- 前端三页共用 api/config.ts，测试聚焦表单校验矩阵与乐观锁冲突提示。

## 3. 不可测项标注

- 无。

## 4. 依赖与前置条件

- mall_system MySQL 库已预建；identity 迁移基线 V9（V10 本 Change 分配）。
