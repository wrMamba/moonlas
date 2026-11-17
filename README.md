# MoonLAS

纯 MoonBit 的 LAS 点云读写与处理库，MIT 许可。面向采集质量检查、GIS 地面点处理和点云接入服务，将点属性处理与标准元数据保留放在同一个工作流中。

**0.2.0** 以未压缩 LAS 1.4 的全部点格式及文件结构为实现目标，并兼容 LAS 1.1–1.3。覆盖公共头、VLR、EVLR、0–10 点格式、内部/外部波形引用、Extra Bytes 与投影记录；具体版本矩阵和资源边界见 [LAS 兼容性](docs/las-compatibility.md)。不是 LAZ 解压器，也不提供 CRS 重投影。

## 安装与环境

```sh
moon add wrMamba/moonlas@0.2.0
```

在 `moon.pkg` 中导入：

```moonbit
import {
  "wrMamba/moonlas" @las,
}
```

仓库固定 MoonBit `0.10.18+6c83a7f62`。CI 对 `wasm-gc`、`wasm`、`js`、Linux `native` 执行检查、测试、构建和四个示例。库只依赖 MoonBit core；调用者负责把文件读入 `Bytes` 和保存输出。

## 快速开始

```moonbit
fn main {
  try {
    let doc = @las.create([
      { ..@las.Point::new(100, 200, 30), classification: 2 },
      { ..@las.Point::new(120, 220, 40), classification: 1 },
    ], 0, @las.Transform::new(0.01))
    let input_bytes = @las.encode(doc)
    let parsed = @las.decode(input_bytes)
    let ground = parsed.select({ ..@las.Selection::all(), classifications: [2] })
    let output_bytes = @las.encode(ground)
    assert_eq(@las.decode(output_bytes).points.length(), 1)
    println("accepted=1; format=0")
  } catch {
    _ => abort("LAS workflow failed")
  }
}
```

坐标原始整数与 scale/offset 分开保存。`Transform::position` 计算物理坐标；`requantize` 仅修改量化编码并报告各轴最大误差，不转换坐标系。

## 点属性、质量检查与地形

- 所有点格式 0–10 的整数坐标、强度、回波、分类及标志、扫描角、用户数据、来源、GPS、RGB、NIR、波形字段按对应格式读取和写出。
- `Document::audit` 计算分类、回波、标志、边界和强度统计，并报告头部统计不一致。
- `select`、`crop` 与 `within_radius` 生成新文档；`elevation_grid` 输出有预算的稠密网格，地形示例将格网统计写成 CSV。
- `open_records` 提供基于输入 `Bytes` 的游标，支持 `batch`、`seek`，避免一次建立全部 Point 对象；它不是磁盘流式读取器。
- `merge` 要求版本、点格式、额外字节宽度、项目/文件标识、global encoding、VLR、扩展头、间隙、尾部及元数据相对位置兼容，右侧按左侧坐标编码重新量化。应用负责确认 CRS 相同。

## 元数据与波形

`decode` 保留未知 VLR/EVLR、保留字、固定文本原始字节、扩展头字节、点前间隙、每点额外字节及点后尾部。`with_points` / 筛选 / 编码会重算点数和边界，并随点区长度变化重定位 EVLR 与内部波形绝对偏移。普通处理不删减波形记录，允许保留未引用的数据包。

```moonbit
let records = parsed.evlrs()
let projection = parsed.projection_records()
let dimensions = @las.extra_dimensions(parsed.vlrs, parsed.header.record_length - 20)
```

最后一行的 `20` 仅适用于点格式 0 的基础宽度。其他格式基础宽度见兼容性表。Extra Bytes 解析全部 30 种数值类型和未类型化字节区，保留 no-data/min/max/scale/offset；`extra_values` 返回精确整数或浮点值，scale/offset 由应用显式使用，64 位 ID 不转成 Double。GeoTIFF/WKT 记录按原字节获取与保留，不求解投影。LAS 1.4 格式 6–10 的生产数据应设置 WKT global encoding 位并提供适当的 WKT 记录。

