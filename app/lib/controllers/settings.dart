import 'package:app/api.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class SettingsController extends GetxController {
  final box = GetStorage();
  late Api api;

  @override
  void onInit() {
    super.onInit();

    api = Api();
  }

  void unpairDevice() {
    api.sendWithCallback('unpair', {}, (response) {
      if (response['status'] == false) {
        Get.snackbar(
          "Success",
          response['data']['message'],
          colorText: Colors.white,
          backgroundColor: Colors.lightBlue,
          icon: const Icon(Icons.add_alert),
        );
        disconnectApp();
      } else {
        Get.snackbar(
          "Error",
          response['data']['message'],
          colorText: Colors.white,
          backgroundColor: Colors.lightBlue,
          icon: const Icon(Icons.add_alert),
        );
      }
    });
  }

  void disconnectApp() {
    box.remove('serial');
    box.remove('secret');
    box.remove('setup');
    api.stop();
    Get.offAllNamed('/pair');
  }
}
