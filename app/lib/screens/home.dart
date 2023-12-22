import 'package:app/controllers/home.dart';
import 'package:app/controllers/main.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final mainController = Get.find<MainController>();
  final homeController = Get.put(HomeController());

  @override
  Widget build(BuildContext context) {
    return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Obx(() => Text(
              mainController.connected.value
                  ? (mainController.activated.value
                      ? 'Activated'
                      : 'Deactivated')
                  : 'Disconnected',
              style: const TextStyle(fontSize: 30, color: Colors.red))),
        ]);
  }
}
