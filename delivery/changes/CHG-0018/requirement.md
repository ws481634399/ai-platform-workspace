---
id: "REQ-M3-003"
name: "购物车"
content: "建立基于 Redis 的会员购物车与 LocalStorage 游客购物车：加购合并、改量、删除、选择、实时商品/价格/库存校验，登录后幂等合并；memberId 取自 SecurityContext，不锁库存、不产生成交价、不跨库直查。"
source: requirement-doc
created-at: "2026-09-14T07:00:00.000Z"
---

# Requirement

> 原始需求全文归档于 `references/M3.md`（REQ-M3-003 第一至十九章 + 文末注意点 6、7 与依赖微调），本文件记录本 Change 的输入边界。

## 需求描述

按 `docs/需求/M3/M3.md` 中 `REQ-M3-003 购物车` 执行完整 SDD。建立商城购物车能力，用户可把真实 SKU 加入购物车并统一管理，为 M4 订单结算提供输入。

**范围决策（已与用户确认，解决 M3.md 正文“建议支持”与 DoD“必做”的矛盾）：**

- 游客购物车（LocalStorage）与登录后合并为 **M3 P0 必做**；PRD 必须明确合并幂等键、冲突策略与数量上限。

**存储与可靠性边界（已与用户确认，回应 M3.md 注意点 7）：**

- 会员购物车采用纯 Redis 临时态，不引入 MySQL 购物车模型；
- Key 采用滑动 TTL 90 天（任意写操作续期）；
- 单会员最多 100 个不同 SKU 条目；单 SKU 数量上限 999；
- `selected` 选择状态存服务端 Redis（跨设备一致）；
- 接受 Redis 故障/重启导致购物车丢失的边界（购物车是购买意向，不锁库存、不产生交易，损失可接受）；基础设施侧 Redis 开启 AOF 作为基本兜底（infra 配置随本 Change 确认）。

**购物车条目：** 核心引用 memberId + skuId，维护 quantity/selected/createdAt/updatedAt；商品名称、价格、状态、库存不是购物车权威数据，实时来源于 mall-product / mall-inventory。

**加入购物车：** 校验 Product 存在且可售、SKU 存在且有效、数量合法；同一会员重复加同一 SKU 合并增加 quantity 而非新增条目；加购不锁库存。加入时是否强制库存充足由 Design 确定（建议：不阻断，超量在查看时提示）。

**修改数量 / 删除：** quantity 必须 >0，受上限约束，杜绝负数/0 残留/整数溢出；支持单条与批量删除；只能操作本人购物车。

**选择状态：** 单选、取消单选、全选、取消全选；为 M4 Checkout Preview 标识拟购 SKU（M3 只提供入口，不做结算预览）。

**实时校验（查看购物车时）：** 按 Product/Inventory 最新状态识别商品下架、SKU 失效、价格变化、库存不足、商品不存在；展示最新价格。购物车价格≠订单成交价，成交价由 M4 重算；禁止信任浏览器传入的 price/totalAmount。

**游客购物车与合并（P0）：** 未登录加购存浏览器 LocalStorage；登录成功后把游客车合并到会员车；相同 SKU 数量相加并受单 SKU/条目上限约束（超上限截断到上限并提示）；合并必须幂等——页面重试/重复提交不得反复累加（PRD 定义幂等键：一次性 mergeToken 或等价机制）。

**安全：** 服务端会员购物车的 memberId 必须从 SecurityContext 获取，禁止信任前端传入 memberId；所有操作验证资源归属。

**跨服务访问：** mall-cart 通过既有内部 API/Contract（mall-contracts）获取 Product/Inventory 数据，禁止跨服务 SQL 直查。

**mall-web 购物车页：** 列表、图片、名称、SKU 属性、当前价格、数量、库存状态、有效状态、单选/全选、删除、改量、选中金额、去结算入口（入口在 M3 仅占位/置灰或提示 M4）。

## 补充信息

- 优先级：P0
- 前置依赖：REQ-M3-001 的注册/登录与可信 memberId（地址不阻塞本需求）、REQ-M3-002 的商品/SKU/库存契约（CHG-0017 批量查询能力）、CHG-0015
- 主要服务：mall-cart；协作 mall-product、mall-inventory
- 主要前端：mall-web
- 主要基础设施：Redis
- 主要仓库：repo-1、repo-2（如涉及 AOF 配置则含 repo-4）
- 非本需求范围：创建订单、库存锁定、成交价确认、支付、优惠券、运费、超时关单（均 M4）；购物车持久化营销分析。
