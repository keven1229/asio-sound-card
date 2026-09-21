#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ASIO-CARD UART 协议参考实现 (ESP32 侧) — 与 XU316 固件严格对齐
固件实现: firmware/sw_usb_audio/app_usb_aud_asiocard/src/extensions/usb_uart_ctrl.xc
协议定义: docs/schematic/05-control.md §5.4

帧格式 (921600-8N1):
    0xAA | CMD | LEN | PAYLOAD[0..LEN-1] | CRC8 | 0x55
    CRC8: poly 0x07, MSB-first, init 0x00, 覆盖 CMD..PAYLOAD

用途:
    1. 自测:   python esp32_protocol_ref.py           (全量自测)
    2. 参考向量: python esp32_protocol_ref.py --vectors  (打印可交叉验证的帧)
    3. 联调辅助: import 本文件的 encode_frame/decode_frame/parse_vu
"""
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")   # 避免 Windows 控制台 GBK 乱码

FRAME_HEAD = 0xAA
FRAME_TAIL = 0x55

# 命令 (ESP32 -> XU316)
CMD_SET_MIX  = 0x01   # 10 电平 + 限幅阈值 + 使能
CMD_QUERY    = 0x02
CMD_FACTORY  = 0x03
CMD_PRESET   = 0x04
# 响应 (XU316 -> ESP32)
RESP_VU      = 0x11
RESP_STATUS  = 0x12
RESP_EVENT   = 0x13

# 混音源顺序 (与固件 ASIOCARD_SRC_COUNT=5 一致)
SRC_MIC, SRC_LINE, SRC_MAIN, SRC_BACKING, SRC_GAME = range(5)

# 预设电平表 (与固件 presets[3][10] 对齐; 联调时如需改, 两边同步)
PRESETS = {
    0: [255, 255, 0,   0,   0,   255, 255, 255, 255, 255],   # 直通
    1: [255, 180, 200, 180, 150,  255, 200, 255, 220, 180],  # 直播标准
    2: [255, 255, 255, 255, 255,  0,   0,   0,   0,   0],    # 纯监听
}
DEFAULT_LIMITER_THRESH_DB = 3
DEFAULT_LIMITER_ENABLE = 1


def crc8(data: bytes, init: int = 0x00) -> int:
    """CRC8 poly 0x07, MSB-first, init 0x00 — 与固件 crc8_update 一致"""
    crc = init
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = ((crc << 1) ^ 0x07) & 0xFF if (crc & 0x80) else (crc << 1) & 0xFF
    return crc


def encode_frame(cmd: int, payload: bytes) -> bytes:
    assert 0 <= cmd <= 0xFF and len(payload) <= 0xFF
    body = bytes([cmd, len(payload)]) + payload
    return bytes([FRAME_HEAD]) + body + bytes([crc8(body)]) + bytes([FRAME_TAIL])


def decode_frame(buf: bytearray) -> tuple:
    """从字节流中取出一帧. 返回 (cmd, payload) 或 None (数据不足时保留缓冲).
    帧尾/CRC 错则丢弃帧头重同步 (与固件状态机同语义)."""
    while len(buf) >= 5:
        if buf[0] != FRAME_HEAD:
            buf.pop(0)
            continue
        length = buf[2]
        total = 5 + length          # HEAD CMD LEN PAYLOAD CRC TAIL
        if len(buf) < total:
            return None             # 帧不完整, 等更多字节
        crc_ok  = (crc8(bytes(buf[1:3 + length])) == buf[3 + length])
        tail_ok = (buf[4 + length] == FRAME_TAIL)
        if crc_ok and tail_ok:
            cmd, payload = buf[1], bytes(buf[3:3 + length])
            del buf[:total]
            return (cmd, payload)
        buf.pop(0)                  # 校验失败: 丢帧头, 重同步
    return None


def build_set_mix(levels_monitor, levels_stream, limiter_thresh_db=DEFAULT_LIMITER_THRESH_DB,
                  limiter_enable=DEFAULT_LIMITER_ENABLE) -> bytes:
    """0x01: 10 电平(监听 5 + 直播混音 5, 0..255) + 阈值(-dB) + 使能"""
    payload = bytes(levels_monitor + levels_stream) + bytes([limiter_thresh_db, limiter_enable])
    assert len(payload) == 12
    return encode_frame(CMD_SET_MIX, payload)


def build_query() -> bytes:
    return encode_frame(CMD_QUERY, b"")


def build_factory_reset() -> bytes:
    return encode_frame(CMD_FACTORY, b"")


def build_preset(n: int) -> bytes:
    return encode_frame(CMD_PRESET, bytes([n]))


def parse_vu(payload: bytes) -> dict:
    """0x11: 7 个 int16 小端 dBFS*100 (mic, line, streamMixL/R, monitorL/R, clip) + 1B clip 标志"""
    assert len(payload) == 15, f"0x11 payload 长度应为 15, 实际 {len(payload)}"
    vals = [int.from_bytes(payload[i:i + 2], "little", signed=True) for i in range(0, 14, 2)]
    return {
        "mic_db100": vals[0], "line_db100": vals[1],
        "streamMixL_db100": vals[2], "streamMixR_db100": vals[3],
        "monitorL_db100": vals[4], "monitorR_db100": vals[5],
        "clip_db100": vals[6], "clip_flag": payload[14],
    }


def parse_status(payload: bytes) -> dict:
    """0x12: usb(1B) 采样率族(1B, 0=44.1k族) 速率(2B LE, Hz/100) 固件版本(2B LE)"""
    assert len(payload) == 6
    return {
        "usb_attached": payload[0],
        "rate_family": payload[1],
        "samplerate": int.from_bytes(payload[2:4], "little") * 100,
        "fw_version": int.from_bytes(payload[4:6], "little"),
    }


# ---------------- 自测 ----------------
def _test_crc():
    # 参考向量 (可人工核对: CRC-8 poly 0x07 init 0 对 "123456789" = 0xF4)
    assert crc8(b"123456789") == 0xF4, f"CRC 参考向量失败: {crc8(b'123456789'):#x}"
    print("[PASS] CRC8 poly0x07 MSB-first init0 (check value 0xF4)")

def _test_frames():
    f = build_set_mix([255, 255, 0, 0, 0], [255, 200, 255, 220, 180], 3, 1)
    assert f[0] == 0xAA and f[-1] == 0x55 and f[2] == 12
    buf = bytearray(f)
    cmd, payload = decode_frame(buf)
    assert cmd == CMD_SET_MIX and len(payload) == 12 and len(buf) == 0
    print("[PASS] 0x01 帧编解码回环")

    # 损坏一字节应丢弃重同步
    bad = bytearray(f); bad[6] ^= 0xFF
    assert decode_frame(bad) is None
    print("[PASS] CRC 损坏帧被丢弃")

    # 0x11 解析: mic=+1.00dB, line=-3.16dB, 其余 0, clip 标志=1
    vu = (100).to_bytes(2, "little", signed=True) \
       + (-316).to_bytes(2, "little", signed=True) \
       + bytes(8) + (0).to_bytes(2, "little", signed=True) + bytes([1])
    d = parse_vu(vu)
    assert d["mic_db100"] == 100 and d["line_db100"] == -316 and d["clip_flag"] == 1
    print("[PASS] 0x11 VU 解析 (100 / -3.16dB / clip)")

    # 0x12 解析: usb=1, 48k族, 192000Hz(编码 1920), fw 0x0100
    st = bytes([1, 1]) + (1920).to_bytes(2, "little") + (0x0100).to_bytes(2, "little")
    d = parse_status(st)
    assert d["samplerate"] == 192000 and d["fw_version"] == 0x0100 and d["usb_attached"] == 1
    print("[PASS] 0x12 状态解析 (192kHz / fw 1.0)")

def _print_vectors():
    print("-- 参考帧向量 (hex, 供 ESP32 侧抓包交叉验证) --")
    for name, f in [
        ("0x01 直播标准混音", build_set_mix(PRESETS[1][:5], PRESETS[1][5:], 3, 1)),
        ("0x02 查询", build_query()),
        ("0x03 恢复出厂", build_factory_reset()),
        ("0x04 预设2(纯监听)", build_preset(2)),
    ]:
        print(f"  {name:20s} {f.hex(' ')}")

if __name__ == "__main__":
    if "--vectors" in sys.argv:
        _print_vectors()
    else:
        print("== ASIO-CARD UART 协议参考实现自测 ==")
        _test_crc()
        _test_frames()
        print("== 全部通过 ==")
