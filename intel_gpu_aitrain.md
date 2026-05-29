# Intel GPU (Arc Pro 140T) AI Training/Inference Protection Guide

> **Device:** Intel Arc Pro 130T/140T (Arrow Lake-P) — PCI ID `8086:7d51`
> **NPU:** Intel AI Boost (`/dev/dri/renderD128`)
> **OS:** Ubuntu 26.04 LTS, Kernel `7.0.0-15-generic`
> **OpenVINO:** `2026.1.0` (releases/2026/1)
> **PyTorch:** `2.12.0+xpu` (XPU available)
> **oneAPI:** `2026.0` (compiler, MKL, DNNL, TBB)
> **llama.cpp:** `b9404` (SYCL backend, IntelLLVM 2026.0.0)
> **intel-gpu-tools:** `libze-intel-gpu1 26.14.37833.4`

---

## ⚠️ Known Risks

| Risk | Symptom | Root Cause |
|------|---------|------------|
| **Kernel Panic** | System freeze, hard reboot required | GPU sustained high load triggers driver crash |
| **Segfault (139)** | Process exits with code 139 | GPU memory access violation or driver bug |
| **NaN/Inf Output** | NaN values in tensors, usually precedes kernel panic | **GPU driver is about to crash** (not quantization error) |
| **Throttling** | Inference speed drops 2-5x suddenly | GPU temperature too high, auto-downclocking |
| **Power Spike** | Whole system performance drops | Instant power draw exceeds PSU limit |

---

## 🛡️ Protection Layers (5-Layer Defense)

### Layer 1: Active Cooling (Root Cause Fix)

**Key insight: NaN is NOT a quantization precision issue — it's a warning that the GPU driver is about to crash.**
After adding cooling mechanisms, NaN disappeared completely (INT8 *with* cooling = no NaN; INT8 *without* cooling = NaN).
This proves the root cause is GPU overheating / power starvation.

Configuration (`rag/config.py`):
```python
BATCH_SIZE = 10                # Small batches reduce power spikes
BATCH_COOLDOWN_INTERVAL = 3    # Cool down every 3 batches
BATCH_COOLDOWN_SECONDS = 5     # 5s short break
FILE_COOLDOWN_SECONDS = 30     # 30s break after each file
CRASH_COOLDOWN = 60            # 60s recovery after crash
```

### Layer 2: Thermal Detection

```python
# embedding.py — detect throttling by inference time
if bt > baseline * THERMAL_THROTTLE_FACTOR:  # current > 2x baseline
    time.sleep(30)  # extra 30s cooling
    baseline = (baseline + bt) / 2  # update baseline
```

Intel GPU has no userspace temperature API (`intel_gpu_top` requires root).
**Using inference latency as a proxy for temperature** is the most practical approach.

### Layer 3: Crash Recovery

```python
# embedding.py — self-healing on crash
for attempt in range(3):
    try:
        out = compiled(...)   # inference
        break
    except Exception:
        time.sleep(10)
        _load_model()         # recompile model
else:
    raise RuntimeError("3 consecutive crashes, skip this batch")

# build_index.py — file-level isolation
try:
    embeddings = embed.encode(docs)  # one file fails
except Exception:
    time.sleep(60)                   # cooldown
    # continue to next file, don't abort
```

### Layer 4: GPU Health Check

```python
# embedding.py — probe GPU every 10 batches
def health_check(self):
    try:
        compiled(["。"])  # minimal inference to verify GPU
        return True
    except Exception:
        return False
```

### Layer 5: NaN Guard

```python
# embedding.py — _clean() catches NaN before ChromaDB rejects them
def _clean(tensor):
    if not np.isfinite(tensor).all():
        tensor = np.nan_to_num(tensor, nan=0.0)
        return tensor
```

---

## 📊 Before/After GPU Usage Comparison

> Data: `sudo intel_gpu_top -s 1000`, 70s continuous sampling
Note: OpenVINO GPU inference uses the **Render/3D (RCS)** engine, not the Compute (CCS) engine.

| Metric | Before (INT4, batch=20, no cooling) | After (INT8, batch=10, with cooling) |
|--------|-------|------|
| **GPU Render/3D usage** | > **90%** sustained full load | Peak **~19%**, avg **2.3%** |
| **GPU frequency (actual)** | Sustained ~1800 MHz | Avg **456 MHz**, peak **2151 MHz** |
| **GPU power** | Sustained high, easily overheats | Avg **2.9W**, peak **20.8W** |
| **RC6 idle ratio** | ~0% (never rests) | **~31%** (frequent cooling breaks) |
| **NaN/Inf output** | ❌ Frequent → Kernel Panic | ✅ Zero NaN, zero crashes |
| **Time per file (1000 poems)** | ~60s (fast but dangerous) | ~350s (slow but safe) |

**Conclusion:** After optimization, GPU actual workload dropped significantly — RCS usage from >90% to peak 19%,
RC6 idle from 0% to 31%. Although 5-6x slower per file, the system no longer Kernel Panics.

---

| Config | Speed (1000 poems) | Stability | Notes |
|--------|-------------------|-----------|-------|
| GPU INT4, batch=20 | ~60s | ❌ Kernel panic | Do not use |
| **GPU INT8, batch=10 + cooling** | **~350s** | **✅ Stable** | **Recommended** |
| CPU INT8, batch=10 | ~10min | ✅ Rock solid | Fallback |
| NPU INT8 | TBD | Needs static shapes | Future optimization |

---

---

# Intel GPU (Arc Pro 140T) AI 训练/推理保护指南

