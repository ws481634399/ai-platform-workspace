---
affected-repositories: [repo-1]
story-id: "STORY-004-01-01-01"
change-design-ref: "requirement-design.md#2-提议方案"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §2
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0019
- Story ID: STORY-004-01-01-01
- Change Design 引用: `requirement-design.md#2-提议方案`
- 状态流转: specified → designed
- 需要 Migration: no（本 Story 不建业务表；Flyway 目录预留；mall_order schema 启动前由本地环境确认）
- 数据变更概要: 新增 Redis key 空间 `order:submit-token:*`（仅签发，下 Story 消费）

## 1. 模块改动（Module Changes）

### 1.1 mall-order 从空骨架建成可运行服务（repo-1）

- pom：新增 mall-common-security、spring-boot-starter-oauth2-resource-server、mall-common-redis（testcontainers 依赖同 cart）；surefire 注入 TESTCONTAINERS_RYUK_DISABLED。
- application.yml：port 8105；spring.datasource（mall_order，环境变量 MYSQL_* 同其他服务）；flyway enabled；data.redis；mall.security.jwt.*；mall.security.internal.shared-secret；`mall.order.{product,inventory,member,cart}-uri` 默认 8103/8106/8102/8104。
- `infrastructure.config.OrderSecurityConfiguration`：照抄 CartSecurityConfiguration——`/api/internal/** hasRole SERVICE`、`/api/mall/** hasRole MEMBER`、`/api/admin/** hasRole ADMIN`、actuator health 放行、@Profile("!test")；测试 ApiTestSecurityConfig 仿 cart support（进程内 RSA JWT + internal filter）。
- `domain.order`：OrderStatus/OrderOperation 枚举、Money（整数分 record：goods/discount/freight/pay，不变量 pay=goods-discount+freight）、OrderErrorCode（B04xx：DEPENDENCY_UNAVAILABLE 503、ITEMS_EMPTY/INVALID 400、PRODUCT_NOT_SALABLE/SKU_INVALID/STOCK_INSUFFICIENT/ADDRESS_INVALID/SUBMIT_TOKEN_INVALID/STATUS_NOT_ALLOWED/ORDER_NOT_FOUND 先定义，后续 Story 使用）。
- `application.order.port`：ProductSkuPort（record SkuSnapshot 与 cart 同字段）、InventoryPort（availability + lock/release/confirm 方法签名一次定义齐，本 Story 仅实现与使用 availability）、MemberAddressPort（findAddress(memberId,addressId)）、CartSelectionPort（selectedItems(memberId)）、SubmitTokenStore（issue/consume）。
- `infrastructure.client`：RestProductSkuAdapter/RestInventoryAdapter/RestMemberAddressAdapter/RestCartSelectionAdapter——每个独立 RestClient 或共用 builder，默认头 X-Internal-Token，UnifyResult 解包，故障/信封非法/解析失败统一抛 BusinessException(DEPENDENCY_UNAVAILABLE,503)；@StringId 字段 Object 接 + parseLong 兼容。
- `infrastructure.redis.RedisSubmitTokenStore`：StringRedisTemplate；issue(memberId, payloadJson) → UUID，`SET order:submit-token:{memberId}:{token} <json> EX 600`；consume 用 DefaultRedisScript Lua GETDEL（下 Story 调用，本 Story 单测验证）。
- `application.order.CheckoutPreviewService`：resolveItems(source, bodyItems) → 校验入参 → product batch → inventory availability → address（可选）→ 组装 PreviewItem（单价/小计/状态/issueCodes）→ 金额合计 → 可下单判断 → 可下单时 tokenStore.issue；memberId 来自 SecurityContextFacade.currentSubject()。
- `interfaces.rest.mall.MemberOrderController` + dto/OrderDtos：POST /preview；@Valid request record；View record 经 assembler 输出（ID 字符串）。

### 1.2 mall-member 新增内部地址端点（repo-1）

- `interfaces.rest.internal.InternalMemberAddressController`：`GET /api/internal/members/{memberId}/addresses/{addressId}`；直接注入 AddressRepository（或 AddressApplicationService 新增 internalFind），findByIdForMember 命中→AddressInternalView（id 字符串、receiverName/phone/province/city/district/detailAddress/postalCode/isDefault）；空→BusinessException(AddressErrorCode.NOT_FOUND,404)（与会员侧既有错误码一致）。
- MemberSecurityConfiguration 已覆盖 /api/internal/** SERVICE，无需安全改动。

## 2. 接口契约细化

| 方法 | 路径 | 请求 | 响应/错误 |
| --- | --- | --- | --- |
| POST | /api/mall/orders/preview | {source, addressId?, items?} | 200 PreviewView；400 source 非法/items 非法/空；401；503 |
| GET | /api/internal/members/{m}/addresses/{a} | SERVICE | 200 AddressInternalView；404 不存在或不归属 |

- PreviewView 所有 Long 金额字段序列化为 number（分）；ID 字段字符串；时间字段本接口无。
- issueCodes 枚举：NOT_FOUND / PRODUCT_OFF_SHELF / SKU_INVALID / OUT_OF_STOCK / ADDRESS_INVALID；stockStatus：OK/LOW/OUT_OF_STOCK/UNKNOWN。

## 3. 数据变更

- 无 MySQL DDL。Redis 新 namespace：`order:submit-token:{memberId}:{uuid}` value=JSON `{source,addressId,fingerprint,issuedAt}` EX 600。
- 行指纹 fingerprint：items 按 skuId 排序后 `(skuId:quantity)` join ';' 的 SHA-256（或直接存规范化 JSON，下 Story 等值比对即可——默认存规范化 JSON 串）。

## 4. 错误处理

- 入参：source 缺失/非法、BUY_NOW items 空或超 100、quantity 越界 → 400 ORDER_ITEMS_INVALID；CART 选中项为空 → 200（items=[], availableToSubmit=false），不报错。
- product 返回 salable=false：不抛异常，行级 issueCodes；client 传输故障 → 503。
- inventory availability 行级缺失补 0；传输故障 → 503（不做行级 UNKNOWN 可下单）。
- 地址不存在/非归属：行级 ADDRESS_INVALID（预览 200）；member client 传输故障 → 503。
- token 签发失败（Redis 异常）：503 ORDER_DEPENDENCY_UNAVAILABLE。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-901 | repo-1 | order 骨架/安全/配置/通用枚举/Money/四端口 Rest 客户端/submitToken 存储/preview/member 地址端点 | AC-001~010 | — |

## 6. 测试策略

- 领域单测：Money 不变量（pay=goods-discount+freight、负值拒绝）、PreviewAssembler 行状态/金额/availableToSubmit 矩阵（全 OK/缺货/下架/地址无效/空车）。
- API 集成测试（H2 + MockRestServiceServer 或 Mockito 端口）：两源预览、入参 400、篡改 items 忽略、503 归一、401/403 安全；submitToken 签发载荷与 TTL。
- Redis：SubmitTokenStore issue/consume GETDEL 幂等（Testcontainers，仿 AbstractRedisIntegrationTest）。
- mall-member：InternalMemberAddressController 测试（命中/不命中 404/无 token 401/归属隔离）。
