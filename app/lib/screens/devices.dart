import 'package:app/controllers/pairing.dart';
import 'package:app/controllers/main.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Devices extends StatefulWidget {
  const Devices({Key? key}) : super(key: key);

  @override
  State<Devices> createState() => _DevicesState();
}

class _DevicesState extends State<Devices> {
  final mainController = Get.find<MainController>();
  final pairingController = Get.find<PairingController>();

  @override
  void initState() {
    super.initState();
    pairingController.startScan();
  }

  @override
  void dispose() {
    pairingController.stopScan();
    super.dispose();
  }

  @override
  // display bluetooth.devices using tileList
  Widget build(BuildContext context) {
    return SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height / 2,
        child: Obx(() => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: ListView(children: <Widget>[
                for (var device in pairingController.devices)
                  Card(
                      child: ElevatedButton(
                    child: ListTile(
                      leading: const Icon(Icons.bluetooth),
                      title: Text(device.advName),
                    ),
                    onPressed: () async {
                      pairingController.connect(device);
                      Get.offAllNamed('/pair');
                    },
                  )),
              ]),
            )));
  }
}
