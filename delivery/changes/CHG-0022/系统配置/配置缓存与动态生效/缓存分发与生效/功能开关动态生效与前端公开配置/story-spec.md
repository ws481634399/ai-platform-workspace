---
story-id: "STORY-006-02-01-02"
change-spec-ref: "requirement-spec.md#33-story-拆分总表"
scope-refs: [S3]
---

# Story Spec（Story 产品规格）

> 阶段：sdd-prd Story 级产物
> 输入：requirement-spec.md §3.1 [S3]/§4/§5
> 产出状态：specified

## 0. 元信息

- Change ID: CHG-0022
- Story ID: STORY-006-02-01-02 功能开关动态生效与前端公开配置
- Change spec 引用: `requirement-spec.md#33-story-拆分总表`（S3）

## 1. Story 目标

让功能开关产生真实行为控制：明确 DYNAMIC/RESTART_REQUIRED 生效语义；公开开关查询端点 GET /api/mall/public-features 仅返回 publicFlag 配置；落地两个真实消费闭环——search.enabled 关闭后 mall-search 后端拒绝（FEATURE_DISABLED）且 mall-web 隐藏搜索入口，mall.guest-cart.enabled 关闭后 mall-cart 拒绝游客写操作；前端隐藏 + 后端拒绝双生效。

## 2. Scope（范围）

### 2.1 包含

- [S3] effectType 元数据：feature/parameter 管理视图展示生效方式；M5 种子均 DYNAMIC。
- [S3] PublicFeaturesController：GET /api/mall/public-features（permitAll，网关 mall-system 公开路由），仅返回 publicFlag=true 开关 {key,enabled}（含缓存：复用聚合键）。
- [S3] mall-search：搜索接口入口 featureGate.ensureEnabled("search.enabled")（默认 true）；关闭抛 FeatureDisabledException → 统一错误 FEATURE_DISABLED（HTTP 403/409 与错误码 design 定稿）；mall-gateway 新增 /api/mall/public-features → 8108 公开路由。
- [S3] mall-cart：游客写操作（游客加购/游客购物车修改/合并前游客能力）入口校验 mall.guest-cart.enabled，关闭返回 FEATURE_DISABLED；会员正常购物车不受影响。
- [S3] mall-web：stores/features.ts 启动加载 public-features；顶部搜索框/搜索入口 v-if 受控；失败默认策略（公开端点不可达时默认展示，design 明示 fail-open 仅用于 UI 显隐）。
- [S3] mall-admin：配置页按钮/菜单权限已在 STORY-006-01-01-01 完成；本 Story 仅做必要的开关即时刷新体验（保存后本地标记，可选）。

### 2.2 不包含

- 按用户/比例灰度；AI 开关的真实消费（AI 服务尚不存在；键不进种子）。
- RESTART_REQUIRED 参数的重启钩子（机制与标识存在即可，无实际重启类种子）。

## 3. 业务规则

- [后端权威] UI 隐藏不是安全控制：所有受开关保护的写/读能力必须经 FeatureGate；关闭后绕过前端直调 API 返回 FEATURE_DISABLED。
- [默认值] search.enabled、mall.guest-cart.enabled 缺失时代码默认 true（安全默认值按产品文档 §31：高风险写能力默认关闭——这两个键在种子中显式 true；未种子化环境默认值 design 逐键评估，搜索/游客车为已有能力默认 true 避免回归）。
- [公开最小化] public-features 不返回非公开键、不返回系统参数、不返回分组等元信息。
- [生效时延] 后端拒绝路径以 60s 本地缓存 TTL 为上限（与 STORY-006-02-01-01 一致）；管理端改开关后最迟 60s 全服务生效，重启立即生效。
- [会员不受影响] guest-cart 关闭仅约束游客（无 member 身份）的购物车写操作；登录会员的一切行为不变。

## 4. 接口与字段规格

- GET /api/mall/public-features（PUBLIC）→ {features:[{key:"search.enabled",enabled:true}, ...]}。
- 受保护接口关闭时：UnifyResult 错误 {success:false,code:"FEATURE_DISABLED",message:"功能未开启"}，HTTP 403（最终以 design 错误码表为准）。

## 5. Story 验收标准

| ID | 验收标准 |
| --- | --- |
| AC-001 | 未登录访问 /api/mall/public-features 返回 200，仅含 publicFlag=true 开关键与 enabled；非公开键不出现 |
| AC-002 | search.enabled=true 时搜索正常；置 false 后（≤60s）GET /api/mall/search/products 直接返回 FEATURE_DISABLED，错误结构统一 |
| AC-003 | search.enabled=false 时 mall-web 顶部搜索入口隐藏（公开开关刷新后）；重新开启恢复显示与搜索 |
| AC-004 | mall.guest-cart.enabled=false：游客加购/改量被后端拒绝 FEATURE_DISABLED；登录会员加购/下单不受影响；重新开启恢复游客能力 |
| AC-005 | 管理页可见 effectType 标识；修改开关到后端拒绝生效的时延不超过 60s（测试用短 TTL 或重启验证立即生效路径） |
| AC-006 | 公开端点异常（mall-system 宕机）时 mall-web 不因配置加载失败白屏（UI fail-open 或默认值），而服务端 FeatureGate 在缓存全失时按代码默认值决策 |
| AC-007 | 前后端测试全绿（含关闭态后端拒绝的集成测试与前端入口显隐组件测试） |
