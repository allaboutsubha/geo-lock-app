import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_jailbreak_detection/flutter_jailbreak_detection.dart';

void main() {
  runApp(const GeoLockApp());
}

class GeoLockApp extends StatelessWidget {
  const GeoLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo Lock App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // বসিরহাট রেলওয়ে স্টেশনের সঠিক ল্যাটিটিউড এবং লংটিউড
  final double stationLatitude = 22.6502669;
  final double stationLongitude = 88.8669008;

  // প্ল্যাটফর্ম চ্যানেল ডেভেলপার অপশন চেক করার জন্য
  static const platform = MethodChannel('com.example.geolocator/security');

  String _statusMessage = 'সিকিউরিটি ও জিপিএস স্মুথিং যাচাই করা হচ্ছে...';
  bool _isWithinRange = false;
  bool _isDeviceSecure = true;

  @override
  void initState() {
    super.initState();
    _checkSecurityAndSmoothedLocation();
  }

  // ১. ডেভেলপার অপশন অন আছে কিনা চেক করার ফাংশন
  Future<bool> _isDeveloperOptionsEnabled() async {
    try {
      final bool result = await platform.invokeMethod('isDeveloperOptionsEnabled');
      return result;
    } on PlatformException catch (_) {
      return false;
    }
  }

  // ২. জিপিএস জিটার ও ফ্ল্যাকচুয়েশন এড়ানোর জন্য স্মুথিং লজিক (এভারেজিং)
  Future<void> _checkSecurityAndSmoothedLocation() async {
    try {
      setState(() {
        _statusMessage = 'ডিভাইস সিকিউরিটি চেক করা হচ্ছে...';
      });

      // ক. রুট বা জেলব্রেক চেক
      bool isRooted = await FlutterJailbreakDetection.developerMode;
      bool isJailBroken = await FlutterJailbreakDetection.jailbroken;

      if (isRooted || isJailBroken) {
        setState(() {
          _isDeviceSecure = false;
          _isWithinRange = false;
          _statusMessage = 'সতর্কতা: আপনার ডিভাইসটি Root বা Jailbroken করা! অ্যাপ বন্ধ থাকবে।';
        });
        return;
      }

      // খ. ডেভেলপার অপশন চেক
      bool devOptionsOn = await _isDeveloperOptionsEnabled();
      if (devOptionsOn) {
        setState(() {
          _isDeviceSecure = false;
          _isWithinRange = false;
          _statusMessage = 'সতর্কতা: আপনার ফোনে Developer Options অন করা আছে! ক্যামেরা বন্ধ থাকবে।';
        });
        return;
      }

      // গ. জিপিএস সার্ভিস অন আছে কিনা চেক
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _statusMessage = 'দয়া করে আপনার ফোনের জিপিএস (GPS) অন করুন।';
          _isWithinRange = false;
        });
        return;
      }

      // ঘ. লোকেশন পারমিশন চেক
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _statusMessage = 'লোকেশন পারমিশন বাধ্যতামূলক।';
            _isWithinRange = false;
          });
          return;
        }
      }

      setState(() {
        _statusMessage = 'লোকেশন স্টেবল করা হচ্ছে (জিটার স্মুথিং)...';
      });

      // ঙ. জিপিএস ফ্ল্যাকচুয়েশন এড়াতে পরপর ৩ বার রিডিং নিয়ে গড় (Average) বের করা
      double totalDistance = 0.0;
      int successfulSamples = 0;
      const int totalSamples = 3;

      for (int i = 0; i < totalSamples; i++) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // মক লোকেশন চেক প্রতি স্যাম্পলে
        if (position.isMocked) {
          setState(() {
            _isDeviceSecure = false;
            _isWithinRange = false;
            _statusMessage = 'সতর্কতা: ফেক জিপিএস (Mock Location) ধরা পড়েছে!';
          });
          return;
        }

        double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          stationLatitude,
          stationLongitude,
        );

        totalDistance += distance;
        successfulSamples++;

        // স্যাম্পলগুলোর মাঝে সামান্য বিরতি (১ সেকেন্ড)
        if (i < totalSamples - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      // গড় দূরত্ব হিসাব
      double averageDistance = totalDistance / successfulSamples;

      setState(() {
        _isDeviceSecure = true;
        // চ. কঠোর ৩০ মিটার বাউন্ডারি রুল
        if (averageDistance <= 30.0) {
          _isWithinRange = true;
          _statusMessage = 'নিরাপদ সীমার ভেতরে আছেন (${averageDistance.toStringAsFixed(1)} মিটার)। ক্যামেরা ব্যবহার করতে পারেন।';
        } else {
          _isWithinRange = false;
          _statusMessage = 'আপনি ৩০ মিটার সীমার বাইরে চলে গেছেন (${averageDistance.toStringAsFixed(1)} মিটার)! ক্যামেরা বন্ধ রয়েছে।';
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'লোকেশন বা সিকিউরিটি যাচাই করতে সমস্যা হয়েছে: $e';
        _isWithinRange = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geo Lock App - Basirhat'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isWithinRange ? Icons.lock_open : Icons.lock,
              size: 80,
              color: _isWithinRange ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _isWithinRange
                  ? () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ক্যামেরা ওপেন হচ্ছে...')),
                      );
                    }
                  : null,
              icon: const Icon(Icons.camera_alt),
              label: const Text('সেলফি তুলুন / ক্যামেরা অন করুন'),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _checkSecurityAndSmoothedLocation,
              icon: const Icon(Icons.refresh),
              label: const Text('পুনরায় যাচাই করুন'),
            ),
          ],
        ),
      ),
    );
  }
}