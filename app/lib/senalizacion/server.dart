
import 'package:socket_io/socket_io.dart';
import 'package:flutter/material.dart';

class ServerManager with ChangeNotifier {
  Server? _server;
  String? IpClient;

  List<String> _connectedClients = []; 

  List<String> get connectedClients => _connectedClients;

  void startServer() {
    _server = Server();

    _server?.on('connection', (client) {
      
     
      //Valor unico del cliente.
      String IpClient = client.id;
      notifyListeners();
      print('Cliente connected: $IpClient jeje, feliz');
      _connectedClients.add(client.id); //Añadimos el socket del cliente a nuestra lista de conectados
      
      client.on('solicitarTransmision', (data) {
          final ipcli = data['ipcli'];
          final sdpOffer = data['sdpOffer'];

      client.broadcast.to(ipcli).emit('solicitarPantalla', {
        'IpClient': client.id,
        'sdpOffer': sdpOffer,
      });
    });

      client.on("answerTransmision", (data) {
          final IpClient = data['IpClient'];
          final sdpAnswer = data['sdpAnswer'];

          client.to(IpClient).emit("TransmisionAnswered", {
            'ipp': client.id,
            'sdpAnswer': sdpAnswer,
          });
        });

      client.on("IceCandidate", (data) {
          final ipcli = data['ipcli'];
          final iceCandidate = data['iceCandidate'];

          client.to(ipcli).emit("IceCandidate", {
            'sender': client.id,
            'iceCandidate': iceCandidate,
          });
        });

    client.on('disconnect', (_) {
        _connectedClients.remove(client.id);
        notifyListeners();
        print('Client disconnected: ${client.id}');
      });
    });

    _server?.listen(3000);
    print('Server listening on port 3000');
  }


}
