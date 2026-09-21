import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const GeoLockApp());
}

class GeoLockApp extends StatelessWidget {
  const GeoLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo Lock Step 1',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const StepOneScreen(),
    );
  }
}

class StepOneScreen extends StatefulWidget {
  const StepOneScreen({super.key});

  @override
  State<StepOneScreen> createState() => _StepOneScreenState();
}

class _StepOneScreenState extends State<StepOneScreen> with WidgetsBindingObserver {
  String _statusMessage = 'জিপিএস (GPS) স্ট্যাটাস চেক করা হচ্ছে...';
  bool _isGpsEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkGpsStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // অ্যাপ ব্যাকগ্রাউন্ড বা সেটিংস থেকে ফিরে এলে অটোমেটিক চেক করবে
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkGpsStatus();
    }
  }

  // জিপিএস অন আছে কিনা তা চেক করার নিরাপদ ফাংশন
  Future<void> _checkGpsStatus() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      
      setState(() {
        _isGpsEnabled = serviceEnabled;
        if (serviceEnabled) {
          _statusMessage = 'জিপিএস (GPS) বর্তমানে অন আছে! ✅\nপরবর্তী স্টেপের জন্য প্রস্তুত।';
        } else {
          _statusMessage = 'সতর্কতা: আপনার ফোনের জিপিএস (GPS) বন্ধ রয়েছে। ❌';
        }
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'লোকেশন চেক করতে সমস্যা হচ্ছে: $e';
        _isGpsEnabled = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Step 1: GPS Check'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isGpsEnabled ? Icons.location_on : Icons.location_off,
                size: 80,
                color: _isGpsEnabled ? Colors.green : Colors.red,
              ),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              
              // জিপিএস বন্ধ থাকলে অন করার সেটিংস বাটন দেখাবে
              if (!_isGpsEnabled)
                ElevatedButton.icon(
                  onPressed: () async {
                    await Geolocator.openLocationSettings();
                  },
                  icon: const Icon(Icons.settings),
                  label: const Text('জিপিএস (GPS) অন করুন'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),

              const SizedBox(height: 15),
              
              // স্ট্যাটাস রিফ্রেশ করার বাটন
              OutlinedButton.icon(
                onPressed: _checkGpsStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('স্ট্যাটাস রিফ্রেশ করুন'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}