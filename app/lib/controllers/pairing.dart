import 'dart:convert';
import 'dart:io';

import 'package:app/controllers/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class PairingController extends GetxController {
  final box = GetStorage();
  MainController mainController = Get.find<MainController>();

  var devices = [].obs;
  var step = 0.obs;

  BluetoothDevice? device;
  BluetoothCharacteristic? characteristic;

  bool waitForReplyBool = false;

  String url = "alarm.devpi.me";
  String ssid = "";
  String password = "";

  final String autoScanDeviceName = "OC01-";

  void startBluetooth() async {
    // first, check if bluetooth is supported by your hardware
    // Note: The platform is initialized on the first call to any FlutterBluePlus method.
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported by this device");
      return;
    }

    // handle bluetooth on & off
    // note: for iOS the initial state is typically BluetoothAdapterState.unknown
    // note: if you have permissions issues you will get stuck at BluetoothAdapterState.unauthorized
    FlutterBluePlus.adapterState.listen((BluetoothAdapterState state) {
      print(state);
      if (state == BluetoothAdapterState.on) {
        // usually start scanning, connecting, etc
      } else {
        // show an error to the user, etc
      }
    });

    // turn on bluetooth ourself if we can
    // for iOS, the user controls bluetooth enable/disable
    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }

    // listen to scan results
    // Note: `onScanResults` only returns live scan results, i.e. during scanning
    // Use: `scanResults` if you want live scan results *or* the previous results
    FlutterBluePlus.scanResults.listen((results) {
      if (results.isNotEmpty) {
        ScanResult r = results.last; // the most recently found device

        // add to devices list if not already in it
        if (!devices.contains(r.device) && r.device.advName != "") {
          devices.add(r.device);
        }

        if (Get.currentRoute == '/pair') {
          // if device is found, connect to it
          if (r.device.advName.contains(autoScanDeviceName) &&
              (device == null || device!.isConnected == false)) {
            stopScan();
            connect(r.device);
          }
        }
      }
    }, onError: (e) {
      print(e);
    });

    // Wait for Bluetooth enabled & permission granted
    // In your real app you should use `FlutterBluePlus.adapterState.listen` to handle all states
    await FlutterBluePlus.adapterState
        .where((val) => val == BluetoothAdapterState.on)
        .first;

    FlutterBluePlus.events.onConnectionStateChanged.listen((event) {
      if (!event.device.isConnected) {
        changeStep(0);
        print("Device disconnected");
      }
    });
  }

  void startScan() async {
    // Start scanning
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));
  }

  void stopScan() async {
    // Stop scanning
    await FlutterBluePlus.stopScan();

    devices.clear();
  }

  void connect(BluetoothDevice device) async {
    changeStep(1);
    // Disconnect from any device
    disconnect();

    // Connect to device
    try {
      await device.connect();
    } catch (e) {
      print(e);
      Get.snackbar(
        "Error",
        "Failed to connect to device",
        colorText: Colors.white,
        backgroundColor: Colors.lightBlue,
        icon: const Icon(Icons.add_alert),
      );
      return;
    }

    this.device = device;

    // Discover services
    List<BluetoothService> services = await device.discoverServices();

    // Reads last service
    BluetoothService service = services.last;
    // Reads last characteristic
    characteristic = service.characteristics.last;

    final subscription = characteristic!.onValueReceived.listen((value) async {
      // We receive JSON data from the device as {"event": "event_name", "data": { ... }}
      // We need to parse it
      var json = jsonDecode(utf8.decode(value));

      switch (json['event']) {
        case "cb-wifi":
          if (json['data']['status'] == true) {
            changeStep(3);
          } else {
            Get.snackbar(
              "Error",
              "Failed to connect to WiFi",
              colorText: Colors.white,
              backgroundColor: Colors.lightBlue,
              icon: const Icon(Icons.add_alert),
            );
          }
          break;

        case "cb-server":
          if (json['data']['status'] == true) {
            box.write('serial', json['data']['serial']);
            box.write('secret', json['data']['secret']);

            changeStep(4);

            send("setup", {});
            await characteristic!.read(timeout: 25);
          } else {
            Get.snackbar(
              "Error",
              "Failed to connect to server",
              colorText: Colors.white,
              backgroundColor: Colors.lightBlue,
              icon: const Icon(Icons.add_alert),
            );
          }
          break;

        case "cb-setup":
          changeStep(0);
          if (json['data']['status'] == true) {
            stopWaitForReply();
            stopScan();
            box.write('setup', true);
            Get.offAllNamed('/home');
          } else {
            Get.snackbar(
              "Error",
              "Failed to setup device",
              colorText: Colors.white,
              backgroundColor: Colors.lightBlue,
              icon: const Icon(Icons.add_alert),
            );
          }
          break;
      }
    });

    device.cancelWhenDisconnected(subscription);

    await characteristic!.setNotifyValue(true);

    changeStep(2);
  }

  void stopWaitForReply() {
    waitForReplyBool = false;
  }

  void disconnect() async {
    // Disconnect from device
    if (device != null) {
      await device!.disconnect();
      device = null;
    }

    // Clear characteristic
    characteristic = null;
  }

  void send(String event, dynamic data) {
    if (characteristic != null) {
      characteristic!
          .write(utf8.encode(jsonEncode({'event': event, 'data': data})));
    }
  }

  void changeStep(int s) {
    step.value = s;

    switch (s) {
      case 0:
        mainController.setButton(
          title: 'Add manually',
          action: () {
            Get.toNamed('/devices');
          },
        );
        break;
      case 1:
        // mainController.setButton(
        //   title: '',
        //   action: () {},
        // );
        break;
      case 2:
        mainController.setButton(
          title: 'Set wifi',
          action: () {
            send('wifi', {'ssid': ssid, 'password': password});
            characteristic!.read(timeout: 25);
          },
        );
        break;
      case 3:
        mainController.setButton(
          title: 'Set server',
          action: () {
            send('server', {'address': url});
            characteristic!.read(timeout: 65);
          },
        );
        break;
      case 4:
        mainController.setButton(
          title: '',
          action: () {},
        );
        break;
    }
  }

  String stepToText() {
    switch (step.value) {
      case 0:
        return "Waiting for device";
      case 1:
        return "Connecting to device";
      case 2:
        return "Connecting to WiFi";
      case 3:
        return "Connecting to server";
      case 4:
        return "Waiting for setup to finish";
      default:
        return "Unknown step";
    }
  }

  void setSSID(String value) {
    ssid = value;
  }

  void setPassword(String value) {
    password = value;
  }

  void setURL(String value) {
    url = value;
  }
}
