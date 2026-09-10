# Test Report — CHG-0006 本地基础设施环境

> change-id: CHG-0006
> implementation-source: implementation.md
> evidence-index: evidence/evidence.yaml
> from-state: developing
> to-state: testing
> tested-at: 2026-09-08T20:33:16+08:00

## 1. 测试范围

### 1.1 repo-4（完成后所有权修订）

| DU | 测试范围 | 测试类型 |
| --- | --- | --- |
| DU-WS-001 | Compose、环境变量、MySQL/Redis、八库、网络、安全与 Scope Guard | 静态 + 集成 |
| DU-WS-002 | 四服务 health、Nacos/MinIO readiness、PowerShell 入口 | 集成 |
| DU-WS-003 | Docker 前置、持久化、两轮运行、mall-identity 联调 | E2E + 跨仓集成 |

测试环境为 Windows 11、PowerShell、Docker Engine 29.4.0、Docker Compose v5.1.1。本机 3306 已被占用，按照端口覆盖契约仅在忽略的 `.env` 使用 MySQL 13306；默认 `.env.example` 仍为 3306。

repo-1 只运行已有 `mall-identity` Jar，不修改源码。测试使用新的 7006 fixture，完成后删除 MySQL 表、Redis key、MinIO object 和测试 Bucket。

## 2. 测试执行汇总

| 分类 | 总数 | 通过 | 失败 | 跳过/PENDING | 通过率（已执行） |
| --- | --- | --- | --- | --- | --- |
| 环境与静态 | 4 | 4 | 0 | 0 | 100% |
| 集成测试 | 8 | 7 | 0 | 1 | 100% |
| E2E 测试 | 2 | 2 | 0 | 0 | 100% |
| 合计 | 14 | 13 | 0 | 1 | 100% |

严格按全部条目计为 92.9%；唯一非 PASS 是规格明确允许的 Java → Redis PENDING，并非测试失败。

### TC/AC 覆盖矩阵

| TC | AC | 结果 | 独立测试结论 |
| --- | --- | --- | --- |
| TC-001 | AC-001 | PASS | Docker Engine/Compose 命令退出码 0 |
| TC-002 | AC-002 | PASS | Compose 可解析且服务集合精确为四项 |
| TC-003 | AC-003 | PASS | 四服务均为 healthy |
| TC-004 | AC-004 | PASS | MySQL 八库存在且 utf8mb4 |
| TC-005 | AC-005 | PASS | Redis 正确密码 PONG、错误密码拒绝 |
| TC-006 | AC-006 | PASS | Nacos Server/Console ready、Standalone |
| TC-007 | AC-007 | PASS | MinIO ready、登录成功、最终无 Bucket |
| TC-008 | AC-008 | PASS | 四服务名在统一网络可解析连接 |
| TC-009 | AC-009 | PASS | 三类数据跨普通 down/up 恢复 |
| TC-010 | AC-010 | PASS | `.env` 忽略且未跟踪，配置契约完整 |
| TC-011 | AC-011 | PASS | 脚本状态/健康/错误码符合约定 |
| TC-012 | AC-012 | PASS | 独立第二轮 up 后四服务恢复健康 |
| TC-013 | AC-013 | PARTIAL | Java MySQL/Nacos PASS；Redis 无入口，PENDING |
| TC-014 | AC-014 | PASS | 无越界服务、业务 DDL/DML 或业务 Bucket |

### 镜像 digest

| 镜像 | RepoDigest |
| --- | --- |
| MySQL 8.4.11 | `sha256:b3b90af2a6552ae30c266fdb7d5dd55f3afb72404bb78d37fe8a23eb857fd3fb` |
| Redis 7.4.11 Alpine | `sha256:ff02b58f971e7d7d156a1267e283fcbbeee91773b6aa36c49dac28ecfe28eadf` |
| Nacos 3.0.3 | `sha256:a223937902d4292e49ce6bcca8c9d47d29d508075b7f7c6ba98e1a34ff9c3f3b` |
| MinIO RELEASE | `sha256:064117214caceaa8d8a90ef7caa58f2b2aeb316b5156afe9ee8da5b4d83e12c8` |

## 3. 证据清单

- `evidence/logs/independent-infra-test.log`：TC-001～TC-014 独立测试摘要。
- `evidence/logs/test-mall-identity.stdout.log`：测试阶段 Java → MySQL/Nacos 原始启动日志。
- `evidence/logs/test-mall-identity.stderr.log`：测试阶段 Java stderr（无错误）。
- `delivery/CHG-0006/.../DU-WS-001/evidence/`：DU-WS-001 代码与红绿灯证据。
- `delivery/CHG-0006/.../DU-WS-002/evidence/`：DU-WS-002 脚本与 readiness 证据。
- `delivery/CHG-0006/.../DU-WS-003/evidence/`：DU-WS-003 开发阶段持久化与 Java 联调证据。

## 4. 失败项分析

无未闭环失败。测试过程中 TC-007 首次发现开发 fixture 的空 Bucket 未删除；已仅删除 `chg0006-persistence-probe` 测试 Bucket并重跑通过。

Java → Redis 保持 PENDING：`mall-identity` 当前 POM 无 `mall-common-redis`/Spring Data Redis 依赖，配置无 Redis properties。该结果符合 AC-013 对“无能力入口必须说明且不得伪造 PASS”的要求。

## 5. 测试结论

13 个 TC 完整 PASS，1 个 TC 的两项能力 PASS、Redis 子项 PENDING，0 FAIL。四服务当前继续保持 healthy，可进入 Test Human Gate。

## 6. 独立基础设施仓迁移回归（2026-09-09）

- 从 `implementation/ai-platform-infrastructure/deploy/` 执行 Compose 静态解析，退出码 0。
- 从新仓启动并等待 MySQL、Redis、Nacos、MinIO，四项均为 healthy。
- 写入临时 Redis 标记后执行普通 `down/up`，标记恢复成功并已删除，证明迁移继续复用命名卷。
- `deploy/` 与 `delivery/CHG-0006/` 只存在于 repo-4，Workspace 根对应实现路径已移除。
- 迁移回归 8/8 PASS；完整日志见 repo-4 的 `DU-WS-003/evidence/logs/repository-migration-verification.log`。

迁移只修正仓库所有权，不改变原 14 条验收标准结论；服务在回归结束后保持 healthy。
