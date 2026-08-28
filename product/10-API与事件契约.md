---
title: API 与事件契约
tags: [api, contract, rocketmq, events, rest]
related-changes: []
created-at: 2026-08-28T00:00:00Z
updated-at: 2026-08-28T00:00:00Z
---

# AI 智能电商微服务平台——API 与事件契约

## 1. 文档信息

- **项目名称**：AI 智能电商微服务平台
- **英文名称**：AI-Powered E-Commerce Platform
- **项目代号**：AI Mall
- **仓库名称**：`ai-mall-platform`
- **文档名称**：API 与事件契约
- **文档路径**：`docs/10-API与事件契约.md`
- **当前版本**：V0.1
- **文档状态**：初稿
- **关联文档**：
  - `docs/00-项目总览.md`
  - `docs/01-产品需求文档.md`
  - `docs/02-统一语言词汇表.md`
  - `docs/03-领域事件风暴.md`
  - `docs/04-子域与限界上下文.md`
  - `docs/05-上下文映射图.md`
  - `docs/06-聚合与领域模型设计.md`
  - `docs/07-核心业务流程.md`
  - `docs/08-系统与微服务架构.md`
  - `docs/09-数据库设计.md`

### 1.1 版本记录

| 版本 | 日期 | 说明 |
|---|---|---|
| V0.1 | 初始版本 | 明确 REST API、内部服务接口、AI 接口、统一响应、错误码、幂等协议和 RocketMQ 事件契约 |

---

## 2. 文档目的

本文档用于统一 AI 智能电商微服务平台中各应用、微服务和异步消费者之间的通信协议，明确：

1. REST API 路径、HTTP 方法和资源命名；
2. 商城端、后台端、认证端、内部服务和 AI 接口边界；
3. 请求头、响应头和身份传递方式；
4. 统一成功响应、异常响应和分页结构；
5. 业务错误码及 HTTP 状态码映射；
6. 创建订单、支付、库存锁定等写操作的幂等协议；
7. OpenFeign 内部调用契约；
8. AI 普通响应和 SSE 流式响应规范；
9. RocketMQ Topic、Tag、消费者组和事件结构；
10. 商品、订单、库存、配置和 AI 集成事件；
11. API 和事件版本兼容策略；
12. 契约测试、OpenAPI 文档和联调验收要求。

本文件定义的是跨边界通信契约，不用于共享领域实体、数据库持久化对象或聚合根。

---

# 3. 契约设计原则

## 3.1 契约优先

服务开发前应先明确：

```text
请求
响应
错误码
身份
幂等
超时
事件
版本
```

接口和事件契约确定后，各服务可独立开发和测试。

---

## 3.2 领域模型不跨服务共享

允许共享：

- 内部 API 请求 DTO；
- 内部 API 响应 DTO；
- 集成事件；
- 事件公共元数据；
- 统一分页协议；
- 统一错误结构。

禁止共享：

- `Product`；
- `Order`；
- `Inventory`；
- `Member`；
- `Role`；
- `Menu`；
- Repository；
- MyBatis PO；
- 领域服务。

---

## 3.3 API 以资源为中心

推荐：

```text
GET    /api/mall/orders
POST   /api/mall/orders
GET    /api/mall/orders/{orderId}
POST   /api/mall/orders/{orderId}/cancel
```

不推荐：

```text
POST /doCreateOrder
POST /updateOrderStatus
GET  /getOrderList
POST /executeCancel
```

---

## 3.4 API 与事件职责分离

API 适合：

- 立即获取结果；
- 查询；
- 用户正在等待的业务写操作；
- 需要明确成功或失败的同步操作。

事件适合：

- 搜索索引同步；
- 支付后库存确认扣减；
- 取消后库存释放；
- 操作日志；
- 配置缓存失效；
- AI 文档解析；
- 统计和通知。

---

## 3.5 所有跨服务写操作必须幂等

重点场景：

- 创建订单；
- 锁定库存；
- 释放库存；
- 确认扣减库存；
- 模拟支付；
- 取消订单；
- 发货；
- 退款审核；
- 商品索引更新；
- 配置事件消费；
- AI 写工具调用。

---

# 4. API 分类与路径前缀

## 4.1 认证接口

```text
/api/auth/**
```

用途：

- 商城注册和登录；
- 后台登录；
- 刷新令牌；
- 退出登录。

---

## 4.2 商城公开接口

```text
/api/mall/**
```

其中部分接口允许游客访问：

- 商品列表；
- 商品详情；
- 分类；
- 品牌；
- 商品搜索；
- 公开功能配置；
- AI 智能导购的公开能力。

---

## 4.3 商城会员接口

仍使用：

```text
/api/mall/**
```

但要求 `MEMBER` 身份，例如：

- 购物车；
- 收货地址；
- 订单；
- 退款；
- 个人资料；
- AI 订单助手。

---

## 4.4 后台管理接口

```text
/api/admin/**
```

要求：

- `ADMIN` 身份；
- 对应权限编码；
- 后端数据权限校验。

---

## 4.5 内部服务接口

```text
/api/internal/**
```

要求：

- 不对普通浏览器开放；
- 只允许服务间访问；
- 验证服务身份；
- 传递 TraceId；
- 必要时验证服务间 Token 或签名。

---

## 4.6 AI 接口

```text
/api/ai/**
```

用途：

- AI 智能导购；
- 商品对比；
- RAG 智能客服；
- AI 订单助手；
- 流式会话。

后台 AI 管理接口：

```text
/api/admin/ai/**
```

---

# 5. HTTP 方法规范

| 方法 | 用途 | 示例 |
|---|---|---|
| `GET` | 查询资源 | `GET /api/mall/products/{id}` |
| `POST` | 创建资源或执行明确业务动作 | `POST /api/mall/orders` |
| `PUT` | 完整更新资源或更新确定配置 | `PUT /api/admin/feature-configs/{key}` |
| `PATCH` | 局部更新资源 | 第一版谨慎使用 |
| `DELETE` | 删除或移除资源 | `DELETE /api/mall/cart/items/{skuId}` |

业务动作无法自然表达为 CRUD 时，使用动作路径：

```text
POST /api/admin/products/{id}/publish
POST /api/admin/products/{id}/unpublish
POST /api/mall/orders/{id}/cancel
POST /api/mall/orders/{id}/pay
POST /api/admin/orders/{id}/ship
POST /api/mall/orders/{id}/confirm-receipt
```

---

# 6. URL 命名规范

## 6.1 使用复数名词

推荐：

```text
/products
/orders
/roles
/menus
/shipping-addresses
/refund-requests
/feature-configs
/system-parameters
```

---

## 6.2 使用小写中划线

推荐：

```text
/shipping-addresses
/confirm-receipt
/refund-requests
/system-parameters
```

不推荐：

```text
/shippingAddresses
/confirm_receipt
/SystemParameters
```

---

## 6.3 查询条件使用 Query Parameter

示例：

```text
GET /api/admin/orders?status=PENDING_SHIPMENT&page=1&size=20
```

---

## 6.4 资源归属明确

推荐：

```text
GET /api/mall/orders/{orderId}
GET /api/mall/shipping-addresses/{addressId}
```

后端从安全上下文读取当前会员，不允许前端任意指定 `memberId` 访问他人数据。

---

# 7. API 版本策略

## 7.1 第一版路径

为保持当前项目文档一致，第一版采用：

```text
/api/**
```

不显式加入 `/v1`。

## 7.2 破坏性变更

后续出现不兼容变更时使用：

```text
/api/v2/**
```

## 7.3 兼容性规则

兼容变更：

- 新增可选响应字段；
- 新增可选请求字段；
- 新增枚举值前确认消费者可容错；
- 新增接口。

不兼容变更：

- 删除字段；
- 重命名字段；
- 修改字段类型；
- 改变字段业务含义；
- 修改必填规则；
- 修改错误码语义。

不兼容变更必须：

- 新建版本；
- 保留旧版过渡期；
- 更新 OpenAPI；
- 更新契约测试；
- 通知所有消费者。

---

# 8. 请求公共 Header

## 8.1 外部请求 Header

| Header | 必填 | 说明 |
|---|---|---|
| `Authorization` | 受保护接口必填 | `Bearer <access-token>` |
| `X-Trace-Id` | 可选 | 前端可传，Gateway 缺失时生成 |
| `X-Request-Id` | 建议 | 单次请求唯一标识 |
| `X-Client-Type` | 建议 | `MALL_WEB`、`MALL_ADMIN` |
| `Accept-Language` | 可选 | 第一版默认 `zh-CN` |
| `Idempotency-Key` | 部分写接口必填 | 防重复业务请求 |

