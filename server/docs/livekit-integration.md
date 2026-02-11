# LiveKit Integration Guide

## Voice/Video Rooms in Element

### Option 1: Element Call (Built-in)

Element has built-in video calling. Enable in Element settings:
1. Settings → Labs
2. Enable "Video rooms"
3. Enable "Element Call video rooms"

Create video room:
1. Click "+" to create room
2. Select "Video room"
3. Done!

### Option 2: Custom LiveKit Widget

Add LiveKit as a widget to any room.

#### Create LiveKit Room Widget

```javascript
// livekit-widget.js
const LIVEKIT_URL = 'wss://livekit.y7xyz.com';
const API_KEY = 'your-api-key';
const API_SECRET = 'your-api-secret';

// Generate access token (do this server-side!)
async function getToken(roomName, participantName) {
    const response = await fetch('/api/livekit/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ roomName, participantName })
    });
    return response.json();
}
```

#### Token Server (Node.js)

```javascript
// server.js
const express = require('express');
const { AccessToken } = require('livekit-server-sdk');

const app = express();
app.use(express.json());

const API_KEY = process.env.LIVEKIT_API_KEY;
const API_SECRET = process.env.LIVEKIT_API_SECRET;

app.post('/api/livekit/token', (req, res) => {
    const { roomName, participantName } = req.body;
    
    const token = new AccessToken(API_KEY, API_SECRET, {
        identity: participantName,
    });
    
    token.addGrant({
        roomJoin: true,
        room: roomName,
        canPublish: true,
        canSubscribe: true,
        canPublishData: true,
    });
    
    res.json({ token: token.toJwt() });
});

app.listen(3001);
```

#### Matrix Widget URL

Add widget to room:
```
/addwidget https://your-livekit-widget.com?room=$room_id&user=$user_id
```

---

## Streaming with LiveKit

### Start a Stream

```bash
# Using LiveKit CLI
livekit-cli create-room --name "stream-room" \
    --url wss://livekit.y7xyz.com \
    --api-key $LIVEKIT_API_KEY \
    --api-secret $LIVEKIT_API_SECRET

# Start RTMP ingress (for OBS)
livekit-cli create-ingress \
    --url wss://livekit.y7xyz.com \
    --api-key $LIVEKIT_API_KEY \
    --api-secret $LIVEKIT_API_SECRET \
    --room "stream-room" \
    --name "My Stream" \
    --input-type rtmp
```

### OBS Settings

```
Server: rtmp://livekit.y7xyz.com:1935/live
Stream Key: (from create-ingress output)
```

### Record a Stream

```bash
# Start recording
livekit-cli start-egress \
    --url wss://livekit.y7xyz.com \
    --api-key $LIVEKIT_API_KEY \
    --api-secret $LIVEKIT_API_SECRET \
    --room "stream-room" \
    --output /recordings/stream.mp4
```

---

## Mobile Apps

### Element (iOS/Android)
- Built-in voice/video calls
- Works with your Matrix server
- Download from App Store / Play Store

### LiveKit Meet App
- For dedicated video rooms
- https://meet.livekit.io

---

## API Examples

### Create Room (Python)

```python
from livekit import api

client = api.LiveKitAPI(
    'https://livekit.y7xyz.com',
    'API_KEY',
    'API_SECRET'
)

# Create room
room = client.room.create_room(
    api.CreateRoomRequest(name="my-room", empty_timeout=600)
)

# List participants
participants = client.room.list_participants(
    api.ListParticipantsRequest(room="my-room")
)
```

### Generate Token (Python)

```python
from livekit import api
import time

token = api.AccessToken('API_KEY', 'API_SECRET')
token.with_identity("user123")
token.with_name("John Doe")
token.add_grant(api.VideoGrants(
    room_join=True,
    room="my-room",
    can_publish=True,
    can_subscribe=True
))
token.with_ttl(time.timedelta(hours=1))

jwt = token.to_jwt()
```

---

## Troubleshooting

### No audio/video
- Check TURN server: `turnutils_uclient -T -u test -w test turn.y7xyz.com`
- Check firewall: ports 3478, 5349, 50000-60000

### Connection fails
- Verify LiveKit is running: `docker logs livekit`
- Check WebSocket: `wscat -c wss://livekit.y7xyz.com`

### Echo/feedback
- Enable echo cancellation in LiveKit config
- Use headphones

---

Created by Dragon 🐉
