---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-003-01-03-01"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §5 分派行
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0016
- Story ID: STORY-003-01-03-01
- Change Design 引用: `requirement-design.md#5-story-设计分派story-design-assignments`
- 状态流转: pending → designed
- 需要 Migration: yes（mall_member V2 收货地址表）
- 数据变更概要: 新建 shipping_address（生成列实现每会员默认唯一）

## 1. 模块改动（Module Changes）

### repo-1 mall-member

- `domain.member.ShippingAddress` 实体（id/memberId/receiverName/receiverPhone/province/city/district/detailAddress/postalCode/isDefault）+ 工厂/修改方法承载校验。
- `domain.member.AddressRepository`：findByMember/listOrdered/getById/insert/update/delete/clearDefault/countByMember。
- `application.member.AddressApplicationService`：list/add/update/delete/setDefault/getDefault；memberId 全部来自 SecurityContextFacade；先 count 上限 20；首条自动默认；setDefault 单事务清旧设新；update/delete 先加载并校验归属，不匹配抛 NOT_FOUND。
- `infrastructure.persistence.address.{AddressPo,AddressMapper,AddressRepositoryImpl}`；列表排序 `is_default DESC, updated_at DESC`。
- `interfaces.rest.mall.ShippingAddressController`（/api/mall/shipping-addresses）+ DTO（@StringId id/memberId 不出参给前端）；类级 ROLE_MEMBER。

### repo-2 mall-web

- `src/api/address.ts`；views `member/AddressListView.vue`（列表/新增/编辑/删除/设默认，弹窗表单与字段级错误）；个人中心入口。

## 2. 接口契约细化

| 方法 | 路径 | 请求 | 响应/错误 |
| --- | --- | --- | --- |
| GET | /api/mall/shipping-addresses | — | {items:AddressView[], defaultId:string\|null} |
| POST | /api/mall/shipping-addresses | {receiverName,receiverPhone,province,city,district,detailAddress,postalCode?} | 201 AddressView；400；409 ADDRESS_LIMIT（20） |
| PUT | /api/mall/shipping-addresses/{id} | 同上学段 | AddressView；404（不存在/越权同一文案） |
| DELETE | /api/mall/shipping-addresses/{id} | — | 204；404 |
| PUT | /api/mall/shipping-addresses/{id}/default | — | AddressView；404；409 并发冲突 |
| GET | /api/mall/shipping-addresses/default | — | AddressView 或 200 {item:null} |
- AddressView: {id,receiverName,receiverPhone,province,city,district,detailAddress,postalCode,isDefault}（无 memberId）。

## 3. 数据变更

```sql
-- mall_member V2
CREATE TABLE shipping_address (
  id BIGINT PRIMARY KEY AUTO_INCREMENT,
  member_id BIGINT NOT NULL,
  receiver_name VARCHAR(32) NOT NULL,
  receiver_phone VARCHAR(20) NOT NULL,
  province VARCHAR(64) NOT NULL,
  city VARCHAR(64) NOT NULL,
  district VARCHAR(64) NOT NULL,
  detail_address VARCHAR(128) NOT NULL,
  postal_code CHAR(6) NULL,
  is_default TINY(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  default_member_flag BIGINT GENERATED ALWAYS AS (IF(is_default = 1, member_id, NULL)) STORED,
  INDEX idx_address_member (member_id, is_default, updated_at),
  CONSTRAINT uk_address_default UNIQUE (default_member_flag)
);
```

## 4. 错误处理

- 归属不匹配：ADDRESS_NOT_FOUND(404)，不区分"不存在/他人"。
- 并发设默认唯一键冲突：捕获 DuplicateKeyException → ADDRESS_DEFAULT_CONFLICT(409)。
- 删除默认：删除后不自动选新默认（spec 口径）；前端列表据此展示"无默认地址"。
- 校验：手机号 `^1[3-9]\d{9}$`；postalCode `^\d{6}$`；必填与长度按 spec。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-604 | repo-1 | 地址表 V2 + 领域/应用/接口全量（CRUD/默认/上限/归属） | AC-019,020,021,022,023,024 | — |
| DU-FE-603 | repo-2 | 地址管理页 | AC-019,020,021,022,023,024 | DU-BE-604 |

> 跨 Story 依赖：会员会话与网关隔离由 STORY-003-01-01-02 的 DU-BE-602 落地，mall-web 登录态由同 Story 的 DU-FE-601 落地（requirement-design §6：DU-BE-604 depends on DU-BE-602；DU-FE-603 depends on DU-FE-601,DU-BE-604）。

## 6. 测试策略

- 后端：地址校验参数化测试；首条自动默认；设默认旧值复位（SQL 断言全表仅一条）；删除默认后 getDefault 为空；上限第 21 条 409；跨会员越权 A→B 地址全方法 404；并发设默认（两线程）唯一约束 409。
- 前端：表单校验/列表排序展示/设默认刷新；vue-tsc/eslint/build。
