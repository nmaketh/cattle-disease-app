import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../cases/data/case_repository.dart';
import '../../cases/model/case_record.dart';
import '../../settings/bloc/settings_bloc.dart';
import '../../settings/bloc/settings_state.dart';

class VetInboxPage extends StatefulWidget {
  const VetInboxPage({super.key});

  @override
  State<VetInboxPage> createState() => _VetInboxPageState();
}

class _VetInboxPageState extends State<VetInboxPage> {
  bool _isLoading = true;
  String? _error;
  List<CaseRecord> _items = const [];
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final rows = await context.read<CaseRepository>().getVetInbox(limit: 100);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vet Inbox')),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settings) {
          if (settings.userRole != 'vet') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 48),
                    const SizedBox(height: 10),
                    const Text(
                      'Vet Inbox is available only in Vet role.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () => context.go('/app/settings'),
                      child: const Text('Open Settings'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48),
                    const SizedBox(height: 10),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (_items.isEmpty) {
            return const Center(
              child: Text('No cases currently pending vet action.'),
            );
          }
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = _items[index];
                final confidence = item.confidence == null
                    ? '-'
                    : '${(item.confidence! * 100).toStringAsFixed(1)}%';
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    onTap: () => context.push('/app/case/${item.id}'),
                    title: Text(
                      '${item.prediction ?? 'Unknown'} - ${item.animalLabel}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Confidence: $confidence\n'
                      'CHW: ${item.chwOwnerLabel}\n'
                      'Assigned Vet: ${item.assignedVetLabel}\n'
                      'Created: ${DateFormat('MMM d, h:mm a').format(item.createdAt)}',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
