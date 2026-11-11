# 选题与语义查重记录

核验日期：2026-11-11。账号：wrMamba。对象：`wrMamba/moonlas@0.1.0`。本记录是有范围、有访问限制的工程研究，不是官方查重裁决，也不主张绝对唯一。

## 需求基线与候选选择

未声称参赛者具有未提供的行业经历。需求依据是成熟跨语言点云工具 laspy/PDAL 与 LAS 点记录格式：采集 QC、GIS 地面点高程聚合、机器人/可视化批量接入均需共享二进制格式及属性保留能力。完整核心限定为内存 Bytes 输入输出，不以未来文件服务、渲染器或压缩功能充当成果。

执行了已安装 `osc2026-guide` 的 Project Research Guide：先检索生态、查看近邻接口与实现/测试，再比较核心工作流及维护状态。赛事口径沿用本构建 Skill 的 2026 年 9 月新生态建设要求，不把研究 Skill 的其他赛道入口当作报名操作。

以下 1–5 分是选题判断，不是用户调查、性能测量或官方评分。硬性直接重复优先于分数。

|不同领域候选|需求/通用性|复用/深度|验证/可交付|重合风险|结果|
|---|---|---|---|---|---|
|IMU 姿态融合（Madgwick/Mahony）|4|4|4|高：sensor_driver 已列出融合器，另有相机/坐标库|淘汰；不把访问不到源码当作空白|
|EDF/EDF+ 生理信号记录 IO|4|4|4|高：现有 `peng-jun21/edf` 已实现头部/记录读写|淘汰；已有直接替代|
|LAS 点云二进制及属性处理|5|5|4|邻近几何、栅格和井测文本库；未在本范围确认成熟直接替代|选择有界子集，见下表与限制|

三个可执行闭环分别为 `examples/quality`（采集点→审计和属性筛选→LAS）、`examples/terrain`（地面点→空间裁剪/高程统计→CSV）、`examples/ingest`（格式8记录→分批游标/量化/球裁剪→LAS）。不是仅更名的同一个示例。

## 搜索范围与原始证据

初查和交付前反查均在 2026-11-11。`moon search --limit 100 --output-json` 搜索格式名、英文/中文同义词、算法、API 与任务；保留 status、结果数和 package summary，不把模糊词命中计作核心能力。

