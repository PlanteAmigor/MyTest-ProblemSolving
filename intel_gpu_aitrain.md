# Intel Arc GPU Stability Guide for AI Workloads

[![Ubuntu](https://img.shields.io/badge/OS-Ubuntu%2026.04%20LTS-E95420)](https://ubuntu.com/)
[![Kernel](https://img.shields.io/badge/Kernel-7.0.0--15--generic-blue)](https://kernel.org/)
[![OpenVINO](https://img.shields.io/badge/OpenVINO-2026.1-00A3E0)](https://docs.openvino.ai/)
[![PyTorch](https://img.shields.io/badge/PyTorch-2.12+xpu-EE4C2C)](https://pytorch.org/)

**A practical guide to preventing GPU driver crashes (Kernel Panic, Segfault) on Intel Arc discrete GPUs under sustained AI inference workloads.**

---

## Platforms & Models Tested

| Category | Details |
|----------|---------|
| **GPU** | Intel Arc Pro 130T/140T (Arrow Lake-P, PCI ID `8086:7d51`) |
| **NPU** | Intel AI Boost (`/dev/dri/renderD128`) |
| **RAM** | 64 GB |
| **OS** | Ubuntu 26.04 LTS |
| **Kernel** | `7.0.0-15-generic` |
| **Frameworks** | OpenVINO `2026.1`, PyTorch `2.12.0+xpu`, llama.cpp `b9404` (SYCL) |
| **Compiler** | oneAPI `2026.0` (IntelLLVM, MKL, DNNL, TBB) |
| **GPU driver** | `libze-intel-gpu1 26.14.37833.4` |

| Model | Task | Format | Size |
|-------|------|--------|------|
| **Qwen3-Embedding-4B** | Text embedding (2560-dim) | OpenVINO INT8 | ~3 GB |
| **Qwen3-Reranker-4B** | Text reranking | OpenVINO INT8 | ~3 GB |
| **Qwen3.5-4B** | Text generation | GGUF (IQ4_XS) | ~2.5 GB |

---

## The Problem

Under sustained AI inference workloads (e.g., batch-encoding thousands of text passages), Intel Arc GPUs are prone to:

- **Kernel Panic** – Complete system freeze requiring hard reboot
- **Segfault (exit code 139)** – Process crashes from GPU memory access violation
- **NaN/Inf Output** – GPU outputs garbage values before crashing
- **Throttling** – Inference speed drops 2–5× due to thermal downclocking

**Root cause:** Intel Arc consumer GPUs lack robust thermal/power management for sustained compute loads. The GPU driver becomes unstable when running at high utilization (>90%) for extended periods.

---

## Key Findings

### 1. NaN Output is a Crash Warning

NaN/Inf values in inference output are **not a quantization precision issue** — they are a **precursor to GPU driver crash**. After implementing active cooling, NaN disappeared completely even with the same INT8 model. This confirms the root cause is GPU overheating / power starvation, not numerical precision.

### 2. OpenVINO Uses Render/3D Engine

On Intel Arc GPUs, OpenVINO runs inference on the **Render/3D (RCS)** engine, not the Compute (CCS) engine. Monitor `RCS` busy %, not `CCS`.

### 3. INT8 > INT4 for Stability

INT4 quantization increases numerical edge-case behavior on Intel GPUs, making NaN/crash more likely. INT8 provides reliable stability with acceptable performance.

---

## Before / After Comparison

### GPU Workload Metrics

| Metric | Before (INT4, batch=20, no cooling) | After (INT8, batch=10, with cooling) |
|--------|-------------------------------------|--------------------------------------|
| GPU Render/3D usage | > **90%** sustained | Peak **~19%**, avg **2.3%** |
| GPU freq (actual) | Sustained ~1800 MHz | Avg **456 MHz**, peak **2151 MHz** |
| GPU power | Sustained high → overheating | Avg **2.9 W**, peak **20.8 W** |
| RC6 idle ratio | ~**0%** (never rests) | **~31%** (frequent cooling breaks) |
| NaN/Inf output | ❌ Frequent → Kernel Panic | ✅ Zero NaN, zero crashes |
| Time per 1000 texts | ~**60 s** (fast but dangerous) | ~**350 s** (slow but safe) |

**Data source:** `sudo intel_gpu_top -s 1000`, 70-second continuous sampling during embedding inference.

### Stability Comparison

| Config | Speed (1000 texts) | Stability | Verdict |
|--------|-------------------|-----------|---------|
| GPU INT4, batch=20 | ~60 s | ❌ Kernel panic | Do not use |
| **GPU INT8, batch=10 + cooling** | **~350 s** | **✅ Stable** | **Recommended** |
| CPU INT8, batch=10 | ~10 min | ✅ Rock solid | Fallback |
| NPU INT8 | TBD | Needs static shapes | Future |

---

## Summary

Intel Arc GPUs can handle AI inference workloads reliably when **active cooling** is employed:

- **Small batches** prevent power spikes
- **Frequent breaks** between batches give the GPU time to cool
- **Thermal detection via latency monitoring** catches throttling early and triggers extra cooldown
- **INT8 quantization** avoids numerical edge cases

Without these measures, sustained GPU load >90% will eventually trigger a driver crash — regardless of operating system (Linux is more stable than Windows, but still susceptible).

---

# Intel Arc GPU AI 负载稳定性指南

**在 Intel Arc 独立显卡上，防止长时间 AI 推理负载导致 GPU 驱动崩溃（Kernel Panic、段错误）的实践指南。**

---

## 测试平台与模型

| 类别 | 详情 |
|------|------|
| **GPU** | Intel Arc Pro 130T/140T (Arrow Lake-P, PCI ID `8086:7d51`) |
| **NPU** | Intel AI Boost (`/dev/dri/renderD128`) |
| **内存** | 64 GB |
| **系统** | Ubuntu 26.04 LTS |
| **内核** | `7.0.0-15-generic` |
| **框架** | OpenVINO `2026.1`, PyTorch `2.12.0+xpu`, llama.cpp `b9404` (SYCL) |
| **编译器** | oneAPI `2026.0` (IntelLLVM, MKL, DNNL, TBB) |
| **GPU 驱动** | `libze-intel-gpu1 26.14.37833.4` |

| 模型 | 任务 | 格式 | 大小 |
|------|------|------|------|
| **Qwen3-Embedding-4B** | 文本向量化 (2560维) | OpenVINO INT8 | ~3 GB |
| **Qwen3-Reranker-4B** | 文本排序 | OpenVINO INT8 | ~3 GB |
| **Qwen3.5-4B** | 文本生成 | GGUF (IQ4_XS) | ~2.5 GB |

---

## 问题描述

在长时间 AI 推理负载下（如批量编码数千段文本），Intel Arc GPU 容易出现：

- **Kernel Panic** — 系统完全死机，需要硬重启
- **段错误 (exit code 139)** — 进程崩溃，显存访问异常
- **NaN/Inf 输出** — GPU 在崩溃前输出异常值
- **降频** — 推理速度骤降 2-5 倍

**根本原因：** Intel Arc 消费级 GPU 缺乏针对长时间计算负载的热管理和供电管理机制。GPU 驱动在高占用率（>90%）下持续运行会变得不稳定。

---

## 关键发现

### 1. NaN 输出是崩溃前兆

推理结果中的 NaN/Inf **不是量化精度问题**，而是 **GPU 驱动即将崩溃的信号**。加入主动冷却后，同一 INT8 模型的 NaN 完全消失。证明根因是 GPU 过热/供电不足。

### 2. OpenVINO 使用 Render/3D 引擎

在 Intel Arc GPU 上，OpenVINO 的推理走 **Render/3D (RCS)** 引擎，不走 Compute (CCS) 引擎。监控时注意看 `RCS` 占用率。

### 3. INT8 优于 INT4

INT4 量化在 Intel GPU 上更容易触发数值边界情况，增加 NaN/崩溃风险。INT8 在保持可用性能的同时提供了可靠的稳定性。

---

## 优化前后对比

### GPU 负载指标

| 指标 | 优化前 (INT4, batch=20, 无冷却) | 优化后 (INT8, batch=10, 有冷却) |
|------|--------------------------------|-------------------------------|
| GPU Render/3D 占用 | > **90%** 持续满载 | 峰值 **~19%**，均值 **2.3%** |
| GPU 实际频率 | 持续 ~1800 MHz | 均值 **456 MHz**，峰值 **2151 MHz** |
| GPU 功耗 | 持续高负载 → 过热 | 均值 **2.9 W**，峰值 **20.8 W** |
| RC6 空闲比例 | ~**0%**（从不休息） | **~31%**（频繁冷却） |
| NaN/Inf 输出 | ❌ 频繁出现 → Kernel Panic | ✅ 零 NaN、零崩溃 |
| 每千条耗时 | ~**60 s**（快但不稳） | ~**350 s**（慢但安全） |

**数据来源：** `sudo intel_gpu_top -s 1000`，在 Embedding 推理过程中连续采集 70 秒。

### 稳定性对比

| 配置 | 速度 (千条) | 稳定性 | 结论 |
|------|-----------|--------|------|
| GPU INT4, batch=20 | ~60 s | ❌ Kernel panic | 不推荐 |
| **GPU INT8, batch=10 + 冷却** | **~350 s** | **✅ 稳定** | **推荐** |
| CPU INT8, batch=10 | ~10 min | ✅ 绝对稳定 | 备用 |
| NPU INT8 | 待测 | 需静态 shape | 后续 |

---

## 总结

Intel Arc GPU 在**主动冷却**策略下可以稳定运行 AI 推理负载：

- **小 batch** 避免瞬时功耗尖峰
- **频繁间歇** 让 GPU 有充分冷却时间
- **通过推理延迟监测温度**，在降频初期及时触发额外冷却
- **INT8 量化** 避免数值边界问题

如果不采取这些措施，GPU 在 >90% 占用率下持续运行最终会导致驱动崩溃——无论操作系统如何（Linux 比 Windows 更稳定，但同样受影响）。
