# 工程提交审计

保守计数 **21**：17 个实现切片、独立参考验证、异常/性质测试、三个下游示例、四后端CI。后续文档、格式修复和CI修复均不增加此数字。没有回填日期或伪造已在历史 SHA 运行最终45测试。

| SHA | 独立工程目的 | 变更路径 |
|---|---|---|
| `ddf57ba8026d` | feat: define validated LAS point attributes and resource budgets | `.gitignore`, `model.mbt`, `model_wbtest.mbt`, `moon.mod`, `moon.pkg` |
| `e42d05d9c668` | feat: add bounded little-endian readers and safe length arithmetic | `binary.mbt`, `binary_wbtest.mbt`, `model.mbt` |
| `81736fd1158e` | feat: serialize exact integer floating-point and fixed-width metadata fields | `writer.mbt`, `writer_wbtest.mbt` |
| `cd55004b7981` | feat: parse LAS 1.2 and 1.4 headers with count and version constraints | `header.mbt`, `header_wbtest.mbt` |
| `e0a95c5e939e` | feat: retain bounded VLR payloads and pre-point padding | `metadata.mbt`, `metadata_wbtest.mbt` |
| `9c4e6e08cf91` | feat: decode legacy and extended LAS point attribute bitfields | `point_read.mbt`, `point_read_wbtest.mbt` |
| `984e185614fb` | feat: write seven LAS point formats without attribute loss | `point_write.mbt`, `point_write_wbtest.mbt` |
| `15a06bc497df` | feat: transform scaled coordinates with explicit quantization and finite bounds | `coordinates.mbt`, `coordinates_wbtest.mbt` |
| `d50f7c8caf34` | feat: assemble validated documents and recompute point extents and counts | `document.mbt`, `document_wbtest.mbt` |
| `1f7b9c7620ce` | feat: serialize complete LAS documents with bounded metadata and canonical headers | `document.mbt`, `encode.mbt`, `encode_wbtest.mbt`, `metadata.mbt` |
| `e072bb2e70ea` | feat: audit classification return flags intensity and stale header summaries | `audit.mbt`, `audit_wbtest.mbt` |
| `cbed35cd8c65` | feat: filter LAS attributes with stable ordering and metadata preservation | `selection.mbt`, `selection_wbtest.mbt` |
| `3cdf7afac3b7` | feat: crop scaled LAS coordinates by inclusive bounds and overflow-safe radius | `spatial.mbt`, `spatial_wbtest.mbt` |
| `3ede29b07dc9` | feat: aggregate bounded elevation grids with empty-cell and ground-class semantics | `grid.mbt`, `grid_wbtest.mbt` |
| `a8a3b02f5fd5` | feat: requantize coordinates with explicit tolerance and measured axis errors | `requantize.mbt`, `requantize_wbtest.mbt` |
| `98dd0c0e43ce` | feat: merge compatible LAS tiles without hiding metadata or quantization conflicts | `merge.mbt`, `merge_wbtest.mbt` |
| `73ba20d08440` | feat: decode bounded LAS records on demand with seekable batch cursors | `cursor.mbt`, `cursor_wbtest.mbt` |
| `3fdb6c1414a9` | test: cross-check 352 records and canonical writes against pinned laspy oracles | `encode.mbt`, `header.mbt`, `reference_wbtest.mbt`, `tools/generate_oracles.py`, `tools/oracle-manifest.json` |
| `afe4a05f42fd` | test: harden truncation budgets and mutated documents with 1792 record properties | `document.mbt`, `robustness_wbtest.mbt` |
| `01f3b8001dd6` | feat: demonstrate acquisition QC terrain gridding and batched sensor ingestion | `examples/ingest/main.mbt`, `examples/ingest/moon.pkg`, `examples/ingest/pkg.generated.mbti`, `examples/quality/main.mbt`, `examples/quality/moon.pkg`, `examples/quality/pkg.generated.mbti`, `examples/terrain/main.mbt`, `examples/terrain/moon.pkg`, `examples/terrain/pkg.generated.mbti` |
| `2da803418b0d` | ci: reproduce strict four-backend workflows and independent oracle regeneration | `.github/workflows/ci.yml`, `pkg.generated.mbti`, `tools/audit_source.py` |

验证方式：查看每个提交的实际源码/对应测试；最终同一发布候选运行严格检查、构建、45个测试与示例。独立 laspy 参考352点，1792属性组合单列；实际CI链接和精确发布SHA记录在仓库外交付审计，避免文件自引用。Windows本地native只通过check，test/build缺C工具链；Linux CI承担真实native验收。
