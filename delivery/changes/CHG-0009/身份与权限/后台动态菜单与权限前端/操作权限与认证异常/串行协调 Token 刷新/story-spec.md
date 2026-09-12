---
story-id: "STORY-001-03-03-02"
change-spec-ref: "change-spec.md#33-story-拆分总表"
scope-refs: [S8]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：`change-spec.md` §3.3 与 `exploration.md`
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0009
- Story ID: STORY-001-03-03-02
- Change spec 引用: `change-spec.md#33-story-拆分总表`
- 状态流转: pending → specified

## 1. Story 目标

合并并发 Access Token 过期请求，避免 Refresh 风暴、重复轮换和无限重试。

## 2. Scope（范围）

### 2.1 包含

- single-flight Promise、请求队列复用、一次重放、refresh 跳过标记、失败广播。

### 2.2 不包含

- 跨标签页锁、离线重试队列。

## 3. 业务规则

同一时刻最多一个 refresh；等待请求共享结果；成功更新 Token 后每个请求最多重放一次；refresh 请求不递归；失败统一 reject 并清理会话。

## 4. 接口与字段规格

RefreshCoordinator.refreshOnce():Promise<TokenPair>；Axios config `_retry`/`skipAuthRefresh`；仅特定 401 业务码触发。

## 5. Story 验收标准

| ID | 验收标准（可测试） | 备注 |
|---|---|---|
| AC-001 | 多个并发请求同时收到可刷新 401 时，只发送一次 Refresh，成功后所有原请求各重放一次。 | |
| AC-002 | Refresh 失败时所有等待请求均被拒绝并只执行一次集中会话清理。 | |
| AC-003 | 重放请求再次 401 或 Refresh 请求自身 401 时不进入循环刷新。 | |

