import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

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
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        fontFamily: 'Roboto',
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
  final String _authUrl = "http://localhost:3000/register_devices/device_info";

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
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Token Authentication'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                labelText: 'Enter Token',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                prefixIcon: const Icon(Icons.security),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _authenticate(context),
              icon: const Icon(Icons.login),
              label: const Text('Authenticate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
            ),
          ],
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
  final String _postUrl = "http://localhost:3000/devices/data";
  List<Map<String, dynamic>> _sentData = [];
  Timer? _timer;
  bool _isSending = false;

  Map<String, dynamic> _generateData() {
    final random = Random();

    double addNoise(double value) {
      double noise = value * 0.02 * (random.nextDouble() - 0.5) * 2;
      return double.parse((value + noise).toStringAsFixed(2));
    }

    double voltage = 230.0;
    double current = 10.0;
    double power = voltage * current * 0.95;
    double frequency = 50.0;
    double pf = 0.95;
    double electricPrice = 0.15;

    return {
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
    final data = {"device": generatedData};

    try {
      final response = await http.post(
        Uri.parse(_postUrl),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        setState(() {
          _sentData.add(responseData['device'] ?? generatedData);
        });
      } else {
        debugPrint("Failed to submit data: ${response.statusCode}");
      }
    } catch (error) {
      debugPrint("Error submitting data: $error");
    }
  }

  void _startSendingData() {
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _sendData());
    setState(() {
      _isSending = true;
    });
  }

  void _stopSendingData() {
    _timer?.cancel();
    setState(() {
      _isSending = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Energy Data Dashboard'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: _isSending ? null : _startSendingData,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start'),
                ),
                ElevatedButton.icon(
                  onPressed: _isSending ? _stopSendingData : null,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                _buildStatisticCard("Average Frequency", _calculateAverage("frequency"), Colors.deepPurple),
                _buildStatisticCard("Average PF", _calculateAverage("PF"), Colors.deepPurpleAccent),
                _buildStatisticCard("Avg Electric Price", _calculateAverage("electricPrice"), Colors.purpleAccent),
                _buildLineChart("Voltage Over Index", "voltage", Colors.deepPurple),
                _buildLineChart("Power Over Index", "power", Colors.purple),
                _buildLineChart("Current Over Index", "current", Colors.deepPurpleAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticCard(String title, double value, Color color) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(fontSize: 18, color: color),
        ),
        trailing: Text(
          value.toStringAsFixed(2),
          style: TextStyle(fontSize: 24, color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildLineChart(String title, String key, Color color) {
    List<FlSpot> spots = _sentData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value[key] ?? 0.0);
    }).toList();

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      color: color,
                      barWidth: 4,
                      spots: spots,
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateAverage(String key) {
    if (_sentData.isEmpty) return 0.0;
    double sum = _sentData.fold(0.0, (prev, element) => prev + (element[key] ?? 0.0));
    return sum / _sentData.length;
  }
}
