import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FlashlightApp());
}

/// Thin wrapper around the native torch channel (see MainActivity.kt).
class Torch {
  static const _channel = MethodChannel('flashlight/torch');

  static Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> set(bool on) async {
    try {
      await _channel.invokeMethod('setTorch', {'on': on});
    } catch (_) {
      // Ignore: the UI already reflects "no flash" when unavailable.
    }
  }
}

enum LightMode { steady, strobe, sos }

class FlashlightApp extends StatelessWidget {
  const FlashlightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flashlight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0E0F12),
        useMaterial3: true,
      ),
      home: const FlashlightHome(),
    );
  }
}

class FlashlightHome extends StatefulWidget {
  const FlashlightHome({super.key});

  @override
  State<FlashlightHome> createState() => _FlashlightHomeState();
}

class _FlashlightHomeState extends State<FlashlightHome>
    with WidgetsBindingObserver {
  bool _available = true;
  bool _active = false; // user has switched the light on
  bool _lit = false; // flash is physically on right now
  LightMode _mode = LightMode.steady;
  double _strobeHz = 5;
  Timer? _timer;
  int _sosStep = 0;

  // SOS in Morse: ... --- ...  (unit = 200 ms)
  // Each entry: [on?, units]
  static const List<List<int>> _sosPattern = [
    [1, 1], [0, 1], [1, 1], [0, 1], [1, 1], [0, 3], //
    [1, 3], [0, 1], [1, 3], [0, 1], [1, 3], [0, 3], //
    [1, 1], [0, 1], [1, 1], [0, 1], [1, 1], [0, 7],
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Torch.isAvailable().then((v) {
      if (mounted) setState(() => _available = v);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // No setState here: the widget is being torn down.
    _timer?.cancel();
    _timer = null;
    _lit = false;
    Torch.set(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android releases the torch when another app grabs the camera;
    // re-apply our state when we come back.
    if (state == AppLifecycleState.resumed && _active) {
      _start();
    }
  }

  void _setLit(bool on) {
    _lit = on;
    Torch.set(on);
    if (mounted) setState(() {});
  }

  void _stopAll() {
    _timer?.cancel();
    _timer = null;
    _setLit(false);
  }

  void _start() {
    _timer?.cancel();
    switch (_mode) {
      case LightMode.steady:
        _setLit(true);
        break;
      case LightMode.strobe:
        final half = Duration(milliseconds: (500 / _strobeHz).round());
        _setLit(true);
        _timer = Timer.periodic(half, (_) => _setLit(!_lit));
        break;
      case LightMode.sos:
        _sosStep = 0;
        _runSos();
        break;
    }
  }

  void _runSos() {
    if (!_active || _mode != LightMode.sos) return;
    final step = _sosPattern[_sosStep % _sosPattern.length];
    _setLit(step[0] == 1);
    _sosStep++;
    _timer = Timer(Duration(milliseconds: 200 * step[1]), _runSos);
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    setState(() => _active = !_active);
    _active ? _start() : _stopAll();
  }

  void _selectMode(LightMode m) {
    HapticFeedback.selectionClick();
    setState(() => _mode = m);
    if (_active) _start();
  }

  void _openScreenLight() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScreenLightPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glow = _lit ? Colors.amber : Colors.transparent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashlight'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Screen light',
            icon: const Icon(Icons.smartphone),
            onPressed: _openScreenLight,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_available)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No camera flash found on this device. '
                  'Use the screen light (phone icon, top right) instead.',
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: _toggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _active
                          ? const Color(0xFF2A2410)
                          : const Color(0xFF1B1D22),
                      border: Border.all(
                        color: _active ? Colors.amber : Colors.white24,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: glow.withOpacity(0.55),
                          blurRadius: 60,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.power_settings_new,
                      size: 96,
                      color: _active ? Colors.amber : Colors.white54,
                    ),
                  ),
                ),
              ),
            ),
            Text(
              _active ? 'ON' : 'OFF',
              style: TextStyle(
                fontSize: 22,
                letterSpacing: 6,
                fontWeight: FontWeight.w600,
                color: _active ? Colors.amber : Colors.white54,
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SegmentedButton<LightMode>(
                segments: const [
                  ButtonSegment(
                    value: LightMode.steady,
                    label: Text('Steady'),
                    icon: Icon(Icons.flashlight_on),
                  ),
                  ButtonSegment(
                    value: LightMode.strobe,
                    label: Text('Strobe'),
                    icon: Icon(Icons.flash_auto),
                  ),
                  ButtonSegment(
                    value: LightMode.sos,
                    label: Text('SOS'),
                    icon: Icon(Icons.sos),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => _selectMode(s.first),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _mode == LightMode.strobe
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                      child: Row(
                        children: [
                          const Text('Speed'),
                          Expanded(
                            child: Slider(
                              min: 1,
                              max: 15,
                              divisions: 14,
                              value: _strobeHz,
                              label: '${_strobeHz.round()} Hz',
                              onChanged: (v) {
                                setState(() => _strobeHz = v);
                                if (_active) _start();
                              },
                            ),
                          ),
                          Text('${_strobeHz.round()} Hz'),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

/// Full-screen white light with adjustable colour warmth — works on any phone.
class ScreenLightPage extends StatefulWidget {
  const ScreenLightPage({super.key});

  @override
  State<ScreenLightPage> createState() => _ScreenLightPageState();
}

class _ScreenLightPageState extends State<ScreenLightPage> {
  double _warmth = 0; // 0 = white, 1 = warm amber

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(Colors.white, const Color(0xFFFFC46B), _warmth)!;
    return Scaffold(
      backgroundColor: color,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: SizedBox.expand(
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Tap anywhere to close',
                  style: TextStyle(color: Colors.black45),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Slider(
                    value: _warmth,
                    onChanged: (v) => setState(() => _warmth = v),
                    activeColor: Colors.black54,
                    inactiveColor: Colors.black12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
