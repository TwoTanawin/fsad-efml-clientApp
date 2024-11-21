import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Energy Data App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthPage(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _tokenController = TextEditingController();
  final String _authUrl = "http://localhost:3000/register_devices/device_info"; // Authentication endpoint

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _authenticate(BuildContext context) async {
    final token = _tokenController.text;

    try {
      final response = await http.get(
        Uri.parse(_authUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Navigate to the data submission page with the token
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DataPage(token: token),
          ),
        );
      } else {
        final errorData = jsonDecode(response.body);
        _showError(context, errorData['error'] ?? "Authentication failed");
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
        title: const Text('Enter Token'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _tokenController,
                decoration: const InputDecoration(
                  labelText: 'Token',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _authenticate(context),
                child: const Text('Authenticate'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DataPage extends StatefulWidget {
  final String token;

  const DataPage({super.key, required this.token});

  @override
  State<DataPage> createState() => _DataPageState();
}

class _DataPageState extends State<DataPage> {
  final String _postUrl = "http://localhost:3000/devices/data"; // Data submission endpoint
  List<Map<String, dynamic>> _submittedData = [];

  Map<String, dynamic> _generateData() {
    final random = Random();

    double addNoise(double value) {
      double noise = value * 0.02 * (random.nextDouble() - 0.5) * 2; // +/- 2% noise
      return double.parse((value + noise).toStringAsFixed(2));
    }

    double voltage = 230.0; // Nominal voltage
    double current = 10.0; // Nominal current
    double power = voltage * current * 0.95; // Power = Voltage * Current * PF
    double frequency = 50.0; // Standard frequency
    double pf = 0.95; // Power factor
    double electricPrice = 0.15; // Price per kWh

    return {
      "isActive": true,
      "voltage": addNoise(voltage),
      "current": addNoise(current),
      "power": addNoise(power),
      "frequency": addNoise(frequency),
      "PF": addNoise(pf),
      "electricPrice": addNoise(electricPrice),
    };
  }

Future<void> _sendData() async {
  final generatedData = _generateData();
  final data = {
    "device": generatedData,
  };

  try {
    final response = await http.post(
      Uri.parse(_postUrl),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      // Add the generated data directly to the list
      setState(() {
        _submittedData.add(generatedData); // Use generatedData instead of data['device']
      });
    } else {
      debugPrint("Failed to submit data: ${response.statusCode}");
    }
  } catch (error) {
    debugPrint("Error submitting data: $error");
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Energy Data'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _sendData,
            child: const Text('Generate and Send Data'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _submittedData.length,
              itemBuilder: (context, index) {
                final data = _submittedData[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  child: ListTile(
                    title: Text("Data Set #${index + 1}"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Voltage: ${data['voltage']} V"),
                        Text("Current: ${data['current']} A"),
                        Text("Power: ${data['power']} W"),
                        Text("Frequency: ${data['frequency']} Hz"),
                        Text("PF: ${data['PF']}"),
                        Text("Electric Price: ${data['electricPrice']} USD"),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
