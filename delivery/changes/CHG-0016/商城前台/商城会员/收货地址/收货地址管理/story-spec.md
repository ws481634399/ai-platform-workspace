---
story-id: "STORY-003-01-03-01"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S4]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.3 + exploration.md
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0016
- Story ID: STORY-003-01-03-01
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

提供收货地址全量管理：列表、新增、修改、删除、设置默认、查询默认；后端以 SecurityContext memberId 强制资源归属，默认地址全会员唯一，数量上限 20；mall-web 提供地址管理与选择页（为 M4 结算预留）。

## 2. Scope（范围）

### 2.1 包含

- [S4] 地址 CRUD、set-default、默认查询；字段校验；归属校验；默认唯一事务；删除默认策略；20 条上限；mall-web 地址列表/编辑/默认设置 UI。

### 2.2 不包含

- 订单地址快照（M4）；地址级联到订单历史（删改地址不影响历史订单）；省市区数据源服务（前端内置标准数据包）。

## 3. 业务规则

- 所有查询/写操作以当前 memberId 为过滤条件；访问他人 addressId 一律 404。
- 第一条地址自动默认；set-default 单事务复位旧默认；并发设置靠事务/唯一约束保证只有一个默认。
- 删除默认后无默认；默认查询无记录返回空对象/200。
- receiverName 1–32；phone 大陆手机号；省市区+detailAddress（1–128）必填；postalCode 可选 6 位数字；上限 20 条。

## 4. 接口与字段规格

- GET /api/mall/shipping-addresses（列表，默认优先）
- POST /api/mall/shipping-addresses
- PUT /api/mall/shipping-addresses/{id}
- DELETE /api/mall/shipping-addresses/{id}
- POST /api/mall/shipping-addresses/{id}/set-default
- GET /api/mall/shipping-addresses/default（无则 200 空）
- 字段：id(string)、receiverName、receiverPhone、province、city、district、detailAddress、postalCode?、isDefault、createdAt、updatedAt。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-019 | 合法新增地址成功；第一条自动 isDefault=true |
| AC-020 | 列表仅含本人地址，默认优先、再按更新时间排序 |
| AC-021 | 改/删自己地址成功；操作他人 addressId → 404 且数据不变 |
| AC-022 | 设置新默认后旧默认复位，仅一个默认；并发设置仍唯一 |
| AC-023 | 删除默认后无默认；默认查询返回空不报错 |
| AC-024 | 非法字段 400 提示；满 20 条再新增被拒绝 |
| AC-025 | mall-web 地址管理页流程可用，build/lint/type-check 通过（地址部分） |
