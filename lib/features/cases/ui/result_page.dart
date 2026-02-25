import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../settings/data/settings_repository.dart';
import '../../../widgets/section_card.dart';
import '../../../widgets/status_chip.dart';
import '../bloc/case_bloc.dart';
import '../bloc/case_event.dart';
import '../bloc/case_state.dart';
import '../model/case_record.dart';

const _resultWarnBg = Color(0xFFFBF1DD);
const _resultWarnBorder = Color(0xFFE6CF99);
const _resultWarnText = Color(0xFF6D5218);
const _resultSoftGreen = Color(0xFFE8F1E9);
const _resultSoftGreen2 = Color(0xFFDEEADF);
const _resultUrgentBg = Color(0xFFF7E1DA);
const _resultUrgentFg = Color(0xFF8A2D1F);
const _resultMediumBg = Color(0xFFFBF1DD);
const _resultMediumFg = Color(0xFF7A5A12);
const _resultLowBg = Color(0xFFE4F0E6);
const _resultLowFg = Color(0xFF225C3A);

class ResultPage extends StatefulWidget {
  const ResultPage({super.key, required this.caseId});

  final String caseId;

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CaseBloc>().add(CaseOpenedById(widget.caseId));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prediction Result')),
      body: BlocBuilder<CaseBloc, CaseState>(
        builder: (context, state) {
          final item = state.selectedCase;
          if (item == null || item.id != widget.caseId) {
            if (!state.isLoading) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.find_in_page_outlined, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'This case is no longer available.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => context.go('/app/history'),
                        child: const Text('Go to History'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          }

          final confidence = item.confidence;
          final confidencePercent = confidence == null
              ? '--'
              : '${(confidence * 100).toStringAsFixed(1)}%';
          final methodType = _methodType(item);
          final recommendations = item.recommendations.isEmpty
              ? _defaultRecommendation(item.prediction)
              : item.recommendations;
          final imagePaths = _imagePaths(item);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: SectionCard(
                  key: ValueKey('${item.id}-${item.prediction}-${item.status}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          StatusChip(status: item.status),
                          const SizedBox(width: 8),
                          _UrgencyChip(urgency: item.urgency),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item.prediction ?? 'Prediction pending',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Confidence: $confidencePercent'),
                      const SizedBox(height: 4),
                      Text('Method: ${item.method ?? 'Pending'}'),
                      const SizedBox(height: 2),
                      Text('Input modality: $methodType'),
                      const SizedBox(height: 2),
                      Text('Workflow: ${item.workflowStatus ?? 'unspecified'}'),
                      const SizedBox(height: 12),
                      if (confidence != null)
                        LinearProgressIndicator(
                          value: confidence.clamp(0, 1),
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(999),
                        )
                      else
                        const Text('Confidence will appear after sync.'),
                      if (confidence != null && confidence < 0.70) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _resultWarnBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _resultWarnBorder),
                          ),
                          child: const Text(
                            'Low confidence. Retake a clearer photo in daylight and resubmit.',
                            style: TextStyle(color: _resultWarnText, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (imagePaths.isNotEmpty)
                SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Case Images (${imagePaths.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 120,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: imagePaths.length,
                          separatorBuilder: (_, index) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final path = imagePaths[index];
                            return SizedBox(
                              width: 140,
                              child: FutureBuilder<Uint8List>(
                                future: XFile(path).readAsBytes(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.memory(snapshot.data!, fit: BoxFit.cover),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              if (imagePaths.isNotEmpty) const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What to do next',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...recommendations.map((tip) {
                      return CheckboxListTile(
                        value: false,
                        onChanged: (_) {},
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        title: Text(tip),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explainability (Grad-CAM)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 170,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [_resultSoftGreen, _resultSoftGreen2],
                        ),
                        border: Border.all(color: const Color(0xFFD6DED5)),
                      ),
                      child: item.gradcamPath == null
                          ? const Center(
                              child: Text(
                                'No explainability map available for this case yet.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : _GradCamView(path: item.gradcamPath!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              PrimaryButtonRow(
                onViewCase: () => context.push('/app/case/${item.id}'),
                onNewCase: () => context.go('/app/new-case'),
                onSync: () => context.read<CaseBloc>().add(
                  const CasePendingSyncRequested(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<String> _imagePaths(CaseRecord item) {
    final out = <String>[];
    final seen = <String>{};
    if (item.imagePath != null && item.imagePath!.trim().isNotEmpty) {
      final p = item.imagePath!.trim();
      if (seen.add(p)) {
        out.add(p);
      }
    }
    for (final p in item.attachments) {
      final s = p.trim();
      if (s.isNotEmpty && seen.add(s)) {
        out.add(s);
      }
    }
    return out;
  }

  String _methodType(CaseRecord item) {
    final method = (item.method ?? '').toLowerCase();
    if (method.isNotEmpty && method != 'pending') {
      return method;
    }
    final hasImage = item.imagePath != null && item.imagePath!.trim().isNotEmpty;
    final symptomCount = item.symptoms.values.where((value) => value).length;
    if (hasImage && symptomCount > 0) {
      return 'hybrid';
    }
    if (hasImage) {
      return 'image';
    }
    return 'symptoms';
  }

  List<String> _defaultRecommendation(String? prediction) {
    final disease = prediction?.toLowerCase() ?? '';
    if (disease.contains('lsd')) {
      return const [
        'Isolate the affected animal immediately.',
        'Clean and disinfect shared areas.',
        'Consult a veterinarian for confirmatory diagnosis.',
      ];
    }
    if (disease.contains('fmd')) {
      return const [
        'Reduce herd movement and contact.',
        'Disinfect feed and water points.',
        'Call your vet for treatment planning.',
      ];
    }
    return const [
      'Continue daily observation.',
      'Retake photo if condition changes.',
      'Keep prevention and vaccination records updated.',
    ];
  }
}

class _GradCamView extends StatelessWidget {
  const _GradCamView({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final normalized = path.trim();
    return FutureBuilder<String>(
      future: _resolveGradcamUrl(context, normalized),
      builder: (context, snapshot) {
        final resolved = snapshot.data?.trim() ?? normalized;
        final isRemote = resolved.startsWith('http://') || resolved.startsWith('https://');
        if (!isRemote) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Grad-CAM generated on backend:\n$resolved',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.network(
            resolved,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Text(
                  'Could not load Grad-CAM image.\n$resolved',
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<String> _resolveGradcamUrl(BuildContext context, String value) async {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (!value.startsWith('/')) {
      return value;
    }
    final settings = await context.read<SettingsRepository>().load();
    final base = settings.apiBaseUrl.trim().replaceAll(RegExp(r'/$'), '');
    if (base.isEmpty) {
      return value;
    }
    return '$base$value';
  }
}

class _UrgencyChip extends StatelessWidget {
  const _UrgencyChip({required this.urgency});

  final String urgency;

  @override
  Widget build(BuildContext context) {
    Color background;
    Color foreground;
    switch (urgency.toLowerCase()) {
      case 'high':
        background = _resultUrgentBg;
        foreground = _resultUrgentFg;
        break;
      case 'medium':
        background = _resultMediumBg;
        foreground = _resultMediumFg;
        break;
      default:
        background = _resultLowBg;
        foreground = _resultLowFg;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: foreground.withValues(alpha: 0.18)),
      ),
      child: Text(
        '$urgency Urgency',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class PrimaryButtonRow extends StatelessWidget {
  const PrimaryButtonRow({
    super.key,
    required this.onViewCase,
    required this.onNewCase,
    required this.onSync,
  });

  final VoidCallback onViewCase;
  final VoidCallback onNewCase;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onViewCase,
          icon: const Icon(Icons.info_outline_rounded),
          label: const Text('View Case'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onNewCase,
          icon: const Icon(Icons.add_circle_outline_rounded),
          label: const Text('New Case'),
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: onSync,
          icon: const Icon(Icons.sync_rounded),
          label: const Text('Sync Pending'),
        ),
      ],
    );
  }
}
