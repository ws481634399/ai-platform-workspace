---
story-id: "STORY-002-01-02-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S5, S6, S7, S9]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 对应行 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0010
- Story ID: STORY-002-01-02-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

在 mall-product 建立 Brand 聚合，提供品牌创建/修改、分页与名称关键字查询、启用/禁用能力，并在 mall-admin 提供品牌维护页面，使商品可归属名称唯一、启停可控的品牌；停用品牌不再被新商品引用，为商品 SPU 建模提供可信品牌主数据。

## 2. Scope（范围）

### 2.1 包含

- 品牌创建/修改（S5）：名称（全局唯一）、Logo 地址、描述、排序。
- 品牌查询（S6）：后台分页列表、名称关键字模糊筛选、按 sort 稳定排序；供商品表单选择的启用品牌列表。
- 品牌启用/禁用（S7）：状态切换与准入后果。
- mall-admin 品牌管理页面（S9）：列表、搜索、新增、编辑、启停，权限按钮控制。

### 2.2 不包含

- 分类维护（STORY-002-01-01-01）。
- Logo 文件上传/对象存储系统：仅保存 URL/Object Key 字符串。
- 品牌物理删除（需求级统一排除，仅禁用）。
- 品牌分组、品牌授权资质、多语言品牌名。
- 商品/SPU 实体维护（REQ-M2-002）；本 Story 只提供品牌查询与状态供其引用校验。

## 3. 业务规则

- 名称唯一：brand.name 全局唯一；比较前对输入做 trim，落库不区分大小写重复（同名不同大小写视为重复，具体大小写敏感策略 Design 结合数据库排序规则确定，但业务行为是"同名即拒"）；并发创建同名依靠数据库唯一约束兜底。
- 禁用语义：禁用品牌不出现在商品创建/编辑的可选品牌列表；不影响存量商品数据、不强制下架。
- 排序：列表默认 sort 升序、id 升序稳定返回。
- Logo：可为空；非空时为字符串地址，长度受限；本服务不校验/不承载文件内容。
- 描述：可空，长度受限（Design 定具体长度）。
- 权限：list/create/update/disable 分别对应 product:brand:list/create/update/disable；未授权写操作返回 403。

## 4. 接口与字段规格

字段（Brand）：

| 字段 | 类型 | 约束 |
| --- | --- | --- |
| id | long | 主键，系统生成 |
| name | string | 必填，1~64 字符，trim，全局唯一 |
| logo | string/null | Logo 地址（URL/Object Key），可空 |
| description | string/null | 品牌描述，可空，限长 |
| sort | int | 排序值，默认 0 |
| status | enum | ENABLED / DISABLED，默认 ENABLED |
| createdAt / updatedAt | datetime | 系统维护 |

接口（REST，经网关 /api 前缀，统一 UnifyResult；路径 Design 定稿）：

- `GET /admin/brands`：分页查询，参数 page/size、keyword（名称模糊）、status（可选），需 list 权限。
- `GET /admin/brands/{id}`：品牌详情。
- `POST /admin/brands`：创建，需 create 权限。
- `PUT /admin/brands/{id}`：修改 name/logo/description/sort，需 update 权限；改名重复 → 业务错误。
- `PUT /admin/brands/{id}/status`：启用/禁用，需 disable 权限。

异常响应：名称重复、字段超长、无权限返回明确业务错误码与中文提示。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
| --- | --- | --- |
| AC-001 | 给定合法品牌信息，有权限管理员创建 → 成功，列表可查到该品牌且状态为启用。 | |
| AC-002 | 再次创建同名品牌（含首尾空格、大小写差异）→ 被拒绝并提示名称已存在，库中仍只有一条。 | 全局唯一 |
| AC-003 | 把已有品牌改名为另一已存在品牌名 → 被拒绝，原名称不变；改为新名称 → 成功。 | 改名唯一 |
| AC-004 | 修改品牌描述、Logo 地址、sort 后查询，返回最新值；Logo 以字符串地址保存。 | |
| AC-005 | 以名称关键字分页查询 → 仅返回名称匹配记录，分页 total/page/size 正确，默认按 sort、id 稳定排序。 | 查询 |
| AC-006 | 禁用品牌后，商品可选品牌列表不含该品牌；启用后恢复；存量商品引用数据不被改动。 | 禁用准入 |
| AC-007 | 无 product:brand:* 对应权限的身份直调写接口 → 403 且数据不变；有权限 → 成功。 | RBAC |
| AC-008 | mall-admin 品牌页可完成分页浏览、关键字搜索、新增、编辑、启停全流程，列表与接口数据一致并有操作反馈。 | 端到端 |
| AC-009 | 并发提交两个同名创建请求 → 恰有一个成功，另一个收到唯一约束业务错误，不产生重名数据。 | 并发防护 |
