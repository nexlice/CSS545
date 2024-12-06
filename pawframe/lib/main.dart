import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Paw Frame',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Home'), // Always show MyHomePage as the first screen
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  final TextEditingController _zipController = TextEditingController();
  String? _animalType;
  double _animalAge = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPreferences(); // Always load preferences on initial load
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _zipController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _savePreferences();
    } else if (state == AppLifecycleState.resumed) {
      _loadPreferences();
    }
  }

  Future<void> _loadPreferences() async {
    await _secureStorage.deleteAll(); // Clear preferences first, if needed
    String? animalType = await _secureStorage.read(key: 'animalType');
    String? animalAge = await _secureStorage.read(key: 'animalAge');
    String? zipCode = await _secureStorage.read(key: 'zipCode');

    setState(() {
      _animalType = animalType ?? 'Dog';
      _animalAge = double.tryParse(animalAge ?? '0.0') ?? 0.0;
      _zipController.text = zipCode ?? '00000';
    });
  }

  Future<void> _savePreferences() async {
    await _secureStorage.write(key: 'animalType', value: _animalType ?? 'Dog');
    await _secureStorage.write(key: 'animalAge', value: _animalAge.toString());
    await _secureStorage.write(key: 'zipCode', value: _zipController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.amber,
        title: Text(widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            DropdownButton<String>(
              value: _animalType,
              items: <String>['Dog', 'Cat', 'Others'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _animalType = newValue;
                });
              },
            ),
            Column(
              children: [
                Text("Animal Age: ${_animalAge.toStringAsFixed(1)} years"),
                Slider(
                  value: _animalAge,
                  min: 0.0,
                  max: 20.0,
                  divisions: 20,
                  label: _animalAge.toStringAsFixed(1),
                  onChanged: (double value) {
                    setState(() {
                      _animalAge = value;
                    });
                  },
                ),
              ],
            ),
            TextField(
              controller: _zipController,
              decoration: const InputDecoration(labelText: "Enter ZIP Code"),
              keyboardType: TextInputType.number,
            ),
            ElevatedButton(
              onPressed: () async {
                await _savePreferences();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const AnimalListScreen(),
                  ),
                );
              },
              child: const Text('Save Preferences'),
            ),
          ],
        ),
      ),
    );
  }
}


class AnimalListScreen extends StatefulWidget {
  const AnimalListScreen({super.key});

  @override
  _AnimalListScreenState createState() => _AnimalListScreenState();
}

class _AnimalListScreenState extends State<AnimalListScreen> {
  List<dynamic> _animals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAnimals();
  }

  Future<void> _fetchAnimals() async {
    const String apiUrl = 'https://data.kingcounty.gov/resource/ytc8-tcih.json';
    const String apiToken = '6yAff0sPYQ6WXsPGlUkV1Gced';

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Host': 'data.kingcounty.gov',
          'Accept': 'application/json',
          'X-App-Token': apiToken,
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _animals = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        print('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('Error occurred: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Available Animals')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : PageView.builder(
              scrollDirection: Axis.vertical,
              itemCount: _animals.length,
              itemBuilder: (context, index) {
                final animal = _animals[index];
                print("current animal index is:$index");
                return _buildAnimalCard(animal);
              },
            ),
    );
  }

  String parseAnimalMemo(String? rawMemo) {
    if (rawMemo == Null) {
      return 'No description available';
    }

    List<String> parsedData = rawMemo!.split('<p/>');
    Map<String, String> memoMap = {};
    for (String item in parsedData) {
      if (item.contains(':')) {
        int splitIndex = item.indexOf(':');
        String key = item.substring(0, splitIndex).trim();
        String value = item.substring(splitIndex + 1).trim();
        memoMap[key] = value;
      }
    }

    String result = "";

    memoMap.forEach((key, value) {
      result += '$key: $value\n';
    });

    return result;
  }

  Widget _buildAnimalCard(Map<String, dynamic> animal) {
    // Page flip animation
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnimalMemoPage(
              animalMemo: parseAnimalMemo(animal['memo']),
            ),
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            fit: FlexFit.loose,
            child: Image.network(
              animal['image']?['url'] ??
                  'https://petharbor.com/get_image.asp?RES=Detail&LOCATION=KING&ID=A708686',
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return const Center(child: Text('Image not available'));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  animal['animal_name'] ?? 'Untitled',
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AnimalMemoPage extends StatelessWidget {
  final String animalMemo;

  const AnimalMemoPage({super.key, required this.animalMemo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Animal Memo')),
      body: SingleChildScrollView(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(seconds: 1),
            child: Container(
              key: ValueKey<String>(animalMemo),
              color: Colors.white,
              padding: const EdgeInsets.all(16.0),
              child: Text(
                animalMemo,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
