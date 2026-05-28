#!/bin/bash
# 一键切换 扬声器 <-> 耳机
# 针对 Realtek ALC245 插孔检测失效的修复
# 需要 WirePlumber 配置禁用 ACP (已配置在 51-headphone-fix.conf)
# 使用: bash switch-audio.sh

# 检测当前状态: 读取耳机开关（on,on=耳机模式, off,off=扬声器模式）
HP_STATE=$(amixer -c0 cget numid=2 2>/dev/null | grep -oP '(?<=: values=)\S+')

if [ "$HP_STATE" = "on,on" ]; then
    # ── 切换到扬声器 ──
    echo "🔊 切换到 扬声器"
    amixer -c0 cset numid=2 off,off >/dev/null 2>&1   # 关闭耳机
    amixer -c0 cset numid=1 0,0     >/dev/null 2>&1   # 耳机音量归零
    amixer -c0 cset numid=4 on,on   >/dev/null 2>&1   # 开启扬声器
    amixer -c0 cset numid=3 87,87   >/dev/null 2>&1   # 扬声器音量最大
    echo "✅ 当前: 扬声器"
else
    # ── 切换到耳机 ──
    echo "🎧 切换到 耳机"
    amixer -c0 cset numid=4 off,off >/dev/null 2>&1   # 关闭扬声器
    amixer -c0 cset numid=3 0,0     >/dev/null 2>&1   # 扬声器音量归零
    amixer -c0 cset numid=2 on,on   >/dev/null 2>&1   # 开启耳机
    amixer -c0 cset numid=1 70,70   >/dev/null 2>&1   # 耳机音量 70%
    echo "✅ 当前: 耳机"
fi
