import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_scope.dart';
import 'data/lexicon.dart';
import 'data/review_store.dart';
import 'data/splitter.dart';
import 'screens/explore_screen.dart';
import 'screens/puzzle_screen.dart';
import 'screens/review_screen.dart';
import 'screens/split_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WordBlocksApp());
}

class WordBlocksApp extends StatefulWidget {
  const WordBlocksApp({super.key});

  @override
  State<WordBlocksApp> createState() => _WordBlocksAppState();
}

class _WordBlocksAppState extends State<WordBlocksApp> {
  late final Future<(Lexicon, Splitter, ReviewStore)> _load = _init();

  static Future<(Lexicon, Splitter, ReviewStore)> _init() async {
    final (lexicon, prefs) = await (Lexicon.load(), SharedPreferences.getInstance()).wait;
    return (lexicon, Splitter(lexicon), ReviewStore(prefs));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '字根工坊',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // AppScope wraps the Navigator (not just the home page) so pushed pages can read it too.
      builder: (context, navigator) => FutureBuilder(
        future: _load,
        builder: (context, snap) {
          if (snap.hasError) {
            return Scaffold(body: Center(child: Text('資料載入失敗：${snap.error}')));
          }
          if (!snap.hasData) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final (lexicon, splitter, store) = snap.data!;
          return AppScope(lexicon: lexicon, splitter: splitter, store: store, child: navigator!);
        },
      ),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _titles = ['字根地圖', '拆解', '今日複習', '字根積木'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_tab])),
      body: IndexedStack(
        index: _tab,
        children: const [ExploreScreen(), SplitScreen(), ReviewScreen(), PuzzleScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.hub_outlined), selectedIcon: Icon(Icons.hub), label: '字根地圖'),
          NavigationDestination(icon: Icon(Icons.view_week_outlined), selectedIcon: Icon(Icons.view_week), label: '拆解'),
          NavigationDestination(icon: Icon(Icons.style_outlined), selectedIcon: Icon(Icons.style), label: '複習'),
          NavigationDestination(icon: Icon(Icons.extension_outlined), selectedIcon: Icon(Icons.extension), label: '積木'),
        ],
      ),
    );
  }
}
