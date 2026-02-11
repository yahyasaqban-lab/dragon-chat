const { app, BrowserWindow, Menu, Tray, ipcMain, shell, nativeTheme } = require('electron');
const path = require('path');
const Store = require('electron-store');

// Initialize store for settings
const store = new Store({
    defaults: {
        homeserver: 'https://matrix.y7xyz.com',
        livekitUrl: 'wss://livekit.y7xyz.com',
        windowBounds: { width: 1200, height: 800 },
        theme: 'dark',
        minimizeToTray: true,
        startMinimized: false
    }
});

let mainWindow;
let tray;

// Single instance lock
const gotTheLock = app.requestSingleInstanceLock();
if (!gotTheLock) {
    app.quit();
} else {
    app.on('second-instance', () => {
        if (mainWindow) {
            if (mainWindow.isMinimized()) mainWindow.restore();
            mainWindow.focus();
        }
    });
}

function createWindow() {
    const bounds = store.get('windowBounds');
    
    mainWindow = new BrowserWindow({
        width: bounds.width,
        height: bounds.height,
        minWidth: 800,
        minHeight: 600,
        title: 'Dragon Chat',
        icon: path.join(__dirname, '../assets/icon.png'),
        webPreferences: {
            nodeIntegration: false,
            contextIsolation: true,
            preload: path.join(__dirname, 'preload.js'),
            webSecurity: true
        },
        backgroundColor: '#1a1a2e',
        titleBarStyle: process.platform === 'darwin' ? 'hiddenInset' : 'default',
        show: !store.get('startMinimized')
    });

    // Load the app
    mainWindow.loadFile(path.join(__dirname, 'index.html'));

    // Save window size on resize
    mainWindow.on('resize', () => {
        const { width, height } = mainWindow.getBounds();
        store.set('windowBounds', { width, height });
    });

    // Handle close
    mainWindow.on('close', (event) => {
        if (store.get('minimizeToTray') && !app.isQuitting) {
            event.preventDefault();
            mainWindow.hide();
        }
    });

    mainWindow.on('closed', () => {
        mainWindow = null;
    });

    // Open external links in browser
    mainWindow.webContents.setWindowOpenHandler(({ url }) => {
        shell.openExternal(url);
        return { action: 'deny' };
    });
}

function createTray() {
    const iconPath = path.join(__dirname, '../assets/tray-icon.png');
    tray = new Tray(iconPath);
    
    const contextMenu = Menu.buildFromTemplate([
        { 
            label: 'Show Dragon Chat', 
            click: () => mainWindow.show() 
        },
        { type: 'separator' },
        {
            label: 'Status',
            submenu: [
                { label: '🟢 Online', type: 'radio', checked: true },
                { label: '🟡 Away', type: 'radio' },
                { label: '🔴 Do Not Disturb', type: 'radio' },
                { label: '⚫ Invisible', type: 'radio' }
            ]
        },
        { type: 'separator' },
        { 
            label: 'Settings', 
            click: () => {
                mainWindow.show();
                mainWindow.webContents.send('open-settings');
            }
        },
        { type: 'separator' },
        { 
            label: 'Quit', 
            click: () => {
                app.isQuitting = true;
                app.quit();
            }
        }
    ]);
    
    tray.setToolTip('Dragon Chat');
    tray.setContextMenu(contextMenu);
    
    tray.on('click', () => {
        if (mainWindow.isVisible()) {
            mainWindow.hide();
        } else {
            mainWindow.show();
        }
    });
}

function createMenu() {
    const template = [
        {
            label: 'Dragon Chat',
            submenu: [
                { label: 'About Dragon Chat', role: 'about' },
                { type: 'separator' },
                { label: 'Settings', accelerator: 'CmdOrCtrl+,', click: () => mainWindow.webContents.send('open-settings') },
                { type: 'separator' },
                { label: 'Hide', accelerator: 'CmdOrCtrl+H', role: 'hide' },
                { label: 'Quit', accelerator: 'CmdOrCtrl+Q', click: () => { app.isQuitting = true; app.quit(); } }
            ]
        },
        {
            label: 'Edit',
            submenu: [
                { role: 'undo' },
                { role: 'redo' },
                { type: 'separator' },
                { role: 'cut' },
                { role: 'copy' },
                { role: 'paste' },
                { role: 'selectAll' }
            ]
        },
        {
            label: 'View',
            submenu: [
                { role: 'reload' },
                { role: 'forceReload' },
                { role: 'toggleDevTools' },
                { type: 'separator' },
                { role: 'resetZoom' },
                { role: 'zoomIn' },
                { role: 'zoomOut' },
                { type: 'separator' },
                { role: 'togglefullscreen' }
            ]
        },
        {
            label: 'Rooms',
            submenu: [
                { label: 'Create Room', accelerator: 'CmdOrCtrl+N', click: () => mainWindow.webContents.send('create-room') },
                { label: 'Join Room', accelerator: 'CmdOrCtrl+J', click: () => mainWindow.webContents.send('join-room') },
                { type: 'separator' },
                { label: 'Start Voice Call', accelerator: 'CmdOrCtrl+Shift+V', click: () => mainWindow.webContents.send('start-voice') },
                { label: 'Start Video Call', accelerator: 'CmdOrCtrl+Shift+C', click: () => mainWindow.webContents.send('start-video') }
            ]
        },
        {
            label: 'Help',
            submenu: [
                { label: 'Documentation', click: () => shell.openExternal('https://docs.y7xyz.com') },
                { label: 'Report Issue', click: () => shell.openExternal('https://github.com/yahya/dragon-chat/issues') },
                { type: 'separator' },
                { label: 'About', click: () => mainWindow.webContents.send('show-about') }
            ]
        }
    ];
    
    const menu = Menu.buildFromTemplate(template);
    Menu.setApplicationMenu(menu);
}

// IPC Handlers
ipcMain.handle('get-store', (event, key) => store.get(key));
ipcMain.handle('set-store', (event, key, value) => store.set(key, value));
ipcMain.handle('get-version', () => app.getVersion());

// App events
app.whenReady().then(() => {
    nativeTheme.themeSource = store.get('theme');
    createWindow();
    createTray();
    createMenu();
    
    app.on('activate', () => {
        if (BrowserWindow.getAllWindows().length === 0) {
            createWindow();
        } else {
            mainWindow.show();
        }
    });
});

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
        app.quit();
    }
});

app.on('before-quit', () => {
    app.isQuitting = true;
});
