---
id: "ENG-BASE-002"
name: "建立 mall-common 与 mall-contracts 公共基础模块"
content: "建立 mall-common 与 mall-contracts 公共基础模块，形成统一的技术复用层和跨服务契约层，为后续各微服务提供稳定公共能力，同时保持业务领域模型隔离（M0，P0，前置 ENG-BASE-001）"
source: user
created-at: "2026-08-30T15:54:34Z"
---

# Requirement

> 本文件记录需求来源原文，由 sdd-explore 在探索阶段写入。
> 与 exploration.md 分离：本文件是输入沉淀，exploration.md 是分析产物（Feature 归属/影响分析）。
> 原始需求文档已归档至 `references/ENG-BASE-002.md`。

## 需求描述

> 以下为用户提供的原始需求全文（保持原话，未做改写）。

### ENG-BASE-002 建立 mall-common 与 mall-contracts 公共基础模块

类型：**工程基础需求**  
开发阶段：**M0**  
优先级：**P0**  
前置需求：**ENG-BASE-001**

建立 `mall-common` 与 `mall-contracts` 公共基础模块，形成统一的技术复用层和跨服务契约层，为后续各微服务提供稳定公共能力，同时保持业务领域模型隔离。

**重点说明：**  
`mall-common` 只负责共享技术能力，`mall-contracts` 只负责跨服务 API 与事件契约。商品、订单、库存、会员等具体领域模型不得放入公共模块，避免形成强耦合的分布式单体。

#### 需求要求

1. 建立以下 `mall-common` 模块：

```text
mall-common-core
mall-common-web
mall-common-security
mall-common-redis
mall-common-mq
mall-common-openfeign
mall-common-log
mall-common-test
```

2. 建立以下 `mall-contracts` 模块：

```text
mall-api-contracts
mall-event-contracts
```

3. 所有模块必须加入 Maven 多模块工程并参与统一构建。

4. `mall-common` 只允许存放通用技术能力，不得包含：

```text
Product
Order
Inventory
Member
Role
Menu
```

等具体业务领域模型和业务实现。

5. `mall-contracts` 只允许存放：

```text
API Request / Response
内部服务 DTO
集成事件
事件公共元数据
```

不得包含：

```text
Repository
Mapper
PO
ApplicationService
DomainService
领域聚合
```

6. 公共模块依赖关系必须保持清晰，`mall-common-core` 作为基础模块，不应反向依赖 Web、Redis、MQ、OpenFeign 等上层模块。

7. 业务微服务按需依赖公共模块，不得通过 Maven 直接依赖其他业务微服务的实现模块。

8. 本阶段只建立公共模块结构、依赖关系和职责边界，不提前实现后续 Redis、MQ、Security、Feign 等完整业务能力。

#### 验收标准

* `mall-common` 8 个子模块全部存在；
* `mall-contracts` 2 个子模块全部存在；
* 所有模块已加入 Maven Reactor；
* 根目录执行 Maven 全量构建成功；
* `mall-common` 中不存在具体业务领域模型；
* `mall-contracts` 中不存在领域和持久化实现；
* 不存在业务服务之间的直接 Maven 实现依赖；
* 不存在 Maven 循环依赖；
* 各模块职责边界明确。

#### 非本需求范围

本需求不负责实现：

* 统一响应；
* 全局异常；
* JWT / RBAC；
* Redis 业务能力；
* RocketMQ 业务消息；
* OpenFeign 具体业务调用；
* 商品、订单、库存、会员等业务功能。

## 补充信息

- 需求来源：`docs/需求/M0/ENG-BASE-002.md`（原始文档已归档至本 Change `references/`）
- 前置需求：ENG-BASE-001（已由 CHG-0001 交付并归档，见 `delivery/archive/CHG-0001/`）
