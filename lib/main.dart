// ignore_for_file: use_key_in_widget_constructors, prefer_const_constructors, avoid_web_libraries_in_flutter, unused_import, deprecated_member_use, library_private_types_in_public_api, avoid_function_literals_in_foreach_calls

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
//import 'providers/task_provider.dart';
//import 'screens/task_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: "AIzaSyCyXkao-jBnKexFoyqFzCfd6va1ldGaTu4",
      authDomain: "thingstodo-eda.firebaseapp.com",
      projectId: "thingstodo-eda",
      storageBucket: "thingstodo-eda.appspot.com",
      messagingSenderId: "352415805190",
      appId: "1:352415805190:web:fdb8cfe606dfec306df887",
    ),
  );
  runApp(MyApp());
}

class Task {
  String id;
  String title;
  String description;
  bool isExpanded;

  Task(
      {required this.id,
      required this.title,
      this.description = '',
      this.isExpanded = false});
}

class TaskProvider with ChangeNotifier {
  List<Task> _tasks = [];

  List<Task> get tasks => _tasks;

  Future<void> fetchTasks() async {
    var snapshot = await FirebaseFirestore.instance.collection('tasks').get();
    _tasks = snapshot.docs.map((doc) {
      var data = doc.data();
      return Task(
        id: doc.id,
        title: data['title'],
        description: data['description'],
        isExpanded: data['isExpanded'],
      );
    }).toList();
    notifyListeners();
  }

  Future<void> addTask(String title, String description) async {
    var docRef = await FirebaseFirestore.instance.collection('tasks').add({
      'title': title,
      'description': description,
      'isExpanded': false,
    });
    _tasks.add(Task(id: docRef.id, title: title, description: description));
    notifyListeners();
  }

  Future<void> deleteTask(String id) async {
    await FirebaseFirestore.instance.collection('tasks').doc(id).delete();
    _tasks.removeWhere((task) => task.id == id);
    notifyListeners();
  }

  void toggleExpansion(int index) {
    _tasks[index].isExpanded = !_tasks[index].isExpanded;
    notifyListeners();
  }
}

class TaskScreen extends StatefulWidget {
  @override
  _TaskScreenState createState() => _TaskScreenState();
}

class _TaskScreenState extends State<TaskScreen> {
  final TextEditingController _taskController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Provider.of<TaskProvider>(context, listen: false).fetchTasks();
  }

  void _showDeleteConfirmationDialog(BuildContext context, String taskId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Görevi Sil'),
          content: Text('Silmek istediğinizden emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('İptal'),
            ),
            TextButton(
              onPressed: () {
                Provider.of<TaskProvider>(context, listen: false)
                    .deleteTask(taskId);
                Navigator.of(context).pop();
              },
              child: Text('Evet'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  List<Widget> _buildDescription(String description) {
    final RegExp urlRegExp = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );
    final List<Widget> widgets = [];
    final Iterable<RegExpMatch> matches = urlRegExp.allMatches(description);

    if (matches.isEmpty) {
      widgets.add(Text(description));
    } else {
      int currentIndex = 0;
      matches.forEach((match) {
        if (match.start > currentIndex) {
          widgets.add(Text(description.substring(currentIndex, match.start)));
        }
        final String url = match.group(
            0)!; // Burada non-null assertion operatorü kullanarak url'nin null olmadığını belirttik
        widgets.add(
          GestureDetector(
            onTap: () => _launchUrl(url),
            child: Text(
              url,
              style: TextStyle(
                  color: Colors.blue, decoration: TextDecoration.underline),
            ),
          ),
        );
        currentIndex = match.end;
      });
      if (currentIndex < description.length) {
        widgets.add(Text(description.substring(currentIndex)));
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Görevler'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<TaskProvider>(
              builder: (context, taskProvider, child) {
                return ListView.builder(
                  itemCount: taskProvider.tasks.length,
                  itemBuilder: (context, index) {
                    final task = taskProvider.tasks[index];
                    return GestureDetector(
                      onTap: () {
                        taskProvider.toggleExpansion(index);
                      },
                      child: ExpansionPanelList(
                        elevation: 1,
                        expandedHeaderPadding: EdgeInsets.all(0),
                        expansionCallback: (panelIndex, isExpanded) {
                          taskProvider.toggleExpansion(index);
                        },
                        children: [
                          ExpansionPanel(
                            headerBuilder: (context, isExpanded) {
                              return ListTile(
                                title: Text(task.title),
                              );
                            },
                            body: Column(
                              children: [
                                ListTile(
                                  title: task.description.isEmpty
                                      ? Text('Detay yok')
                                      : Wrap(
                                          children: _buildDescription(
                                              task.description),
                                        ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(right: 16.0),
                                      child: TextButton(
                                        onPressed: () {
                                          _showDeleteConfirmationDialog(
                                              context, task.id);
                                        },
                                        child: Text('Sil',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            isExpanded: task.isExpanded,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FloatingActionButton(
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) {
                return AlertDialog(
                  title: Text('Yeni Görev Ekle'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _taskController,
                        decoration: InputDecoration(
                          hintText: 'Görev Başlığı',
                        ),
                      ),
                      TextField(
                        controller: _descriptionController,
                        decoration: InputDecoration(
                          hintText: 'Görev Detayları',
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () {
                        if (_taskController.text.isNotEmpty) {
                          Provider.of<TaskProvider>(context, listen: false)
                              .addTask(_taskController.text,
                                  _descriptionController.text);
                          _taskController.clear();
                          _descriptionController.clear();
                          Navigator.of(context).pop();
                        }
                      },
                      child: Text('Ekle'),
                    ),
                  ],
                );
              },
            );
          },
          child: Icon(Icons.add),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TaskProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'thingstodo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: TaskScreen(),
      ),
    );
  }
}
