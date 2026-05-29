# OpenOCD 编译错误记录

## 环境信息

| 项目 | 内容 |
|------|------|
| 操作系统 | Ubuntu 26.04 LTS (Resolute Raccoon), x86_64 |
| 内核 | Linux 7.0.0-15-generic |
| GCC 版本 | gcc (Ubuntu 15.2.0-16ubuntu1) 15.2.0 |
| OpenOCD 版本 | 0.12.0+dev-01529-gf92f577cc (2026-05-29) |
| 架构 | x86_64-pc-linux-gnu |
| 编译方式 | 从 GitHub 源码编译（`./bootstrap && ./configure && make`） |

---

## 编译错误：`-Werror=discarded-qualifiers`

### 现象

```text
src/jtag/drivers/vdebug.c:1221:23: error: initialization discards 'const' qualifier from pointer target type [-Werror=discarded-qualifiers]
src/server/telnet_server.c:71:34: error: initialization discards 'const' qualifier from pointer target type [-Werror=discarded-qualifiers]
src/rtos/ecos.c:513:30: error: initialization discards 'const' qualifier from pointer target type [-Werror=discarded-qualifiers]
src/helper/log.c:123:11: error: assignment discards 'const' qualifier from pointer target type [-Werror=discarded-qualifiers]
src/helper/options.c:154:30: error: initialization discards 'const' qualifier from pointer target type [-Werror=discarded-qualifiers]
```

### 原因

OpenOCD 使用 `-Werror` 将所有警告视为错误。C 标准中 `strchr(const char *, int)` 的返回值是 `char *`（历史遗留设计），但传入的参数是 `const char *`。GCC 15.2.0 检测到 `const` 限定符被丢弃后，配合 `-Werror` 将其判定为编译错误。

这属于**上游兼容性问题**——OpenOCD 较旧的源码未适配 GCC 15 的新警告等级，并非用户操作错误。

### 涉及文件与修复

| 文件 | 行号 | 修复方式 |
|------|------|---------|
| `src/jtag/drivers/vdebug.c` | 1221 | `char *pchar` → `(char *)strchr(CMD_ARGV[0], ':')` 强制转型 |
| `src/server/telnet_server.c` | 71 | `char *line_end` → `const char *line_end` |
| `src/rtos/ecos.c` | 513 | `char *fidx` → `const char *fidx` |
| `src/helper/log.c` | 123 | `char *f` → `const char *f` |
| `src/helper/options.c` | 154 | `char *next` → `const char *next` |

### 修复原则

- 如果 `strchr()` 的结果**只用于读取**（如 `const char *` 变量的重新赋值、只读比较），将变量声明为 `const char *`
- 如果 `strchr()` 的结果**需要修改原字符串**，对返回值做 `(char *)` 强制转型

### 相关依赖安装

编译前需安装的依赖（不安装会导致 configure 检测不到调试器支持）：

```bash
sudo apt install libusb-1.0-0-dev libftdi1-dev libhidapi-dev libcapstone-dev libtool autoconf automake pkg-config make gcc
```

---

# OpenOCD Build Error Record (English)

## Environment

| Item | Value |
|------|-------|
| OS | Ubuntu 26.04 LTS (Resolute Raccoon), x86_64 |
| Kernel | Linux 7.0.0-15-generic |
| GCC version | gcc (Ubuntu 15.2.0-16ubuntu1) 15.2.0 |
| OpenOCD version | 0.12.0+dev-01529-gf92f577cc (2026-05-29) |
| Architecture | x86_64-pc-linux-gnu |
| Build method | Compiled from GitHub source (`./bootstrap && ./configure && make`) |

---

## Build Error: `-Werror=discarded-qualifiers`

### Symptom

```text
src/jtag/drivers/vdebug.c:1221:23: error: initialization discards 'const' qualifier from pointer target type [-Werror=discarded-qualifiers]
src/server/telnet_server.c:71:34: error: initialization discards 'const' qualifier from pointer target type [-Werror=discarded-qualifiers]
src/rtos/ecos.c:513:30: error: initialization discards 'const' qualifier from pointer target type [-Werror=discarded-qualifiers]
src/helper/log.c:123:11: error: assignment discards 'const' qualifier from pointer target type [-Werror=discarded-qualifiers]
src/helper/options.c:154:30: error: initialization discards 'const' qualifier from pointer target type [-Werror=discarded-qualifiers]
```

### Cause

OpenOCD uses `-Werror` to treat all warnings as errors. In the C standard, `strchr(const char *, int)` has a return type of `char *` (a historical design quirk), even when the input argument is `const char *`. GCC 15.2.0 detects that the `const` qualifier is discarded and, combined with `-Werror`, raises a compilation error.