- 点云：`LAS`、`LASF`、`ASPRS`、`LiDAR LAS`、`LAS point cloud`、`point cloud`、`pointcloud`、`激光雷达`、`点云`、`laspy`、`PDAL`、`Potree`、`E57`、`laz`、`Extra Bytes`、`point format`、`return number`、`read_las`、`decode_las`、`voxel`、`octree`、`spatial indexing`。
- 姿态：`IMU`、`AHRS`、`attitude`、`orientation`、`quaternion`、`Madgwick`、`Mahony`、`sensor fusion`、`姿态`、`惯性`。
- 信号：`EDF`、`EEG`、`biosignal`、`electroencephalography`、`脑电`。
- MoonCakes 模块页/公开接口与中文英文 README；官方 [awesome-moonbit](https://github.com/moonbitlang/awesome-moonbit/tree/2c21cca295d865327783cba31861cd78ecb955a4)；GitHub 仓库与 `language:MoonBit` 代码搜索，包括以上接口名的反查。代码搜索使用 per_page=100，记录 `total_count`/`incomplete_results`，相关结果未超过一页。
- 交付前反查：Moon `LASF`、`LAS point cloud`、`laspy` 均为成功响应且 0 命中；`read_las` 为 28 个模糊结果，不是 0，匹配摘要涉及 read-last、shell、ROS 消息等；`elevation_grid` 为 4 个结果，见新增邻近项。零命中不能证明唯一。
- 最后 GitHub `LASF language:MoonBit` 为 15 项，`incomplete_results=false`：btoi、UI/font atlas、imgui、ffmpeg样本、Win32常量、Brotli向量和 sprite示例等，未显示 LASF 点记录 IO。不是把包含 atlas 的字串误判为 LAS 解析器。
- 逐个读取永久登记表的相关能力指纹，包括已完成/预留/淘汰/外部核验条目，比较工作流而不只比项目名。MoonBench/MoonContract 等永久保留范围也不属于本项目。

原始 JSON、MoonCakes 提取正文、源码/测试、GitHub 递归 tree 和 SHA 留在本机工程研究目录，不上传私人申报书或凭据。公开报告提供可重新定位的上游链接与具体源码路径。

## 实际行为矩阵

版本为 MoonCakes 检索时版本；SHA 为所读取 GitHub 树，二者不冒充已证明完全一致的包归档。

|对象与读取证据|核心输入→处理→输出|与 MoonLAS 的关系|
|---|---|---|
|[MoonWell](https://github.com/2200732518gjy/moonwell/tree/d9b1a752f959ad0fe79f1a17f78688aed30cead5) `0.3.2`；`header.mbt`、`header_wbtest.mbt`|井测 LAS 文本→深度曲线解析/质量与装配→井测结果|名称碰撞；不是 LASF 二进制点云|
|[MOctree](https://github.com/OrisGo/MOctree/tree/d99d0098a81055448a6b3bc6721d940103cd77c1) `OrisGo/octree@0.1.0`；`objects/query.mbt`、`query_test.mbt`|通用对象/包围盒→预算受控静态空间查询/射线→命中|邻近工具；没有 LAS 格式、回波/分类/记录 IO|
|[moon-geometry](https://github.com/walkzzz/moon-geometry/tree/2b59b8b953ecf8764ef6009dc2f7697f2eec539a) `0.251.0`；`applied/point_cloud` 实现与白盒测试|几何点→重心/AABB/体素/近邻→几何结果；另有分水岭栅格模块|点集算法邻近；MoonLAS 不重造通用几何/最近邻库|
|[camera-models](https://github.com/cxh04/moonbit-camera-models/tree/1341d5ac31dae7d2d8921e6d6c873640bb42e3b4) `0.2.1`；接口/树与文档|相机参数/坐标→投影与反投影→坐标|可组合，非 LAS 点记录工作流|
|[TopoLens](https://github.com/wdgodghl/moontopolens/tree/bc7b5ccbbdbefebe2d8e7f56a8700592678a034b) `0.20.8`；文档/接口/树|地理/拓扑任务→相应分析→结果|邻近地理应用，不据名称判定重复|
|[moonbit-cog](https://github.com/Mostan-303/moonbit-cog/tree/3efdb55a55ab78ceef5f8b7f74568ce7b94b0c5d) `0.2.0`；`README_ZH.md`、`src/hydrology/flow_direction.mbt`、`hydrology_test.mbt`|GeoTIFF/栅格→D8流向/汇流→栅格；测试3×3东向最低邻居|栅格下游邻近，不是点记录 LAS 二进制 IO|
|[moonmoon](https://github.com/vectie/moonmoon/tree/38a9791b260516e67814d9e4c2aba52875880d02) `0.1.0`；`src/terrain_import/ascii_grid.mbt`、`ascii_grid_test.mbt`|Esri ASCII/PDS月表地形→有界导入、无数据/坐标处理→地形证据|地形消费者邻近；ASCII grid 不等于 LAS 点云|
|[ros2-mbt](https://github.com/OJII3/ros2-mbt/tree/a4ff17183b8be7f6251ea1e42af1d4920f92dadf) `0.12.0`；`ros/messages/sensor_msgs/sensor_msgs.mbt`、`sensor_msgs_test.mbt`|PointCloud2→CDR序列化/反序列化→ROS消息；含sequence往返|机器人接入邻近，消息容器不承担LAS公共头、VLR与量化约束|
|[EDF](https://github.com/peng-jun21/moonbit-edf/tree/3be5fed558ff6acfb11f5916b1c2f64f495f49be) `peng-jun21/edf@0.2.2`；`header.mbt`、`recording_test.mbt`|EDF记录→头/信号读写→记录|信号候选直接替代，故淘汰|
|[sensor_driver](https://mooncakes.io/docs/maria/sensor_driver) `0.1.0`；MoonCakes README/API|传感器输入→Madgwick/Complementary/Kalman融合→姿态|姿态候选高重合；GitHub404，源码抓取失败，**未声称读到融合源码/测试**|

LAS IO、保留属性、量化、元数据冲突和资源预算构成独立的格式边界。给通用几何库附加全部格式解析会引入另一完整问题域；给井测文本库扩展点云是同名异义。故本次选择独立格式包；几何、ROS 或栅格应用可以消费其结果，而不是复制邻居项目的空间索引、消息传输或水文算法。

## 参考与访问限制

- 成熟基线：[laspy](https://github.com/laspy/laspy/tree/b4e14088d24e7e23f72fd9d33d61f63a9668cb74)，BSD-3-Clause。实际读取 `laspy/header.py`、`laspy/point/dims.py`、`LICENSE.txt`；独立差分使用发布版2.6.1。没有复制上游实现、测试或数据。
- ASPRS规范PDF与PDAL文档请求403，raw.githubusercontent出现连接重置；改用GitHub API读取可访问的第一方源码。未伪称逐条完成官方规范全覆盖。
- GitHub搜索可能受索引、代码语言识别与账户可见性限制；Moon搜索为当日摘要检索，不等于全生态穷举。远端树有明确SHA且相关递归树 `truncated=false`；传输失败没有当作“不存在”。
- 未获真实下游用户采纳证明、性能优势证明或官方新颖性认证。只主张上述可复查范围内未确认成熟维护中的直接替代。

## 实际范围收敛

预留阶段曾考虑通用 voxel/nearest 索引和库级 CSV/JSON 导出；实现时主动收窄，**没有交付这些能力**。实际为 LAS 1.2/1.4，格式0/1/2/3/6/7/8，属性/VLR/gap保留、QC、筛选、闭区间AABB/球裁剪、有界高程栅格、容限量化/严格拼接、记录游标。CSV仅为 terrain 示例格式化输出。LAZ、waveform、EVLR、CRS解释/重投影、完整GIS、磁盘流式IO均不在范围内。
