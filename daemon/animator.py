#!/usr/bin/env python3
import os, time, json, threading
from pathlib import Path

BASE = Path('/apps/bitpix-buddy')
STATE_FILE = BASE / 'daemon' / 'runtime-state.json'
FRAMES_DIR = BASE / 'buddy-packs' / 'default'

INTERVAL = 1 / 24  # 24fps tick

# Default manifest actions:
# idle -> [frame_1.png, frame_2.png]
# working -> [frame_3.png]
# error -> [frame_4.png]

FPS_MAP = {
    'idle': {'frames': ['frame_1.png','frame_2.png'], 'fps': 24},
    'working': {'frames': ['frame_3.png'], 'fps': 24},
    'error': {'frames': ['frame_4.png'], 'fps': 24},
}

def read_state():
    if not STATE_FILE.exists():
        return 'idle'
    try:
        data = json.loads(STATE_FILE.read_text())
        action = data.get('action', 'idle').strip().lower()
        return action if action in FPS_MAP else 'idle'
    except Exception:
        return 'idle'

def write_state(action: str):
    STATE_FILE.write_text(json.dumps({'action': action}))

def anim_loop():
    action = None
    frame_idx = 0
    last = time.time()
    while True:
        now = time.time()
        if now - last < INTERVAL:
            time.sleep(max(0, INTERVAL - (now - last)))
            last = now

        cur = read_state()
        if cur != action:
            action = cur
            frame_idx = 0
        if action not in FPS_MAP:
            action = 'idle'
            frame_idx = 0

        frames = FPS_MAP[action]['frames']
        frame = frames[frame_idx % len(frames)]
        frame_idx += 1
        # Store currently shown frame index so external clients can inspect if needed
        Path(BASE / 'daemon' / 'runtime-frame.txt').write_text(frame)
        last = time.time()

if __name__ == '__main__':
    write_state('idle')
    t = threading.Thread(target=anim_loop, daemon=True)
    t.start()
    print('animator running at 24fps')
    while True:
        time.sleep(3600)
