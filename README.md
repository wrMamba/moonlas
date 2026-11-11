# MoonLAS

纯 MoonBit 的**有界 LAS 点云二进制处理库**，模块 `wrMamba/moonlas@0.1.0`。
读取 LAS 1.2/1.4 的七种点记录格式，保留点属性和不透明元数据，完成质量检查、筛选、空间裁剪、量化与高程栅格聚合。不依赖 Python、C 点云库或操作系统文件 API。

## 解决什么问题

采集质量检查系统需要核对分类、回波、强度及头部边界；GIS/遥感流水线需要筛出地面点并生成小区域高程栅格；机器人和可视化接入层需要按批解码、统一坐标量化且保留颜色、GPS 和额外属性。MoonLAS 让这些系统共用格式与边界检查，而不是分别实现 LASF 字节偏移和位字段。

本项目不是井测文本 LAS 解析器，不是完整 GIS 引擎，也不是 LAZ 解压器。

## 环境与安装

固定验收工具链：`moonc v0.10.18+6c83a7f62`，`moon 0.1.20261028`。支持 `wasm-gc`、`wasm`、`js` 和 `native` 后端；JS 需要 Node.js，native 需要相应 C 编译器。CI 在 Ubuntu 24.04 对四后端执行严格 check/test/build 与三个示例，另有独立 laspy 参考向量再生成作业。

在新的 MoonBit 项目中：

```sh
moon add wrMamba/moonlas@0.1.0
```

在使用包的 `moon.pkg` 中加入：

```moonbit
import { "wrMamba/moonlas" @las }
```

### 快速开始

下面是完整可运行的 `main.mbt`；包需设置 `pkgtype(kind: "executable")`。

```moonbit
fn main {
  try {
    let p = @las.Point::new(10, 20, 30)
    let points = [p, { ..p, x: 40, classification: 2 }]
    let doc = @las.create(points, 0, @las.Transform::new(0.01), minor=2)
    let raw = @las.encode(doc)
    let parsed = @las.decode(raw)
    let ground = parsed.select({ ..@las.Selection::all(), classifications: [2] })
    println(ground.points.length()) // 1
    println(@las.encode(ground).length()) // 247
  } catch { _ => abort("LAS processing failed") }
}
```

库处理 `Bytes` 而不打开文件；应用自行从文件、网络或对象存储获取字节。错误类型 `LasError` 区分 `Truncated(offset)`、`Limit(message)`、`Invalid(message)` 与 `Unsupported(message)`，调用者可匹配错误而不是终止进程。

## 已交付能力

| 能力 | 具体契约 |
| --- | --- |
| 读写 | LAS 1.2 格式 0/1/2/3；LAS 1.4 格式 0/1/2/3/6/7/8 |
| 点属性 | raw Int32 XYZ、强度、回波、分类、标志、扫描角、来源 ID、用户数据，以及对应格式的 GPS/RGB/NIR |
| 元数据 | 16 字节项目 UUID、文件头标识、VLR 不透明 payload、VLR 到点区的 gap、每点额外字节 |
| 质量审计 | 分类/回波/标志直方图，强度范围与均值、实际边界，发现头部边界/回波统计陈旧 |
| 筛选 | 分类、来源 ID、强度、首/末/单回波、withheld、GPS 闭区间；所有条件取交集，输出顺序不变 |
| 空间操作 | 缩放坐标下的闭 AABB / 球形裁剪，正比例尺和偏移校验 |
| 栅格 | 有界稠密 XY 网格；非空 cell 的点数、class 2 数量、高程最小/最大/均值及平均强度 |
| 量化/拼接 | 半远离零舍入，Int32 溢出检查、调用者显式误差容限；元数据冲突拒绝而非猜测合并 |
| 按需访问 | `open_records`、`seek`、`next`、`batch`；输入仍为完整有界 Bytes，不是磁盘流式 reader |

完整公共接口由 [`pkg.generated.mbti`](pkg.generated.mbti) 给出。数据结构包含可变数组；操作前会重新检查结构，不提供并发/不可变快照保证。

## API 工作流

### 采集检查与修复

```moonbit
let report = doc.audit()
let repaired = doc.with_points(doc.points)
let output = @las.encode(repaired)
```

`decode` 接受可审计的陈旧边界/回波统计；其他非法结构仍报错。`with_points` 重建点数、回波统计、边界、record width、VLR 数量与 offset。`encode` 先要求结构自洽，再规范化派生字段；它不是逐字节原文件归档器。LAS 1.4 输出的 legacy 计数字段为零，读取旧格式时也接受与扩展计数一致的非零 legacy 字段。固定文本字段只保留首个 NUL 之前的可打印 ASCII，后部填充重新置零。

### GIS：地面筛选、裁剪和栅格