---

## 8.2 内部服务 Header

| Header | 必填 | 说明 |
|---|---|---|
| `X-Trace-Id` | 是 | 全链路追踪 |
| `X-Request-Id` | 是 | 当前调用标识 |
| `X-Service-Name` | 是 | 调用方服务名称 |
| `X-Service-Token` | 是 | 第一版服务间认证 |
| `X-Subject-Id` | 按需 | 经 Java 验证的用户或管理员 ID |
| `X-Subject-Type` | 按需 | `MEMBER`、`ADMIN`、`SERVICE` |
| `X-Permission-Codes` | 谨慎使用 | 仅向 AI 传递必要最小权限 |

内部服务不得信任由浏览器直接传入的身份 Header。

---

# 9. 统一成功响应

## 9.1 标准结构

```json
{
  "success": true,
  "code": "SUCCESS",
  "message": "操作成功",
  "data": {},
  "traceId": "2f9f8d8d8d8d"
}
```

字段说明：

| 字段 | 类型 | 说明 |
|---|---|---|
| `success` | boolean | 是否成功 |
| `code` | string | 业务结果码 |
| `message` | string | 用户可理解的提示 |
| `data` | any | 实际业务数据 |
| `traceId` | string | 链路追踪标识 |

---

## 9.2 无数据成功响应

```json
{
  "success": true,
  "code": "SUCCESS",
  "message": "操作成功",
  "data": null,
  "traceId": "2f9f8d8d8d8d"
}
```

---

## 9.3 创建成功

HTTP 状态码可使用：

```text
201 Created
```

响应：

```json
{
  "success": true,
  "code": "SUCCESS",
  "message": "创建成功",
  "data": {
    "id": "10001"
  },
  "traceId": "2f9f8d8d8d8d"
}
```

---

# 10. 统一异常响应

## 10.1 标准结构

```json
{
  "success": false,
  "code": "ORDER_NOT_FOUND",
  "message": "订单不存在",
  "data": null,
  "details": null,
  "traceId": "2f9f8d8d8d8d"
}
```

## 10.2 参数校验异常

```json
{
  "success": false,
  "code": "COMMON_VALIDATION_FAILED",
  "message": "请求参数不合法",
  "data": null,
  "details": [
    {
      "field": "quantity",
      "message": "购买数量必须大于 0"
    }
  ],
  "traceId": "2f9f8d8d8d8d"
}
```

## 10.3 安全要求

异常响应不得返回：

- Java 堆栈；
- SQL；
- 数据库表名；
- 内部 IP；
- Token；
- 密码；
- 大模型 API Key；
- 服务间密钥。

详细异常写入服务日志，通过 `traceId` 查询。

---

# 11. HTTP 状态码规范

| HTTP 状态码 | 场景 |
|---|---|
| `200` | 查询成功、普通操作成功 |
| `201` | 创建成功 |
| `204` | 删除成功且无响应体，可选 |
| `400` | 参数错误、请求格式错误 |
| `401` | 未登录、Token 无效 |
| `403` | 已认证但无权限 |
| `404` | 资源不存在 |
| `409` | 状态冲突、重复提交、版本冲突 |
| `422` | 业务条件不满足，可选 |
| `429` | 请求过于频繁 |
| `500` | 未预期系统错误 |
| `502` | 上游服务调用失败 |
| `503` | 服务不可用或功能降级 |
| `504` | 上游服务超时 |

业务错误码是主要判断依据，HTTP 状态码用于表达请求级结果。

---

# 12. 分页协议

## 12.1 请求参数

```text
page=1
size=20
```

规则：

- `page` 从 1 开始；
- `size` 默认 20；
- `size` 最大 100；
- 超过最大值时返回参数错误或自动限制，项目统一建议返回参数错误。

---

## 12.2 分页响应

```json
{
  "success": true,
  "code": "SUCCESS",
  "message": "查询成功",
  "data": {
    "records": [],
    "total": 100,
    "page": 1,
    "size": 20,
    "pages": 5
  },
  "traceId": "2f9f8d8d8d8d"
}
```

---

## 12.3 排序参数

```text
sortBy=createdAt
sortDirection=DESC
```

服务端必须限制可排序字段，不能直接拼接用户输入到 SQL。

---

# 13. 时间、金额和 ID 规范

## 13.1 时间

统一使用 ISO 8601：

```text
2026-08-01T13:30:00+08:00
```

或统一 UTC：

```text
2026-08-01T05:30:00Z
```

项目必须在实现前固定一种策略。

---

## 13.2 金额

API 金额统一使用整数分：

```json
{
  "salePrice": 299900,
  "currency": "CNY"
}
```

前端展示：

```text
¥2999.00
```

禁止传输浮点金额作为成交依据。

---

## 13.3 ID

由于 JavaScript 对大整数存在精度限制，所有 `BIGINT` ID 在 JSON 中统一按字符串返回：

```json
{
  "orderId": "100000000000000001"
}
```

---

# 14. 错误码规范

## 14.1 命名结构

```text
领域_具体错误
```

例如：

```text
ORDER_NOT_FOUND
INVENTORY_INSUFFICIENT
AUTH_TOKEN_EXPIRED
```

---

## 14.2 通用错误码

| 错误码 | HTTP | 说明 |
|---|---:|---|
| `SUCCESS` | 200 | 操作成功 |
| `COMMON_BAD_REQUEST` | 400 | 请求错误 |
| `COMMON_VALIDATION_FAILED` | 400 | 参数校验失败 |
| `COMMON_NOT_FOUND` | 404 | 资源不存在 |
| `COMMON_CONFLICT` | 409 | 资源冲突 |
| `COMMON_TOO_MANY_REQUESTS` | 429 | 请求过于频繁 |
| `COMMON_INTERNAL_ERROR` | 500 | 系统内部错误 |
| `COMMON_UPSTREAM_ERROR` | 502 | 上游服务异常 |
| `COMMON_SERVICE_UNAVAILABLE` | 503 | 服务不可用 |
| `COMMON_UPSTREAM_TIMEOUT` | 504 | 上游服务超时 |

---

## 14.3 认证与权限错误码

| 错误码 | HTTP | 说明 |
|---|---:|---|
| `AUTH_UNAUTHORIZED` | 401 | 未登录 |
| `AUTH_INVALID_CREDENTIALS` | 401 | 账号或密码错误 |
| `AUTH_TOKEN_INVALID` | 401 | Token 无效 |
| `AUTH_TOKEN_EXPIRED` | 401 | Token 已过期 |
| `AUTH_REFRESH_TOKEN_INVALID` | 401 | Refresh Token 无效 |
| `AUTH_ACCOUNT_DISABLED` | 403 | 账号已禁用 |
| `AUTH_ACCOUNT_LOCKED` | 403 | 账号已锁定 |
| `AUTH_FORBIDDEN` | 403 | 无访问权限 |
| `AUTH_SERVICE_FORBIDDEN` | 403 | 非法内部服务调用 |

---

## 14.4 商品错误码

| 错误码 | HTTP | 说明 |
|---|---:|---|
| `PRODUCT_NOT_FOUND` | 404 | 商品不存在 |
| `PRODUCT_NOT_SALABLE` | 409 | 商品不可售 |
| `PRODUCT_NOT_PUBLISHED` | 409 | 商品未上架 |
| `PRODUCT_CANNOT_BE_PUBLISHED` | 409 | 商品不满足上架条件 |
| `PRODUCT_MAIN_IMAGE_MISSING` | 409 | 缺少商品主图 |
| `PRODUCT_SKU_MISSING` | 409 | 缺少有效 SKU |
| `SKU_NOT_FOUND` | 404 | SKU 不存在 |
| `SKU_DISABLED` | 409 | SKU 已禁用 |
| `SKU_CODE_DUPLICATED` | 409 | SKU 编码重复 |
| `SKU_SPECIFICATION_DUPLICATED` | 409 | SKU 规格组合重复 |
| `PRODUCT_PRICE_CHANGED` | 409 | 商品价格已变化 |

---

## 14.5 购物车错误码

| 错误码 | HTTP | 说明 |
|---|---:|---|
| `CART_NOT_FOUND` | 404 | 购物车不存在 |
| `CART_ITEM_NOT_FOUND` | 404 | 购物车项不存在 |
| `CART_ITEM_INVALID` | 409 | 购物车项已失效 |
| `CART_QUANTITY_INVALID` | 400 | 数量不合法 |
| `CART_QUANTITY_EXCEEDED` | 409 | 超过最大购买数量 |
| `CART_EMPTY` | 409 | 没有可结算商品 |

