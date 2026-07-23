import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class SiteProgressScreen extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final String siteId;
  final String siteName;

  const SiteProgressScreen({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
    required this.siteId,
    required this.siteName,
  });

  @override
  _SiteProgressScreenState createState() => _SiteProgressScreenState();
}

class _SiteProgressScreenState extends State<SiteProgressScreen> {
  final Color primaryColor = const Color(0xFF0b3470);
  final TextEditingController workDoneController = TextEditingController();
  final TextEditingController percentageController = TextEditingController();
  final TextEditingController issuesController = TextEditingController();
  final TextEditingController materialsController = TextEditingController();
  List<XFile> photos = [];
  List<XFile> videos = [];
  List<String> photoUrls = [];
  List<String> videoUrls = [];
  final ImagePicker picker = ImagePicker();
  bool isLoading = false;

  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        photos.add(image);
      });
    }
  }

  Future<void> takePhoto() async {
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        photos.add(image);
      });
    }
  }

  Future<void> pickVideo() async {
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        videos.add(video);
      });
    }
  }

  Future<List<String>> uploadFiles(List<XFile> files, String folder) async {
    List<String> urls = [];
    for (final file in files) {
      final ref = FirebaseStorage.instance.ref().child('$folder/${DateTime.now().millisecondsSinceEpoch}');
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  Future<void> saveProgress() async {
    if (workDoneController.text.isEmpty || percentageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill work done and percentage')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final photoUrls = await uploadFiles(photos, 'site_photos');
      final videoUrls = await uploadFiles(videos, 'site_videos');

      await FirebaseFirestore.instance.collection('site_progress').add({
        'siteId': widget.siteId,
        'siteName': widget.siteName,
        'supervisorId': widget.supervisorId,
        'supervisorName': widget.supervisorName,
        'workDone': workDoneController.text,
        'percentage': double.tryParse(percentageController.text) ?? 0,
        'issues': issuesController.text,
        'requiredMaterials': materialsController.text,
        'photos': photoUrls,
        'videos': videoUrls,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Progress saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving progress: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving progress: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Site Progress'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Site Info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.siteName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text('Supervisor: ${widget.supervisorName}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Work Done
                TextField(
                  controller: workDoneController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Today\'s Work Done',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Percentage
                TextField(
                  controller: percentageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Work Percentage',
                    border: OutlineInputBorder(),
                    suffixText: '%',
                  ),
                ),
                const SizedBox(height: 12),

                // Issues
                TextField(
                  controller: issuesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Issues Faced',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                // Required Materials
                TextField(
                  controller: materialsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Required Materials',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                // Photos Section
                const Text(
                  'Photos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: takePhoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take Photo'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: pickImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Upload Photo'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (photos.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Stack(
                            children: [
                              Image.file(
                                File(photos[index].path),
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      photos.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 20),

                // Videos Section
                const Text(
                  'Videos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: pickVideo,
                  icon: const Icon(Icons.video_library),
                  label: const Text('Upload Video'),
                ),
                const SizedBox(height: 8),
                if (videos.isNotEmpty)
                  Column(
                    children: videos.asMap().entries.map((entry) {
                      final index = entry.key;
                      final video = entry.value;
                      return ListTile(
                        leading: const Icon(Icons.video_file),
                        title: Text(video.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              videos.removeAt(index);
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 24),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: saveProgress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Save Progress',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
