const { contextBridge, ipcRenderer } = require('electron');

// Expose protected methods to renderer
contextBridge.exposeInMainWorld('electronAPI', {
    // Store
    getStore: (key) => ipcRenderer.invoke('get-store', key),
    setStore: (key, value) => ipcRenderer.invoke('set-store', key, value),
    
    // App info
    getVersion: () => ipcRenderer.invoke('get-version'),
    
    // Events from main
    onOpenSettings: (callback) => ipcRenderer.on('open-settings', callback),
    onCreateRoom: (callback) => ipcRenderer.on('create-room', callback),
    onJoinRoom: (callback) => ipcRenderer.on('join-room', callback),
    onStartVoice: (callback) => ipcRenderer.on('start-voice', callback),
    onStartVideo: (callback) => ipcRenderer.on('start-video', callback),
    onShowAbout: (callback) => ipcRenderer.on('show-about', callback),
    
    // Platform
    platform: process.platform
});
