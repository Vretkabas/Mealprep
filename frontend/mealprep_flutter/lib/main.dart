import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

// Setup Dio (HTTP Client)
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost', // Via Nginx
    connectTimeout: const Duration(seconds: 5),
  ));
  return dio;
});

// retrieve test data
final apiCheckProvider = FutureProvider<String>((ref) async {
  final dio = ref.watch(dioProvider);
  try {
    // call endpoint
    final response = await dio.get('/mini-test');
    return response.data.toString();
  } catch (e) {
    return "Fout bij verbinden: $e";
  }
});

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Promo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 3. Lees de status van de API call
    final apiStatus = ref.watch(apiCheckProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Promo Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_cart, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              "Backend Status:",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            // 4. Toon loading, error of data
            apiStatus.when(
              data: (data) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(data, textAlign: TextAlign.center),
              ),
              error: (err, stack) => Text("Error: $err", style: const TextStyle(color: Colors.red)),
              loading: () => const CircularProgressIndicator(),
            ),
            
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => ref.refresh(apiCheckProvider),
              child: const Text("Test Verbinding Opnieuw"),
            )
          ],
        ),
      ),
    );
  }
}