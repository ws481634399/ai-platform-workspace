# 测试规范

> 版本：v0.1  
> 类型：工程通用规范  
> 作用域：OpenSpec Workspace


# 1. 文档目的


本文档定义软件开发过程中的测试要求、验证流程和测试证据管理规范。


目标：

- 保证代码修改符合预期；
- 降低功能回归风险；
- 建立可追踪的质量验证流程；
- 为 AI Coding Agent 提供明确的测试执行标准。


---

# 2. 测试基本原则


## 2.1 测试是 Change 的一部分


测试不是开发完成后的额外步骤。


每个 Change 都应该包含：

```
需求

↓

实现

↓

验证

↓

证据
```


测试结果属于 Change 的交付证据。


---

## 2.2 测试应该覆盖风险


测试重点应该围绕：

- 业务核心流程；
- 关键数据变化；
- 高风险代码修改；
- 外部接口交互。


不是简单追求测试数量。


---

## 2.3 自动化优先


对于重复执行的验证：

优先使用自动化测试。


例如：

- 单元测试；
- 集成测试；
- API测试；
- 自动化回归测试。


---

# 3. 测试类型


OpenSpec 支持以下测试类型。


---

# 3.1 单元测试


目的：

验证单个模块或组件的正确性。


适用于：

- 方法逻辑；
- 服务层逻辑；
- 工具类。


示例：


```
OrderServiceTest
```


要求：

- 测试逻辑清晰；
- 覆盖关键分支；
- 不依赖外部环境。


---

# 3.2 集成测试


目的：

验证多个模块协作。


适用于：

- 服务调用；
- 数据库交互；
- 消息通信。


例如：


```
OrderServiceIntegrationTest
```


---

# 3.3 API测试


目的：

验证接口行为。


应该验证：


- 请求参数；
- 返回结构；
- 状态码；
- 异常情况。


---

# 3.4 端到端测试


目的：

验证完整业务流程。


例如：


```
用户下单

↓

支付

↓

订单完成
```


适用于：

核心业务流程验证。


---

# 4. 测试设计规范


## 4.1 测试应该对应需求


测试应该能够回答：


```
需求是否被正确实现？
```


示例：


需求：

```
用户可以取消订单
```


测试：

```
订单取消成功

取消后库存恢复

已支付订单不可直接取消
```


---

## 4.2 测试数据明确


测试应该明确：

- 输入数据；
- 执行条件；
- 预期结果。


避免：

依赖不明确的环境状态。


---

## 4.3 测试结果可验证


测试结果应该包含：

- 成功或失败；
- 执行时间；
- 环境信息；
- 失败原因。


---

# 5. 测试命名规范


测试名称应该表达行为。


推荐：

```
shouldCancelOrderWhenStatusIsPending()
```


避免：

```
test1()

testOrder()
```


---

# 6. 测试覆盖要求


测试重点覆盖：


## 核心业务


必须覆盖：

- 正常流程；
- 异常流程；
- 边界情况。


---

## 数据变化


涉及数据修改时：

需要验证：

- 数据正确性；
- 状态变化；
- 一致性。


---

## 接口变化


API修改需要验证：

- 新接口行为；
- 兼容性；
- 错误处理。


---

# 7. AI Coding Agent 测试规则


AI 修改代码后必须考虑测试。


执行流程：


```
读取 Change

↓

理解 Design

↓

修改代码

↓

执行测试

↓

生成测试证据
```


---

AI 不应该：


- 跳过测试验证；
- 声称未执行的测试已通过；
- 删除失败测试隐藏问题。


---

# 8. 测试证据管理


测试结果应该保存在 Change 中。


目录：


```
delivery/

└── changes/

    └── CHG-XXX/

        └── evidence/

            └── test-report.md
```


---

测试报告建议包含：


```markdown
# Test Report


## Change

CHG-XXX


## Test Environment

开发环境


## Executed Tests

- Unit Test

- Integration Test


## Result

PASS


## Notes

无异常
```

### 8.1 Evidence YAML 中 commit sha 一律加引号（CHG-0025 晋升）

evidence.yaml 等证据文件中，所有 commit sha（尤其短 sha）必须以双引号包裹：

- YAML 1.1 将含 `e` 的形如 `967e359` 的 token 按科学计数法解析（→ Infinity），
  Gate 读取到的 commit 值与真实提交完全不符。
- 即便是不含 `e` 的 sha 也统一加引号，保持口径一致，避免后续截断换短 sha 时踩坑。

> 来源：CHG-0025 sdd-review：未加引号的 sha 被解析为 Infinity 致 Gate 失败。


---

# 9. 测试失败处理


测试失败时：


不能直接忽略。


应该记录：


- 失败原因；
- 影响范围；
- 修复方案。


必要时创建：


```
delivery/reports/unresolved/
```


---

# 10. 测试与 Change 生命周期


测试对应 Change 流程：


```
Requirement

↓

PRD

↓

Design

↓

Implementation

↓

Testing

↓

Evidence

↓

Converge
```


没有验证证据的 Change 不应进入完成状态。


---

# 11. 测试环境管理


测试环境应该明确：