This is an **upstream compatibility issue** — OpenOCD's older source code has not been adapted to GCC 15's stricter warning levels. It is not a user error.

### Affected Files and Fixes

| File | Line | Fix |
|------|------|-----|
| `src/jtag/drivers/vdebug.c` | 1221 | `char *pchar` → `(char *)strchr(CMD_ARGV[0], ':')` explicit cast |
| `src/server/telnet_server.c` | 71 | `char *line_end` → `const char *line_end` |
| `src/rtos/ecos.c` | 513 | `char *fidx` → `const char *fidx` |
| `src/helper/log.c` | 123 | `char *f` → `const char *f` |
| `src/helper/options.c` | 154 | `char *next` → `const char *next` |

### Fix Principle

- If `strchr()` result is **read-only** (e.g., reassigning a `const char *` variable, read-only comparisons), declare the variable as `const char *`
- If `strchr()` result is **used to modify the original string**, use an explicit `(char *)` cast on the return value

### Required Dependencies

Dependencies required before building (without these, `configure` will not detect debugger support):

```bash
sudo apt install libusb-1.0-0-dev libftdi1-dev libhidapi-dev libcapstone-dev libtool autoconf automake pkg-config make gcc
```

---

# STM32CubeCLT 1.21.0 安装问题记录

## 环境信息

| 项目 | 内容 |
|------|------|
| 操作系统 | Ubuntu 26.04 LTS (Resolute Raccoon), x86_64 |
| 安装包 | `st-stm32cubeclt_1.21.0_27995_20260219_1804_amd64.sh` (makeself 自解压归档) |
| 安装目标 | `/opt/st/stm32cubeclt_1.21.0` |
| 方式 | 手动解压 + 手动提取 tar.gz + 手动配置环境变量 |

---

## 问题一：`Installation dir cannot be temporary one`

### 现象

```text
Installation dir cannot be temporary one: /home/amigor/STM32CubeCLT
```

### 原因

`setup.sh` 中有一项安全检查：

```bash
if [ "$installdir" = "$thisdir" ]; then
    echo "Installation dir cannot be temporary one: $thisdir"
```

`thisdir` 为脚本所在目录（即 makeself 解压出的临时目录）。如果用户指定的安装目录恰好等于解压目录本身，脚本拒绝继续。这在使用 `--target ~/STM32CubeCLT` 并回答安装目录为同一路径时触发。

### 解决方案

安装到**不同于解压目录**的路径（如 `/opt/st/stm32cubeclt_1.21.0`）。

---

## 问题二：`cleanup.sh` 删除解压目录导致后续运行失败

### 现象

```text
bash: cd: /home/amigor/STM32CubeCLT: 没有那个文件或目录
shell-init: 获取当前目录时出错: getcwd: 无法访问父目录: 没有那个文件或目录
```

### 原因

任何失败（包括 exit_if_not_interactive）都会触发 `trap`，调用 `cleanup.sh` 删除整个解压目录。Shell 的 cwd 指向已删除的目录，后续所有命令均报 `getcwd` 错误。

### 解决方案

发生该情况后，先 `cd` 到其他正常目录（如 `cd /home/amigor/下载/ppt`）恢复 shell 状态，再重新解压。

---

## 问题三：许可协议交互式输入在 `sudo` 下失效

### 现象

脚本停在 `I ACCEPT (y) / I DO NOT ACCEPT (N) [N/y]`，输入 `y` 未被正确读取，显示 `License NOT accepted`。

### 原因

`sudo bash -c '...'` 或管道传入时，`read` 读取的标准输入被重定向或丢失。

### 解决方案

设置环境变量 `LICENSE_ALREADY_ACCEPTED=1` 跳过 license prompt 阶段：

```bash
export LICENSE_ALREADY_ACCEPTED=1
```

`prompt_linux_license.sh` 入口处会检查该变量：

```bash
if [ "$LICENSE_ALREADY_ACCEPTED" ] ; then
    exit 0
fi
```

---

## 问题四：`tar` 命令使用相对路径导致文件找不到

### 现象

```text
tar (child): st-stm32cubeclt*.tar.gz：无法 open: 没有那个文件或目录
```

### 原因

`setup.sh` 中 `tar` 使用相对路径且未先 `cd` 到脚本目录：

```bash
tar zxf st-stm32cubeclt*.tar.gz -C $installdir
```

若 cwd 不是脚本所在目录则找不到 tar.gz。

### 解决方案

最终方案：**完全跳过 `setup.sh`，手动完成安装**（见下方最终方案）。

---

## 最终方案：手动安装

### 步骤 1：解压