> **设备:** Intel Arc Pro 130T/140T (Arrow Lake-P) — PCI ID `8086:7d51`
> **系统:** Ubuntu 26.04 LTS, 内核 `7.0.0-15-generic`
> **OpenVINO:** `2026.1.0`
> **PyTorch:** `2.12.0+xpu`
> **oneAPI:** `2026.0`
> **llama.cpp:** `b9404` (SYCL)
> **intel-gpu-tools:** `26.14.37833.4`

---

## ⚠️ 已知风险

| 风险 | 现象 | 原因 |
|------|------|------|
| **Kernel Panic** | 系统完全死机，需硬重启 | GPU 持续高负载导致驱动级崩溃 |
| **段错误 (Segfault)** | 进程退出码 139 | 显存访问越界或驱动 bug |
| **NaN/Inf 输出** | 向量出现 NaN，随后可能 kernel panic | **GPU 驱动濒临崩溃的前兆**，非量化精度问题 |
| **降频 (Throttling)** | 推理速度突然变慢 2-5x | GPU 温度过高自动降频 |
| **供电不足** | 整机性能下降 | 瞬时功耗超过供电极限 |

---

## 🛡️ 保护措施（五层防御）

### 第一层：主动冷却（治本）

**关键认识：NaN 不是量化精度问题，而是 GPU 即将崩溃的前兆信号。**
加了冷却机制后 NaN 自动消失（INT8 加冷却前有 NaN，加冷却后没有），
说明根因是 GPU 过热/供电不足导致驱动输出异常。

配置参数 (`rag/config.py`):
```python
BATCH_SIZE = 10                # 小 batch，减少瞬时功耗
BATCH_COOLDOWN_INTERVAL = 3    # 每 3 个 batch 冷却 5s
BATCH_COOLDOWN_SECONDS = 5
FILE_COOLDOWN_SECONDS = 30     # 每个文件后冷却 30s
CRASH_COOLDOWN = 60            # 崩溃后冷却 60s
```

### 第二层：降频检测

```python
# embedding.py - 每个 batch 后检测推理时间
if bt > baseline * THERMAL_THROTTLE_FACTOR:  # 当前 > 基准 2 倍
    time.sleep(30)  # 额外冷却 30s
    baseline = (baseline + bt) / 2  # 更新基准
```

因为 Intel GPU 没有用户态温度读取接口（`intel_gpu_top` 需要 root），
**用推理耗时反推温度**是最实用的方法。

### 第三层：崩溃恢复

```python
# embedding.py - 崩溃自愈
for attempt in range(3):
    try:
        out = compiled(...)   # 推理
        break
    except Exception:
        time.sleep(10)
        _load_model()         # 重新编译模型
else:
    raise RuntimeError("连续 3 次崩溃，跳过该 batch")

# build_index.py - 文件级隔离
try:
    embeddings = embed.encode(docs)  # 一个文件失败
except Exception:
    time.sleep(60)                   # 冷却一分钟
    # 继续下一个文件，不中断整体流程
```

### 第四层：GPU 探活

```python
# embedding.py - 每 10 个 batch 检查 GPU
def health_check(self):
    try:
        compiled(["。"])  # 做一次极简推理
        return True
    except Exception:
        return False
```

### 第五层：NaN 兜底

```python
# embedding.py - 在 ChromaDB 拒绝之前清理 NaN
def _clean(tensor):
    if not np.isfinite(tensor).all():
        tensor = np.nan_to_num(tensor, nan=0.0)
        return tensor
```

---

## 📊 GPU 占用前后对比（优化效果）

> 数据来源: `sudo intel_gpu_top -s 1000` 连续采集 70s  
> 注：OpenVINO GPU 推理走 **Render/3D (RCS)** 引擎，不走 Compute (CCS) 引擎。

| 指标 | 优化前（INT4, batch=20, 无冷却） | 优化后（INT8, batch=10, 有冷却） |
|------|------|------|
| **GPU Render/3D 占用** | > **90%** 持续满载 | 峰值 **~19%**，均值 **2.3%** |
| **GPU 频率** | 持续高频 ~1800 MHz | 均值 **456 MHz**，峰值 **2151 MHz** |
| **GPU 功耗** | 持续高功耗，易过热 | 均值 **2.9W**，峰值 **20.8W** |
| **RC6 空闲比例** | ~0%（从不休息） | **~31%**（大量空闲冷却） |
| **NaN/Inf 输出** | ❌ 频繁出现 → Kernel Panic | ✅ 零 NaN、零崩溃 |
| **单文件耗时 (1000首)** | ~60s（快但危险） | ~350s（慢但安全） |

**结论：** 优化后 GPU 实际干活时间大幅减少，RCS 占用从 >90% 降到峰值 19%，
RC6 空闲率从 0% 升到 31%。虽然慢了 5-6 倍，但系统再也不会 Kernel Panic 了。

---

## 📊 性能与稳定性权衡

| 配置 | 速度 (1000首) | 稳定性 | 适用场景 |
|------|-------------|--------|---------|
| GPU INT4, batch=20 | ~60s | ❌ Kernel panic | 不推荐 |
| GPU INT8, batch=10 + 冷却 | ~350s | ✅ 稳定运行 | 推荐建库 |
| CPU INT8, batch=10 | ~10min | ✅ 绝对稳定 | 备用方案 |
| NPU INT8 | 待测 | 需静态 shape | 后续优化 |

---

> 最后更新: 2026-05-29
> 经验: Linux 比 Windows 更稳，但仍会出现 kernel panic。

