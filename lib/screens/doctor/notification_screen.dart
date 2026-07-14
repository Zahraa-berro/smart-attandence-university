// notification_screen.dart
import 'package:flutter/material.dart';

// ── Shared store so notifications persist across navigation ──────────────────
class NotificationStore {
  NotificationStore._();
  static final NotificationStore instance = NotificationStore._();

  // All notifications: each has type "notification" or "assignment"
  final List<Map<String, dynamic>> all = [
    {
      "type":    "notification",
      "title":   "Midterm Exam",
      "message": "Mobile App Development exam on Monday at 10:00 AM.",
      "time":    "10 min ago",
      "icon":    Icons.school_rounded,
      "color":   const Color(0xFFD85A30),
      "course":  "Mobile Application Development",
      "section": "Tue",
    },
    {
      "type":    "assignment",
      "title":   "Assignment 1",
      "message": "Chapter 2 exercises — due next Sunday.",
      "time":    "1 hour ago",
      "icon":    Icons.assignment_rounded,
      "color":   const Color(0xFF5B8DEF),
      "course":  "Database Systems",
      "section": "Sun",
      "fileName": "assignment1.pdf",
      "hasFile":  true,
    },
    {
      "type":    "notification",
      "title":   "Lecture Reminder",
      "message": "Computer Networks lecture starts in 30 minutes.",
      "time":    "Today",
      "icon":    Icons.notifications_active_rounded,
      "color":   const Color(0xFF1D9E75),
      "course":  "Computer Networks",
      "section": "Mon",
    },
  ];
}

// ── Screen ────────────────────────────────────────────────────────────────────
class NotificationScreen extends StatefulWidget {
  final String? courseTitle;
  final String? section;

