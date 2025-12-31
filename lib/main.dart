import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/bill_splitter_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Add comprehensive error handling to prevent crashes
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };
  
  // Handle app lifecycle to clean up resources
  SystemChannels.lifecycle.setMessageHandler((message) async {
    debugPrint('App lifecycle: $message');
    if (message == 'AppLifecycleState.paused' || 
        message == 'AppLifecycleState.detached') {
      // Force cleanup when app is being closed
      debugPrint('App is being closed, forcing cleanup...');
    }
    return null;
  });
  
  // Catch any errors during app initialization
  try {
    runApp(const BillSplitterApp());
  } catch (error, stackTrace) {
    debugPrint('App initialization error: $error');
    debugPrint('Stack trace: $stackTrace');
    // Try to run a minimal app to show error
    runApp(MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Splitr - Error')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'App failed to start.\nPlease restart the app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

class BillSplitterApp extends StatefulWidget {
  const BillSplitterApp({super.key});

  @override
  State<BillSplitterApp> createState() => _BillSplitterAppState();
}

class _BillSplitterAppState extends State<BillSplitterApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('App lifecycle state changed: $state');
    
    switch (state) {
      case AppLifecycleState.paused:
        debugPrint('App paused - cleaning up resources...');
        break;
      case AppLifecycleState.detached:
        debugPrint('App detached - forcing cleanup...');
        break;
      case AppLifecycleState.resumed:
        debugPrint('App resumed');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Splitr',
      theme: AppTheme.softLight,
      home: const BillSplitterScreen(),
      debugShowCheckedModeBanner: false,
      // Add error handling for widget tree errors
      builder: (context, widget) {
        ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
          return Scaffold(
            appBar: AppBar(title: const Text('Splitr - Error')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Something went wrong.\nPlease restart the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Try to restart by rebuilding the widget tree
                      if (context.mounted) {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const BillSplitterScreen()),
                          (route) => false,
                        );
                      }
                    },
                    child: const Text('Restart'),
                  ),
                ],
              ),
            ),
          );
        };
        return widget!;
      },
    );
  }
}
