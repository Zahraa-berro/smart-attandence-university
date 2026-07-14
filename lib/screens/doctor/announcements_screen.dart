import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AnnouncementsScreen extends StatefulWidget {
  final String courseId;
  final String classId;
  final String className;
  final String courseTitle;
  final String userId;

  const AnnouncementsScreen({
    super.key,
    required this.courseId,
    required this.classId,
    required this.className,
    required this.courseTitle,
    required this.userId,
  });

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _api_service_get();
      if (!mounted) return;
      setState(() {
        _announcements = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _api_service_get() async {
    return await _api_service_get_impl();
  }

  Future<List<Map<String, dynamic>>> _api_service_get_impl() async {
    return await _apiService.getClassAnnouncements(
      courseId: widget.courseId,
      classId: widget.classId,
    );
  }

  void _showAddAnnouncementSheet() {
    final titleCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    bool saving = false;
    String? errorText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFD3D1C7), borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Color(0xFF1D9E75), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Create Announcement', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                            Text('${widget.courseTitle} - ${widget.className}', style: const TextStyle(fontSize: 11, color: Color(0xFF888780))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Text('Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(controller: titleCtrl, decoration: InputDecoration(hintText: 'Announcement title', filled: true, fillColor: const Color(0xFFF1EFE8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), prefixIcon: const Icon(Icons.title_rounded, color: Color(0xFF888780)))),
                  const SizedBox(height: 12),
                  const Text('Message', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextField(controller: msgCtrl, maxLines: 5, decoration: InputDecoration(hintText: 'Write your message...', filled: true, fillColor: const Color(0xFFF1EFE8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
                  if (errorText != null) ...[const SizedBox(height: 12), Text('', style: TextStyle(color: Color(0xFFD85A30)))],
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final title = titleCtrl.text.trim();
                              final msg = msgCtrl.text.trim();
                              if (title.isEmpty) {
                                setLocal(() => errorText = 'Title is required.');
                                return;
                              }
                              setLocal(() => saving = true);
                              try {
                                await _apiService.createAnnouncement(
                                  userId: widget.userId,
                                  courseId: widget.courseId,
                                  classId: widget.classId,
                                  title: title,
                                  message: msg.isEmpty ? null : msg,
                                );
                                if (!mounted) return;
                                Navigator.pop(ctx);
                                await _loadAnnouncements();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement created.'), backgroundColor: Color(0xFF1D9E75)));
                              } catch (e) {
                                setLocal(() {
                                  saving = false;
                                  errorText = e.toString().replaceFirst('Exception: ', '');
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D9E75), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Create Announcement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      appBar: AppBar(
        title: Text('${widget.courseTitle} · ${widget.className}'),
        backgroundColor: const Color(0xFF5DCAA5),
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _showAddAnnouncementSheet,
                icon: const Icon(Icons.add_alert_rounded),
                label: const Text('Create Announcement'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D9E75), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Color(0xFFD85A30))))
                    : _announcements.isEmpty
                        ? const Center(child: Text('No announcements yet.'))
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: _announcements.length,
                            itemBuilder: (_, i) {
                              final a = _announcements[i];
                              final title = a['title']?.toString() ?? '';
                              final msg = a['message']?.toString() ?? '';
                              final created = a['createdAt']?.toString() ?? '';
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                    if (msg.isNotEmpty) ...[const SizedBox(height: 8), Text(msg)],
                                    if (created.isNotEmpty) ...[const SizedBox(height: 8), Text(created, style: const TextStyle(fontSize: 12, color: Color(0xFF888780)))],
                                  ]),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
