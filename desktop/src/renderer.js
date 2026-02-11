// Dragon Chat - Renderer Process
// Handles Matrix SDK and LiveKit integration

// Matrix SDK will be loaded dynamically
let matrixClient = null;
let livekitRoom = null;
let currentRoomId = null;

// DOM Elements
const elements = {
    // Screens
    loginScreen: document.getElementById('login-screen'),
    mainScreen: document.getElementById('main-screen'),
    
    // Login
    loginForm: document.getElementById('login-form'),
    homeserverInput: document.getElementById('homeserver'),
    usernameInput: document.getElementById('username'),
    passwordInput: document.getElementById('password'),
    loginError: document.getElementById('login-error'),
    
    // User
    userName: document.getElementById('user-name'),
    userAvatar: document.getElementById('user-avatar'),
    
    // Rooms
    dmList: document.getElementById('dm-list'),
    roomList: document.getElementById('room-list'),
    voiceList: document.getElementById('voice-list'),
    
    // Current Room
    currentRoomName: document.getElementById('current-room-name'),
    currentRoomTopic: document.getElementById('current-room-topic'),
    messages: document.getElementById('messages'),
    messageInput: document.getElementById('message-input'),
    sendBtn: document.getElementById('send-btn'),
    memberList: document.getElementById('member-list'),
    memberCount: document.getElementById('member-count'),
    
    // Call
    callOverlay: document.getElementById('call-overlay'),
    videoGrid: document.getElementById('video-grid'),
    
    // Settings
    settingsModal: document.getElementById('settings-modal'),
};

// Initialize
async function init() {
    // Load saved homeserver
    const homeserver = await window.electronAPI.getStore('homeserver');
    elements.homeserverInput.value = homeserver;
    
    // Check for saved credentials
    const accessToken = await window.electronAPI.getStore('accessToken');
    const userId = await window.electronAPI.getStore('userId');
    
    if (accessToken && userId) {
        await initMatrix(homeserver, userId, accessToken);
    }
    
    // Setup event listeners
    setupEventListeners();
    setupElectronListeners();
}

function setupEventListeners() {
    // Login form
    elements.loginForm.addEventListener('submit', handleLogin);
    
    // Message input
    elements.messageInput.addEventListener('keypress', (e) => {
        if (e.key === 'Enter' && !e.shiftKey) {
            e.preventDefault();
            sendMessage();
        }
    });
    
    elements.sendBtn.addEventListener('click', sendMessage);
    
    // Room buttons
    document.getElementById('new-room-btn').addEventListener('click', createRoom);
    document.getElementById('new-dm-btn').addEventListener('click', startDM);
    document.getElementById('new-voice-btn').addEventListener('click', createVoiceRoom);
    
    // Call buttons
    document.getElementById('voice-call-btn').addEventListener('click', () => startCall('voice'));
    document.getElementById('video-call-btn').addEventListener('click', () => startCall('video'));
    document.getElementById('screen-share-btn').addEventListener('click', shareScreen);
    document.getElementById('end-call').addEventListener('click', endCall);
    document.getElementById('toggle-mute').addEventListener('click', toggleMute);
    document.getElementById('toggle-video').addEventListener('click', toggleVideo);
    
    // Settings
    document.getElementById('settings-btn').addEventListener('click', openSettings);
    document.getElementById('close-settings').addEventListener('click', closeSettings);
    
    // Logout
    document.getElementById('logout-btn').addEventListener('click', logout);
}

function setupElectronListeners() {
    window.electronAPI.onOpenSettings(() => openSettings());
    window.electronAPI.onCreateRoom(() => createRoom());
    window.electronAPI.onJoinRoom(() => joinRoom());
    window.electronAPI.onStartVoice(() => startCall('voice'));
    window.electronAPI.onStartVideo(() => startCall('video'));
}

