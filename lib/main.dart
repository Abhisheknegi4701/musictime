import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:developer' as developer;
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:flutter/material.dart';
import 'package:geocode/geocode.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'model.dart';

const String countKey = 'count';

/// The name associated with the UI isolate's [SendPort].
const String isolateName = 'isolate';

/// A port used to communicate from a background isolate to the UI isolate.
final ReceivePort port = ReceivePort();

SharedPreferences? prefs;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();

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

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Location location = Location();
  List<String> weatherlist = ["Select Weather", "Sunny", "Cloudy", "Mist"];
  TimeOfDay selectedTime = TimeOfDay.now();
  String musictext = "Select Music";
  String selectedwether = "Select Weather";
  AssetsAudioPlayer assetsAudioPlayer = AssetsAudioPlayer();

  static SendPort? uiSendPort;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getlocation();
    location.onLocationChanged.listen((LocationData currentLocation) {
      // Use current location
    });
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
                developer.log(selectedTime.toString());
                await AndroidAlarmManager.periodic(
                  const Duration(seconds: 5),
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
      });
    }
  }

  Future<void> getlocation() async {
    Location location = Location();

    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    LocationData _locationData;

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _locationData = await location.getLocation();
    GeoCode geoCode = GeoCode();
    Address address = await geoCode.reverseGeocoding(
        latitude: _locationData.latitude!.toDouble(),
        longitude: _locationData.longitude!.toDouble());
    getwhether(address.city);
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
}
