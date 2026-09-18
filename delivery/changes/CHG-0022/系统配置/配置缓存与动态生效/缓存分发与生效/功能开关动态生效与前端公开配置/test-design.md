# Test Design（Verification Intent — 验证意图）

> 阶段：sdd-task 产物（STORY 级）
> 输入：story-spec.md（AC）+ story-design.md（DU 划分）
> 产出状态：tasked

## 0. 元信息

- Change ID: CHG-0022
- Story ID: STORY-006-02-01-02
- Feature Path: 系统配置 > 配置缓存与动态生效 > 缓存分发与生效 > 功能开关动态生效与前端公开配置
- 状态流转: designed → tasked
- TC 总数: 8

## 1. 测试用例

| TC | 验证方式 | verified-by AC | 归属 DU | 备注 |
| --- | --- | --- | --- | --- |
| TC-001 | API：匿名 GET /api/mall/public-features → 200，仅 publicFlag=1 的 [{key,enabled}]；非公开键（参数/私有开关）不出现 | AC-001 | DU-BE-509 | [S1] |
| TC-002 | 集成：search.enabled=true 搜索 200；置 false（短 TTL/手动清缓存后 ≤60s）GET /api/mall/search/products → 403 B0606 FEATURE_DISABLED 统一结构；重开恢复 200 | AC-002 | DU-BE-509 | Integration Gate 场景六 |
| TC-003 | 前端组件：features store 加载后搜索入口 v-if 显隐；false 态访问 /search 显示功能未开放空态；重开恢复 | AC-003 | DU-FE-504 | [S1] |
| TC-004 | 集成：mall.guest-cart.enabled=false → 游客 merge-token/merge 两端点（M4 游客数据进入服务端的唯一写入口）403 B0606；会员 /cart/items 加购 200、读购物车 200 不经开关；匿名直接加购无独立服务端点，关闭态由前端禁用按钮+登录引导拦截；重开游客恢复 | AC-004 | DU-BE-509 | [S1] |
| TC-005 | API/前端：effectType 字段在管理页明示标识（无 RESTART 种子时机制可造一条验证展示）；开关切换到后端拒绝时延 ≤60s（测试用可注入 TTL） | AC-005 | DU-BE-509, DU-FE-504 | [S1] |
| TC-006 | 韧性：mock public-features 503/断网 → mall-web 不白屏、入口默认可见（fail-open）；服务端 Redis+system 全失时 FeatureGate 按代码默认（启用）决策 | AC-006 | DU-BE-509, DU-FE-504 | [S1] |
| TC-007 | 构建门禁：mall-search/mall-cart mvn test 绿；mall-web vitest（入口显隐/403 提示）+ type-check/lint/build 绿 | AC-007 | DU-BE-509, DU-FE-504 | [S1] |
| TC-008 | 网关：匿名经 8080 访问 public-features 200；/api/admin/system-parameters 等未登录 401 | AC-001 | DU-BE-509 | [S1] |

## 2. 测试策略

- 后端：开关切点用切片测试（mock FeatureGate 两态）+ 一条真实开关翻转 IT（TTL 注入缩短）。
- 前端：msw mock public-features 两态，断言入口显隐与错误兜底。
- 浏览器验证开关动态生效整链路放 Integration Gate 场景六。

## 3. 不可测项标注

- 无。

## 4. 依赖与前置条件

- DU-BE-508 缓存客户端；搜索/购物车既有写端点。
