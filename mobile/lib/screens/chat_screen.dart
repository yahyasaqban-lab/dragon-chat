import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:matrix/matrix.dart';
import '../services/matrix_service.dart';
import '../services/livekit_service.dart';
import '../theme/app_theme.dart';
import 'call_screen.dart';

class ChatScreen extends StatefulWidget {
  final Room room;
  final bool startCall;
  
  const ChatScreen({
    super.key,
    required this.room,
    this.startCall = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  Timeline? _timeline;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
    
    if (widget.startCall) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startVoiceCall();
      });
    }
  }

  Future<void> _loadTimeline() async {
    _timeline = await widget.room.getTimeline(
      onUpdate: () {
        if (mounted) setState(() {});
      },
    );
    
    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    _messageController.clear();
    
    final matrixService = Provider.of<MatrixService>(context, listen: false);
    await matrixService.sendMessage(widget.room, text);
    
    _scrollToBottom();
  }

  void _startVoiceCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          room: widget.room,
          isVideo: false,
        ),
      ),
    );
  }

  void _startVideoCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallScreen(
          room: widget.room,
          isVideo: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.room.name ?? 'Chat'),
            Text(
              '${widget.room.summary.mJoinedMemberCount ?? 0} members',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: _startVoiceCall,
            tooltip: 'Voice Call',
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: _startVideoCall,
            tooltip: 'Video Call',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showRoomOptions(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildMessageList(),
          ),
          
          // Input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_timeline == null || _timeline!.events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🐉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Send the first message!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    
    final events = _timeline!.events
        .where((e) => e.type == EventTypes.Message)
        .toList()
        .reversed
        .toList();
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isMe = event.senderId == widget.room.client.userID;
        final showAvatar = index == 0 || 
            events[index - 1].senderId != event.senderId;
        
        return _buildMessageBubble(event, isMe, showAvatar);
      },
    );
  }

  Widget _buildMessageBubble(Event event, bool isMe, bool showAvatar) {
    final sender = event.senderFromMemoryOrFallback;
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: 8,
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe && showAvatar) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.accent,
              child: Text(
                (sender.displayName ?? sender.senderId)[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ] else if (!isMe) ...[
            const SizedBox(width: 40),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.accent : AppColors.secondary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && showAvatar)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        sender.displayName ?? sender.senderId,
                        style: TextStyle(
                          color: AppColors.accentLight,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Text(
                    event.body,
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(event.originServerTs),
                    style: TextStyle(
                      fontSize: 11,
                      color: isMe 
                          ? Colors.white.withOpacity(0.7)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.attach_file),
              onPressed: _pickAttachment,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Message ${widget.room.name ?? ""}...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.primary,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: AppColors.accent,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _pickAttachment() {
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
                child: Icon(Icons.image, color: Colors.white),
              ),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(context);
                // Pick image
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.tertiary,
                child: Icon(Icons.insert_drive_file, color: Colors.white),
              ),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(context);
                // Pick file
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppColors.success,
                child: Icon(Icons.location_on, color: Colors.white),
              ),
              title: const Text('Location'),
              onTap: () {
                Navigator.pop(context);
                // Share location
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomOptions() {
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
              leading: const Icon(Icons.info_outline),
              title: const Text('Room Info'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Members'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: AppColors.error),
              title: const Text('Leave Room', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(context);
                _leaveRoom();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _leaveRoom() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.secondary,
        title: const Text('Leave Room'),
        content: const Text('Are you sure you want to leave this room?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await widget.room.leave();
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}