```bash
bash st-stm32cubeclt_1.21.0_27995_20260219_1804_amd64.sh --noexec --target /tmp/stm32cubeclt_extract
```

### 步骤 2：提取核心文件到目标目录

```bash
sudo mkdir -p /opt/st/stm32cubeclt_1.21.0
sudo tar zxf /tmp/stm32cubeclt_extract/st-stm32cubeclt_1.21.0_27995_20260219_1804_amd64.tar.gz -C /opt/st/stm32cubeclt_1.21.0
sudo cp /tmp/stm32cubeclt_extract/uninstall_clt.sh /opt/st/stm32cubeclt_1.21.0/
```

### 步骤 3：配置环境变量

```bash
sudo tee /etc/profile.d/cubeclt-bin-path_1.21.0.sh > /dev/null << 'EOF'
export PATH="/opt/st/stm32cubeclt_1.21.0:/opt/st/stm32cubeclt_1.21.0/STM32CubeProgrammer/bin:/opt/st/stm32cubeclt_1.21.0/STLink-gdb-server/bin:/opt/st/stm32cubeclt_1.21.0/CMake/bin:/opt/st/stm32cubeclt_1.21.0/Ninja/bin:/opt/st/stm32cubeclt_1.21.0/st-arm-clang/bin:/opt/st/stm32cubeclt_1.21.0/GNU-tools-for-STM32/bin:$PATH"
export CLANG_GCC_CMSIS_COMPILER="/opt/st/stm32cubeclt_1.21.0/st-arm-clang"
export GCC_TOOLCHAIN_ROOT="/opt/st/stm32cubeclt_1.21.0/GNU-tools-for-STM32/bin"
EOF
sudo chmod 644 /etc/profile.d/cubeclt-bin-path_1.21.0.sh
```

### 步骤 4：修复目录权限

```bash
sudo chmod 755 /opt/st/ /opt/st/stm32cubeclt_1.21.0/
```

### 步骤 5：安装 STLink 调试支持

```bash
sudo bash /tmp/stm32cubeclt_extract/st-stlink-udev-rules-1.0.3-3-linux-noarch.sh  # 接受许可
sudo bash /tmp/stm32cubeclt_extract/st-stlink-server.2.1.1-1-linux-amd64.install.sh  # 接受许可
sudo cp /tmp/stm32cubeclt_extract/st-stlink-udev-rules.uninstall.sh /opt/st/stm32cubeclt_1.21.0/
sudo cp /tmp/stm32cubeclt_extract/stlink-server.uninstall.sh /opt/st/stm32cubeclt_1.21.0/
```

### 步骤 6：清理

```bash
rm -rf /tmp/stm32cubeclt_extract
```

### 附注

- **libncurses5 缺失警告**：Ubuntu 26.04 已无 `libncurses5` 包（由 `libncurses6` 取代）。实测 STM32CubeCLT 各组件无实际依赖 `libncurses5`，可安全忽略该警告。
- **OpenSSL 版本警告**：`libssl.so.3` 依赖 `OPENSSL_3.6.0`，Ubuntu 26.04 提供的版本可能更高，影响待验证。
- 使用前执行 `source /etc/profile.d/cubeclt-bin-path_1.21.0.sh` 加载环境变量。

---

# STM32CubeCLT 1.21.0 Installation Issues (English)

## Environment

| Item | Value |
|------|-------|
| OS | Ubuntu 26.04 LTS (Resolute Raccoon), x86_64 |
| Package | `st-stm32cubeclt_1.21.0_27995_20260219_1804_amd64.sh` (makeself self-extracting archive) |
| Install target | `/opt/st/stm32cubeclt_1.21.0` |
| Method | Manual extraction + manual tar.gz unpack + manual env config |

---

## Issue 1: `Installation dir cannot be temporary one`

### Symptom

```text
Installation dir cannot be temporary one: /home/amigor/STM32CubeCLT
```

### Cause

`setup.sh` has a safety check:

```bash
if [ "$installdir" = "$thisdir" ]; then
    echo "Installation dir cannot be temporary one: $thisdir"
```

`thisdir` is the extraction directory of the makeself archive. If the user specifies an install path identical to the extraction directory, the script refuses to proceed.

### Solution

Install to a **different directory** from the extraction path (e.g., `/opt/st/stm32cubeclt_1.21.0`).

---

## Issue 2: `cleanup.sh` deletes extraction dir, breaking subsequent runs

### Symptom

```text
bash: cd: /home/amigor/STM32CubeCLT: 没有那个文件或目录
shell-init: 获取当前目录时出错: getcwd: 无法访问父目录: 没有那个文件或目录
```

### Cause

