import 'package:app/api.dart';
import 'package:app/controllers/main.dart';
import 'package:app/notification_service.dart';
import 'package:get/get.dart';

class HomeController extends GetxController {
  late Api api;
  MainController mainController = Get.find();

  @override
  void onInit() {
    super.onInit();
    api = Api();
    api.start();
    api.onEvent('event', (response) {
      NotificationService().showNotification(
        title: "Alerte !",
        body: response['data']['name'],
      );
    });

    api.onEvent('statuschanged', (response) {
      mainController.connected.value = response['connected'];
      mainController.activated.value = response['activated'];
    });
  }
}