```moonbit
let ground = doc.select({ ..@las.Selection::all(), classifications: [2], include_withheld: false })
let area = ground.crop({ min: { x: 0.0, y: 0.0, z: -100.0 }, max: { x: 100.0, y: 100.0, z: 500.0 } })
let grid = area.elevation_grid(2.0)
let cell = grid.at(0, 0) // Cell?；空 cell/越界为 None
```

栅格原点为输入点的实际 XY 最小值，按 `floor((coord-origin)/cell_size)` 分箱。边界最大值恰好位于分界线时落入下一个格；行优先存储。空点集返回 0×0 网格。class 2 仅作数值分类计数，不推断语义正确性或 CRS。

### 接入：批量读取、容限重编码与拼接

```moonbit
let cursor = @las.open_records(input_bytes)
let batch = cursor.batch(256)
cursor.seek(0)
let result = doc.requantize(@las.Transform::new(0.02), 0.011)
let output_bytes = @las.encode(result.document)
let joined = doc.merge(other_doc, 0.011)
```

`requantize` 返回实际各轴最大误差，超容限拒绝。不是坐标参考系转换。`merge` 要求版本、点格式、额外字节宽度、global encoding、项目/文件标识、VLR 和 gap 相同；右侧量化到左侧坐标编码，保留左侧头部来源/日期/软件信息。仅比例尺不同并不证明 CRS 相同，应用必须保证坐标系一致。

## 三个可运行场景

以下输入均为仓库内原创合成数据，不依赖网络或私人点云。

```sh
moon run examples/quality --deny-warn  # 120 点质量统计，剔除 withheld/低强度，101 点输出
moon run examples/terrain --deny-warn  # 地面筛选与裁剪，3×3 网格，CSV 统计输出
moon run examples/ingest --deny-warn   # 格式 8，64 点分批读取，量化、球裁剪，27 点输出
```

## 资源、安全与已知限制

- 默认输入/序列化预算 64 MiB、点数 1,000,000、VLR 4096、网格 1,000,000 格；可通过 `Limits` 显式调整。安全上限分别为 1 GiB、10,000,000 点、65,535 VLR、10,000,000 格。预算不等于进程峰值内存保证；数组、元数据和输出会复制。
- 64 位头部计数仅接受高 32 位为零且低位在预算内，不支持任意 64 位规模文件。乘法、偏移和分配前检查，失败返回错误。
- LAS 1.0/1.1/1.3、格式 4/5/9/10、LAZ/压缩位、waveform、EVLR、扩展公共头、尾随数据和未知 global encoding 位不支持。
- 严格子集：回波编号必须从 1 开始且不超过总回波，旧格式最多 5；0 回波记录拒绝。GPS/坐标/比例尺/偏移必须有限，比例尺必须为正；旧扫描角范围 [-90,90]，现代 raw 扫描角 [-30000,30000]（单位 0.006°）。
- 固定字段仅支持可打印 ASCII；不解释 Extra Bytes schema、GeoTIFF/WKT 或 CRS、不做重投影。VLR payload 与点额外字节按不透明字节保留。
- 空间筛选为线性扫描，栅格为有预算的稠密矩阵；不是通用八叉树、最近邻库、渲染器、DTM 插值器或生产级超大文件服务。
- 边界/直方图审计为精确值比较；浮点量化需要结合应用误差容限。解析器会检查结构，但未做安全审计认证，也不保证任意合法 LAS 均可处理。

## 验证与复现

```sh
moon info
moon fmt --check
moon check --deny-warn --target wasm-gc
moon test --deny-warn --target wasm-gc
moon build --deny-warn --target wasm-gc
python tools/audit_source.py
```

将目标替换为 `wasm`、`js`、`native` 可复核其他后端。当前 45 个测试：包括 11 份由 **laspy 2.6.1 / numpy 2.2.6** 生成的文件、352 条独立记录逐字段读取与更改后完整写入字节对照、1792 条自生成属性组合、截断前缀、预算、冲突和三个下游流程。

独立向量再生成请使用隔离 Python 3.12 环境：

```sh
python -m venv .oracle-env
# 激活该环境后：
python -m pip install laspy==2.6.1 numpy==2.2.6
python tools/generate_oracles.py
moon fmt
# 生成物应与提交版本一致：
git diff --exit-code -- reference_wbtest.mbt tools/oracle-manifest.json
```

实质生产源码的物理行/非空非注释行由 inventory 脚本输出；测试、生成的参考向量、示例和接口均不计入。没有发布性能优越性或实测用户规模声明。

## 来源、许可与 AI

原创 MoonBit 实现，MIT；仅使用 MoonBit core。行为参考 [laspy](https://github.com/laspy/laspy)（BSD-3-Clause），不复制其实现、测试或数据。详见 [NOTICE](NOTICE)、[AI-USE.md](AI-USE.md)、[架构与安全](docs/architecture.md)、[语义查重](docs/competition/duplicate-check.md)。AI 参与实现、测试、调试与文档，测试结果不等于官方赛事验收；本流程不自动报名。