---

## 14.6 订单错误码

| 错误码 | HTTP | 说明 |
|---|---:|---|
| `ORDER_NOT_FOUND` | 404 | 订单不存在 |
| `ORDER_ACCESS_DENIED` | 403 | 无权访问该订单 |
| `ORDER_STATUS_INVALID` | 409 | 当前状态不允许执行该操作 |
| `ORDER_DUPLICATE_SUBMISSION` | 409 | 重复提交订单 |
| `ORDER_IDEMPOTENCY_KEY_REQUIRED` | 400 | 缺少幂等键 |
| `ORDER_PAYMENT_EXPIRED` | 409 | 订单已超过支付时间 |
| `ORDER_ALREADY_PAID` | 409 | 订单已支付 |
| `ORDER_ALREADY_CANCELLED` | 409 | 订单已取消 |
| `ORDER_AMOUNT_MISMATCH` | 409 | 订单金额不一致 |
| `ORDER_ADDRESS_INVALID` | 409 | 收货地址无效 |
| `ORDER_ITEMS_INVALID` | 409 | 订单商品无效 |

---

## 14.7 库存错误码

| 错误码 | HTTP | 说明 |
|---|---:|---|
| `INVENTORY_NOT_INITIALIZED` | 409 | 库存未初始化 |
| `INVENTORY_INSUFFICIENT` | 409 | 可用库存不足 |
| `INVENTORY_DISABLED` | 409 | 库存已禁用 |
| `INVENTORY_RESERVATION_DUPLICATED` | 409 | 重复锁定库存 |
| `INVENTORY_RESERVATION_NOT_FOUND` | 404 | 库存锁定记录不存在 |
| `INVENTORY_ALREADY_RELEASED` | 409 | 库存已释放 |
| `INVENTORY_ALREADY_DEDUCTED` | 409 | 库存已确认扣减 |
| `INVENTORY_VERSION_CONFLICT` | 409 | 库存并发冲突 |
| `INVENTORY_INVARIANT_VIOLATION` | 500 | 库存不变量异常 |

---

## 14.8 退款错误码

| 错误码 | HTTP | 说明 |
|---|---:|---|
| `REFUND_NOT_ALLOWED` | 409 | 当前订单不可退款 |
| `REFUND_DUPLICATED` | 409 | 已存在进行中的退款 |
| `REFUND_NOT_FOUND` | 404 | 退款申请不存在 |
| `REFUND_STATUS_INVALID` | 409 | 退款状态不允许操作 |
| `REFUND_AMOUNT_INVALID` | 409 | 退款金额不合法 |
| `REFUND_FEATURE_DISABLED` | 503 | 退款功能未启用 |

---

## 14.9 配置错误码

| 错误码 | HTTP | 说明 |
|---|---:|---|
| `FEATURE_NOT_FOUND` | 404 | 功能配置不存在 |
| `FEATURE_DISABLED` | 503 | 功能当前不可用 |
| `CONFIG_NOT_FOUND` | 404 | 系统参数不存在 |
| `CONFIG_VALUE_INVALID` | 400 | 参数值不合法 |
| `CONFIG_BUILT_IN_DELETE_FORBIDDEN` | 403 | 内置配置不能删除 |

---

## 14.10 AI 错误码

| 错误码 | HTTP | 说明 |
|---|---:|---|
| `AI_FEATURE_DISABLED` | 503 | AI 功能未启用 |
| `AI_SERVICE_UNAVAILABLE` | 503 | AI 服务暂不可用 |
| `AI_REQUEST_INVALID` | 400 | AI 请求不合法 |
| `AI_CONVERSATION_NOT_FOUND` | 404 | 会话不存在 |
| `AI_MAX_ROUNDS_EXCEEDED` | 409 | 超过最大对话轮数 |
| `AI_TOOL_CALL_FAILED` | 502 | AI 工具调用失败 |
| `AI_OUTPUT_INVALID` | 502 | AI 输出结构不合法 |
| `AI_NO_MATCHED_PRODUCT` | 200 | 未找到匹配商品 |
| `AI_KNOWLEDGE_NOT_FOUND` | 200 | 未检索到可靠知识 |
| `AI_WRITE_CONFIRMATION_REQUIRED` | 409 | AI 写操作需要二次确认 |

---

# 15. 幂等协议

## 15.1 Idempotency-Key

需要幂等保护的外部接口使用：

```text
Idempotency-Key: <unique-value>
```

建议格式：

```text
业务类型-客户端标识-随机值
```

示例：

```text
order-create-web-550e8400-e29b-41d4-a716-446655440000
```

---

## 15.2 创建订单幂等

接口：

```text
POST /api/mall/orders
```

Header：

```text
Idempotency-Key
```

规则：

- 同一会员、同一幂等键只能成功创建一次订单；
- 相同键且请求摘要一致，返回原订单；
- 相同键但请求摘要不同，返回冲突；
- 幂等记录有有效期；
- 前端防重复点击不是最终保障。

---

## 15.3 库存幂等

| 操作 | 幂等标识 |
|---|---|
| 锁定库存 | `businessNo + skuId` |
| 释放库存 | `reservationNo + skuId` |
| 确认扣减 | `reservationNo + skuId` |

---

## 15.4 支付幂等

使用：

```text
paymentNo
```

或：

```text
orderNo + paymentType
```

重复支付请求：

- 已成功则返回原成功结果；
- 处理中则返回处理中；
- 已失败可按规则重新发起。

---

## 15.5 AI 写工具幂等

AI 调用取消订单或申请退款时携带：

```text
toolCallId
```

Java 服务将其作为辅助幂等标识，但最终仍以：

- `orderNo`；
- `refundNo`；
- 订单状态。

完成业务校验。

---

# 16. 商城认证 API

## 16.1 会员注册

```text
POST /api/auth/member/register
```

请求：

```json
{
  "loginName": "user001",
  "password": "Example@123",
  "confirmPassword": "Example@123",
  "nickname": "新用户"
}
```

响应：

```json
{
  "success": true,
  "code": "SUCCESS",
  "message": "注册成功",
  "data": {
    "memberId": "10001"
  },
  "traceId": "trace-001"
}
```

---

## 16.2 会员登录

```text
POST /api/auth/member/login
```

请求：

```json
{
  "loginName": "user001",
  "password": "Example@123"
}
```

响应：

```json
{
  "success": true,
  "code": "SUCCESS",
  "message": "登录成功",
  "data": {
    "accessToken": "access-token",
    "refreshToken": "refresh-token",
    "tokenType": "Bearer",
    "expiresIn": 7200,
    "member": {
      "memberId": "10001",
      "nickname": "新用户",
      "avatarUrl": null
    }
  },
  "traceId": "trace-001"
}
```

---

## 16.3 管理员登录

```text
POST /api/auth/admin/login
```

请求：

```json
{
  "account": "admin",
  "password": "Example@123"
}
```

响应：

```json
{
  "success": true,
  "code": "SUCCESS",
  "message": "登录成功",
  "data": {
    "accessToken": "admin-access-token",
    "refreshToken": "admin-refresh-token",
    "tokenType": "Bearer",
    "expiresIn": 7200,
    "adminUser": {
      "adminUserId": "1",
      "displayName": "超级管理员",
      "superAdmin": true
    }
  },
  "traceId": "trace-001"
}
```

---

## 16.4 刷新令牌

```text
POST /api/auth/refresh
```

请求：

```json
{
  "refreshToken": "refresh-token"
}
```

---

## 16.5 退出登录

```text
POST /api/auth/logout
```

要求认证。

---

# 17. 商城商品 API

## 17.1 商品列表

```text
GET /api/mall/products
```

Query：

```text
categoryId
brandId
page
size
sortBy
sortDirection
```

响应记录：

```json
{
  "productId": "10001",
  "productName": "示例商品",
  "subtitle": "示例副标题",
  "mainImageUrl": "https://...",
  "minPrice": 299900,
  "maxPrice": 399900,
  "currency": "CNY",
  "available": true
}
```

---

## 17.2 商品详情

```text
GET /api/mall/products/{productId}
```

响应：

```json
{
  "productId": "10001",
  "productCode": "PRD000001",
  "productName": "示例商品",
  "subtitle": "示例副标题",
  "description": "商品描述",
  "category": {
    "categoryId": "20001",
    "categoryName": "笔记本电脑"
  },
  "brand": {
    "brandId": "30001",
    "brandName": "示例品牌"
  },
  "images": [],
  "attributes": [],
  "skus": [
    {
      "skuId": "11001",
      "skuCode": "SKU000001",
      "specifications": {
        "颜色": "黑色",
        "存储": "256GB"
      },
      "salePrice": 299900,
      "currency": "CNY",
      "availableQuantity": 20,
      "salable": true
    }
  ],
  "status": "PUBLISHED"
}
```

