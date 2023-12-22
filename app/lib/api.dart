import 'package:app/controllers/main.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:get_storage/get_storage.dart';

class Api {
  MainController mainController = Get.find<MainController>();
  IO.Socket? socket;
  final box = GetStorage();
  static final Api _instance = Api._internal();

  var status = false;

  factory Api() {
    return _instance;
  }

  Api._internal();
  void start() {
    socket = IO.io('https://alarm.devpi.me', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
    });

    socket!.onConnect((_) {
      sendWithCallback('login', {
        'serial': box.read("serial"),
        'secret': box.read("secret"),
        'type': 'app'
      }, (response) {
        if (response['status'] == false) {
          status = true;
          Get.snackbar(
            "Success",
            response['data']['message'],
            colorText: Colors.white,
            backgroundColor: Colors.lightBlue,
            icon: const Icon(Icons.add_alert),
          );

          mainController.setConnected(response['data']['device']['connected']);
          mainController.setActivated(response['data']['device']['activated']);
        } else {
          status = false;
          Get.snackbar(
            "Error",
            response['data']['message'],
            colorText: Colors.white,
            backgroundColor: Colors.lightBlue,
            icon: const Icon(Icons.add_alert),
          );
        }
      });
    });

    socket!.onConnectError((data) => print("connectError: $data"));

    socket!.onConnectTimeout((data) => print("connectTimeout: $data"));

    socket!.onDisconnect((_) => print('disconnect'));

    socket!.connect();
  }

  void stop() {
    socket!.disconnect();
  }

  void send(String event, dynamic data) {
    socket!.emit(event, data);
  }

  void sendWithCallback(String event, dynamic data, Function callback) {
    socket!.emit(event, data);
    socket!.on('callback-$event', (response) {
      callback(response);
      // remove listener
      socket!.off('callback-$event');
    });
  }

  void onEvent(String event, Function callback) {
    socket!.on(event, (response) {
      callback(response);
    });
  }
}