// Login Handler
async function handleLogin(e) {
    e.preventDefault();
    
    const homeserver = elements.homeserverInput.value;
    const username = elements.usernameInput.value;
    const password = elements.passwordInput.value;
    
    try {
        showLoginError(null);
        elements.loginForm.querySelector('button').disabled = true;
        elements.loginForm.querySelector('button').textContent = 'Signing in...';
        
        // Initialize Matrix client
        const sdk = await import('matrix-js-sdk');
        const tempClient = sdk.createClient({ baseUrl: homeserver });
        
        // Login
        const response = await tempClient.login('m.login.password', {
            user: username,
            password: password,
        });
        
        // Save credentials
        await window.electronAPI.setStore('accessToken', response.access_token);
        await window.electronAPI.setStore('userId', response.user_id);
        await window.electronAPI.setStore('homeserver', homeserver);
        
        // Initialize with credentials
        await initMatrix(homeserver, response.user_id, response.access_token);
        
    } catch (error) {
        console.error('Login failed:', error);
        showLoginError(error.message || 'Login failed. Please check your credentials.');
    } finally {
        elements.loginForm.querySelector('button').disabled = false;
        elements.loginForm.querySelector('button').textContent = 'Sign In';
    }
}

function showLoginError(message) {
    if (message) {
        elements.loginError.textContent = message;
        elements.loginError.classList.remove('hidden');
    } else {
        elements.loginError.classList.add('hidden');
    }
}

// Matrix Initialization
async function initMatrix(homeserver, userId, accessToken) {
    try {
        const sdk = await import('matrix-js-sdk');
        
        matrixClient = sdk.createClient({
            baseUrl: homeserver,
            accessToken: accessToken,
            userId: userId,
        });
        
        // Setup event handlers
        matrixClient.on('sync', onSync);
        matrixClient.on('Room.timeline', onRoomTimeline);
        matrixClient.on('Room.name', onRoomUpdate);
        matrixClient.on('RoomMember.membership', onMembershipChange);
        
        // Start client
        await matrixClient.startClient({ initialSyncLimit: 20 });
        
    } catch (error) {
        console.error('Matrix init failed:', error);
        showLoginError('Failed to connect to server');
    }
}

function onSync(state) {
    if (state === 'PREPARED') {
        // Show main screen
        elements.loginScreen.classList.add('hidden');
        elements.mainScreen.classList.remove('hidden');
        
        // Update user info
        const user = matrixClient.getUser(matrixClient.getUserId());
        elements.userName.textContent = user?.displayName || matrixClient.getUserId();
        elements.userAvatar.textContent = (user?.displayName || matrixClient.getUserId()).charAt(0).toUpperCase();
        
        // Load rooms
        loadRooms();
    }
}

function loadRooms() {
    const rooms = matrixClient.getRooms();
    
    elements.dmList.innerHTML = '';
    elements.roomList.innerHTML = '';
    elements.voiceList.innerHTML = '';
    
    rooms.forEach(room => {
        const isDM = room.getJoinedMemberCount() === 2;
        const isVoice = room.name?.includes('Voice') || room.name?.includes('🔊');
        
        const roomElement = createRoomElement(room);
        
        if (isVoice) {
            elements.voiceList.appendChild(roomElement);
        } else if (isDM) {
            elements.dmList.appendChild(roomElement);
        } else {
            elements.roomList.appendChild(roomElement);
        }
    });
}

function createRoomElement(room) {
    const div = document.createElement('div');
    div.className = 'room-item';
    div.dataset.roomId = room.roomId;
    
    const unreadCount = room.getUnreadNotificationCount('total');
    
    div.innerHTML = `
        <span class="room-icon">${room.name?.charAt(0) || '#'}</span>
        <span class="room-name">${room.name || 'Unnamed Room'}</span>
        ${unreadCount > 0 ? `<span class="unread-badge">${unreadCount}</span>` : ''}
    `;
    
    div.addEventListener('click', () => selectRoom(room.roomId));
    
    return div;
}

// Room Selection
async function selectRoom(roomId) {
    currentRoomId = roomId;
    const room = matrixClient.getRoom(roomId);
    
    if (!room) return;
    
    // Update UI
    document.querySelectorAll('.room-item').forEach(el => el.classList.remove('active'));
    document.querySelector(`[data-room-id="${roomId}"]`)?.classList.add('active');
    
    elements.currentRoomName.textContent = room.name || 'Unnamed Room';
    elements.currentRoomTopic.textContent = room.currentState.getStateEvents('m.room.topic', '')?.[0]?.getContent()?.topic || '';
    
    // Enable input
    elements.messageInput.disabled = false;
    elements.sendBtn.disabled = false;
    elements.messageInput.placeholder = `Message ${room.name}...`;
    
    // Load messages
    loadMessages(room);
    
    // Load members
    loadMembers(room);
    
    // Mark as read
    matrixClient.sendReadReceipt(room.timeline[room.timeline.length - 1]);
}

