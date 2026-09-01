---
id: STORY-2
name: 建立 mall-common 与 mall-contracts 公共基础模块
level: story
status: delivered
bound-chg: CHG-0002
---

# 建立 mall-common 与 mall-contracts 公共基础模块

mall-common 8 技术子模块 + mall-contracts 2 契约子模块的职责边界与依赖方向治理 (ENG-BASE-002)

> 绑定 Change：`CHG-0002`（验收核验型，关联历史 CHG-0001）
>
> 核验结论（2026-08-31）：AC-1~AC-10 复验全部通过——静态 POM 审计（R1~R4 规则集）零违规；
> mall-common-core / mall-api-contracts / mall-event-contracts 依赖树均仅自身坐标（零依赖，core 无
> Web/Redis/MQ/OpenFeign 反向依赖）；mvn validate 24 项目全绿。审计基线 350304b 零漂移，
> 证据见 `delivery/changes/CHG-0002/`STORY 目录 `evidence/`（ac-verification.md + logs/ 4 文件）。
