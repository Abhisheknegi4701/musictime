import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'model.dart';

const String countKey = 'count';

/// The name associated with the UI isolate's [SendPort].
const String isolateName = 'isolate';

/// A port used to communicate from a background isolate to the UI isolate.
final ReceivePort port = ReceivePort();

SharedPreferences? prefs;

bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  // bring to foreground
  Timer.periodic(const Duration(seconds: 60), (timer) async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
    print(placemarks);
    Placemark place = placemarks[0];
    getwhether(place.subLocality);
  });
  return true;
}

void onStart(ServiceInstance service) {

  // bring to foreground
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    
  });

}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // this will executed when app is in foreground or background in separated isolate
      onStart: onStart,

      // auto start service
      autoStart: true,
      isForegroundMode: true,
      foregroundServiceNotificationTitle: "Pearl Client Workspace",
      foregroundServiceNotificationContent: "App is working in Background",
    ),
    iosConfiguration: IosConfiguration(
      // auto start service
      autoStart: true,

      // this will executed when app is in foreground in separated isolate
      onForeground: onStart,

      // you have to enable background fetch capability on xcode project
      onBackground: onIosBackground,
    ),
  );
  service.startService();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  await initializeService();
  // Register the UI isolate's SendPort to allow for communication from the
  // background isolate.
  IsolateNameServer.registerPortWithName(
    port.sendPort,
    isolateName,
  );
  prefs = await SharedPreferences.getInstance();
  if (!prefs!.containsKey(countKey)) {
    await prefs!.setInt(countKey, 0);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<String> weatherlist = ["Select Weather", "Sunny", "Cloudy", "Mist"];
  TimeOfDay selectedTime = TimeOfDay.now();
  String musictext = "Select Music";
  String selectedwether = "Select Weather";
  AssetsAudioPlayer assetsAudioPlayer = AssetsAudioPlayer();
  var seleTime;

  static SendPort? uiSendPort;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getlocation();
    /*assetsAudioPlayer.open(
      Audio("Assets/Yaara Teri Yaari.mp3"),
    );*/
  }

  playmusic() {
    assetsAudioPlayer.open(Audio(""));
  }

  // The callback for our alarm
  static Future<void> callback() async {
    developer.log('Alarm fired!');
    // Get the previous cached count and increment it.
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(countKey) ?? 0;
    await prefs.setInt(countKey, currentCount + 1);
    // This will be null if we're running in the background.
    uiSendPort ??= IsolateNameServer.lookupPortByName(isolateName);
    uiSendPort?.send(null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: Container(
        margin: const EdgeInsets.fromLTRB(0, 10, 0, 0),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Select Weather : ",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                      decoration: BoxDecoration(
                          color: Colors.white30,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black, width: 2)),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text("Select Weather"),
                        value: selectedwether,
                        items: weatherlist.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != "Select Weather") {
                            setState(() {
                              selectedwether = v!;
                            });
                          }
                        },
                      ),
                    ),
                  )
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Select Time :  ",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 15, 10, 15),
                      decoration: BoxDecoration(
                          color: Colors.white30,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black, width: 2)),
                      child: GestureDetector(
                        onTap: () {
                          _selectTime(context);
                        },
                        child: Text(
                          selectedTime.period.toString() == "DayPeriod.pm"
                              ? selectedTime.hour.toString() +
                                  ":" +
                                  selectedTime.minute.toString() +
                                  " PM"
                              : selectedTime.hour.toString() +
                                  ":" +
                                  selectedTime.minute.toString() +
                                  " AM",
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                dynamic currentTime = DateFormat("HH:mm").format(DateTime.now());
                var selected=   DateTime(selectedTime.hour, selectedTime.minute);
                var time=DateFormat.jm().format(selected);

                print("one "+currentTime.toString());
                print("two "+seleTime.toString());
                var format = DateFormat("HH:mm");
                var one = format.parse(currentTime);
                var two = format.parse(seleTime);
                print("${two.difference(one)}");
                var diff=two.difference(one);
                // var d=DateTime.parse(diff.toString());
                print("sada"+diff.toString().split('.')[0]);
                var h=diff.inSeconds.toString();
                await AndroidAlarmManager.periodic(
                  Duration(seconds: int.parse(h)),
                  // Ensure we have a unique alarm ID.
                  Random().nextInt(pow(2, 31) as int),
                  callback,
                  exact: true,
                  wakeup: true,
                );
              },
              child: Container(
                decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black, width: 2)),
                margin: const EdgeInsets.fromLTRB(20, 50, 20, 10),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      "Submit",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      )),
    );
  }

  Future<void> _selectTime(context) async {
    final TimeOfDay? picked_s = await showTimePicker(
        context: context,
        initialTime: selectedTime,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          );
        });

    if (picked_s != null && picked_s != selectedTime) {
      setState(() {
        selectedTime = picked_s;
        seleTime=picked_s.hour.toString()+":"+picked_s.minute.toString();
      });
    }
  }

  Future<void> getlocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      await Geolocator.openLocationSettings();
      return Future.error('Location services are disabled.');
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {

        return Future.error('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
    print(placemarks);
    Placemark place = placemarks[0];
    getwhether(place.subLocality);
  }

}

Future<List<Whether>> getwhether(String? locality) async {
  var url = "https://api.openweathermap.org/data/2.5/weather?q=" +
      locality.toString() +
      "&APPID=43ea6baaad7663dc17637e22ee6f78f2";

  // Starting Web API Call.
  var response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    //final items = json.decode(response.body).cast<Map<String, dynamic>>();

    List<Whether> whetherlist = json
        .decode(response.body)["data"]
        .map<Whether>((json) => Whether.fromJson(json))
        .toList();

    //log("thisone" + question.toString());

    return whetherlist;
    //showToast(profile.toString());
  } else {
    throw Exception('Failed to load data from Server.');
  }
}

