// main.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'firebase_options.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase Upload/Download',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> _uploadFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      File file = File(result.files.single.path!);
      String fileName = result.files.single.name;

      debugPrint("Path: $file, fileName: $fileName");

      try {
        // Upload file to Firebase Storage
        TaskSnapshot uploadTask =
            await _storage.ref('files/$fileName').putFile(file);
        String downloadUrl = await uploadTask.ref.getDownloadURL();
        debugPrint("uploadTask: $uploadTask, downloadUrl: $downloadUrl");
        // Save metadata to Firestore
        await _firestore.collection('files').add({
          'name': fileName,
          'url': downloadUrl,
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File uploaded successfully')));
      } catch (e) {
        print(e);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to upload file')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Upload/Download')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('files')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const CircularProgressIndicator();

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              DocumentSnapshot doc = snapshot.data!.docs[index];
              return ListTile(
                title: Text(doc['name']),
                trailing: IconButton(
                  icon: const Icon(Icons.download),
                  onPressed: () => _downloadFile(doc['url'], doc['name']),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadFile,
        child: const Icon(Icons.upload_file),
      ),
    );
  }

  Future<void> _downloadFile(String url, String fileName) async {
    try {
      // Obtenez le répertoire local pour stocker le fichier
      Directory? directory = await getExternalStorageDirectory();

      // Chemin complet du fichier
      String filePath = '${directory?.path}/$fileName';

      debugPrint("directory: $directory, filePath: $filePath");

      // Utilisation de dio pour télécharger le fichier
      Dio dio = Dio();
      await dio.download(url, filePath, onReceiveProgress: (received, total) {
        if (total != -1) {
          print('Progress: ${(received / total * 100).toStringAsFixed(0)}%');
        }
      });

      // Si le téléchargement est réussi, montrez une notification
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Téléchargement de $fileName terminé')));
    } catch (e) {
      // Si une erreur se produit, montrez une notification
      debugPrint("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du téléchargement : $e')));
    }
  }

  // Future<void> _downloadFile(String url, String fileName) async {
  //   // Note: In a real app, you'd implement the actual download here.
  //   // For this example, we'll just show a snackbar.
  //   ScaffoldMessenger.of(context)
  //       .showSnackBar(SnackBar(content: Text('Downloading $fileName')));
  // }
}