function loadMessages(room) {
    elements.messages.innerHTML = '';
    
    const timeline = room.timeline.slice(-50);
    
    timeline.forEach(event => {
        if (event.getType() === 'm.room.message') {
            addMessage(event);
        }
    });
    
    scrollToBottom();
}

function addMessage(event) {
    const content = event.getContent();
    const sender = matrixClient.getUser(event.getSender());
    
    const div = document.createElement('div');
    div.className = 'message';
    div.dataset.eventId = event.getId();
    
    const time = new Date(event.getTs()).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    
    div.innerHTML = `
        <div class="message-avatar">${(sender?.displayName || event.getSender()).charAt(0).toUpperCase()}</div>
        <div class="message-content">
            <div class="message-header">
                <span class="message-author">${sender?.displayName || event.getSender()}</span>
                <span class="message-time">${time}</span>
            </div>
            <div class="message-text">${escapeHtml(content.body || '')}</div>
        </div>
    `;
    
    elements.messages.appendChild(div);
}

function onRoomTimeline(event, room) {
    if (room.roomId === currentRoomId && event.getType() === 'm.room.message') {
        addMessage(event);
        scrollToBottom();
    }
    
    // Update room list for unread counts
    loadRooms();
}

function onRoomUpdate() {
    loadRooms();
}

function onMembershipChange() {
    if (currentRoomId) {
        const room = matrixClient.getRoom(currentRoomId);
        if (room) loadMembers(room);
    }
}

function loadMembers(room) {
    const members = room.getJoinedMembers();
    
    elements.memberCount.textContent = members.length;
    elements.memberList.innerHTML = '';
    
    members.forEach(member => {
        const div = document.createElement('div');
        div.className = 'member-item';
        div.innerHTML = `
            <div class="member-avatar">${(member.name || member.userId).charAt(0).toUpperCase()}</div>
            <span class="member-name">${member.name || member.userId}</span>
            <span class="member-status-dot"></span>
        `;
        elements.memberList.appendChild(div);
    });
}

// Send Message
async function sendMessage() {
    const text = elements.messageInput.value.trim();
    if (!text || !currentRoomId) return;
    
    try {
        await matrixClient.sendMessage(currentRoomId, {
            msgtype: 'm.text',
            body: text,
        });
        
        elements.messageInput.value = '';
    } catch (error) {
        console.error('Failed to send message:', error);
    }
}

// Voice/Video Calls with LiveKit
async function startCall(type) {
    if (!currentRoomId) return;
    
    try {
        const { Room, RoomEvent, VideoPresets } = await import('livekit-client');
        
        const livekitUrl = await window.electronAPI.getStore('livekitUrl');
        
        // Get token from your server
        const token = await getLivekitToken(currentRoomId);
        
        livekitRoom = new Room();
        
        livekitRoom.on(RoomEvent.TrackSubscribed, handleTrackSubscribed);
        livekitRoom.on(RoomEvent.TrackUnsubscribed, handleTrackUnsubscribed);
        livekitRoom.on(RoomEvent.ParticipantConnected, handleParticipantConnected);
        livekitRoom.on(RoomEvent.ParticipantDisconnected, handleParticipantDisconnected);
        
        await livekitRoom.connect(livekitUrl, token);
        
        // Enable media based on call type
        if (type === 'video') {
            await livekitRoom.localParticipant.enableCameraAndMicrophone();
        } else {
            await livekitRoom.localParticipant.setMicrophoneEnabled(true);
        }
        
        // Show call overlay
        elements.callOverlay.classList.remove('hidden');
        document.getElementById('call-title').textContent = type === 'video' ? 'Video Call' : 'Voice Call';
        
        // Add local video
        addVideoTile(livekitRoom.localParticipant, true);
        
    } catch (error) {
        console.error('Failed to start call:', error);
        alert('Failed to start call: ' + error.message);
    }
}

async function getLivekitToken(roomName) {
    // In production, fetch this from your server
    // For now, return a placeholder
    const response = await fetch(`https://livekit.y7xyz.com/api/token`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            roomName: roomName,
            participantName: matrixClient.getUserId(),
        }),
    });
    
    const data = await response.json();
    return data.token;
}

