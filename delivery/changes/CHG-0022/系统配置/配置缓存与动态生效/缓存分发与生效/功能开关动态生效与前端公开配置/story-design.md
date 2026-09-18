---
affected-repositories: [repo-1, repo-2]
story-id: "STORY-006-02-01-02"
change-design-ref: "requirement-design.md#5-story-设计分派story-design-assignments"
---

# Story Design（Story 技术设计）

> 阶段：sdd-design Story 级产物
> 输入：story-spec.md + requirement-design.md §2.4/§4
> 产出状态：designed

## 0. 元信息

- Change ID: CHG-0022
- Story ID: STORY-006-02-01-02
- 状态流转: specified → designed
- 相关仓库: repo-1（mall-search/mall-cart/mall-system/mall-gateway）、repo-2（mall-web）
- 需要 Migration: no
- 数据变更概要: 无

## 1. 模块改动（Module Changes）

### repo-1（DU-BE-509）

- mall-search：MallSearchController 查询入口（或 ProductSearchService 首行）调 featureGate.ensureEnabled("search.enabled")；关闭时 B0606 FEATURE_DISABLED → 403 {code:"B0606",message:"功能暂未开放"}。依赖 mall-common-config（DU-BE-508）。
- mall-cart：仅游客（未登录）写操作（加购/改数量/删除/选中）入口校验 featureGate.isEnabled("mall.guest-cart.enabled",true)；关闭 → B0606 403；会员写操作、所有读操作不受影响。
- mall-system：interfaces.rest.mall.MallConfigController GET /api/mall/public-features（permitAll）：读 Redis 聚合键 aimall:{env}:system:public-features（未命中则查 public_flag=1 条目并回填，TTL 600s），返回 [{key,enabled}]；不含任何参数值/非公开键。
- mall-gateway：/api/mall/public-features 加匿名白名单转 mall-system；其余 /api/admin/** 配置路由在 DU-BE-507 已建。

### repo-2 mall-web（DU-FE-504）

- stores/features.ts：应用启动（main.ts/ App onMounted）调 GET /api/mall/public-features 加载公开开关 Map；提供 hasFeature(key)（未知键 fail-open 返回 true）；加载失败静默（WARN）不阻塞应用。
- 搜索入口：HomeView/Header 搜索框与 /search 入口 v-if="hasFeature('search.enabled')"；关闭时直接访问 /search 显示"功能暂未开放"空态（后端 403 同样兜底提示）。
- 游客购物车：游客写操作按钮在关闭态隐藏/禁用；接口 403 全局提示"游客购物车暂未开放，请登录"。

## 2. 接口契约细化

| 方法 | 路径 | 身份 | 响应 |
| --- | --- | --- | --- |
| GET | /api/mall/public-features | 匿名 permitAll | UnifyResult<[{key,enabled}]>（仅 public_flag=1） |
| GET | /api/mall/search/products（开关关闭时） | 匿名 | 403 B0606 |
| 游客 POST /api/mall/cart/items（开关关闭时） | 匿名 | 403 B0606 |

## 3. 数据变更

无。

## 4. 错误处理

- 配置服务/Redis 全不可用：消费方按代码默认（search.enabled=true、mall.guest-cart.enabled=true）放行（fail-open，WARN 日志）；
- effect_type=RESTART_REQUIRED 的参数本 Story 不接入消费（仅后台展示标记）；DYNAMIC 有界生效 ≤60s——AFTER_COMMIT 删键后跨服务新读立即取 Redis 新值，消费端最迟经本地缓存 60s TTL 到期收敛，无额外传播时延；
- 前端拉取失败 fail-open。

## 5. DU 划分（Delivery Units）

| DU id | repository | goal | covers | depends on |
| ----- | ---------- | ---- | ------ | ---------- |
| DU-BE-509 | repo-1 | public-features 端点+网关白名单+search/cart 开关切点 B0606 | AC-001, AC-002, AC-004, AC-005, AC-006 | 无 |
| DU-FE-504 | repo-2 | mall-web features store/搜索入口显隐/游客车禁用态 | AC-003, AC-007 | DU-BE-509 |

> 跨 Story 依赖（不入本表）：DU-BE-509 实际前置 DU-BE-508（STORY-006-02-01-01 缓存客户端/内部端点）。

## 6. 测试策略

- 单测/切片：ensureEnabled 通过/抛 B0606；游客车会员不受影响、读不受影响；public-features 只返公开键且走聚合缓存；
- IT：关闭 search.enabled→60s 内搜索 403，再开启恢复；游客车关闭→游客 403/会员 200；
- 前端 Vitest：hasFeature fail-open、入口 v-if、403 提示。