---

## 17.3 分类树

```text
GET /api/mall/categories/tree
```

---

## 17.4 品牌列表

```text
GET /api/mall/brands
```

---

# 18. 商城搜索 API

## 18.1 商品搜索

```text
GET /api/mall/search/products
```

Query：

```text
keyword
categoryId
brandId
minPrice
maxPrice
available
sortBy
sortDirection
page
size
```

支持排序：

```text
RELEVANCE
PRICE_ASC
PRICE_DESC
SALES_DESC
NEWEST
```

---

## 18.2 搜索建议

```text
GET /api/mall/search/suggestions?keyword=笔记
```

---

# 19. 商城购物车 API

## 19.1 查询购物车

```text
GET /api/mall/cart
```

响应：

```json
{
  "items": [
    {
      "productId": "10001",
      "skuId": "11001",
      "productName": "示例商品",
      "skuSpecification": "黑色 / 256GB",
      "imageUrl": "https://...",
      "unitPrice": 299900,
      "quantity": 2,
      "selected": true,
      "valid": true,
      "invalidReason": null,
      "availableQuantity": 20,
      "lineAmount": 599800
    }
  ],
  "selectedAmount": 599800,
  "selectedCount": 2
}
```

---

## 19.2 加入购物车

```text
POST /api/mall/cart/items
```

请求：

```json
{
  "productId": "10001",
  "skuId": "11001",
  "quantity": 2
}
```

---

## 19.3 修改数量

```text
PUT /api/mall/cart/items/{skuId}
```

请求：

```json
{
  "quantity": 3
}
```

---

## 19.4 删除购物车项

```text
DELETE /api/mall/cart/items/{skuId}
```

---

## 19.5 选择购物车项

```text
POST /api/mall/cart/items/{skuId}/select
```

---

## 19.6 取消选择

```text
POST /api/mall/cart/items/{skuId}/unselect
```

---

## 19.7 全选

```text
POST /api/mall/cart/select-all
```

---

## 19.8 取消全选

```text
POST /api/mall/cart/unselect-all
```

---

# 20. 商城会员与地址 API

## 20.1 当前会员资料

```text
GET /api/mall/members/me
```

---

## 20.2 修改当前会员资料

```text
PUT /api/mall/members/me
```

---

## 20.3 地址列表

```text
GET /api/mall/shipping-addresses
```

---

## 20.4 新增地址

```text
POST /api/mall/shipping-addresses
```

请求：

```json
{
  "receiverName": "张三",
  "receiverPhone": "13812345678",
  "provinceName": "江苏省",
  "cityName": "南京市",
  "districtName": "鼓楼区",
  "detailAddress": "示例路 1 号",
  "postalCode": "210000",
  "defaultFlag": true
}
```

---

## 20.5 修改地址

```text
PUT /api/mall/shipping-addresses/{addressId}
```

---

## 20.6 删除地址

```text
DELETE /api/mall/shipping-addresses/{addressId}
```

---

## 20.7 设置默认地址

```text
POST /api/mall/shipping-addresses/{addressId}/set-default
```

---

# 21. 商城订单 API

## 21.1 订单预览

```text
POST /api/mall/orders/preview
```

请求：

```json
{
  "source": "CART",
  "items": [
    {
      "productId": "10001",
      "skuId": "11001",
      "quantity": 2
    }
  ],
  "shippingAddressId": "20001"
}
```

响应：

```json
{
  "previewToken": "preview-token",
  "items": [
    {
      "productId": "10001",
      "skuId": "11001",
      "productName": "示例商品",
      "skuSpecification": "黑色 / 256GB",
      "unitPrice": 299900,
      "quantity": 2,
      "lineAmount": 599800,
      "available": true
    }
  ],
  "shippingAddress": {
    "addressId": "20001",
    "receiverName": "张三",
    "receiverPhone": "138****5678",
    "fullAddress": "江苏省南京市鼓楼区示例路 1 号"
  },
  "orderAmount": 599800,
  "currency": "CNY"
}
```

---

## 21.2 创建订单

```text
POST /api/mall/orders
```

Header：

```text
Idempotency-Key: order-create-...
```

请求：

```json
{
  "previewToken": "preview-token",
  "source": "CART",
  "items": [
    {
      "productId": "10001",
      "skuId": "11001",
      "quantity": 2
    }
  ],
  "shippingAddressId": "20001",
  "remark": "工作日送货"
}
```

响应：

```json
{
  "orderId": "50001",
  "orderNo": "ORD202608010001",
  "orderStatus": "PENDING_PAYMENT",
  "orderAmount": 599800,
  "currency": "CNY",
  "paymentDeadline": "2026-08-01T14:30:00+08:00"
}
```

---

## 21.3 订单列表

```text
GET /api/mall/orders
```

Query：

```text
status
page
size
```

---

## 21.4 订单详情

```text
GET /api/mall/orders/{orderId}
```

---

## 21.5 模拟支付

```text
POST /api/mall/orders/{orderId}/pay
```

Header：

```text
Idempotency-Key: payment-...
```

请求：

```json
{
  "paymentType": "SIMULATED"
}
```

响应：

```json
{
  "paymentNo": "PAY202608010001",
  "orderNo": "ORD202608010001",
  "paymentStatus": "SUCCEEDED",
  "orderStatus": "PENDING_SHIPMENT",
  "paidAt": "2026-08-01T14:00:00+08:00"
}
```

---

## 21.6 取消订单

```text
POST /api/mall/orders/{orderId}/cancel
```

请求：

```json
{
  "reason": "不想购买了"
}
```

---

## 21.7 确认收货

```text
POST /api/mall/orders/{orderId}/confirm-receipt
```

---

## 21.8 申请退款

```text
POST /api/mall/orders/{orderId}/refund-requests
```

请求：

```json
{
  "reason": "商品不符合预期"
}
```

---

## 21.9 退款详情

```text
GET /api/mall/refund-requests/{refundId}
```

---

# 22. 后台当前用户与权限 API

## 22.1 当前管理员信息

```text
GET /api/admin/current-user
```

---

## 22.2 当前管理员菜单

```text
GET /api/admin/current-user/menus
```

响应：

```json
{
  "menus": [
    {
      "menuId": "1",
      "parentId": null,
      "menuName": "商品管理",
      "menuType": "DIRECTORY",
      "routeName": "Product",
      "routePath": "/product",
      "componentPath": "Layout",
      "icon": "Goods",
      "sortOrder": 10,
      "children": []
    }
  ]
}
```

---

## 22.3 当前权限集合

```text
GET /api/admin/current-user/permissions
```

响应：

```json
{
  "permissions": [
    "product:list",
    "product:create",
    "product:update",
    "product:publish"
  ]
}
```

---

# 23. 后台管理员、角色与菜单 API

## 23.1 管理员

```text
GET    /api/admin/admin-users
POST   /api/admin/admin-users
GET    /api/admin/admin-users/{id}
PUT    /api/admin/admin-users/{id}
POST   /api/admin/admin-users/{id}/enable
POST   /api/admin/admin-users/{id}/disable
POST   /api/admin/admin-users/{id}/reset-password
PUT    /api/admin/admin-users/{id}/roles
```

---

## 23.2 角色

```text
GET    /api/admin/roles
POST   /api/admin/roles
GET    /api/admin/roles/{id}
PUT    /api/admin/roles/{id}
POST   /api/admin/roles/{id}/enable
POST   /api/admin/roles/{id}/disable
PUT    /api/admin/roles/{id}/menus
GET    /api/admin/roles/{id}/menus
```

角色菜单更新请求：

```json
{
  "menuIds": ["1", "2", "3", "4"]
}
```

---

## 23.3 菜单

```text
GET    /api/admin/menus/tree
POST   /api/admin/menus
GET    /api/admin/menus/{id}
PUT    /api/admin/menus/{id}
DELETE /api/admin/menus/{id}
POST   /api/admin/menus/{id}/enable
POST   /api/admin/menus/{id}/disable
```

---

# 24. 后台商品 API

## 24.1 商品列表

```text
GET /api/admin/products
```

Query：

```text
keyword
categoryId
brandId
status
page
size
```

---

## 24.2 创建商品

```text
POST /api/admin/products
```

权限：

```text
product:create
```

请求：

