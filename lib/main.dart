import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:loading_progress/loading_progress.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '照片色調辨識器',
      theme: ThemeData(
        //colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Navigation(title: '照片色調辨識器'),
    );
  }
}

class Navigation extends StatefulWidget {
  const Navigation({super.key, required this.title});

  final String title;

  @override
  State<Navigation> createState() => _NavigationState();
}

class _NavigationState extends State<Navigation> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
        ),
        bottomNavigationBar: NavigationBar(
          onDestinationSelected: (int index) {
            setState(() {
              currentPageIndex = index;
            });
          },
          indicatorColor: Colors.amber[800],
          selectedIndex: currentPageIndex,
          destinations: const <Widget>[
            NavigationDestination(
              icon: Icon(Icons.home),
              label: '首頁',
            ),
            NavigationDestination(
              icon: Icon(Icons.history),
              label: '歷史紀錄',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings),
              label: '設定',
            ),
          ],
        ),
        body: IndexedStack(
          index: currentPageIndex,
          children: const <Widget>[
            HomePage(),
            HistoryPage(),
            SettingPage(),
          ],
        ));
  }
}

/// Home Page ///
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ImagePicker _picker = ImagePicker();
  List<XFile> pickedFileList = [];
  Color pickcolor = Colors.blue;
  static const Color guidePrimary = Color(0xFF6200EE);
  static const Color guidePrimaryVariant = Color(0xFF3700B3);
  static const Color guideSecondary = Color(0xFF03DAC6);
  static const Color guideSecondaryVariant = Color(0xFF018786);
  static const Color guideError = Color(0xFFB00020);
  static const Color guideErrorDark = Color(0xFFCF6679);
  static const Color blueBlues = Color(0xFF174378);
  final Map<ColorSwatch<Object>, String> colorsNameMap =
      <ColorSwatch<Object>, String>{
    ColorTools.createPrimarySwatch(guidePrimary): 'Guide Purple',
    ColorTools.createPrimarySwatch(guidePrimaryVariant): 'Guide Purple Variant',
    ColorTools.createAccentSwatch(guideSecondary): 'Guide Teal',
    ColorTools.createAccentSwatch(guideSecondaryVariant): 'Guide Teal Variant',
    ColorTools.createPrimarySwatch(guideError): 'Guide Error',
    ColorTools.createPrimarySwatch(guideErrorDark): 'Guide Error Dark',
    ColorTools.createPrimarySwatch(blueBlues): 'Blue blues',
  };
  bool isUploadRunning = false;

  Future<bool> colorPickerDialog() async {
    return ColorPicker(
      // Use the dialogPickerColor as start color.
      color: pickcolor,
      // Update the dialogPickerColor using the callback.
      onColorChanged: (Color color) => setState(() => pickcolor = color),
      width: 40,
      height: 40,
      borderRadius: 4,
      spacing: 5,
      runSpacing: 5,
      wheelDiameter: 155,
      heading: Text(
        'Select color',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subheading: Text(
        'Select color shade',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      wheelSubheading: Text(
        'Selected color and its shades',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      showMaterialName: true,
      showColorName: true,
      showColorCode: true,
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(
        longPressMenu: true,
      ),
      materialNameTextStyle: Theme.of(context).textTheme.bodySmall,
      colorNameTextStyle: Theme.of(context).textTheme.bodySmall,
      colorCodeTextStyle: Theme.of(context).textTheme.bodySmall,
      pickersEnabled: const <ColorPickerType, bool>{
        ColorPickerType.both: false,
        ColorPickerType.primary: true,
        ColorPickerType.accent: true,
        ColorPickerType.bw: false,
        ColorPickerType.custom: true,
        ColorPickerType.wheel: true,
      },
      customColorSwatchesAndNames: colorsNameMap,
    ).showPickerDialog(
      context,
      // New in version 3.0.0 custom transitions support.
      transitionBuilder: (BuildContext context, Animation<double> a1,
          Animation<double> a2, Widget widget) {
        final double curvedValue =
            Curves.easeInOutBack.transform(a1.value) - 1.0;
        return Transform(
          transform: Matrix4.translationValues(0.0, curvedValue * 200, 0.0),
          child: Opacity(
            opacity: a1.value,
            child: widget,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
      constraints:
          const BoxConstraints(minHeight: 460, minWidth: 300, maxWidth: 320),
    );
  }

  Widget _previewimages() {
    if (pickedFileList.isNotEmpty) {
      return SizedBox(
          height: 200,
          child: ListView.builder(
              key: UniqueKey(),
              itemCount: pickedFileList.length,
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                return SizedBox(
                    height: 200,
                    child: Image.file(File(pickedFileList[index].path)));
              }));
    } else {
      return const Text(
        '選擇的圖片將顯示在這裡',
        textAlign: TextAlign.center,
      );
    }
  }

  Widget _UploadButton() {
    return FilledButton(
        onPressed: isUploadRunning
            ? null
            : () async {
                final prefs = await SharedPreferences.getInstance();
                String history = prefs.getString('history') ?? "";
                if (history == "") {
                  history = "[]";
                }
                List<dynamic> history_arr = jsonDecode(history);
                String server = prefs.getString("server") ?? "";
                if (server == "") {
                  return;
                }
                server = "$server/upload";
                setState(() => isUploadRunning = true);
                LoadingProgress.start(context);
                //print('isUploadRunning: ' + isUploadRunning.toString());
                var request = http.MultipartRequest('POST', Uri.parse(server));
                request.fields['user_id'] = '1'; // FIXME
                request.fields['color'] = pickcolor.hex;
                for (XFile f in pickedFileList) {
                  print(f.name);
                  request.files.add(http.MultipartFile.fromBytes(
                      'file', File(f.path).readAsBytesSync(),
                      filename: f.name,
                      contentType: MediaType('image', 'jpeg')));
                }
                final response = await request.send();
                setState(() => isUploadRunning = false);
                LoadingProgress.stop(context);
                //print('isUploadRunning: ' + isUploadRunning.toString());
                var message = "";
                if (response.statusCode == 200) {
                  var resp = await http.Response.fromStream(response);
                  var resp_json = json.decode(resp.body);
                  message =
                      '成功! 最佳的圖片為「${resp_json[0]['result']}」，詳細結果可至歷史紀錄頁面確認';
                  DateTime now = DateTime.now();
                  String formattedDate =
                      DateFormat('yyyy-MM-dd kk:mm').format(now);
                  history_arr.insert(0, 
                      "{\"time\": \"$formattedDate\", \"color\": \"${pickcolor.hex}\", \"photo\": ${resp_json[0]['result']}}");
                  print("Saving: ${jsonEncode(history_arr)}");
                  prefs.setString('history', jsonEncode(history_arr));
                } else {
                  message = '發生錯誤，伺服器回傳: ${response.statusCode}';
                }
                //print(response.statusCode);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                  ),
                );
              },
        child: isUploadRunning ? const Text('上傳中') : const Text('上傳'));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(
      children: [
        Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: () async {
                    var FileList = await _picker.pickMultiImage();
                    setState(() {
                      pickedFileList = FileList;
                    });
                  },
                  child: const Text('選擇照片')),
            )),
        _previewimages(),
        const Padding(
            padding: EdgeInsets.all(16.0),
            child: SizedBox(
              child: TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '輸入備註',
                ),
              ),
            )),
        ListTile(
          title: const Text('請選擇目標顏色'),
          subtitle: Text('目前已選擇 '
              '${ColorTools.materialNameAndCode(pickcolor, colorSwatchNameMap: colorsNameMap)}'),
          trailing: ColorIndicator(
            width: 44,
            height: 44,
            borderRadius: 4,
            color: pickcolor,
            onSelectFocus: false,
            onSelect: () async {
              final Color colorBeforeDialog = pickcolor;
              if (!(await colorPickerDialog())) {
                setState(() {
                  pickcolor = colorBeforeDialog;
                });
              }
            },
          ),
        ),
        Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: _UploadButton(),
            ))
      ],
    ));
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Future<String> getPreferenceData() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    return pref.getString("history") ?? "[]";
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: getPreferenceData(),
        builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
          if (snapshot.hasData) {
            var arr = <Widget>[];
            arr.add(FilledButton(
                onPressed: () => setState(() {}), child: const Text("重新整理")));
            var data = jsonDecode(snapshot.data ?? "[{}]");
            print("The decode data is $data");
            for (var result in data) {
              print("Now result is $result");
              var images = <Widget>[];
              var result_json = jsonDecode(result);
              for (var imgpath in result_json["photo"]) {
                images.add(buildImage(imgpath));
              }
              arr.add(Card(
                child: Column(
                  children: <Widget>[
                    Text(
                        "上傳時間: ${result_json['time']}    顏色編號: ${result_json['color']}    結果: 共${result_json['photo'].length}張"),
                    Row(
                      children: images,
                    ),
                  ],
                ),
              ));
            }
            return ListView(children: arr);
          } else {
            return CircularProgressIndicator();
          }
        });
  }

  Widget buildImage(filename) {
    return Expanded(
        child: SizedBox(
      height: 200,
      child: Image.network(
          'https://5147-2401-e180-8820-3a4c-a198-1bd2-926e-ef17.ngrok-free.app/picture?filename=$filename'),
    ));
  }
}

/// Setting Page ///
class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<StatefulWidget> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  String server = "";
  final TextEditingController _serverinputcontroller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  void _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    server = prefs.getString("server") ?? "";
    _serverinputcontroller.text = server;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          child: TextField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '伺服器位置',
            ),
            onChanged: (str) async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('server', str);
            },
            controller: _serverinputcontroller,
          ),
        ),
      )
    ]);
  }
}
