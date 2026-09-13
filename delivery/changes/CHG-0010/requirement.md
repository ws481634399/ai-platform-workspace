---
id: "REQ-M2-001"
name: "分类与品牌管理"
content: "按 docs/需求/M2/M2.md 中 REQ-M2-001 建立商品分类与品牌基础数据管理能力，为后续 Product 和 SKU 提供稳定商品组织基础。"
source: requirement-doc
created-at: "2026-09-13T02:40:00.000Z"
---

# Requirement

> 原始需求全文归档于 `references/M2.md`，本文件记录本 Change 的输入边界。

## 需求描述

按 `docs/需求/M2/M2.md` 中 `REQ-M2-001 分类与品牌管理` 执行完整 SDD。建立 mall-product 下 Category（树形、层级、启停、排序）与 Brand（名称、Logo、描述、启停、排序）基础数据管理能力，并通过 mall-admin 后台管理页面维护（列表/树、新增、编辑、启停），操作接入 M1 已建立的 RBAC 权限体系。

核心约束：分类不能成为自己的父节点、不能形成循环层级、不允许引用不存在的父分类、已被商品使用的分类删除需受限制、排序稳定；品牌启用/禁用；商品不能绑定无效分类与品牌；M2 不实现 Product/SKU/上下架/库存/ES/AI。不因方便直接物理删除已产生业务引用的分类。

## 补充信息

- 优先级：P0
- 前置依赖：REQ-M1-002（后台 RBAC 权限体系）、REQ-M1-003（后台动态菜单与权限前端）
- 主要服务：mall-product
- 主要前端：mall-admin
- 主要仓库：repo-1、repo-2
- 领域边界：Product Context（Category、Brand 属于商品权威数据）