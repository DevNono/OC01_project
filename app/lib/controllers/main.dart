import 'package:app/api.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class MainController extends GetxController {
  final box = GetStorage();
  var title = 'Smart Alarm'.obs;
  var leftNavbar = true.obs;
  var rightNavbar = true.obs;
  var buttonTitle = 'Pair'.obs;
  Rx<Function> buttonAction = () {}.obs;

  var connected = false.obs;
  var activated = false.obs;

  @override
  void onInit() {
    super.onInit();
    // Connect to API and check if device is connected and activated
    print('MainController initialized');
  }

  void setNavbar({bool? left, bool? right}) {
    if (left != null) {
      leftNavbar.value = left;
    }
    if (right != null) {
      rightNavbar.value = right;
    }
  }

  void setTitle(String newTitle) {
    title.value = newTitle;
  }

  void setButton({String? title, Function? action}) {
    if (title != null) {
      buttonTitle.value = title;
    }
    if (action != null) {
      buttonAction.value = action;
    }
  }

  void setActivated(bool value) {
    Api api = Api();
    api.sendWithCallback('statuschanged', {'activated': value}, (response) {
      if (response['status'] == false) {
        var route = Get.currentRoute;
        activated.value = value;

        if (route == '/home') {
          buttonTitle.value = (activated.value ? 'Deactivate' : 'Activate');
        }
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

  void setConnected(bool value) {
    connected.value = value;
  }
}
