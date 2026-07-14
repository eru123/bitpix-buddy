# BitPix Buddy Data Schema

## Buddy Pack structure
buddy-pack/
  manifest.json
  actions/
    idle.json
    working.json
    error.json
    deploying.json
  sprites/
    idle.png
    working.png
    error.png
    deploying.png
  audio/
    tick.wav
    complete.wav
    fail.wav

## manifest.json
{
  "name": "default",
  "version": "1.0.0",
  "default_action": "idle",
  "actions": ["idle", "working", "error", "deploying"]
}

## actions/*.json
{
  "name": "idle",
  "frames": [
    {"file": "idle.png", "duration_ms": 120, "sound": null}
  ],
  "loop": true
}
