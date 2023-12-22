import 'package:app/api.dart';
import 'package:get/get.dart';

class LogsController extends GetxController {
  var logs = [].obs;
  late Api api;

  @override
  void onInit() {
    super.onInit();

    api = Api();

    api.sendWithCallback('getevents', {}, (response) {
      setLogs(response['data']);
    });

    api.onEvent('event', (response) {
      addLog(response['data']);
    });
  }

  void setLogs(List newLogs) {
    logs.value = newLogs;
  }

  void addLog(dynamic log) {
    logs.add(log);
  }
}