function addVideoTile(participant, isLocal = false) {
    const tile = document.createElement('div');
    tile.className = 'video-tile';
    tile.id = `tile-${participant.identity}`;
    
    tile.innerHTML = `
        <video autoplay playsinline ${isLocal ? 'muted' : ''}></video>
        <span class="participant-name">${participant.identity}${isLocal ? ' (You)' : ''}</span>
    `;
    
    elements.videoGrid.appendChild(tile);
    
    // Attach tracks
    participant.videoTracks.forEach(publication => {
        if (publication.track) {
            publication.track.attach(tile.querySelector('video'));
        }
    });
}

function handleTrackSubscribed(track, publication, participant) {
    const tile = document.getElementById(`tile-${participant.identity}`);
    if (tile && track.kind === 'video') {
        track.attach(tile.querySelector('video'));
    }
}

function handleTrackUnsubscribed(track) {
    track.detach();
}

function handleParticipantConnected(participant) {
    addVideoTile(participant);
}

function handleParticipantDisconnected(participant) {
    const tile = document.getElementById(`tile-${participant.identity}`);
    if (tile) tile.remove();
}

function toggleMute() {
    if (!livekitRoom) return;
    const enabled = livekitRoom.localParticipant.isMicrophoneEnabled;
    livekitRoom.localParticipant.setMicrophoneEnabled(!enabled);
    document.getElementById('toggle-mute').classList.toggle('active', enabled);
}

function toggleVideo() {
    if (!livekitRoom) return;
    const enabled = livekitRoom.localParticipant.isCameraEnabled;
    livekitRoom.localParticipant.setCameraEnabled(!enabled);
    document.getElementById('toggle-video').classList.toggle('active', enabled);
}

async function shareScreen() {
    if (!livekitRoom) return;
    try {
        await livekitRoom.localParticipant.setScreenShareEnabled(true);
    } catch (error) {
        console.error('Screen share failed:', error);
    }
}

async function endCall() {
    if (livekitRoom) {
        await livekitRoom.disconnect();
        livekitRoom = null;
    }
    elements.callOverlay.classList.add('hidden');
    elements.videoGrid.innerHTML = '';
}

// Room Actions
async function createRoom() {
    const name = prompt('Room name:');
    if (!name) return;
    
    try {
        const result = await matrixClient.createRoom({
            name: name,
            visibility: 'private',
            preset: 'private_chat',
        });
        
        selectRoom(result.room_id);
    } catch (error) {
        console.error('Failed to create room:', error);
    }
}

async function createVoiceRoom() {
    const name = prompt('Voice channel name:');
    if (!name) return;
    
    try {
        const result = await matrixClient.createRoom({
            name: `🔊 ${name}`,
            visibility: 'private',
            preset: 'private_chat',
        });
        
        selectRoom(result.room_id);
    } catch (error) {
        console.error('Failed to create voice room:', error);
    }
}

async function startDM() {
    const userId = prompt('User ID (e.g., @user:y7xyz.com):');
    if (!userId) return;
    
    try {
        const result = await matrixClient.createRoom({
            is_direct: true,
            invite: [userId],
            preset: 'trusted_private_chat',
        });
        
        selectRoom(result.room_id);
    } catch (error) {
        console.error('Failed to create DM:', error);
    }
}

async function joinRoom() {
    const roomId = prompt('Room ID or alias:');
    if (!roomId) return;
    
    try {
        await matrixClient.joinRoom(roomId);
        loadRooms();
    } catch (error) {
        console.error('Failed to join room:', error);
    }
}

// Settings
function openSettings() {
    elements.settingsModal.classList.remove('hidden');
}

function closeSettings() {
    elements.settingsModal.classList.add('hidden');
}

// Logout
async function logout() {
    if (confirm('Are you sure you want to sign out?')) {
        if (matrixClient) {
            await matrixClient.logout();
            matrixClient.stopClient();
        }
        
        await window.electronAPI.setStore('accessToken', null);
        await window.electronAPI.setStore('userId', null);
        
        elements.mainScreen.classList.add('hidden');
        elements.loginScreen.classList.remove('hidden');
    }
}

// Utilities
function scrollToBottom() {
    elements.messages.scrollTop = elements.messages.scrollHeight;
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Initialize app
init();
