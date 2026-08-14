import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/log_service.dart';

class LogViewerScreen extends StatefulWidget {
  const LogViewerScreen({super.key});

  @override
  State<LogViewerScreen> createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  List<LogEntry> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _loading = true;
    });
    final logs = await LogService.getLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _loading = false;
      });
    }
  }

  Future<void> _clearLogs() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('پاک کردن لاگ‌ها'),
        content: const Text('آیا مطمئن هستید که می‌خواهید تمامی لاگ‌های ثبت شده را حذف کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('لغو'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('پاک کردن'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await LogService.clearLogs();
      _loadLogs();
      _showMessage('تمامی لاگ‌ها با موفقیت پاک شدند.');
    }
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    _showMessage('$label کپی شد.');
  }

  Future<void> _copyAllLogs() async {
    if (_logs.isEmpty) {
      _showMessage('لاگی برای کپی کردن وجود ندارد.');
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('# سوران منو - لاگ‌های برنامه');
    buffer.writeln('تاریخ استخراج: ${DateTime.now().toLocal()}');
    buffer.writeln('----------------------------------------\n');

    for (final log in _logs) {
      buffer.writeln('[${log.timestamp.toLocal()}] [${log.level.name.toUpperCase()}] ${log.message}');
      if (log.error != null) {
        buffer.writeln('Error: ${log.error}');
      }
      if (log.stackTrace != null) {
        buffer.writeln('Stack Trace:\n${log.stackTrace}');
      }
      buffer.writeln('----------------------------------------');
    }

    _copyToClipboard(buffer.toString(), 'کل لاگ‌های برنامه');
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return const Color(0xFF62FF00); // accent color
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.redAccent;
    }
  }

  IconData _getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Icons.info_outline;
      case LogLevel.warning:
        return Icons.warning_amber_rounded;
      case LogLevel.error:
        return Icons.error_outline_rounded;
    }
  }

  void _showLogDetails(LogEntry log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF151515),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          maxChildSize: 0.9,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade700,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _getLevelIcon(log.level),
                        color: _getLevelColor(log.level),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'جزئیات لاگ (${log.level.name.toUpperCase()})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'کپی این لاگ',
                        icon: const Icon(Icons.copy_rounded),
                        onPressed: () {
                          final detailText = 'Message: ${log.message}\n'
                              'Time: ${log.timestamp}\n'
                              '${log.error != null ? 'Error: ${log.error}\n' : ''}'
                              '${log.stackTrace != null ? 'Stacktrace:\n${log.stackTrace}' : ''}';
                          _copyToClipboard(detailText, 'متن لاگ');
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildDetailRow('زمان ثبت:', log.timestamp.toLocal().toString()),
                      const SizedBox(height: 12),
                      _buildDetailRow('پیام لاگ:', log.message, isSelectable: true),
                      if (log.error != null) ...[
                        const SizedBox(height: 16),
                        _buildDetailRow('جزئیات خطا (Error):', log.error!, isSelectable: true, isCode: true),
                      ],
                      if (log.stackTrace != null) ...[
                        const SizedBox(height: 16),
                        _buildDetailRow('ردیابی پشته (Stack Trace):', log.stackTrace!, isSelectable: true, isCode: true),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isSelectable = false, bool isCode = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF5F6368),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isCode ? const Color(0xFF0C0C0C) : const Color(0xFF202020),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade800),
          ),
          child: isSelectable
              ? SelectableText(
                  value,
                  style: TextStyle(
                    fontFamily: isCode ? 'monospace' : null,
                    fontSize: isCode ? 13 : 14,
                    height: 1.4,
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    fontFamily: isCode ? 'monospace' : null,
                    fontSize: isCode ? 13 : 14,
                    height: 1.4,
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لاگ‌های برنامه'),
        actions: [
          if (_logs.isNotEmpty) ...[
            IconButton(
              tooltip: 'کپی کل لاگ‌ها',
              icon: const Icon(Icons.copy_all_rounded),
              onPressed: _copyAllLogs,
            ),
            IconButton(
              tooltip: 'پاک کردن کل لاگ‌ها',
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clearLogs,
            ),
          ],
          IconButton(
            tooltip: 'بارگذاری مجدد',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notes_rounded, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'لاگی برای نمایش وجود ندارد.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _logs.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final color = _getLevelColor(log.level);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      color: const Color(0xFF1E1E1E),
                      child: ListTile(
                        onTap: () => _showLogDetails(log),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _getLevelIcon(log.level),
                            color: color,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          log.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          log.timestamp.toLocal().toString().substring(11, 19),
                          style: TextStyle(color: const Color(0xFF80868B), fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              log.level.name.toUpperCase(),
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