```json
{
  "productCode": "PRD000001",
  "productName": "示例商品",
  "subtitle": "示例副标题",
  "description": "商品描述",
  "categoryId": "20001",
  "brandId": "30001",
  "images": [
    {
      "objectKey": "products/temp/main.jpg",
      "imageUrl": "https://...",
      "imageType": "MAIN",
      "mainFlag": true,
      "sortOrder": 1
    }
  ],
  "attributes": [
    {
      "name": "屏幕尺寸",
      "value": "14 英寸"
    }
  ]
}
```

---

## 24.3 修改商品

```text
PUT /api/admin/products/{productId}
```

权限：

```text
product:update
```

---

## 24.4 添加 SKU

```text
POST /api/admin/products/{productId}/skus
```

请求：

```json
{
  "skuCode": "SKU000001",
  "salePrice": 299900,
  "specifications": {
    "颜色": "黑色",
    "存储": "256GB"
  },
  "mainImageUrl": "https://..."
}
```

---

## 24.5 修改 SKU

```text
PUT /api/admin/products/{productId}/skus/{skuId}
```

---

## 24.6 启用 SKU

```text
POST /api/admin/products/{productId}/skus/{skuId}/enable
```

---

## 24.7 禁用 SKU

```text
POST /api/admin/products/{productId}/skus/{skuId}/disable
```

---

## 24.8 商品上架

```text
POST /api/admin/products/{productId}/publish
```

权限：

```text
product:publish
```

---

## 24.9 商品下架

```text
POST /api/admin/products/{productId}/unpublish
```

权限：

```text
product:unpublish
```

---

# 25. 后台分类与品牌 API

## 25.1 分类

```text
GET    /api/admin/categories/tree
POST   /api/admin/categories
PUT    /api/admin/categories/{id}
DELETE /api/admin/categories/{id}
POST   /api/admin/categories/{id}/enable
POST   /api/admin/categories/{id}/disable
```

---

## 25.2 品牌

```text
GET    /api/admin/brands
POST   /api/admin/brands
PUT    /api/admin/brands/{id}
DELETE /api/admin/brands/{id}
POST   /api/admin/brands/{id}/enable
POST   /api/admin/brands/{id}/disable
```

---

# 26. 后台库存 API

## 26.1 库存列表

```text
GET /api/admin/inventories
```

Query：

```text
skuCode
productName
status
lowStock
page
size
```

---

## 26.2 初始化库存

```text
POST /api/admin/inventories
```

权限：

```text
inventory:create
```

请求：

```json
{
  "skuId": "11001",
  "initialQuantity": 100,
  "lowStockThreshold": 10,
  "reason": "首次入库"
}
```

---

## 26.3 增加库存

```text
POST /api/admin/inventories/{skuId}/increase
```

请求：

```json
{
  "quantity": 50,
  "reason": "采购入库"
}
```

---

## 26.4 减少库存

```text
POST /api/admin/inventories/{skuId}/decrease
```

请求：

```json
{
  "quantity": 10,
  "reason": "盘点调整"
}
```

---

## 26.5 库存流水

```text
GET /api/admin/inventory-transactions
```

---

# 27. 后台订单与退款 API

## 27.1 订单列表

```text
GET /api/admin/orders
```

Query：

```text
orderNo
memberId
status
createdFrom
createdTo
page
size
```

---

## 27.2 订单详情

```text
GET /api/admin/orders/{orderId}
```

---

## 27.3 发货

```text
POST /api/admin/orders/{orderId}/ship
```

权限：

```text
order:ship
```

请求：

```json
{
  "logisticsCompany": "顺丰速运",
  "trackingNumber": "SF123456789",
  "remark": "已发货"
}
```

---

## 27.4 后台取消订单

```text
POST /api/admin/orders/{orderId}/cancel
```

权限：

```text
order:cancel
```

---

## 27.5 退款列表

```text
GET /api/admin/refund-requests
```

---

## 27.6 审核通过

```text
POST /api/admin/refund-requests/{refundId}/approve
```

权限：

```text
order:refund
```

请求：

```json
{
  "remark": "同意退款"
}
```

---

## 27.7 审核拒绝

```text
POST /api/admin/refund-requests/{refundId}/reject
```

权限：

```text
order:refund
```

---

# 28. 后台系统配置 API

## 28.1 功能配置列表

```text
GET /api/admin/feature-configs
```

---

## 28.2 修改功能配置

```text
PUT /api/admin/feature-configs/{configKey}
```

权限：

```text
system:feature:update
```

请求：

```json
{
  "enabled": true,
  "changeReason": "开放 AI 导购"
}
```

---

## 28.3 系统参数列表

```text
GET /api/admin/system-parameters
```

---

## 28.4 修改系统参数

```text
PUT /api/admin/system-parameters/{configKey}
```

权限：

```text
system:config:update
```

请求：

```json
{
  "value": "30",
  "changeReason": "调整订单支付超时时间"
}
```

---

## 28.5 公开功能配置

```text
GET /api/mall/public-features
```

响应：

```json
{
  "memberRegisterEnabled": true,
  "refundEnabled": true,
  "aiShoppingEnabled": true,
  "aiCompareEnabled": false,
  "simulatedPaymentEnabled": true
}
```

---

## 28.6 操作日志

```text
GET /api/admin/operation-logs
```

---

# 29. 内部商品 API

## 29.1 批量获取订单商品快照

```text
POST /api/internal/products/order-snapshots
```

请求：

```json
{
  "items": [
    {
      "productId": "10001",
      "skuId": "11001",
      "quantity": 2
    }
  ]
}
```

响应：

```json
{
  "items": [
    {
      "productId": "10001",
      "skuId": "11001",
      "productName": "示例商品",
      "skuSpecification": {
        "颜色": "黑色",
        "存储": "256GB"
      },
      "mainImageUrl": "https://...",
      "salePrice": 299900,
      "currency": "CNY",
      "productStatus": "PUBLISHED",
      "skuStatus": "ENABLED",
      "salable": true
    }
  ]
}
```

---

## 29.2 批量获取 SKU 销售信息

```text
POST /api/internal/skus/batch-sale-info
```

用于购物车和 AI。

---

## 29.3 获取商品搜索投影

```text
GET /api/internal/products/{productId}/search-document
```

仅供 `mall-search` 使用。

---

# 30. 内部会员 API

## 30.1 获取会员状态

```text
GET /api/internal/members/{memberId}/status
```

---

## 30.2 获取收货地址

```text
GET /api/internal/members/{memberId}/shipping-addresses/{addressId}
```

响应：

```json
{
  "memberId": "10001",
  "addressId": "20001",
  "receiverName": "张三",
  "receiverPhone": "13812345678",
  "provinceName": "江苏省",
  "cityName": "南京市",
  "districtName": "鼓楼区",
  "detailAddress": "示例路 1 号",
  "postalCode": "210000",
  "enabled": true
}
```

---

# 31. 内部购物车 API

## 31.1 获取选中项

```text
GET /api/internal/carts/{memberId}/selected-items
```

响应只返回：

```json
{
  "items": [
    {
      "productId": "10001",
      "skuId": "11001",
      "quantity": 2
    }
  ]
}
```

不返回可作为订单成交依据的价格。

---

## 31.2 清理已结算项

```text
DELETE /api/internal/carts/{memberId}/checked-out-items
```

请求：

```json
{
  "skuIds": ["11001"]
}
```

---

# 32. 内部库存 API

## 32.1 锁定库存

```text
POST /api/internal/inventories/reservations
```

请求：

```json
{
  "businessNo": "ORD202608010001",
  "items": [
    {
      "skuId": "11001",
      "quantity": 2
    }
  ]
}
```

响应：

```json
{
  "reservationNo": "RES202608010001",
  "status": "RESERVED",
  "items": [
    {
      "skuId": "11001",
      "quantity": 2,
      "status": "RESERVED"
    }
  ]
}
```

---

## 32.2 释放库存

```text
POST /api/internal/inventories/reservations/{reservationNo}/release
```

请求：

```json
{
  "businessNo": "ORD202608010001",
  "reason": "ORDER_CREATE_FAILED"
}
```

---

## 32.3 确认扣减

```text
POST /api/internal/inventories/reservations/{reservationNo}/confirm-deduction
```

第一版主要由 MQ 消费触发，内部 API 用于补偿和人工处理。

---

## 32.4 查询库存可用性

```text
POST /api/internal/inventories/availability
```

请求：

```json
{
  "items": [
    {
      "skuId": "11001",
      "quantity": 2
    }
  ]
}
```

---

# 33. 内部订单 API

