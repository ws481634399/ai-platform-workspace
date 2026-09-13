# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 位置：STORY 级 —— `CHG-0013/.../库存锁定与释放/test-design.md`
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0013
- Story ID: STORY-002-04-03-01
- Spec 来源: 同目录 story-spec.md
- Design 来源: 同目录 story-design.md；requirement-design.md §6
- 状态流转: designed → tasked
- TC 总数: 7

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API 集成测试：POST /internal/inventory/lock，available>=quantity → 200，locked+=quantity，reservation 状态 LOCKED | AC-010 | DU-BE-403 | 锁定成功 |
| TC-002 | API 集成测试：available<quantity → STOCK_INSUFFICIENT，locked 不变 | AC-011 | DU-BE-403 | 防超卖 |
| TC-003 | API 集成测试：同一 reservationId 重复锁定 → 返回原结果，locked 不重复增加 | AC-012 | DU-BE-403 | 幂等锁定 |
| TC-004 | API 集成测试：POST /internal/inventory/release 基于 LOCKED reservation → locked-=quantity，状态 RELEASED | AC-013 | DU-BE-403 | 释放成功 |
| TC-005 | API 集成测试：同一 reservationId 重复释放 → 不重复减少 locked，返回成功 | AC-014 | DU-BE-403 | 幂等释放 |
| TC-006 | 数据断言：锁定/释放后 inventory_log 存在 LOCK/RELEASE 记录 | AC-018 | DU-BE-403 | LOCK/RELEASE 流水 |
| TC-007 | 并发测试：两个线程同时锁定最后 1 件（quantity=1）→ 仅一个成功，另一个 STOCK_INSUFFICIENT | AC-019 | DU-BE-403 | 并发安全 |

## 2. 测试策略

- Unit：Inventory.lock/release 领域行为。
- API 集成：@SpringBootTest + MockMvc + H2。
- 并发：CountDownLatch + 多线程调用 lock 接口，断言仅一个成功。

## 3. 不可测项标注

无。

## 4. 依赖与前置条件

- DU-BE-401 初始化后库存存在；inventory_reservation 表由 V2 提供。
