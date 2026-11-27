# Changelog

## 0.2.2 — 2026-11-27

- 将官方固定工具链升级到 `moonc 1.0.0-rc1+3c0520448`，配套 `moon` / `moonrun 0.1.20261126`；CI 的四后端与独立 oracle 任务均验证三个组件的实际版本。
- 同步中文安装说明和补丁版本；保持 LAS 支持范围与公共 API 不变。
- 追加本轮生态近邻复查的范围、差异及限制；不主张官方验收或全生态唯一。


## 0.2.1 — 2026-11-25

- Update MoonBit to the official stable toolchain 0.10.22+124d61d05 and adopt its current derive syntax so strict CI remains warning-free.
- Regenerate the public interface with the pinned compiler.

## 0.2.0 — 2026-11-17

- Expand uncompressed LAS support to versions 1.1–1.4 and all point formats 0–10.
- Preserve extended headers, unknown VLR/EVLR records, raw text, reserved fields, gaps and trailing bytes.
- Support internal/external waveform packets and uncompressed 8/16-bit calibrated samples.
- Relocate EVLR and waveform offsets when points or extended metadata change.
- Expose all Extra Bytes numeric layouts with exact 64-bit values and raw projection records.
- Add 35 independently generated documents, 832 reference points, metadata mutation tests and a waveform workflow.
- Public structure additions require migrating literal constructors; use the provided constructors and record update syntax.

## 0.1.0 — 2026-11-11

Initial point IO, quality audit, filtering, grids, cursor, requantization and merge workflows.
