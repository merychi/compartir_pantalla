import 'package:compartir_pantalla/senalizacion/socket.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class GetDisplayMediaSample extends StatefulWidget {
  final String IpClient, ipcli;
  final dynamic offer;
  const GetDisplayMediaSample({
    super.key,
    this.offer,
    required this.IpClient,
    required this.ipcli,
  });

  @override
  _GetDisplayMediaSampleState createState() => _GetDisplayMediaSampleState();
}

class _GetDisplayMediaSampleState extends State<GetDisplayMediaSample> {
  List<RTCIceCandidate> rtcIceCadidates = [];

  final socket = ClientManager.instance
      .socket; //Para manejar la conexión con el servidor de señalizacion
  final _localRenderer =
      RTCVideoRenderer(); //almacenan el vídeo renderizado y permite compartirlo
  final _remoteRenderer = RTCVideoRenderer();

  RTCPeerConnection?
      _rtcPeerConnection; //Conexiones para compartir los videos u objetios de media.

  MediaStream? _localStream; //almanenan un objetio que es del tipo media
  MediaStream? _remoteStream;

  bool _isOpen = false, isVideoOn = true, isAudioOn = false;

  //-------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _initRenderers(); //Comienza la renderizacion
    _setupPeerConnection();
  }

  @override
  void dispose() {
    super.dispose();
    _localRenderer.dispose(); //finaliza la renderizacion
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _rtcPeerConnection?.dispose();
  }

  Future<void> _initRenderers() async {
    // Funcion para iniciar la renderizacion
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _open() async {
    // Función para abrir una transmisión de medios desde la pantalla del dispositivo local
    final mediaConstraints = {
      'audio': false,
      'video': {
        'mediaSource': 'screen',
      },
    };

    try {
      _localStream =
          await navigator.mediaDevices.getDisplayMedia(mediaConstraints);
      _localRenderer.srcObject = _localStream;
    } catch (e) {
      print(e.toString());
    }

    if (!mounted) return;
    setState(() {
      _isOpen = true;
    });
  }

  _setupPeerConnection() async {
    //Maneja la conexión con los servidores stun
    _rtcPeerConnection = await createPeerConnection({
      'iceServers': [
        {
          'urls': [
            'stun:stun1.l.google.com:19302',
            'stun:stun2.l.google.com:19302'
          ]
        }
      ]
    });

    // listen for remotePeer mediaTrack event
    _rtcPeerConnection!.onTrack = (event) {
      // Asigna el primer stream recibido al renderizador remoto
      _remoteRenderer.srcObject = event.streams[0];
      // Actualiza el estado del widget para reflejar los cambios en la interfaz de usuario
      setState(() {});
    };

    // abrimos la transmision local.
    _open();

    // añadir todas las pistas de video o la transmision a una unica variable, en este caso, la de localstream
    _localStream!.getTracks().forEach((track) {
      _rtcPeerConnection!.addTrack(track, _localStream!);
    });

    // se añade el objeto (que contiene las pistas de video) a la variable que renderiza el video
    _localRenderer.srcObject = _localStream;
    setState(() {});

    // conexión 2p2 envio de ice candidatos

    //Si este dispositivo es el que solicita la transmision
    if (widget.offer != null) {
      // Se enlistan todos los ice candidatos en las variables correspondientes de la conexión de socket
      socket!.on("IceCandidate", (data) {
        String candidate = data["iceCandidate"]["candidate"];
        String sdpMid = data["iceCandidate"]["id"];
        int sdpMLineIndex = data["iceCandidate"]["label"];

        // se agragan los candidatos a la conexión Peer (2p2)
        _rtcPeerConnection!.addCandidate(RTCIceCandidate(
          candidate,
          sdpMid,
          sdpMLineIndex,
        ));
      });

      // establecer la oferta SDP como la descripción remota para la conexión de pares.
      await _rtcPeerConnection!.setRemoteDescription(
        RTCSessionDescription(widget.offer["sdp"], widget.offer["type"]),
      );

      //  crear una respuesta SDP para la conexión de pares.
      RTCSessionDescription answer = await _rtcPeerConnection!.createAnswer();

      /* Crear y establecer una respuesta SDP como localDescription permite al receptor 
      de la oferta configurar su conexión de medios de acuerdo con los parámetros negociados*/
      _rtcPeerConnection!.setLocalDescription(answer);

      //  el receptor de la llamada envía su respuesta SDP (Session Description Protocol)
      // de vuelta al oferente a través de un socket
      socket!.emit("answerTransmision", {
        "IpClient": widget.IpClient,
        "sdpAnswer": answer.toMap(),
      });
    }

    // Si este es el celular que va a transmitir
    else {
      // listen for local iceCandidate and add it to the list of IceCandidate
      _rtcPeerConnection!.onIceCandidate =
          (RTCIceCandidate candidate) => rtcIceCadidates.add(candidate);

      // when call is accepted by remote peer
      socket!.on("TransmisionAnswered", (data) async {
        // set SDP answer as remoteDescription for peerConnection
        await _rtcPeerConnection!.setRemoteDescription(
          RTCSessionDescription(
            data["sdpAnswer"]["sdp"],
            data["sdpAnswer"]["type"],
          ),
        );

        // send iceCandidate generated to remote peer over signalling
        for (RTCIceCandidate candidate in rtcIceCadidates) {
          socket!.emit("IceCandidate", {
            "ipcli": widget.ipcli,
            "iceCandidate": {
              "id": candidate.sdpMid,
              "label": candidate.sdpMLineIndex,
              "candidate": candidate.candidate
            }
          });
        }
      });

      // create SDP Offer
      RTCSessionDescription offer = await _rtcPeerConnection!.createOffer();

      // set SDP offer as localDescription for peerConnection
      await _rtcPeerConnection!.setLocalDescription(offer);

      // crea la transmision remota por 2p2
      socket!.emit('solicitarTransmision', {
        "ipcli": widget.ipcli,
        "sdpOffer": offer.toMap(),
      });
    }
  }

  Future<void> _close() async {
    try {
      await _localStream?.dispose();
      await _remoteStream?.dispose();
      _localRenderer.srcObject = null;
      _remoteRenderer.srcObject = null;
    } catch (e) {
      print(e.toString());
    }

    setState(() {
      _isOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Compartir pantalla'),
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          return Center(
            child: Container(
              margin: EdgeInsets.all(0.0),
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: RTCVideoView(_remoteRenderer), // Mostrar el video remoto
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isOpen ? _close : _open,
        child: Icon(_isOpen ? Icons.close : Icons.add),
      ),
    );
  }
}
