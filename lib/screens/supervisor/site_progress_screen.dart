import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class SiteProgressScreen extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final String? siteId;
  final String? siteName;

  const SiteProgressScreen({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
    this.siteId,
    this.siteName,
  });

  @override
  _SiteProgressScreenState createState() => _SiteProgressScreenState();
}

class _SiteProgressScreenState extends State<SiteProgressScreen> {
  final Color primaryColor = const Color(0xFF0b3470);
  final TextEditingController workDoneController = TextEditingController();
  
  String? selectedSiteId;
  String? selectedSiteName;
  List<Map<String, dynamic>> siteDropdownItems = [];
  bool isLoadingSites = true;

  @override
  void initState() {
    super.initState();
    if (widget.siteId != null && widget.siteId!.isNotEmpty) {
      selectedSiteId = widget.siteId;
      selectedSiteName = widget.siteName;
      isLoadingSites = false;
    } else {
      _fetchSupervisorSites();
    }
  }

  Future<void> _fetchSupervisorSites() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .where('supervisor', isEqualTo: widget.supervisorName)
          .get();
          
      if (snapshot.docs.isEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('siteSupervisorMap')
            .where('Supervisor ID', isEqualTo: widget.supervisorId)
            .get();
      }
          
      final sites = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': data['siteId']?.toString() ?? '',
          'name': data['site']?.toString() ?? '',
        };
      }).where((site) => site['id'].toString().isNotEmpty).toList();
      
      setState(() {
        siteDropdownItems = sites;
        if (sites.isNotEmpty) {
          selectedSiteId = sites.first['id'].toString();
          selectedSiteName = sites.first['name'].toString();
        }
        isLoadingSites = false;
      });
    } catch (e) {
      debugPrint('Error fetching sites: $e');
      setState(() => isLoadingSites = false);
    }
  }
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

      if (selectedSiteId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a site.')));
        return;
      }
      await FirebaseFirestore.instance.collection('site_progress').add({
        'siteId': selectedSiteId,
        'siteName': selectedSiteName,
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Site',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Progress',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E2D),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType, String? suffixText}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600]),
          suffixText: suffixText,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 213, 207, 232),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView(
                        children: [
                          // Site Info
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                        if (isLoadingSites)
                          const Center(child: CircularProgressIndicator())
                        else if (siteDropdownItems.isEmpty && selectedSiteId == null)
                          const Text('No sites available. Please assign a site first.', style: TextStyle(color: Colors.red))
                        else
                          DropdownButtonFormField<String>(
                            value: selectedSiteId,
                            decoration: const InputDecoration(
                              labelText: 'Select Site',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                            items: siteDropdownItems.map((site) {
                              return DropdownMenuItem<String>(
                                value: site['id'].toString(),
                                child: Text(site['name'].toString(), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSiteId = value;
                                selectedSiteName = siteDropdownItems.firstWhere((s) => s['id'] == value)['name'].toString();
                              });
                            },
                            isExpanded: true,
                          ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(Icons.person, color: primaryColor, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Text('Supervisor: ${widget.supervisorName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          _buildTextField('Today\'s Work Done', workDoneController, maxLines: 4),
                          const SizedBox(height: 16),

                          _buildTextField('Work Percentage', percentageController, keyboardType: TextInputType.number, suffixText: '%'),
                          const SizedBox(height: 16),

                          _buildTextField('Issues Faced', issuesController, maxLines: 3),
                          const SizedBox(height: 16),

                          _buildTextField('Required Materials', materialsController, maxLines: 3),
                          const SizedBox(height: 24),

                          // Photos Section
                          const Text(
                            'Photos',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: takePhoto,
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Camera'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: primaryColor,
                                    elevation: 0,
                                    side: BorderSide(color: primaryColor.withValues(alpha: 0.2)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: pickImage,
                                  icon: const Icon(Icons.image),
                                  label: const Text('Gallery'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: primaryColor,
                                    elevation: 0,
                                    side: BorderSide(color: primaryColor.withValues(alpha: 0.2)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.file(
                                            File(photos[index].path),
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                          ),
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
                          const SizedBox(height: 24),

                          // Videos Section
                          const Text(
                            'Videos',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: pickVideo,
                              icon: const Icon(Icons.video_library),
                              label: const Text('Upload Video'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: primaryColor,
                                elevation: 0,
                                side: BorderSide(color: primaryColor.withValues(alpha: 0.2)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (videos.isNotEmpty)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: videos.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final video = entry.value;
                                  return ListTile(
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.video_file, color: Colors.indigo),
                                    ),
                                    title: Text(video.name, overflow: TextOverflow.ellipsis),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          videos.removeAt(index);
                                        });
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          const SizedBox(height: 32),

                          // Save Button
                          ElevatedButton(
                            onPressed: saveProgress,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 4,
                              shadowColor: Colors.deepPurple.withValues(alpha: 0.4),
                            ),
                            child: const Text(
                              'Save Progress',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
