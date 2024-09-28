// main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase Upload/Download',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  Dio dio = Dio();
  Future<void> _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;

      try {
        // Upload file to Firebase Storage
        TaskSnapshot uploadTask =
            await _storage.ref('files/$fileName').putFile(file);
        String downloadUrl = await uploadTask.ref.getDownloadURL();

        // Save metadata to Firestore
        await _firestore.collection('files').add({
          'name': fileName,
          'url': downloadUrl,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('File uploaded successfully')));
      } catch (e) {
        debugPrint("$e");
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to upload file')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Firebase Upload/Download')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('files')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot doc = snapshot.data!.docs[index];
              return ListTile(
                title: Text(doc['name']),
                trailing: IconButton(
                  icon: Icon(Icons.download),
                  onPressed: () => _downloadFile(doc['url'], doc['name']),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadFile,
        child: Icon(Icons.upload_file),
      ),
    );
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      // 1. Demander la permission de stockage
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        debugPrint('Permission refusée');
        return;
      }

      // 2. Obtenir le chemin du répertoire de téléchargement
      Directory? downloadDirectory;
      if (Platform.isAndroid) {
        downloadDirectory = await getExternalStorageDirectory();
        // Dossier Downloads pour Android
        downloadDirectory = Directory('/storage/emulated/0/Download');
      } else if (Platform.isIOS) {
        downloadDirectory = await getApplicationDocumentsDirectory();
      }

      String savePath = '${downloadDirectory!.path}/$fileName';

      // 3. Lancer le téléchargement avec Dio
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            debugPrint(
                'Progression du téléchargement : ${(received / total * 100).toStringAsFixed(0)}%');
          }
        },
      );

      debugPrint('Fichier téléchargé et sauvegardé dans : $savePath');
    } catch (e) {
      debugPrint('Erreur lors du téléchargement : $e');
    }
  }
}
