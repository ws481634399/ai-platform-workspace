---
id: "REQ-M0-M2-REMEDIATION"
name: "M0-M2 验收缺口补全"
content: "补全 M1/M2 已明确但未完整落地的功能；不做手机端，mall-web 商城页面归 M3。"
source: user
created-at: "2026-09-13T15:40:00.000Z"
---

# Requirement

## 需求描述

用户原始请求：“不做手机端，你补全未完成的。”

用户范围更正：“mall-web 消费这些 API 做出真正的商城页面（商品列表、商品详情），按 需求M1.md 的里程碑划分属于 M3 商城会员阶段。”

## 补充信息

- 包含：M2 商城/内部商品 API 可达性、Product+至少一个 SKU 原子创建、mall-admin 图片/属性/SKU 完整维护、Inventory 内部接口 SERVICE 授权、M1 lint/401 回归。
- 不包含：手机端；mall-web 商品列表/详情页；会员、购物车、订单。

