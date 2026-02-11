import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class MatrixService extends ChangeNotifier {
  Client? _client;
  bool _isInitialized = false;
  bool _isLoggedIn = false;
  String? _error;
  
  Client? get client => _client;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _isLoggedIn;
  String? get error => _error;
  
  List<Room> get rooms => _client?.rooms ?? [];
  List<Room> get directChats => rooms.where((r) => r.isDirectChat).toList();
  List<Room> get groupRooms => rooms.where((r) => !r.isDirectChat).toList();
  
  String? get userId => _client?.userID;
  String? get displayName => _client?.userID?.localpart;
  
  static const String defaultHomeserver = 'https://matrix.y7xyz.com';
  
  final _secureStorage = const FlutterSecureStorage();
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final dir = await getApplicationDocumentsDirectory();
      final databasePath = '${dir.path}/dragon_chat_matrix.db';
      
      _client = Client(
        'DragonChat',
        databaseBuilder: (_) async {
          final db = HiveCollectionsDatabase(
            'dragon_chat_matrix',
            '${dir.path}/matrix_hive',
          );
          await db.open();
          return db;
        },
      );
      
      await _client!.init();
      
      _isInitialized = true;
      _isLoggedIn = _client!.isLogged();
      
      if (_isLoggedIn) {
        _setupListeners();
      }
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  Future<bool> login({
    required String homeserver,
    required String username,
    required String password,
  }) async {
    try {
      _error = null;
      
      // Check if homeserver has protocol
      if (!homeserver.startsWith('http')) {
        homeserver = 'https://$homeserver';
      }
      
      await _client!.checkHomeserver(Uri.parse(homeserver));
      
      await _client!.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: username),
        password: password,
        initialDeviceDisplayName: 'Dragon Chat Mobile',
      );
      
      // Save credentials
      await _secureStorage.write(key: 'homeserver', value: homeserver);
      await _secureStorage.write(key: 'userId', value: _client!.userID);
      
      _isLoggedIn = true;
      _setupListeners();
      notifyListeners();
      
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> register({
    required String homeserver,
    required String username,
    required String password,
  }) async {
    try {
      _error = null;
      
      if (!homeserver.startsWith('http')) {
        homeserver = 'https://$homeserver';
      }
      
      await _client!.checkHomeserver(Uri.parse(homeserver));
      
      await _client!.uiaRequestBackground(
        (auth) => _client!.register(
          username: username,
          password: password,
          auth: auth,
          initialDeviceDisplayName: 'Dragon Chat Mobile',
        ),
      );
      
      _isLoggedIn = true;
      _setupListeners();
      notifyListeners();
      
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  void _setupListeners() {
    _client!.onSync.stream.listen((_) {
      notifyListeners();
    });
    
    _client!.onEvent.stream.listen((event) {
      notifyListeners();
    });
  }
  
  Future<Room?> createRoom({
    required String name,
    bool isDirect = false,
    List<String>? inviteIds,
  }) async {
    try {
      final roomId = await _client!.createRoom(
        name: name,
        isDirect: isDirect,
        invite: inviteIds,
        preset: isDirect ? CreateRoomPreset.trustedPrivateChat : CreateRoomPreset.privateChat,
      );
      
      return _client!.getRoomById(roomId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
  
  Future<Room?> joinRoom(String roomIdOrAlias) async {
    try {
      final roomId = await _client!.joinRoom(roomIdOrAlias);
      return _client!.getRoomById(roomId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }
  
  Future<void> sendMessage(Room room, String message) async {
    await room.sendTextEvent(message);
  }
  
  Future<void> sendImage(Room room, File imageFile) async {
    await room.sendFileEvent(
      MatrixFile(
        bytes: await imageFile.readAsBytes(),
        name: imageFile.path.split('/').last,
      ),
    );
  }
  
  Future<void> logout() async {
    try {
      await _client!.logout();
      await _secureStorage.deleteAll();
      _isLoggedIn = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  Room? getRoomById(String roomId) {
    return _client?.getRoomById(roomId);
  }
  
  Future<List<User>> searchUsers(String query) async {
    try {
      final response = await _client!.searchUserDirectory(query);
      return response.results.map((r) => User(r.userId, room: rooms.first)).toList();
    } catch (e) {
      return [];
    }
  }
}