  const NotificationScreen({
    super.key,
    this.courseTitle,
    this.section,
  });

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {

  // Filter from store based on course/section scope
  List<Map<String, dynamic>> get _all {
    final data = NotificationStore.instance.all;
    if (widget.courseTitle == null) return data;
    return data
        .where((n) =>
    n["course"] == widget.courseTitle &&
        n["section"] == widget.section)
        .toList();
  }

  List<Map<String, dynamic>> get _notifications =>
      _all.where((n) => n["type"] == "notification").toList();

  bool get _isScoped => widget.courseTitle != null;

  @override
  void initState() {
    super.initState();
  }

  // ── Add Notification ───────────────────────────────────────────────────────
  void _showAddNotification() {
    final titleCtrl   = TextEditingController();
    final messageCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _sheet(
        title: "Send Notification",
        icon: Icons.notifications_active_rounded,
        iconColor: const Color(0xFF1D9E75),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isScoped) ...[
                _scopeBanner(),
                const SizedBox(height: 16),
              ],
              _label("Title"),
              const SizedBox(height: 8),
              _field(titleCtrl, "e.g. Midterm Reminder",
                  Icons.title_rounded),
              const SizedBox(height: 14),
              _label("Message"),
              const SizedBox(height: 8),
              _multiField(messageCtrl, "Write your message here..."),
              const SizedBox(height: 24),
              _actionButton(
                label: "Send Notification",
                color: const Color(0xFF1D9E75),
                icon: Icons.send_rounded,
                onTap: () {
                  if (titleCtrl.text.trim().isEmpty ||
                      messageCtrl.text.trim().isEmpty) return;
                  setState(() {
                    NotificationStore.instance.all.insert(0, {
                      "type":    "notification",
                      "title":   titleCtrl.text.trim(),
                      "message": messageCtrl.text.trim(),
                      "time":    "Now",
                      "icon":    Icons.notifications_active_rounded,
                      "color":   const Color(0xFF1D9E75),
                      "course":  widget.courseTitle ?? "General",
                      "section": widget.section ?? "",
                    });
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Edit ──────────────────────────────────────────────────────────────────
  void _editItem(Map<String, dynamic> item) {
    final titleCtrl =
    TextEditingController(text: item["title"] as String);
    final messageCtrl =
    TextEditingController(text: item["message"] as String);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _sheet(
        title: "Edit",
        icon: Icons.edit_rounded,
        iconColor: const Color(0xFF5B8DEF),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label("Title"),
            const SizedBox(height: 8),
            _field(titleCtrl, "", Icons.title_rounded),
            const SizedBox(height: 14),
            _label("Message"),
            const SizedBox(height: 8),
            _multiField(messageCtrl, ""),
            const SizedBox(height: 24),
            _actionButton(
              label: "Save Changes",
              color: const Color(0xFF5B8DEF),
              icon: Icons.save_rounded,
              onTap: () {
                setState(() {
                  item["title"]   = titleCtrl.text.trim();
                  item["message"] = messageCtrl.text.trim();
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete ────────────────────────────────────────────────────────────────
  void _deleteItem(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text("Delete?",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E))),
        content: Text(
          'Remove "${item["title"]}"?',
          style: const TextStyle(
              fontSize: 13, color: Color(0xFF5F5E5A)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel",
                style: TextStyle(color: Color(0xFF888780))),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() =>
                  NotificationStore.instance.all.remove(item));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD85A30),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text("Delete",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F7F4),
      body: Stack(
        children: [
          // Gradient header
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF5DCAA5),
                  Color(0xFF9FE1CB),
                  Color(0xFFF0997B),
                  Color(0xFFD85A30),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.35, 0.70, 1.0],
              ),
            ),
          ),
          Positioned(
            top: -40,
            right: -20,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Top bar ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: Colors.white,
                            size: 20),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Notifications",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_isScoped)
                              Text(
                                "${widget.courseTitle}  ·  ${widget.section}",
                                style: TextStyle(
                                  color:
                                  Colors.white.withOpacity(0.80),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Tab bar ────────────────────────────────────────────
                const SizedBox(height: 16),

                // ── White sheet ────────────────────────────────────────
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8F7F4),
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28)),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(
                                top: 12, bottom: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD3D1C7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _listView(
                            items: _notifications,
                            emptyText:
                                "No notifications yet.\nTap + to send one.",
                            addLabel: "Send Notification",
                            addColor: const Color(0xFF1D9E75),
                            addIcon: Icons.notifications_active_rounded,
                            onAdd: _showAddNotification,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── List view per tab ─────────────────────────────────────────────────────
  Widget _listView({
    required List<Map<String, dynamic>> items,
    required String emptyText,
    required String addLabel,
    required Color addColor,
    required IconData addIcon,
    required VoidCallback onAdd,
  }) {
    return Column(
      children: [
        // Add button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    addColor.withOpacity(0.80),
                    addColor,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: addColor.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(addIcon, color: Colors.white, size: 16),
                label: Text(
                  addLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),

        // List
        Expanded(
          child: items.isEmpty
              ? Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Text(
                emptyText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                  height: 1.6,
                ),
              ),
            ),
          )
              : ListView.builder(
            padding:
            const EdgeInsets.fromLTRB(20, 0, 20, 40),
            itemCount: items.length,
            itemBuilder: (_, i) => _itemCard(items[i]),
          ),
        ),
      ],
    );
  }

  // ── Item card ─────────────────────────────────────────────────────────────
  Widget _itemCard(Map<String, dynamic> item) {
    final color    = item["color"] as Color;
    final isAssign = item["type"] == "assignment";
    final hasFile  = item["hasFile"] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item["icon"] as IconData,
                      color: color, size: 22),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + scope chip
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item["title"] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                          ),
                          if (!_isScoped &&
                              (item["course"] as String).isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.10),
                                borderRadius:
                                BorderRadius.circular(8),
                              ),
                              child: Text(
                                item["section"] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      Text(
                        item["message"] as String,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF666666),
                          height: 1.5,
                        ),
                      ),

                      // PDF chip
                      if (isAssign && hasFile) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5B8DEF)
                                .withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  size: 13,
                                  color: Color(0xFF5B8DEF)),
                              const SizedBox(width: 5),
                              Text(
                                item["fileName"] as String? ??
                                    "attachment.pdf",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF5B8DEF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      Text(
                        item["time"] as String,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action row
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7F4),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18)),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _actionChip(
                  Icons.edit_rounded,
                  "Edit",
                  const Color(0xFF5B8DEF),
                      () => _editItem(item),
                ),
                const SizedBox(width: 12),
                _actionChip(
                  Icons.delete_outline_rounded,
                  "Delete",
                  const Color(0xFFD85A30),
                      () => _deleteItem(item),
                ),
                if (isAssign && !hasFile) ...[
                  const Spacer(),
                  _actionChip(
                    Icons.upload_file_rounded,
                    "Attach PDF",
                    const Color(0xFF5B8DEF),
                        () {
                      setState(() {
                        item["hasFile"]  = true;
                        item["fileName"] =
                        "attachment_${DateTime.now().millisecondsSinceEpoch}.pdf";
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              "📎 ${item["fileName"]} attached"),
                          backgroundColor:
                          const Color(0xFF5B8DEF),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(12)),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _scopeBanner() => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: const Color(0xFF1D9E75).withOpacity(0.08),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
          color: const Color(0xFF1D9E75).withOpacity(0.20)),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline_rounded,
            size: 16, color: Color(0xFF1D9E75)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "Sending to: ${widget.courseTitle}  ·  Section ${widget.section}",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D9E75),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _actionChip(
      IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      );

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF444441),
    ),
  );

  Widget _field(TextEditingController ctrl, String hint, IconData icon) =>
      TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 14, color: Color(0xFF2C2C2A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
          const TextStyle(color: Color(0xFFB4B2A9), fontSize: 14),
          prefixIcon:
          Icon(icon, size: 18, color: const Color(0xFF888780)),
          filled: true,
          fillColor: const Color(0xFFF1EFE8),
          contentPadding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            const BorderSide(color: Color(0xFF1D9E75), width: 1.5),
          ),
        ),
      );

  Widget _multiField(
      TextEditingController ctrl, String hint) =>
      TextField(
        controller: ctrl,
        maxLines: 4,
        style: const TextStyle(fontSize: 14, color: Color(0xFF2C2C2A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
          const TextStyle(color: Color(0xFFB4B2A9), fontSize: 14),
          filled: true,
          fillColor: const Color(0xFFF1EFE8),
          contentPadding: const EdgeInsets.all(14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            const BorderSide(color: Color(0xFF1D9E75), width: 1.5),
          ),
        ),
      );

  Widget _actionButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) =>
      SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.80), color],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.30),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ElevatedButton.icon(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: Icon(icon, color: Colors.white, size: 18),
            label: Text(
              label,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),
        ),
      );

  Widget _sheet({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) =>
      Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
            BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD3D1C7),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: iconColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E))),
                  ],
                ),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        ),
      );

  String _formatDate(DateTime d) {
    const months = [
      '',
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return "${d.day} ${months[d.month]} ${d.year}";
  }
}