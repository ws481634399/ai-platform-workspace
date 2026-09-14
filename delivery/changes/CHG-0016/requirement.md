---
id: "REQ-M3-001"
name: "商城会员与地址"
content: "在 M1 统一身份认证基础上实现商城 MEMBER 主体的注册、登录、会话、会员资料与收货地址；MEMBER 与 ADMIN 严格隔离，Identity 与 Member Profile 边界清晰，资源归属后端强校验。"
source: requirement-doc
created-at: "2026-09-14T07:00:00.000Z"
---

# Requirement

> 原始需求全文归档于 `references/M3.md`（REQ-M3-001 第一至十一章 + 文末注意点 2、3），本文件记录本 Change 的输入边界。

## 需求描述

按 `docs/需求/M3/M3.md` 中 `REQ-M3-001 商城会员与地址` 执行完整 SDD。在 M1 已建立的 Access Token / Refresh Token / SubjectType / Gateway Authentication / SecurityContext 基础上，正式实现商城 MEMBER 主体能力，普通消费者可在 mall-web 完成：注册、登录、刷新登录状态、退出、查看/修改个人资料、管理收货地址、设置默认地址。

**首期注册/登录方式（M3.md 文末注意点 2 的明确决策，不再留待 Design）：**

- 用户名 + 密码注册；
- 用户名 + 密码登录；
- 手机号、邮箱仅作为会员资料字段（可在资料维护中填写）；
- 短信/邮件验证码注册与登录**不做**，顺延后续阶段（不引入通知服务、验证码限流/防刷/有效期）。

**Identity 与 Member 创建一致性（M3.md 文末注意点 3 的明确决策）：**

- mall-identity 创建 Identity 成功后，通过事件驱动 mall-member 幂等初始化 Member Profile；
- Profile 初始化按 memberId 幂等，失败可重试，不产生不完整/重复会员数据；
- 禁止跨库事务、禁止跨服务直接写表；
- 接受注册后短暂最终一致，并提供补偿路径（如登录后按身份懒补偿/重试初始化）。

**边界（必须保持，不得为方便合并）：**

- mall-identity 管理：memberId、登录账号、passwordHash、认证状态、Refresh Token、账户锁定、登录安全信息；密码修改归 mall-identity；
- mall-member 管理：memberId、nickname、avatar、profile、address 等会员业务资料；昵称修改归 mall-member；
- mall-member 禁止再保存一套登录密码。

**安全要求（两层检查）：**

- 认证：Current Subject Type = MEMBER；MEMBER Token 不允许作为 ADMIN 访问后台，反之亦然；
- 资源归属：Current Member = Resource Owner。地址等私有数据后端必须校验 `Address.memberId == CurrentMember.memberId`，不能只依赖前端不显示。

**收货地址：** 列表、新增、修改、删除、设置默认、查询默认；字段至少含 receiverName/receiverPhone/province/city/district/detailAddress/postalCode（按需）/isDefault；同一会员仅一个默认地址，设置新默认时正确处理原默认；删除默认地址后的策略由 Design 明确（无默认或自动转移）。

**会员资料：** 查看资料、修改昵称、修改头像（可使用 MinIO）、必要基础信息；不做等级/积分/成长值等营销体系。

**mall-web 登录态：** 统一管理 memberId、登录状态、Access Token、必要会员信息；支持刷新恢复、Access Token 过期处理、Refresh Token、退出、401 统一处理；禁止每页各自实现 Token 逻辑。

## 补充信息

- 优先级：P0
- 前置依赖：REQ-M1-001（统一身份认证）；M3 前置就绪修复 CHG-0015（字符串 ID、网关路由）
- 主要服务：mall-identity、mall-member
- 主要前端：mall-web
- 主要仓库：repo-1、repo-2
- 非本需求范围：RBAC/管理员、商品、购物车（CHG-0018）、订单、支付、优惠券、积分、会员等级、短信/邮件验证码、通知服务。
