import 'package:compartir_pantalla/compartir_pantalla.dart';
import 'package:compartir_pantalla/senalizacion/server.dart';
import 'package:compartir_pantalla/senalizacion/socket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required String title}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  dynamic incomingSDPOffer;
  bool isServer = false;
  String localIp = '', remoteIp = '', codLocal = '', codRemote = '';

  @override
  void initState() {
    super.initState();
    _getLocalIp();
  }

  Future<void> _getLocalIp() async {
    final info = NetworkInfo();
    String? ip = await info.getWifiIP();
    setState(() {
      localIp = ip ?? 'Unable to get IP';
      remoteIp = ip ?? 'Unable to get IP';
    });
  }

  bool isValidIp(String ip) {
    final regex = RegExp(
        r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
    return regex.hasMatch(ip);
  }

  void  _updateCods(List<String> clients) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (clients.isNotEmpty) {
        setState(() {
          codLocal = clients.length > 0 ? clients[0] : '';
          codRemote = clients.length > 1 ? clients[1] : '';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("MerryPruebaSocket"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
              },
            ),
          ),

          Text('Local IP: $localIp'),
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: 'Enter IP Address',
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                remoteIp = _ipController.text;
                if (remoteIp.isNotEmpty && isValidIp(remoteIp)) {
                  ClientManager.instance.connectToServer(remoteIp);

                  setState(() {
                    isServer = false;
                  });
                } else {
                  context.read<ServerManager>().startServer();
                  ClientManager.instance.connectToServer(localIp);
                  

                  setState(() {
                    isServer = true;
                    
                  });
                }
              },
              child: Text('Connect/Start Server'),
            ),
            SizedBox(height: 20),
            Text('Connected Clients:'),
            Expanded(
              child: Consumer<ServerManager>(
                builder: (context, serverManager, child) {
                  
                  return ListView.builder(
                    itemCount: serverManager.connectedClients.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(serverManager.connectedClients[index]),
                      );
                    },
                  );
                },
              ),
            ),

          ListTile(
            title: Text('Compartir Pantalla'),
            onTap: (){
              // Actualizar codLocal y codRemote cuando cambien los clientes conectados
              _updateCods(context.read<ServerManager>().connectedClients);
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (BuildContext)=> 
                GetDisplayMediaSample(IpClient: codLocal, ipcli: codRemote)));
            },
          ),
            ElevatedButton(
              child: const Text("Foreground Mode"),
              onPressed: () =>
                  FlutterBackgroundService().invoke("setAsForeground"),
            ),
            /*ElevatedButton(
              child: Text(text),
              onPressed: () async {
                final service = FlutterBackgroundService();
                var isRunning = await service.isRunning();
                isRunning
                    ? service.invoke("stopService")
                    : service.startService();

                setState(() {
                  text = isRunning ? 'Start Service' : 'Stop Service';
                });
              },
            ),*/
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
