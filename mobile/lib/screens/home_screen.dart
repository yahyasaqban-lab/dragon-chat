import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:matrix/matrix.dart';
import '../services/matrix_service.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🐉 ', style: TextStyle(fontSize: 24)),
            const Text('Dragon Chat'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearch,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showNewChatOptions,
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') _logout();
              if (value == 'settings') _openSettings();
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildChatList(),
          _buildVoiceChannels(),
          _buildProfile(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic_none),
            activeIcon: Icon(Icons.mic),
            label: 'Voice',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return Consumer<MatrixService>(
      builder: (context, matrixService, child) {
        final rooms = matrixService.rooms;
        
        if (rooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🐉', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  'No chats yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a new conversation',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _showNewChatOptions,
                  icon: const Icon(Icons.add),
                  label: const Text('New Chat'),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: rooms.length,
          itemBuilder: (context, index) {
            final room = rooms[index];
            return _buildRoomTile(room);
          },
        );
      },
    );
  }

  Widget _buildRoomTile(Room room) {
    final lastEvent = room.lastEvent;
    final unreadCount = room.notificationCount;
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.accent,
        child: Text(
          (room.name ?? 'R')[0].toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(
        room.name ?? 'Unnamed Room',
        style: TextStyle(
          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        lastEvent?.body ?? 'No messages yet',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unreadCount > 0 ? AppColors.textPrimary : AppColors.textSecondary,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lastEvent != null)
            Text(
              _formatTime(lastEvent.originServerTs),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () => _openChat(room),
    );
  }

  Widget _buildVoiceChannels() {
    return Consumer<MatrixService>(
      builder: (context, matrixService, child) {
        final voiceRooms = matrixService.rooms
            .where((r) => r.name?.contains('🔊') ?? false)
            .toList();
        
        if (voiceRooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic_off, size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text(
                  'No voice channels',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _createVoiceChannel,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Voice Channel'),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: voiceRooms.length,
          itemBuilder: (context, index) {
            final room = voiceRooms[index];
            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.success,
                child: Icon(Icons.mic, color: Colors.white),
              ),
              title: Text(room.name ?? 'Voice Channel'),
              subtitle: Text('${room.summary.mJoinedMemberCount ?? 0} members'),
              trailing: IconButton(
                icon: const Icon(Icons.call),
                onPressed: () => _joinVoiceChannel(room),
              ),
              onTap: () => _joinVoiceChannel(room),
            );
          },
        );
      },
    );
  }

  Widget _buildProfile() {
    return Consumer<MatrixService>(
      builder: (context, matrixService, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.accent,
                    child: Text(
                      (matrixService.displayName ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(fontSize: 40, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    matrixService.displayName ?? 'User',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    matrixService.userId ?? '',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Settings
            _buildSettingsTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: Icons.palette_outlined,
              title: 'Appearance',
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: Icons.security_outlined,
              title: 'Privacy & Security',
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: Icons.storage_outlined,
              title: 'Data & Storage',
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: Icons.help_outline,
              title: 'Help',
              onTap: () {},
            ),
            const Divider(height: 32),
            _buildSettingsTile(
              icon: Icons.logout,
              title: 'Logout',
              titleColor: AppColors.error,
              onTap: _logout,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? AppColors.textSecondary),
      title: Text(title, style: TextStyle(color: titleColor)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inDays > 0) {
      return '${diff.inDays}d';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m';
    } else {
      return 'now';
    }
  }

  void _openChat(Room room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(room: room),
      ),
    );
  }

  void _showSearch() {
    // Implement search
  }

  void _showNewChatOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.secondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.accent,
                child: Icon(Icons.person_add, color: Colors.white),
              ),
              title: const Text('New Direct Message'),
              onTap: () {
                Navigator.pop(context);
                _createDirectMessage();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.tertiary,
                child: Icon(Icons.group_add, color: Colors.white),
              ),
              title: const Text('Create Room'),
              onTap: () {
                Navigator.pop(context);
                _createRoom();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.success,
                child: Icon(Icons.mic, color: Colors.white),
              ),
              title: const Text('Create Voice Channel'),
              onTap: () {
                Navigator.pop(context);
                _createVoiceChannel();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.warning,
                child: Icon(Icons.login, color: Colors.white),
              ),
              title: const Text('Join Room'),
              onTap: () {
                Navigator.pop(context);
                _joinRoom();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createDirectMessage() async {
    final userId = await _showInputDialog('User ID', 'Enter user ID (e.g., @user:y7xyz.com)');
    if (userId == null || userId.isEmpty) return;
    
    final matrixService = Provider.of<MatrixService>(context, listen: false);
    final room = await matrixService.createRoom(
      name: '',
      isDirect: true,
      inviteIds: [userId],
    );
    
    if (room != null && mounted) {
      _openChat(room);
    }
  }

  Future<void> _createRoom() async {
    final name = await _showInputDialog('Room Name', 'Enter room name');
    if (name == null || name.isEmpty) return;
    
    final matrixService = Provider.of<MatrixService>(context, listen: false);
    final room = await matrixService.createRoom(name: name);
    
    if (room != null && mounted) {
      _openChat(room);
    }
  }

  Future<void> _createVoiceChannel() async {
    final name = await _showInputDialog('Voice Channel', 'Enter channel name');
    if (name == null || name.isEmpty) return;
    
    final matrixService = Provider.of<MatrixService>(context, listen: false);
    await matrixService.createRoom(name: '🔊 $name');
  }

  Future<void> _joinRoom() async {
    final roomId = await _showInputDialog('Join Room', 'Enter room ID or alias');
    if (roomId == null || roomId.isEmpty) return;
    
    final matrixService = Provider.of<MatrixService>(context, listen: false);
    final room = await matrixService.joinRoom(roomId);
    
    if (room != null && mounted) {
      _openChat(room);
    }
  }

  void _joinVoiceChannel(Room room) {
    // Start voice call in the room
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(room: room, startCall: true),
      ),
    );
  }

  Future<String?> _showInputDialog(String title, String hint) async {
    String? value;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondary,
        title: Text(title),
        content: TextField(
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onChanged: (v) => value = v,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return value;
  }

  void _openSettings() {
    // Navigate to settings
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondary,
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      final matrixService = Provider.of<MatrixService>(context, listen: false);
      await matrixService.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }
}
