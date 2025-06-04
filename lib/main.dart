import 'dart:async';
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:yaml/yaml.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const HomeSwitcher(),
    );
  }
}

enum MatchingScreenType { twoFile, template }

class HomeSwitcher extends StatefulWidget {
  const HomeSwitcher({super.key});

  @override
  State<HomeSwitcher> createState() => _HomeSwitcherState();
}

class _HomeSwitcherState extends State<HomeSwitcher> {
  MatchingScreenType _selected = MatchingScreenType.twoFile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OpenCVマッチングデモ')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Radio<MatchingScreenType>(
                value: MatchingScreenType.twoFile,
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v!),
              ),
              const Text('2ファイルマッチング'),
              Radio<MatchingScreenType>(
                value: MatchingScreenType.template,
                groupValue: _selected,
                onChanged: (v) => setState(() => _selected = v!),
              ),
              const Text('テンプレートマッチング'),
            ],
          ),
          Expanded(
            child:
                _selected == MatchingScreenType.twoFile
                    ? const TwoFileMatchingScreen()
                    : const TemplateMatchingScreen(),
          ),
        ],
      ),
    );
  }
}

class TwoFileMatchingScreen extends StatefulWidget {
  const TwoFileMatchingScreen({super.key});

  @override
  State<TwoFileMatchingScreen> createState() => _TwoFileMatchingScreenState();
}

class _TwoFileMatchingScreenState extends State<TwoFileMatchingScreen> {
  String _result = '';
  File? _imageFile1;
  File? _imageFile2;

  Future<void> _pickImage(int index) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (index == 1) {
          _imageFile1 = File(pickedFile.path);
        } else {
          _imageFile2 = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _runTemplateMatching() async {
    if (_imageFile1 == null || _imageFile2 == null) {
      setState(() {
        _result = '2枚の画像を選択してください';
      });
      return;
    }
    const platform = MethodChannel('opencv_channel');
    try {
      final double similarity = await platform.invokeMethod('matchImages', {
        'image1': _imageFile1!.path,
        'image2': _imageFile2!.path,
      });
      setState(() {
        _result = '類似度: ${similarity.toStringAsFixed(3)}';
      });
    } on PlatformException catch (e) {
      setState(() {
        _result = 'エラー: ${e.message}';
      });
    }
  }

  Future<Size?> _getImageSize(File file) async {
    try {
      final decoded = await decodeImageFromList(await file.readAsBytes());
      return Size(decoded.width.toDouble(), decoded.height.toDouble());
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  _imageFile1 != null
                      ? Column(
                        children: [
                          Image.file(_imageFile1!, width: 100, height: 100),
                          FutureBuilder<Size?>(
                            future: _getImageSize(_imageFile1!),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                return Text(
                                  '画像サイズ: ${snapshot.data!.width.toInt()} x ${snapshot.data!.height.toInt()}',
                                  style: const TextStyle(fontSize: 12),
                                );
                              } else {
                                return const SizedBox.shrink();
                              }
                            },
                          ),
                        ],
                      )
                      : Container(width: 100, height: 100, color: Colors.grey),
                  const SizedBox(height: 4),
                  const Text(
                    '画像1（テンプレート）',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                  ElevatedButton(
                    onPressed: () => _pickImage(1),
                    child: const Text('画像1選択'),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Column(
                children: [
                  _imageFile2 != null
                      ? Column(
                        children: [
                          Image.file(_imageFile2!, width: 100, height: 100),
                          FutureBuilder<Size?>(
                            future: _getImageSize(_imageFile2!),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                return Text(
                                  '画像サイズ: ${snapshot.data!.width.toInt()} x ${snapshot.data!.height.toInt()}',
                                  style: const TextStyle(fontSize: 12),
                                );
                              } else {
                                return const SizedBox.shrink();
                              }
                            },
                          ),
                        ],
                      )
                      : Container(width: 100, height: 100, color: Colors.grey),
                  const SizedBox(height: 4),
                  const Text(
                    '画像2（比較対象）',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                  ElevatedButton(
                    onPressed: () => _pickImage(2),
                    child: const Text('画像2選択'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _runTemplateMatching,
            child: const Text('パターンマッチング実行'),
          ),
          const SizedBox(height: 20),
          Text(_result, style: const TextStyle(fontSize: 20)),
        ],
      ),
    );
  }
}

class TemplateMatchingScreen extends StatefulWidget {
  const TemplateMatchingScreen({super.key});

  @override
  State<TemplateMatchingScreen> createState() => _TemplateMatchingScreenState();
}

class _TemplateMatchingScreenState extends State<TemplateMatchingScreen> {
  String _result = '';
  String? _templateDir;
  File? _cameraImage;
  List<File> _templateFiles = [];
  Map<String, double> _similarityMap = {};
  double _previewSize = 50;
  int? _cameraImageWidth;
  int? _cameraImageHeight;
  Map<String, List<int>> _templateImageSizes = {};

  @override
  void initState() {
    super.initState();
    _loadPreviewSizeFromConfig();
  }