## 33.1 按会员查询订单

```text
GET /api/internal/members/{memberId}/orders
```

仅供 AI 工具等受控服务调用。

---

## 33.2 获取会员订单详情

```text
GET /api/internal/members/{memberId}/orders/{orderId}
```

---

## 33.3 AI 取消订单

```text
POST /api/internal/members/{memberId}/orders/{orderId}/cancel
```

请求：

```json
{
  "toolCallId": "tool-001",
  "confirmed": true,
  "reason": "用户通过 AI 助手确认取消"
}
```

Java 服务仍需验证：

- 会员身份；
- 订单归属；
- 订单状态；
- 功能配置；
- 幂等。

---

# 34. AI API

## 34.1 智能导购会话

```text
POST /api/ai/shopping-assistant/chat
```

请求：

```json
{
  "conversationId": null,
  "message": "预算 3000 元以内，推荐一台适合学习编程的轻薄笔记本"
}
```

响应：

```json
{
  "conversationId": "conv-001",
  "intent": "SHOPPING_RECOMMENDATION",
  "criteria": {
    "category": "笔记本电脑",
    "maxPrice": 300000,
    "useCase": "学习编程",
    "preferredBrands": [],
    "requiredFeatures": ["轻薄"]
  },
  "recommendations": [
    {
      "productId": "10001",
      "productName": "示例笔记本",
      "mainImageUrl": "https://...",
      "price": 299900,
      "currency": "CNY",
      "reason": "满足预算，适合学习编程且便于携带"
    }
  ],
  "followUpQuestion": null
}
```

---

## 34.2 商品对比

```text
POST /api/ai/product-comparisons
```

请求：

```json
{
  "productIds": ["10001", "10002"]
}
```

响应：

```json
{
  "items": [],
  "dimensions": [
    "价格",
    "性能",
    "便携性",
    "适用场景"
  ],
  "summary": "商品 A 更适合便携，商品 B 更适合性能需求。"
}
```

---

## 34.3 RAG 智能客服

```text
POST /api/ai/customer-service/chat
```

请求：

```json
{
  "conversationId": null,
  "message": "订单发货后还能退款吗？"
}
```

响应：

```json
{
  "conversationId": "conv-002",
  "answer": "根据当前平台退款规则……",
  "citations": [
    {
      "documentId": "doc-001",
      "fileName": "退款规则.pdf",
      "chunkId": "chunk-001"
    }
  ],
  "grounded": true
}
```

---

## 34.4 AI 订单助手

```text
POST /api/ai/order-assistant/chat
```

要求 `MEMBER` 身份。

请求：

```json
{
  "conversationId": null,
  "message": "帮我看看最近一笔订单发货了吗？"
}
```

---

# 35. AI SSE 流式协议

## 35.1 接口

```text
POST /api/ai/shopping-assistant/stream
POST /api/ai/customer-service/stream
POST /api/ai/order-assistant/stream
```

Content-Type：

```text
text/event-stream
```

---

## 35.2 SSE 事件类型

### 会话开始

```text
event: conversation
data: {"conversationId":"conv-001"}
```

### 文本增量

```text
event: token
data: {"content":"你好"}
```

### 工具调用开始

```text
event: tool-start
data: {"toolCallId":"tool-001","toolName":"search_products"}
```

### 工具调用完成

```text
event: tool-result
data: {"toolCallId":"tool-001","success":true}
```

### 结构化结果

```text
event: result
data: {"recommendations":[...]}
```

### 完成

```text
event: done
data: {"finishReason":"STOP"}
```

### 错误

```text
event: error
data: {"code":"AI_SERVICE_UNAVAILABLE","message":"AI 服务暂时不可用"}
```

---

## 35.3 SSE 规则

- 每个事件包含合法 JSON；
- 客户端断开后服务停止无意义生成；
- 工具结果中不暴露敏感信息；
- 最终必须发送 `done` 或 `error`；
- Gateway 关闭响应缓冲；
- 设置合理心跳；
- 超时后返回可恢复错误。

---

# 36. 后台 AI 管理 API

## 36.1 知识库

```text
GET    /api/admin/ai/knowledge-bases
POST   /api/admin/ai/knowledge-bases
PUT    /api/admin/ai/knowledge-bases/{id}
POST   /api/admin/ai/knowledge-bases/{id}/enable
POST   /api/admin/ai/knowledge-bases/{id}/disable
```

---

## 36.2 知识文档

```text
GET    /api/admin/ai/knowledge-bases/{id}/documents
POST   /api/admin/ai/knowledge-bases/{id}/documents
DELETE /api/admin/ai/documents/{documentId}
POST   /api/admin/ai/documents/{documentId}/reindex
GET    /api/admin/ai/documents/{documentId}
```

---

## 36.3 AI 对话记录

```text
GET /api/admin/ai/conversations
GET /api/admin/ai/conversations/{conversationId}
GET /api/admin/ai/tool-calls
```

敏感信息必须脱敏。

---

# 37. OpenFeign 契约规范

## 37.1 契约位置

```text
backend/mall-contracts/mall-api-contracts
```

建议按上下文拆包：

```text
com.aimall.contract.product
com.aimall.contract.member
com.aimall.contract.cart
com.aimall.contract.order
com.aimall.contract.inventory
com.aimall.contract.system
```

---

## 37.2 Feign 接口示例

```java
public interface InventoryInternalApi {

    @PostMapping("/api/internal/inventories/reservations")
    ApiResponse<ReserveInventoryResponse> reserve(
        @RequestBody ReserveInventoryRequest request
    );

    @PostMapping(
        "/api/internal/inventories/reservations/{reservationNo}/release"
    )
    ApiResponse<Void> release(
        @PathVariable String reservationNo,
        @RequestBody ReleaseInventoryRequest request
    );
}
```

---

## 37.3 超时建议

| 类型 | 连接超时 | 读取超时 |
|---|---:|---:|
| 普通查询 | 2 秒 | 3 秒 |
| 核心写调用 | 2 秒 | 5 秒 |
| AI 调用 | 3 秒 | 30～60 秒 |
| 文件上传 | 5 秒 | 按文件大小配置 |

具体值以压测结果调整。

---

## 37.4 重试规则

查询接口：

- 可有限重试；
- 只对网络错误和部分 5xx 重试；
- 业务错误不重试。

写接口：

- 默认不自动重试；
- 确认幂等后才能重试；
- 超时后不能假设上游未执行；
- 通过业务查询确认结果。

---

## 37.5 Feign 错误转换

外部错误：

```text
Inventory API Error
```

转换为本上下文异常：

```text
InventoryReservationFailedException
```

领域层不直接依赖 Feign 异常。

---

# 38. 集成事件公共结构

## 38.1 标准事件 Envelope

```json
{
  "eventId": "evt-001",
  "eventType": "PaymentSucceeded",
  "eventVersion": "1.0",
  "aggregateType": "Order",
  "aggregateId": "50001",
  "producer": "mall-order",
  "occurredAt": "2026-08-01T14:00:00+08:00",
  "traceId": "trace-001",
  "payload": {}
}
```

字段说明：

| 字段 | 说明 |
|---|---|
| `eventId` | 全局唯一事件 ID |
| `eventType` | 事件类型 |
| `eventVersion` | 事件版本 |
| `aggregateType` | 来源聚合类型 |
| `aggregateId` | 来源聚合 ID |
| `producer` | 发布服务 |
| `occurredAt` | 业务事实发生时间 |
| `traceId` | 链路 ID |
| `payload` | 事件业务数据 |

---

## 38.2 事件命名

使用已经发生的事实：

```text
ProductPublished
PaymentSucceeded
OrderCancelled
FeatureConfigChanged
```

禁止：

```text
PublishProduct
PayOrder
CancelOrder
```

后者属于命令。

---

# 39. RocketMQ Topic、Tag 与消费者组

## 39.1 Topic

```text
product-events
order-events
inventory-events
system-events
audit-events
ai-events
```

---

## 39.2 product-events

Tags：

```text
PRODUCT_PUBLISHED
PRODUCT_UPDATED
PRODUCT_UNPUBLISHED
SKU_PRICE_CHANGED
SKU_DISABLED
```

消费者组：

```text
search-product-index-consumer
ai-product-projection-consumer
```

第一版 AI 不维护独立商品投影时，可不启用第二个消费者。

---

## 39.3 order-events

Tags：

```text
ORDER_CREATED
PAYMENT_SUCCEEDED
ORDER_CANCELLED
ORDER_SHIPPED
ORDER_COMPLETED
REFUND_REQUESTED
REFUND_COMPLETED
```