```moonbit
let amplitudes = waveform_doc.waveform_samples(waveform_doc.points[0])
let external_samples = waveform_doc.waveform_samples(
  waveform_doc.points[0], external=Some(wdp_bytes),
)
```

波形格式为 4/5/9/10，内部记录及调用者提供的外部 `.wdp` 均可访问。包偏移以 60 字节波形记录头起点为基准；支持无压缩 8/16 位样本并应用 gain/offset。其他编码原样保留，样本解释返回 `Unsupported`。`with_evlrs` 显式替换 EVLR 链并重定位波形，拒绝删除仍被点引用的内部波形记录。

## 四个可运行工作流

```sh
moon run examples/quality --deny-warn
moon run examples/terrain --deny-warn
moon run examples/ingest --deny-warn
moon run examples/waveform --deny-warn
```

输入均为原创合成数据。质量示例从 120 点筛至 101 点；地形示例生成 3×3 高程网格；接入示例分批读取 64 点并裁剪至 27 点；波形示例将格式 10 的两点筛至一点，验证三个 EVLR、WKT、四个波形样本及偏移全部有效。

## 资源与能力边界

默认预算：64 MiB 输入/输出、1,000,000 点、4096 个 VLR/EVLR、1,000,000 网格单元。`Limits` 可显式调整，安全上限为 1 GiB、10,000,000 点、65,535 条记录、10,000,000 网格单元。预算不代表峰值内存保证，元数据与数组可能复制。磁盘上的 64 位长度/计数在分配前验证预算，波形引用与 Extra Bytes 的 64 位数值保全原始位宽。

支持范围为 LAS 1.1–1.4 的未压缩容器；不覆盖 LAS 1.0、1.5、LAZ、压缩波形解码、大文件磁盘流式 IO、重投影、DTM 插值或空间索引。非有限坐标/GPS、零比例尺、非法回波关系、越界扫描角、损坏偏移与超预算输入返回错误。有限负比例尺可用。解析并不保证畸形文件可修复；保留元数据也不等于通用文件逐字节拷贝，编码会规范化派生统计。

## 验证与复现

```sh
moon info
moon fmt --check
moon check --deny-warn --target wasm-gc
moon test --deny-warn --target wasm-gc
moon build --deny-warn --target wasm-gc
python tools/audit_source.py
```

可把目标改为 `wasm`、`js`、`native`。当前 **84 项测试**，独立参考数据包含 laspy 2.6.1 / numpy 2.2.6 生成的 23 个版本/格式组合、736 点，以及 12 个内外波形文档、96 点，共 **35 个文档、832 点**。测试比较读取字段、完整写出字节与修改后写出字节，另覆盖 12 个波形筛选输出；自生成属性矩阵为 2816 个组合，单独计数。

在独立 Python 3.12 环境安装固定依赖后再生：

```sh
python -m pip install laspy==2.6.1 numpy==2.2.6
python tools/generate_oracles.py
python tools/generate_waveform_oracles.py
moon fmt
git diff --exit-code -- reference_wbtest.mbt waveform_reference_wbtest.mbt tools/oracle-manifest.json tools/waveform-oracle-manifest.json
moon test --deny-warn
```

## 0.1.0 迁移

新增的公开字段包括 `Point.waveform`、`Document.tail`、头部扩展及 EVLR/波形偏移、记录保留字与原始文本。优先使用 `Point::new`、`Vlr::new`、`Evlr::new` 和 record update 语法，避免手写所有结构字段。旧版仅支持格式 0/1/2/3/6/7/8 的范围已扩展；新版本会保留以前拒绝的 EVLR、波形及尾部。

## 来源与许可

原创 MoonBit 实现，MIT；参考 [ASPRS LAS 1.4 标准](https://github.com/ASPRSorg/LAS/tree/main-1.4) 的字段定义。行为对照 [laspy](https://github.com/laspy/laspy)（BSD-3-Clause）；不复制其实现、测试或数据。详见 [NOTICE](NOTICE)、[AI 使用说明](AI-USE.md)、[架构](docs/architecture.md)、[兼容性](docs/las-compatibility.md)、[选题研究](docs/competition/duplicate-check.md)。
