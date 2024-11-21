import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _tokenController = TextEditingController();
  final String _url = "http://localhost:3000/register_devices/device_info"; // API endpoint

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _getDeviceInfo(BuildContext context) async {
    final token = _tokenController.text;

    try {
      final response = await http.get(
        Uri.parse(_url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Navigate to the "Device Info" page with data
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DeviceInfoPage(deviceData: data['device_details']),
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        _showError(context, errorData['error'] ?? "Failed to fetch device info");
      }
    } catch (error) {
      _showError(context, "Failed to connect to the server");
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _tokenController,
                decoration: const InputDecoration(
                  labelText: 'Enter Token',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _getDeviceInfo(context),
              child: const Text('Submit Token'),
            ),
          ],
        ),
      ),
    );
  }
}

class DeviceInfoPage extends StatelessWidget {
  final Map<String, dynamic> deviceData;

  const DeviceInfoPage({super.key, required this.deviceData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Device Info'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Device ID: ${deviceData['id']}",
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              "Address: ${deviceData['address']}",
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              "Created At: ${deviceData['created_at']}",
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }
}