消费者组：

```text
order-timeout-consumer
inventory-payment-consumer
inventory-order-cancel-consumer
system-order-audit-consumer
```

---

## 39.4 system-events

Tags：

```text
FEATURE_CONFIG_CHANGED
SYSTEM_PARAMETER_CHANGED
```

消费者组：

```text
service-config-cache-consumer
```

---

## 39.5 audit-events

Tags：

```text
ADMIN_OPERATION
LOGIN_EVENT
```

消费者组：

```text
system-audit-log-consumer
```

---

## 39.6 ai-events

Tags：

```text
KNOWLEDGE_DOCUMENT_UPLOADED
KNOWLEDGE_DOCUMENT_INDEXED
KNOWLEDGE_DOCUMENT_INDEX_FAILED
AI_EXECUTION_COMPLETED
AI_TOOL_CALL_FAILED
```

消费者组：

```text
ai-document-index-consumer
ai-observation-consumer
```

---

# 40. 商品集成事件

## 40.1 ProductPublishedIntegrationEvent

Topic：

```text
product-events
```

Tag：

```text
PRODUCT_PUBLISHED
```

Payload：

```json
{
  "productId": "10001",
  "productVersion": 3
}
```

消费者：

- `mall-search`。

处理：

- 获取商品搜索投影；
- 创建或更新 Elasticsearch 文档。

---

## 40.2 ProductUpdatedIntegrationEvent

Payload：

```json
{
  "productId": "10001",
  "productVersion": 4,
  "changedFields": [
    "productName",
    "subtitle"
  ]
}
```

---

## 40.3 ProductUnpublishedIntegrationEvent

Payload：

```json
{
  "productId": "10001",
  "unpublishedAt": "2026-08-01T15:00:00+08:00"
}
```

处理：

- 搜索索引删除或标记不可售；
- 不影响历史订单。

---

## 40.4 SkuPriceChangedIntegrationEvent

Payload：

```json
{
  "productId": "10001",
  "skuId": "11001",
  "oldPrice": 299900,
  "newPrice": 289900,
  "currency": "CNY"
}
```

---

# 41. 订单集成事件

## 41.1 OrderCreatedIntegrationEvent

Topic：

```text
order-events
```

Tag：

```text
ORDER_CREATED
```

Payload：

```json
{
  "orderId": "50001",
  "orderNo": "ORD202608010001",
  "memberId": "10001",
  "reservationNo": "RES202608010001",
  "orderAmount": 599800,
  "currency": "CNY",
  "paymentDeadline": "2026-08-01T14:30:00+08:00"
}
```

消费者：

- 订单延迟任务；
- 可选统计服务。

---

## 41.2 PaymentSucceededIntegrationEvent

Tag：

```text
PAYMENT_SUCCEEDED
```

Payload：

```json
{
  "orderId": "50001",
  "orderNo": "ORD202608010001",
  "paymentNo": "PAY202608010001",
  "reservationNo": "RES202608010001",
  "paymentAmount": 599800,
  "currency": "CNY",
  "paidAt": "2026-08-01T14:00:00+08:00"
}
```

消费者：

- `mall-inventory`。

处理：

- 幂等确认扣减库存。

---

## 41.3 OrderCancelledIntegrationEvent

Tag：

```text
ORDER_CANCELLED
```

Payload：

```json
{
  "orderId": "50001",
  "orderNo": "ORD202608010001",
  "reservationNo": "RES202608010001",
  "cancelReason": "PAYMENT_TIMEOUT",
  "cancelledAt": "2026-08-01T14:31:00+08:00"
}
```

消费者：

- `mall-inventory`。

处理：

- 幂等释放库存锁定。

---

## 41.4 OrderCompletedIntegrationEvent

Payload：

```json
{
  "orderId": "50001",
  "orderNo": "ORD202608010001",
  "memberId": "10001",
  "completedAt": "2026-08-05T12:00:00+08:00"
}
```

后续可用于：

- 会员成长值；
- 销量统计；
- 评价资格；
- 数据分析。

---

# 42. 库存集成事件

库存核心写操作第一版主要由同步 API 或消费订单事件完成。

可发布以下结果事件用于审计和扩展。

## 42.1 InventoryReservedIntegrationEvent

Payload：

```json
{
  "reservationNo": "RES202608010001",
  "businessNo": "ORD202608010001",
  "items": [
    {
      "skuId": "11001",
      "quantity": 2
    }
  ],
  "reservedAt": "2026-08-01T13:50:00+08:00"
}
```

---

## 42.2 InventoryReleasedIntegrationEvent

```json
{
  "reservationNo": "RES202608010001",
  "businessNo": "ORD202608010001",
  "releasedAt": "2026-08-01T14:31:00+08:00"
}
```

---

## 42.3 InventoryDeductedIntegrationEvent

```json
{
  "reservationNo": "RES202608010001",
  "businessNo": "ORD202608010001",
  "deductedAt": "2026-08-01T14:00:01+08:00"
}
```

---

## 42.4 LowStockDetectedIntegrationEvent

```json
{
  "skuId": "11001",
  "availableQuantity": 5,
  "threshold": 10,
  "detectedAt": "2026-08-01T14:00:01+08:00"
}
```

---

# 43. 系统配置集成事件

## 43.1 FeatureConfigChangedIntegrationEvent

Topic：

```text
system-events
```

Tag：

```text
FEATURE_CONFIG_CHANGED
```

Payload：

```json
{
  "configKey": "ai.shopping.enabled",
  "oldEnabled": false,
  "newEnabled": true,
  "changedBy": "1",
  "changedAt": "2026-08-01T15:00:00+08:00"
}
```

消费者：

- 需要本地缓存配置的业务服务；
- Gateway；
- AI 服务。

处理：

- 清理本地缓存；
- 不直接执行其他业务写操作。

---

## 43.2 SystemParameterChangedIntegrationEvent

Payload：

```json
{
  "configKey": "order.timeout.minutes",
  "oldValue": "30",
  "newValue": "45",
  "parameterType": "INTEGER",
  "changedBy": "1",
  "changedAt": "2026-08-01T15:00:00+08:00"
}
```

规则：

- 新值只影响新创建业务对象；
- 已有订单使用自身 `paymentDeadline`。

---

# 44. 操作日志事件

## 44.1 AdminOperationIntegrationEvent

Topic：

```text
audit-events
```

Tag：

```text
ADMIN_OPERATION
```

Payload：

```json
{
  "operationId": "op-001",
  "operatorId": "1",
  "operatorName": "超级管理员",
  "module": "PRODUCT",
  "action": "PUBLISH",
  "resourceType": "PRODUCT",
  "resourceId": "10001",
  "requestPath": "/api/admin/products/10001/publish",
  "httpMethod": "POST",
  "result": "SUCCESS",
  "errorCode": null,
  "durationMs": 120,
  "ipAddress": "127.0.0.1",
  "occurredAt": "2026-08-01T15:00:00+08:00"
}
```

规则：

- 不记录密码和 Token；
- 日志消费失败不回滚业务；
- 以 `operationId` 幂等。

---

# 45. AI 事件

## 45.1 KnowledgeDocumentUploadedEvent

Payload：

```json
{
  "knowledgeBaseId": "kb-001",
  "documentId": "doc-001",
  "objectKey": "knowledge-bases/kb-001/doc-001/rules.pdf",
  "fileName": "退款规则.pdf",
  "uploadedBy": "1",
  "uploadedAt": "2026-08-01T15:00:00+08:00"
}
```

消费者：

- AI 文档解析和索引任务。

---

## 45.2 KnowledgeDocumentIndexedEvent

Payload：

```json
{
  "knowledgeBaseId": "kb-001",
  "documentId": "doc-001",
  "chunkCount": 120,
  "embeddingModel": "example-embedding-model",
  "indexedAt": "2026-08-01T15:05:00+08:00"
}
```

---

## 45.3 AiToolCallFailedEvent

Payload：

```json
{
  "conversationId": "conv-001",
  "toolCallId": "tool-001",
  "toolName": "search_products",
  "errorCode": "COMMON_UPSTREAM_TIMEOUT",
  "traceId": "trace-001",
  "failedAt": "2026-08-01T15:05:00+08:00"
}
```

---

# 46. 事件消费幂等规范

## 46.1 通用流程

```text
接收消息
→ 检查 eventId + consumerGroup
→ 已成功则直接返回
→ 写入 PROCESSING
→ 执行业务
→ 更新 SUCCEEDED
```

失败：

```text
记录错误
→ 更新 FAILED
→ RocketMQ 重试
```

---

