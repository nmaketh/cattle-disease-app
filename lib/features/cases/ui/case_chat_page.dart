import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_client.dart';
import '../../settings/data/settings_repository.dart';
import '../data/case_repository.dart';

class CaseChatPage extends StatefulWidget {
  const CaseChatPage({
    super.key,
    required this.caseId,
    required this.caseRepository,
    required this.settingsRepository,
    required this.initialUserRole,
  });

  final String caseId;
  final CaseRepository caseRepository;
  final SettingsRepository settingsRepository;
  final String initialUserRole;

  @override
  State<CaseChatPage> createState() => _CaseChatPageState();
}

class _CaseChatPageState extends State<CaseChatPage> {
  final _messageController = TextEditingController();
  bool _loading = false;
  bool _sending = false;
  String _userRole = 'chw';
  String _workflowStatus = 'unknown';
  String? _errorMessage;
  List<Map<String, dynamic>> _messages = const [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _userRole = widget.initialUserRole;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _load();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    super.dispose();
  }

  String _fmtTs(Object? value) {
    final s = value?.toString() ?? '';
    final dt = s.isEmpty ? null : DateTime.tryParse(s)?.toLocal();
    if (dt == null) return s;
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final settings = await widget.settingsRepository.load();
      if (!mounted) return;
      final timeline = await widget.caseRepository.getCaseTimeline(widget.caseId);
      if (!mounted) return;
      final raw = timeline['messages'];
      final parsed = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false)
          : const <Map<String, dynamic>>[];
      setState(() {
        _userRole = settings.userRole;
        _workflowStatus = timeline['workflowStatus']?.toString() ?? 'unknown';
        _messages = parsed;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to load chat timeline.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load chat timeline: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final msg = _messageController.text.trim();
    if (msg.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.caseRepository.addCaseMessage(
        caseId: widget.caseId,
        senderRole: _userRole,
        message: msg,
      );
      _messageController.clear();
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _bubble(Map<String, dynamic> item) {
    final role = (item['senderRole'] ?? 'unknown').toString();
    final msg = (item['message'] ?? '').toString();
    final mine = role.toLowerCase() == _userRole.toLowerCase();
    final ts = _fmtTs(item['createdAt']);
    final bg = mine ? const Color(0xFFDCF8E7) : Colors.white;
    final border = mine ? const Color(0xFFB7E4C7) : const Color(0xFFE5E7EB);
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(mine ? 16 : 4),
      bottomRight: Radius.circular(mine ? 4 : 16),
    );

    return Row(
      mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!mine)
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFE5E7EB),
            child: Text(
              role.isEmpty ? '?' : role[0].toUpperCase(),
              style: const TextStyle(fontSize: 11, color: Colors.black87),
            ),
          ),
        if (!mine) const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: radius,
              border: Border.all(color: border),
              boxShadow: const [
                BoxShadow(color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4B5563)),
                ),
                const SizedBox(height: 4),
                Text(msg, style: const TextStyle(height: 1.25)),
                const SizedBox(height: 6),
                Text(ts, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ),
        if (mine) const SizedBox(width: 8),
        if (mine)
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFF0F766E),
            child: Icon(Icons.person, size: 14, color: Colors.white),
          ),
      ],
    );
  }

  Widget _messagesPanel() {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              FilledButton.tonal(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(child: Text('No messages yet.'));
    }

    return ListView.separated(
      key: ValueKey('chat-${_messages.length}'),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      itemCount: _messages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _bubble(_messages[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shortId = widget.caseId.length > 8 ? widget.caseId.substring(0, 8) : widget.caseId;
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Case Chat'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF0FDF4), Color(0xFFEFF6FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Text('Secure case conversation', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                  const SizedBox(width: 8),
                  Chip(label: Text('Role: ${_userRole.toUpperCase()}')),
                  Chip(label: Text('Status: $_workflowStatus')),
                  Chip(label: Text('Case: $shortId')),
                  if (_loading) const Chip(label: Text('Refreshing...')),
                ],
              ),
            ),
            Expanded(child: _messagesPanel()),
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                color: Colors.red.shade50,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700)),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _send,
                      icon: const Icon(Icons.send_rounded),
                      label: Text(_sending ? 'Sending' : 'Send'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
