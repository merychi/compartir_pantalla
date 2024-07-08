import 'package:socket_io_client/socket_io_client.dart' as IO;

class ClientManager {
  IO.Socket? socket;
  ClientManager._();
  static final instance = ClientManager._();

  void connectToServer(String serverIp) {
    socket = IO.io('http://$serverIp:3000', <String, dynamic>{
      'transports': ['websocket'],
    });

    socket?.on('connect', (_) {
      print('Connected to server');
      print('Sending IP: $serverIp');
      });

    socket?.on('disconnect', (_) {
      print('Disconnected from server');
    });
  }

}
