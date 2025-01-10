import 'package:flutter/material.dart';
import 'dart:convert';
//import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const SignUpApp());

class SignUpApp extends StatelessWidget {
  const SignUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        '/': (context) => const SignUpScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: const Center(
        child: SizedBox(
          width: 400,
          child: Card(
            child: SignUpForm(),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Map<String, dynamic>>> _videos;

  int? _sortColumnIndex;
  bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _videos = fetchVideos();
  }

  Future<List<Map<String, dynamic>>> fetchVideos() async {
    //final String apiUrl = Platform.environment['API_BASE_URL'] ?? 'http://127.0.0.1:3000';
    const String apiUrl = 'http://127.0.0.1:3000/api/videos';
    final response = await http.get(Uri.parse(apiUrl));

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => Map<String, dynamic>.from(item)).toList();
    } else {
      throw Exception('Failed to load videos');
    }
  }

  Future<void> _retryFetchVideos() async {
    setState(() {
      _videos = fetchVideos();
    });
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _sortTable(int columnIndex, bool ascending) {
  setState(() {
    _sortColumnIndex = columnIndex;
    _sortAscending = ascending;
    _videos = _videos.then((videos) {
      videos.sort((a, b) {
        final nameA = Uri.parse(a['url'] ?? '').pathSegments.last;
        final nameB = Uri.parse(b['url'] ?? '').pathSegments.last;
        return ascending
            ? nameA.compareTo(nameB)
            : nameB.compareTo(nameA);
      });
      return videos;
    });
  });
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('视频列表'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _videos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '加载失败: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _retryFetchVideos,
                    child: const Text('重试'),
                  ),
                ],
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('未找到视频数据'));
          } else {
            final videos = snapshot.data!;
            return LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      sortColumnIndex: _sortColumnIndex,
                      sortAscending: _sortAscending,
                      columnSpacing: 16.0,
                      dataRowMinHeight: 48.0, // Set the minimum height for rows
                      dataRowMaxHeight: 60.0,
                      headingRowColor: WidgetStateColor.resolveWith((states) => Colors.grey[200]!, ),
                      columns:  [
                        DataColumn(
                          label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        DataColumn(
                          label: Text('链接', style: TextStyle(fontWeight: FontWeight.bold)),
                          onSort: (columnIndex, ascending) => _sortTable(columnIndex, ascending),
                        ),
                        DataColumn(
                          label: Text('语音分析结果', style: TextStyle(fontWeight: FontWeight.bold)),
                          onSort: (columnIndex, ascending) => _sortTable(columnIndex, ascending),
                        ),
                        DataColumn(
                          label: Text('视频分析结果', style: TextStyle(fontWeight: FontWeight.bold)),
                          onSort: (columnIndex, ascending) => _sortTable(columnIndex, ascending),
                        ),
                      ],
                      rows: videos.asMap().entries.map((entry) {
                        final index = entry.key;
                        final video = entry.value;
                        return DataRow(
                          color: WidgetStateProperty.resolveWith((states) => index.isEven ? Colors.white : Colors.grey[100]),
                          cells: [
                            DataCell(Text(video['uid'] ?? '')),
                            DataCell(
                              GestureDetector(
                                onTap: () => _launchURL(video['url'] ?? ''),
                                child: Text(
                                  Uri.parse(video['url'] ?? '').pathSegments.last,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  video['audio']?.trim() ?? '',
                                  style: const TextStyle(overflow: TextOverflow.visible),
                                ),
                              ),
                            ),
                            DataCell(
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  video['video']?.trim() ?? '',
                                  style: const TextStyle(overflow: TextOverflow.visible),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}



class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key});

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _usernameTextController = TextEditingController();
  final _passwordTextController = TextEditingController();

  double _formProgress = 0;

  void _updateFormProgress() {
    var progress = 0.0;
    final controllers = [
      _usernameTextController,
      _passwordTextController,
    ];

    for (final controller in controllers) {
      if (controller.value.text.isNotEmpty) {
        progress += 1 / controllers.length;
      }
    }

    setState(() {
      _formProgress = progress;
    });
  }

  void _showWelcomeScreen() {
    Navigator.of(context).pushNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      onChanged: _updateFormProgress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedProgressIndicator(value: _formProgress),
          Text('Sign up', style: Theme.of(context).textTheme.headlineMedium),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextFormField(
              controller: _usernameTextController,
              decoration: const InputDecoration(hintText: 'Username'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextFormField(
              controller: _passwordTextController,
              obscureText: true,
              decoration: const InputDecoration(hintText: 'Password'),
            ),
          ),
          TextButton(
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.disabled)
                    ? null
                    : Colors.white;
              }),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.disabled)
                    ? null
                    : Colors.blue;
              }),
            ),
            onPressed: _formProgress == 1 ? _showWelcomeScreen : null,
            child: const Text('Sign up'),
          ),
        ],
      ),
    );
  }
}

class AnimatedProgressIndicator extends StatefulWidget {
  final double value;

  const AnimatedProgressIndicator({
    super.key,
    required this.value,
  });

  @override
  State<AnimatedProgressIndicator> createState() {
    return _AnimatedProgressIndicatorState();
  }
}

class _AnimatedProgressIndicatorState extends State<AnimatedProgressIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation;
  late Animation<double> _curveAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    final colorTween = TweenSequence([
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.red, end: Colors.orange),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.yellow, end: Colors.green),
        weight: 1,
      ),
    ]);

    _colorAnimation = _controller.drive(colorTween);
    _curveAnimation = _controller.drive(CurveTween(curve: Curves.easeIn));
  }

  @override
  void didUpdateWidget(AnimatedProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.animateTo(widget.value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => LinearProgressIndicator(
        value: _curveAnimation.value,
        valueColor: _colorAnimation,
        backgroundColor: _colorAnimation.value?.withValues(alpha: 0.4),
      ),
    );
  }
}