- 环境类型；
- 配置版本；
- 数据来源；
- 依赖服务。


避免：

测试结果无法复现。


---

# 12. 测试检查清单


提交前检查：


```
[ ] 测试范围明确

[ ] 核心逻辑已验证

[ ] 异常场景已覆盖

[ ] 测试结果已记录

[ ] 测试证据已保存

[ ] 失败问题已处理
```


---

# 13. Spring Boot 微服务集成测试补充约定

> 来源：M2（CHG-0010 分类与品牌）实践沉淀；适用于 mall-* 全部服务的 @SpringBootTest 集成测试。

## 13.1 H2 与 MySQL 的大小写敏感性差异

- 事实：MySQL 8 业务库使用 `utf8mb4_0900_ai_ci`，字符串等值与唯一索引大小写不敏感；H2 2.x（即使 `MODE=MySQL`）默认字符串比较**大小写敏感**。
- 约定：凡依赖 ci 语义的唯一字段（名称、编码等），仓储层必须以参数化归一比较（如 `LOWER(col) = LOWER({0})`，禁止字符串拼接）做应用层预判，同时保留数据库唯一索引承担并发终判；测试中须分别覆盖"大小写/首尾空格差异"与"完全同名并发"两类用例。

## 13.2 MyBatis-Plus 分页插件依赖

- MyBatis-Plus 3.5.9 起 `PaginationInnerInterceptor` 的 JSqlParser 支持拆至独立模块 `mybatis-plus-jsqlparser`；使用分页必须显式引入该依赖（版本由 BOM 管理），否则编译期找不到符号。

## 13.3 测试安全切片

- 生产安全配置以 `@Profile("!test")` 隔离时，集成测试必须自带 `@TestConfiguration` 安全链（临时 JWT 编解码器 + 与生产一致的 issuer/audience + 401/403 JSON 响应）。
- 方法级 `@PreAuthorize` 抛出的 `AccessDeniedException` 需要独立的 `@RestControllerAdvice` 转换为 403；仅依赖通用全局异常处理器会将授权失败泄漏为 500。
- 同一服务多个集成测试类共享同一套测试安全配置时，抽取为 `src/test/.../support/` 下的公共 `@TestConfiguration`，禁止复制多份。

## 13.4 编译器参数名保留

- 依赖反射读取参数名的场景（Spring MVC `@PathVariable` 未显式指定 value 等）要求编译开启 `-parameters`；根 pom 的 `maven-compiler-plugin` 统一配置 `<parameters>true</parameters>`，子模块不得关闭。

## 13.5 并发唯一性测试模式

- 验证数据库唯一约束的并发测试使用 `CountDownLatch`（就绪闸 + 启动闸）+ 固定线程池，断言"成功数恰为 1、其余得到冲突业务错误、库中 COUNT=1"，并在 finally 中关闭线程池；Runnable lambda 内的受检中断异常必须就地捕获。
- 注意 H2 内存库可能把并发冲突串行化为多个成功：用例须容忍「恰好一成」与「全部成功但最终 COUNT=1」两种结局，凡失败必须断言为预期的业务冲突错误码；真实 MySQL/PostgreSQL 下的必现冲突在集成测试阶段（真实两进程 + 真实 DB）复验，不得只凭 H2 宣告并发安全。

## 13.6 H2 对 MySQL 生成列 DDL 的兼容写法

- H2（MODE=MySQL）既不识别 MySQL 方言 `IF()` 函数，也不识别计算列的 `STORED` 关键字；
  跨两库的生成列统一写标准 `CASE WHEN ... THEN ... ELSE ... END` 且省略 `STORED`
  （MySQL 8 默认 VIRTUAL；UNIQUE 索引对虚拟生成列仍物化键值，唯一性语义等价）。
- H2 2.x `INFORMATION_SCHEMA.INDEXES` 没有 `IS_UNIQUE/UNIQUE` 列，唯一性别查
  `INDEX_TYPE_NAME LIKE '%UNIQUE%'`；唯一约束自动生成的支持索引名会带 `_INDEX_n`
  后缀，断言按前缀 LIKE 匹配；冲突异常文案中的索引名可能为小写，不要依赖忽略大小写的
  断言（assertj 无对应 API），直接按实测文案断言。

## 13.7 ECJ 增量编译残留错误桩类

- `test-compile` 曾失败后直接跑 `test`（不带 clean），ECJ 增量编译可能已向
  `target/test-classes` 输出「Unresolved compilation problem」错误桩类，导致整类用例
  初始化 Error 而非真实失败。出现整类 `java.lang.Error` 时先 `mvn clean test` 全量重编；
  验证脚本统一走 `clean test` / `clean package`。

> 13.6/13.7 来源：CHG-0016（shipping_address V2 生成列默认唯一，Flyway 干净库迁移验证）。

---

# 14. 总结


测试规范用于保证：

```
需求

+

代码实现

+

质量验证

+

交付证据
```


形成完整闭环。


通过测试规范，AI Coding Agent 能够：

- 理解验证要求；
- 执行正确测试；
- 生成可靠证据；
- 支持持续交付。