## 46.2 业务幂等优先

即使事件消费表失效，业务仍需以以下条件保证正确：

- `reservationNo`；
- `orderNo`；
- 订单当前状态；
- 库存锁定状态；
- 商品版本；
- 配置版本；
- 唯一索引。

---

## 46.3 消息顺序

同一订单的关键事件需要尽量按 `orderNo` 选择消息队列分片。

例如：

```text
OrderCreated
PaymentSucceeded
OrderCancelled
```

消费者仍必须处理乱序情况。

若收到：

```text
OrderCancelled
```

但库存已 `DEDUCTED`，不能直接释放，需要记录异常并人工核查。

---

# 47. 事件重试与死信

## 47.1 可重试异常

- 网络超时；
- 数据库暂时不可用；
- Elasticsearch 暂时不可用；
- MinIO 暂时不可用；
- 依赖服务 5xx；
- 乐观锁短期冲突。

## 47.2 不可重试异常

- 事件字段缺失；
- 事件版本不支持；
- 业务状态永久冲突；
- 目标资源不存在且无法恢复；
- Schema 校验失败。

不可重试异常应：

- 记录失败；
- 进入死信或人工任务；
- 触发告警。

---

# 48. 事件版本兼容

## 48.1 版本号

```text
1.0
1.1
2.0
```

## 48.2 小版本

允许：

- 新增可选字段；
- 新增不影响旧消费者的元数据。

## 48.3 大版本

以下情况必须升级大版本：

- 删除字段；
- 修改字段类型；
- 修改字段语义；
- 改变事件发生时机；
- 改变幂等含义。

## 48.4 消费者策略

消费者应：

- 明确支持的版本；
- 对未知可选字段忽略；
- 对不支持的大版本拒绝消费并告警；
- 不默默猜测字段含义。

---

# 49. 文件上传契约

## 49.1 上传商品图片

```text
POST /api/admin/files/product-images
```

Content-Type：

```text
multipart/form-data
```

响应：

```json
{
  "objectKey": "products/temp/xxx.jpg",
  "fileName": "xxx.jpg",
  "fileSize": 102400,
  "contentType": "image/jpeg",
  "url": "https://..."
}
```

## 49.2 上传知识文档

```text
POST /api/admin/ai/knowledge-bases/{id}/documents
```

限制：

- 文件类型白名单；
- 文件大小限制；
- 文件名清洗；
- MIME 校验；
- Checksum；
- 私有对象存储；
- 后台权限校验。

---

# 50. OpenAPI 与接口文档

## 50.1 Java 服务

使用：

```text
Springdoc OpenAPI
```

## 50.2 AI 服务

使用：

```text
FastAPI OpenAPI
```

## 50.3 Gateway 聚合

可选择：

- Gateway 聚合各服务文档；
- 每个服务独立文档；
- 使用 Apifox 导入统一管理。

## 50.4 文档要求

每个接口必须说明：

- 名称；
- 路径；
- 方法；
- 权限；
- Header；
- 请求字段；
- 响应字段；
- 错误码；
- 幂等；
- 示例；
- 是否支持游客；
- 是否内部接口。

---

# 51. 契约测试

## 51.1 测试范围

- 请求字段；
- 必填规则；
- 字段类型；
- 状态码；
- 错误码；
- 响应结构；
- 枚举；
- Feign 契约；
- 事件 Schema；
- 事件版本。

## 51.2 推荐方式

- Spring MockMvc；
- WebTestClient；
- FastAPI TestClient；
- JSON Schema；
- Pact 可选；
- Testcontainers；
- RocketMQ 集成测试；
- OpenAPI Diff。

## 51.3 重点契约场景

- 创建订单成功；
- 创建订单重复提交；
- 库存不足；
- 商品下架；
- 支付重复；
- 取消重复；
- 无权限发货；
- 配置关闭 AI；
- AI 输出 Schema 错误；
- MQ 重复消息；
- 不支持的事件版本。

---

# 52. API 安全规范

## 52.1 认证

- 商城会员接口需要 `MEMBER`；
- 后台接口需要 `ADMIN`；
- 内部接口需要 `SERVICE`；
- AI 订单接口需要 `MEMBER`；
- 游客接口明确白名单。

## 52.2 授权

后台接口使用：

```java
@PreAuthorize("hasAuthority('order:ship')")
```

## 52.3 数据归属

后端必须校验：

- 地址属于当前会员；
- 订单属于当前会员；
- 退款属于当前会员；
- AI 订单工具只能使用当前会员身份。

## 52.4 参数安全

- Bean Validation；
- 字符串长度限制；
- 枚举白名单；
- 文件 MIME 校验；
- 排序字段白名单；
- JSON 深度和大小限制；
- AI Prompt 注入风险控制。

## 52.5 限流

重点接口：

- 登录；
- 注册；
- AI 会话；
- 商品搜索；
- 创建订单；
- 模拟支付；
- 文件上传。

---

# 53. API 废弃策略

废弃接口需要：

1. 标记 `Deprecated`；
2. OpenAPI 标记废弃；
3. 提供替代接口；
4. 保留至少一个发布周期；
5. 记录调用量；
6. 调用量归零后移除；
7. 破坏性变更进入新版本路径。

---

# 54. 第一版实现优先级

## 54.1 P0

- 统一响应；
- 统一错误码；
- 认证 API；
- 商品 API；
- 购物车 API；
- 地址 API；
- 订单预览；
- 创建订单；
- 支付；
- 取消；
- 发货；
- 权限 API；
- 商品内部快照 API；
- 库存锁定 API；
- 会员地址内部 API；
- AI 智能导购 API；
- TraceId；
- Idempotency-Key。

## 54.2 P1

- Elasticsearch 搜索 API；
- 退款 API；
- 功能配置 API；
- 系统参数 API；
- RocketMQ 核心事件；
- SSE；
- AI 商品对比；
- RAG 客服；
- Outbox；
- 操作日志事件。

## 54.3 P2

- AI 订单写工具；
- 低库存事件；
- 自动确认收货；
- API V2；
- Pact；
- mTLS；
- 复杂退款事件。

---

# 55. 契约验收标准

完成 API 与事件契约后，应满足：

1. 所有路径遵循统一规则；
2. 商城、后台、内部和 AI 接口边界明确；
3. 所有响应使用统一结构；
4. 所有错误有稳定业务错误码；
5. ID 按字符串传输；
6. 金额按整数分传输；
7. 时间格式统一；
8. 分页结构统一；
9. 创建订单具有幂等键；
10. 库存锁定具有业务幂等键；
11. Feign 契约不包含领域实体；
12. 内部接口不直接暴露公网；
13. AI 不直接接收不可信 memberId；
14. AI 流式协议有结束和错误事件；
15. RocketMQ 事件具有公共 Envelope；
16. 核心事件具有 Topic、Tag 和消费者组；
17. 消费者具备幂等和重试策略；
18. 事件版本策略明确；
19. OpenAPI 文档可生成；
20. 契约测试覆盖核心链路。

---

# 56. 当前契约决策

## 56.1 已确定

- 第一版 API 不显式加入 `/v1`；
- 商城接口使用 `/api/mall/**`；
- 后台接口使用 `/api/admin/**`；
- 内部接口使用 `/api/internal/**`；
- AI 接口使用 `/api/ai/**`；
- 统一响应包含 `success`、`code`、`message`、`data`、`traceId`；
- 金额使用整数分；
- BIGINT ID 按字符串返回；
- 创建订单使用 `Idempotency-Key`；
- 内部调用使用 OpenFeign；
- AI 流式输出使用 SSE；
- 事件使用统一 Envelope；
- RocketMQ 按业务域划分 Topic；
- 支付成功和订单取消由库存服务消费；
- 商品事件由搜索服务消费；
- 集成事件与领域事件分离；
- API 和事件契约放入 `mall-contracts`。

## 56.2 待确认

- 时间最终统一使用 UTC 还是 `+08:00`；
- API 是否在正式发布前改为显式 `/api/v1`；
- 内部服务认证采用固定 Token、签名还是 mTLS；
- AI 接口是否经过 Java AI Facade；
- SSE 是否统一使用 POST；
- 是否使用 Pact；
- Outbox 是否进入第一版 P1；
- 商品事件携带完整搜索数据还是只携带 `productId`；
- 是否增加 Webhook；
- 是否对响应字段使用 `snake_case`，当前 Java 和 Vue 统一建议 `camelCase`。

---



本文档作为 V0.1 API 与事件契约基线。后续业务流程、聚合、数据库或消息架构发生变化时，应同步更新本文档。