  Future<void> _loadPreviewSizeFromConfig() async {
    try {
      final configFile = File('lib/template_matching_config.yaml');
      if (await configFile.exists()) {
        final yamlStr = await configFile.readAsString();
        final yaml = loadYaml(yamlStr);
        final size = yaml['template_preview_size'];
        if (size is int || size is double) {
          setState(() {
            _previewSize = size.toDouble();
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _pickTemplateDir() async {
    // Android 13以降はREAD_MEDIA_IMAGES, それ未満はREAD_EXTERNAL_STORAGE
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        if (!await Permission.photos.request().isGranted) {
          await Permission.photos.request();
        }
      } else {
        if (!await Permission.storage.request().isGranted) {
          await Permission.storage.request();
        }
      }
    }
    String? selectedDir = await FilePicker.platform.getDirectoryPath();
    if (selectedDir != null) {
      final dir = Directory(selectedDir);
      List<File> files = [];
      Map<String, List<int>> sizes = {};
      try {
        final entities =
            await dir.list(recursive: false, followLinks: false).toList();
        for (final entity in entities) {
          if (entity is File) {
            final name = entity.path.toLowerCase();
            if (name.endsWith('.jpg') ||
                name.endsWith('.jpeg') ||
                name.endsWith('.png') ||
                name.endsWith('.bmp')) {
              files.add(entity);
              try {
                final decoded = await decodeImageFromList(
                  await entity.readAsBytes(),
                );
                sizes[entity.path] = [decoded.width, decoded.height];
              } catch (_) {
                sizes[entity.path] = [0, 0];
              }
            }
          }
        }
      } catch (e) {
        developer.log('ディレクトリリスト取得エラー: $e', name: 'template_picker');
      }
      setState(() {
        _templateDir = selectedDir;
        _templateFiles = files;
        _templateImageSizes = sizes;
        _similarityMap.clear();
        _result = '';
      });
    }
  }

  Future<void> _takeCameraImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      final decoded = await decodeImageFromList(await file.readAsBytes());
      setState(() {
        _cameraImage = file;
        _cameraImageWidth = decoded.width;
        _cameraImageHeight = decoded.height;
        _similarityMap.clear();
        _result = '';
      });
    }
  }

  Future<List<File>> _refreshTemplateFiles() async {
    if (_templateDir == null) return [];
    final dir = Directory(_templateDir!);
    List<File> files = [];
    Map<String, List<int>> sizes = {};
    try {
      final entities =
          await dir.list(recursive: false, followLinks: false).toList();
      for (final entity in entities) {
        if (entity is File) {
          final name = entity.path.toLowerCase();
          if (name.endsWith('.jpg') ||
              name.endsWith('.jpeg') ||
              name.endsWith('.png') ||
              name.endsWith('.bmp')) {
            files.add(entity);
            try {
              final decoded = await decodeImageFromList(
                await entity.readAsBytes(),
              );
              sizes[entity.path] = [decoded.width, decoded.height];
            } catch (_) {
              sizes[entity.path] = [0, 0];
            }
          }
        }
      }
    } catch (e) {
      developer.log('ディレクトリリスト取得エラー: $e', name: 'template_picker');
    }
    files.sort((a, b) => a.path.compareTo(b.path));
    setState(() {
      _templateFiles = files;
      _templateImageSizes = sizes;
    });
    return files;
  }

  Future<void> _runTemplateMatching() async {
    final currentTemplates = await _refreshTemplateFiles();
    if (_cameraImage == null || currentTemplates.isEmpty) {
      setState(() {
        _result = 'テンプレートディレクトリとカメラ画像を指定してください';
      });
      return;
    }
    const platform = MethodChannel('opencv_channel');
    Map<String, double> simMap = {};
    for (final template in currentTemplates) {
      try {
        final double similarity = await platform.invokeMethod('matchImages', {
          'image1': template.path,
          'image2': _cameraImage!.path,
        });
        simMap[template.path] = similarity;
      } catch (_) {
        simMap[template.path] = double.nan;
      }
    }
    setState(() {
      _similarityMap = simMap;
      _result = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasTemplates = _templateFiles.isNotEmpty;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _pickTemplateDir,
                child: const Text('テンプレートディレクトリ選択'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: _takeCameraImage,
                child: const Text('カメラ画像取得'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _templateDir != null
              ? Text('テンプレート: $_templateDir')
              : const SizedBox(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _cameraImage != null
                  ? Image.file(
                    _cameraImage!,
                    width: _previewSize,
                    height: _previewSize,
                  )
                  : Container(
                    width: _previewSize,
                    height: _previewSize,
                    color: Colors.grey,
                  ),
              const SizedBox(width: 10),
              if (_cameraImageWidth != null && _cameraImageHeight != null)
                Text('画像サイズ: $_cameraImageWidth x $_cameraImageHeight'),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed:
                hasTemplates && _cameraImage != null
                    ? _runTemplateMatching
                    : null,
            child: const Text('テンプレートマッチング実行'),
          ),
          const SizedBox(height: 20),
          if (!hasTemplates && _templateDir != null)
            Text(
              'テンプレート画像が存在しませんでした。',
              style: const TextStyle(color: Colors.red),
            ),
          if (_similarityMap.isNotEmpty && hasTemplates)
            Expanded(
              child: ListView.builder(
                itemCount: _templateFiles.length,
                itemBuilder: (context, idx) {
                  final file = _templateFiles[idx];
                  final sim = _similarityMap[file.path];
                  final size = _templateImageSizes[file.path];
                  return ListTile(
                    leading: Image.file(
                      file,
                      width: _previewSize,
                      height: _previewSize,
                    ),
                    title: Text(file.path.split(Platform.pathSeparator).last),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (size != null && size[0] > 0 && size[1] > 0)
                          Text('画像サイズ: ${size[0]} x ${size[1]}'),
                        Text(
                          sim != null && !sim.isNaN
                              ? '類似度: ${sim.toStringAsFixed(3)}'
                              : '計算失敗',
                          style: TextStyle(
                            color:
                                sim != null && !sim.isNaN
                                    ? Colors.black
                                    : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          if (_result.isNotEmpty)
            Text(_result, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          const Text(
            '※ カメラ画像のサイズ ≧ テンプレート画像のサイズ',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
