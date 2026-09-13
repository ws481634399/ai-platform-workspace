# Implementation（跨仓实施汇总）— SKU 与规格管理 STORY-002-02-02-01

> 阶段：sdd-dev 产物。本文件只做跨仓引用汇总，实施正文在各实现仓 DU 目录。

## 0. 元信息

- Change ID: CHG-0011
- Story: STORY-002-02-02-01 SKU 与规格管理
- Test Design 来源: 本目录 test-design.md
- DU Task 来源: repo-1 DU-BE-305 task-design.md / task-spec.md
- 状态流转: tasked → developing
- 开始时间: 2026-09-13

## 1. Delivery Unit 状态总览

| DU        | 仓库                          | 状态      | Baseline | Result  |
| --------- | ----------------------------- | --------- | -------- | ------- |
| DU-BE-305 | repo-1（ai-platform-backend） | completed | 7cba45e  | 23a1dfb |

> 跨 Story 依赖：DU-BE-305 依赖 STORY-002-02-01-01 的 DU-BE-304（Product 聚合根与仓储），该依赖在 requirement-design §6 声明，不在本 Story DU 表中引用。

## 2. Commit 记录

| Commit  | DU        | 仓库   | 说明                                                       |
| ------- | --------- | ------ | ---------------------------------------------------------- |
| 7cba45e | DU-BE-305 | repo-1 | 开发基线（非本 DU 改动）                                   |
| 23a1dfb | DU-BE-305 | repo-1 | feat(product): 商品 SPU 与 SKU 管理后端                    |
| c65e75b | DU-BE-305 | repo-1 | docs(sdd): CHG-0011 DU-BE-304/305 任务产物                 |
| 6feacef | DU-FE-303 | repo-2 | 开发基线（非本 Story 改动）                                |
| f14ead4 | DU-FE-303 | repo-2 | feat(product): 商品 SPU 与 SKU 管理前端（非本 Story 改动） |

## 3. 各仓实施引用

### repo-1（ai-platform-backend / mall-product）

- DU implementation: implementation/ai-platform-backend/delivery/CHG-0011/商品与库存/商品与 SKU 管理/SKU 与规格/SKU 与规格管理/DU-BE-305/implementation.md
- 范围：Sku 聚合（规格组合 SHA-256 唯一哈希、Money 分价、SkuStatus 启停）、Product 聚合 addSku/updateSku/enableSku/disableSku 行为、ProductApplicationService SKU 子资源端点、Flyway V3（product_sku，含 uk_sku_code 与 uk_product_spec_hash）。
- 关键决策：specification_data 列以 VARCHAR 存储 JSON 字符串（避免 MyBatis-Plus 对 `_json` 列名自动套用 JacksonTypeHandler 导致双重序列化）；SKU 随 Product.update() 全量替换（delete+insert）。

## 4. Fan-in 状态

- [x] 所有 DU 物化完成（du-materialized）
- [x] 所有 DU 进入 testing（du-fan-in-testing）
- [x] 所有 DU completed（du-fan-in-complete）
