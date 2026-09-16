# Implementation（跨仓实施汇总）— CHG-0018 购物车

> 阶段：sdd-dev 产物。本文件为 Change 级跨 Story 汇总，各 Story 实施正文见对应 Story 目录。

## 0. 元信息

- Change ID：CHG-0018（购物车）
- 实施日期：2026-09-16
- 范围：购物车核心操作（写）、购物车实时校验（读模型）、游客购物车与登录合并

## 1. Story 实施总览

| Story | DU | 仓库 | 状态 |
| --- | --- | --- | --- |
| STORY-003-03-01-01 购物车核心操作 | DU-BE-801 / DU-FE-802 | repo-1 / repo-2 | completed |
| STORY-003-03-01-02 购物车实时校验 | DU-BE-802 | repo-1 | completed |
| STORY-003-03-02-01 游客购物车与登录合并 | DU-BE-803 / DU-FE-801 | repo-1 / repo-2 | completed |

## 2. 各 Story 实施引用

- Story 1：`delivery/changes/CHG-0018/商城前台/购物车/会员购物车/购物车核心操作/implementation.md`
- Story 2：`delivery/changes/CHG-0018/商城前台/购物车/会员购物车/购物车实时校验/implementation.md`
- Story 3：`delivery/changes/CHG-0018/商城前台/购物车/游客购物车与合并/游客购物车与登录合并/implementation.md`

## 3. 关键技术决策

1. Redis Hash 存会员车（`cart:member:{memberId}`），Lua 单脚本原子写。
2. 合并 token 一次性（String，TTL 300s，Lua 内 DEL 消费）。
3. 读模型跨服务批量装配（product + inventory 各一次），依赖故障条目级 UNKNOWN。
4. 游客车 LocalStorage 持久化，登录后自动合并（token 失效重取一次，网络失败保留）。