Any failure (including `exit_if_not_interactive`) triggers the `trap` handler, which calls `cleanup.sh` to remove the entire extraction directory. The shell's cwd then points to a deleted directory, causing `getcwd` errors on every command.

### Solution

After this happens, `cd` to a valid directory (e.g., `cd /home/amigor/下载/ppt`) to restore the shell, then re-extract the archive.

---

## Issue 3: License prompt fails under `sudo`

### Symptom

Script stops at `I ACCEPT (y) / I DO NOT ACCEPT (N) [N/y]`, input `y` is not read correctly, shows `License NOT accepted`.

### Cause

When using `sudo bash -c '...'` or piped input, `read` may lose its stdin connection.

### Solution

Set `LICENSE_ALREADY_ACCEPTED=1` to skip the license prompt:

```bash
export LICENSE_ALREADY_ACCEPTED=1
```

`prompt_linux_license.sh` checks this at entry:

```bash
if [ "$LICENSE_ALREADY_ACCEPTED" ] ; then
    exit 0
fi
```

---

## Issue 4: `tar` uses relative path, file not found

### Symptom

```text
tar (child): st-stm32cubeclt*.tar.gz：无法 open: 没有那个文件或目录
```

### Cause

`setup.sh` uses a relative path in `tar` without `cd`-ing to the script directory first:

```bash
tar zxf st-stm32cubeclt*.tar.gz -C $installdir
```

If cwd is not the script directory, the tar.gz cannot be found.

### Solution

**Skip `setup.sh` entirely and perform a manual installation** (see below).

---

## Final Solution: Manual Installation

### Step 1: Extract the archive

```bash
bash st-stm32cubeclt_1.21.0_27995_20260219_1804_amd64.sh --noexec --target /tmp/stm32cubeclt_extract
```

### Step 2: Unpack the tarball to the target directory

```bash
sudo mkdir -p /opt/st/stm32cubeclt_1.21.0
sudo tar zxf /tmp/stm32cubeclt_extract/st-stm32cubeclt_1.21.0_27995_20260219_1804_amd64.tar.gz -C /opt/st/stm32cubeclt_1.21.0
sudo cp /tmp/stm32cubeclt_extract/uninstall_clt.sh /opt/st/stm32cubeclt_1.21.0/
```

### Step 3: Configure environment variables

```bash
sudo tee /etc/profile.d/cubeclt-bin-path_1.21.0.sh > /dev/null << 'EOF'
export PATH="/opt/st/stm32cubeclt_1.21.0:/opt/st/stm32cubeclt_1.21.0/STM32CubeProgrammer/bin:/opt/st/stm32cubeclt_1.21.0/STLink-gdb-server/bin:/opt/st/stm32cubeclt_1.21.0/CMake/bin:/opt/st/stm32cubeclt_1.21.0/Ninja/bin:/opt/st/stm32cubeclt_1.21.0/st-arm-clang/bin:/opt/st/stm32cubeclt_1.21.0/GNU-tools-for-STM32/bin:$PATH"
export CLANG_GCC_CMSIS_COMPILER="/opt/st/stm32cubeclt_1.21.0/st-arm-clang"
export GCC_TOOLCHAIN_ROOT="/opt/st/stm32cubeclt_1.21.0/GNU-tools-for-STM32/bin"
EOF
sudo chmod 644 /etc/profile.d/cubeclt-bin-path_1.21.0.sh
```

### Step 4: Fix directory permissions

```bash
sudo chmod 755 /opt/st/ /opt/st/stm32cubeclt_1.21.0/
```

### Step 5: Install STLink debug support

```bash
sudo bash /tmp/stm32cubeclt_extract/st-stlink-udev-rules-1.0.3-3-linux-noarch.sh  # accept license
sudo bash /tmp/stm32cubeclt_extract/st-stlink-server.2.1.1-1-linux-amd64.install.sh  # accept license
sudo cp /tmp/stm32cubeclt_extract/st-stlink-udev-rules.uninstall.sh /opt/st/stm32cubeclt_1.21.0/
sudo cp /tmp/stm32cubeclt_extract/stlink-server.uninstall.sh /opt/st/stm32cubeclt_1.21.0/
```

### Step 6: Clean up

```bash
rm -rf /tmp/stm32cubeclt_extract
```

### Notes

- **libncurses5 missing warning**: Ubuntu 26.04 no longer ships `libncurses5` (replaced by `libncurses6`). No STM32CubeCLT component actually depends on `libncurses5`; this warning can be safely ignored.
- **OpenSSL version warning**: `libssl.so.3` requires `OPENSSL_3.6.0`. Ubuntu 26.04 may provide a newer version; impact yet to be verified.
- Run `source /etc/profile.d/cubeclt-bin-path_1.21.0.sh` to load environment variables before use.
