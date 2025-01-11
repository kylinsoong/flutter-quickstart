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
  int _rowsPerPage = 10;
  late VideoDataTableSource _videoDataSource;

  @override
  void initState() {
    super.initState();
    _videos = fetchVideos();
  }

  Future<List<Map<String, dynamic>>> fetchVideos() async {
    //final String apiUrl = Platform.environment['API_BASE_URL']?? 'http://127.0.0.1:3000';
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
      _videoDataSource.sort(columnIndex, ascending);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('豆包大模型视频质检'),
      ),
      body: SingleChildScrollView( 
        child: FutureBuilder<List<Map<String, dynamic>>>(
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
              _videoDataSource = VideoDataTableSource(videos, _launchURL);

              return PaginatedDataTable(
                header: const Text('质检结果'),
                rowsPerPage: _rowsPerPage,
                availableRowsPerPage: const [5, 10, 20, 50, 100],
                onRowsPerPageChanged: (value) {
                  setState(() {
                    _rowsPerPage = value!;
                  });
                },
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                columns: [
                  DataColumn(
                    label: const Text('ID', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  DataColumn(
                    label: const Text('视频', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (columnIndex, ascending) => _sortTable(columnIndex, ascending),
                  ),
                  DataColumn(
                    label: const Text('语音分析结果', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (columnIndex, ascending) => _sortTable(columnIndex, ascending),
                  ),
                  DataColumn(
                    label: const Text('视频分析结果', style: TextStyle(fontWeight: FontWeight.bold)),
                    onSort: (columnIndex, ascending) => _sortTable(columnIndex, ascending),
                  ),
                ],
                source: _videoDataSource,
              );
            }
          },
        ),
      ),
    );
  }
}

class VideoDataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> _videos;
  final Future<void> Function(String url) _launchURL;

  VideoDataTableSource(this._videos, this._launchURL);

  @override
  DataRow getRow(int index) {
    assert(index >= 0);
    if (index >= _videos.length) return const DataRow(cells: []);
    final video = _videos[index];
    return DataRow(
      cells: [
        DataCell(
          Center( // 对每个DataCell中的内容添加Center组件包裹，使其内容居中显示
            child: Text(video['uid']?? ''),
          ),
        ),
        DataCell(
          GestureDetector(
            onTap: () => _launchURL(video['url']?? ''),
            child: Center( // 对每个DataCell中的内容添加Center组件包裹，使其内容居中显示
              child: Text(
                Uri.parse(video['url']?? '').pathSegments.last,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ),
        DataCell(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Center( // 对每个DataCell中的内容添加Center组件包裹，使其内容居中显示
              child: Text(
                (video['audio']?.trim()?? '').replaceAll(' ', ''),
                style: const TextStyle(),
                overflow: TextOverflow.visible,
                maxLines: null,
                softWrap: true,
              ),
            ),
          ),
        ),
        DataCell(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Center( // 对每个DataCell中的内容添加Center组件包裹，使其内容居中显示
              child: Text(
                (video['video']?.trim()?? '').replaceAll(' ', ''),
                style: const TextStyle(overflow: TextOverflow.visible),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => _videos.length;

  @override
  int get selectedRowCount => 0;

  void sort(int columnIndex, bool ascending) {
    if (columnIndex == 1) {
      _videos.sort((a, b) {
        final nameA = Uri.parse(a['url']?? '').pathSegments.last;
        final nameB = Uri.parse(b['url']?? '').pathSegments.last;
        return ascending? nameA.compareTo(nameB) : nameB.compareTo(nameA);
      });
    }
    notifyListeners();
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
            onPressed: _formProgress == 1? _showWelcomeScreen : null,
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