import 'package:app/components/button.dart';
import 'package:app/controllers/main.dart';
import 'package:app/controllers/pairing.dart';
import 'package:app/notification_service.dart';
import 'package:app/screens/changepin.dart';
import 'package:app/screens/devices.dart';
import 'package:app/screens/home.dart';
import 'package:app/screens/pairing.dart';
import 'package:app/screens/settings.dart';
import 'package:app/screens/logs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import './constant.dart';

void main() async {
  Get.put(MainController());
  Get.put(PairingController());
  await GetStorage.init();
  await NotificationService().initNotification();
  runApp(const MyApp());
}

void updateScreen(MainController mainController) {
  String currentRoute = Get.currentRoute;
  Future.delayed(Duration.zero, () async {
    switch (currentRoute) {
      case '/home':
        mainController.setTitle('Home');
        mainController.setNavbar(left: false, right: true);

        mainController.setButton(
          title: mainController.activated.value ? 'Deactivate' : 'Activate',
          action: () {
            mainController.setActivated(!mainController.activated.value);
          },
        );
        break;
      case '/settings':
        mainController.setTitle('Settings');
        mainController.setNavbar(left: true, right: false);
        mainController.setButton(title: '');
        break;
      case '/logs':
        mainController.setTitle('Logs');
        mainController.setNavbar(left: true, right: false);
        break;
      case '/change-pin':
        mainController.setTitle('Change Pin');
        mainController.setNavbar(left: true, right: false);
        break;
      case '/devices':
        mainController.setTitle('Devices');
        mainController.setNavbar(left: true, right: false);
        mainController.setButton(title: '');
        break;
      case '/pair':
        mainController.setTitle('Pair');
        mainController.setNavbar(left: false, right: false);
        mainController.setButton(
          title: 'Add manually',
          action: () {
            Get.toNamed('/devices');
          },
        );
        break;
      default:
        mainController.setTitle('Home');
        mainController.setNavbar(left: false, right: false);
        break;
    }
  });
}

class RouteObserver extends GetMiddleware {
  @override
  void onPageDispose() {
    super.onPageDispose();

    var mainController = Get.find<MainController>();
    updateScreen(mainController);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'SmartAlarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        textTheme: GoogleFonts.figtreeTextTheme(
          Theme.of(context).textTheme.apply(
                bodyColor: Colors.white,
                displayColor: Colors.white,
              ),
        ),
      ),
      initialRoute: '/home',
      getPages: [
        GetPage(
          name: '/home',
          page: () => const Main(page: Home()),
          transition: Transition.fadeIn,
          transitionDuration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          popGesture: true,
          middlewares: [
            RouteObserver(),
          ],
        ),
        GetPage(
          name: '/pair',
          page: () => const Main(page: Pairing()),
          transition: Transition.fadeIn,
          transitionDuration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          popGesture: true,
          middlewares: [
            RouteObserver(),
          ],
        ),
        GetPage(
          name: '/devices',
          page: () => const Main(page: Devices()),
          transition: Transition.fadeIn,
          transitionDuration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
          popGesture: true,
          middlewares: [
            RouteObserver(),
          ],
        ),
        GetPage(
          name: '/change-pin',
          page: () => const Main(page: ChangePin()),
          transition: Transition.fadeIn,
          middlewares: [
            RouteObserver(),
          ],
        ),
        GetPage(
          name: '/settings',
          page: () => const Main(page: Settings()),
          transition: Transition.fadeIn,
          middlewares: [
            RouteObserver(),
          ],
        ),
        GetPage(
          name: '/logs',
          page: () => const Main(page: Logs()),
          transition: Transition.fadeIn,
          middlewares: [
            RouteObserver(),
          ],
        ),
      ],
    );
  }
}

class Main extends StatefulWidget {
  const Main({super.key, required this.page});

  final Widget page;

  @override
  State<Main> createState() => _MainState();
}

class _MainState extends State<Main> {
  final mainController = Get.find<MainController>();

  @override
  void initState() {
    super.initState();
    updateScreen(mainController);

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(top: 5.0),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              title: Obx(
                () => Text(
                  mainController.title.value.toString(),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600),
                ),
              ),
              leading: Obx(() => mainController.leftNavbar.value
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () {
                        Get.back();
                      },
                    )
                  : const SizedBox(
                      height: 0,
                      width: 0,
                    )),
              actions: <Widget>[
                Obx(() => mainController.rightNavbar.value
                    ? IconButton(
                        icon: const Icon(Icons.settings_rounded),
                        onPressed: () {
                          Get.toNamed('/settings');
                        },
                      )
                    : const SizedBox(
                        height: 0,
                        width: 0,
                      )),
              ],
              backgroundColor: background,
              elevation: 0.0,
              centerTitle: true,
            ),
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: widget.page,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: background,
      bottomNavigationBar: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 50),
            child: Obx(
              () => mainController.buttonTitle.value != '' &&
                      (Get.currentRoute != "/home" ||
                          mainController.connected.value)
                  ? GradientOutlineButton(
                      text: mainController.buttonTitle.value,
                      onTap:
                          mainController.buttonAction.value as void Function(),
                    )
                  : const SizedBox(
                      height: 0,
                      width: 0,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
