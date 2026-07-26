import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'api_service.dart';

enum _ResultState { idle, loading, success, error }

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  static const Color primaryRed = Color(0xFFB3161F);
  static const Color darkRed = Color(0xFF8E1116);
  static const Color cardBorder = Color(0xFFF0DEDC);

  final _formKey = GlobalKey<FormState>();

  late final Map<String, TextEditingController> _controllers = {
    'vae': TextEditingController(),
    'pve': TextEditingController(),
    'gee': TextEditingController(),
    'rqe': TextEditingController(),
    'rle': TextEditingController(),
    'vas': TextEditingController(),
    'pvs': TextEditingController(),
    'ges': TextEditingController(),
    'rqs': TextEditingController(),
    'rls': TextEditingController(),
  };

  _ResultState _state = _ResultState.idle;
  double? _predictedValue;
  String? _errorMessage;

  static const _estimateFields = [
    _FieldSpec(
      key: 'vae',
      label: 'Voice & Accountability (VAE)',
      tooltip:
          'Estimate of civic participation, free expression, and free media (typical range: -2.5 to 2.5).',
      min: -3.0,
      max: 3.0,
    ),
    _FieldSpec(
      key: 'pve',
      label: 'Political Stability (PVE)',
      tooltip:
          'Estimate of the likelihood of political instability or politically-motivated violence (typical range: -2.5 to 2.5).',
      min: -3.0,
      max: 3.0,
    ),
    _FieldSpec(
      key: 'gee',
      label: 'Gov. Effectiveness (GEE)',
      tooltip:
          'Estimate of public service quality and policy implementation (typical range: -2.5 to 2.5).',
      min: -3.0,
      max: 3.0,
    ),
    _FieldSpec(
      key: 'rqe',
      label: 'Regulatory Quality (RQE)',
      tooltip:
          "Estimate of the government's ability to enable sound private-sector policy (typical range: -2.5 to 2.5).",
      min: -3.0,
      max: 3.0,
    ),
    _FieldSpec(
      key: 'rle',
      label: 'Rule of Law (RLE)',
      tooltip:
          'Estimate of confidence in contract enforcement, property rights, courts, and policing (typical range: -2.5 to 2.5).',
      min: -3.0,
      max: 3.0,
    ),
  ];

  static const _stdErrorFields = [
    _FieldSpec(
      key: 'vas',
      label: 'VAE - Std Error',
      tooltip:
          'Statistical margin of error for the Voice & Accountability estimate.',
      min: 0.0,
      max: 1.5,
    ),
    _FieldSpec(
      key: 'pvs',
      label: 'PVS - Std Error',
      tooltip:
          'Statistical margin of error for the Political Stability estimate.',
      min: 0.0,
      max: 1.5,
    ),
    _FieldSpec(
      key: 'ges',
      label: 'GES - Std Error',
      tooltip:
          'Statistical margin of error for the Government Effectiveness estimate.',
      min: 0.0,
      max: 1.5,
    ),
    _FieldSpec(
      key: 'rqs',
      label: 'RQS - Std Error',
      tooltip:
          'Statistical margin of error for the Regulatory Quality estimate.',
      min: 0.0,
      max: 1.5,
    ),
    _FieldSpec(
      key: 'rls',
      label: 'RLS - Std Error',
      tooltip: 'Statistical margin of error for the Rule of Law estimate.',
      min: 0.0,
      max: 1.5,
    ),
  ];

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validate(_FieldSpec spec) {
    final text = _controllers[spec.key]!.text.trim();
    if (text.isEmpty) {
      return 'Required';
    }
    final value = double.tryParse(text);
    if (value == null) {
      return 'Enter a number';
    }
    if (value < spec.min || value > spec.max) {
      return 'Out of range (${spec.min} to ${spec.max})';
    }
    return null;
  }

  Future<void> _onPredictPressed() async {
    FocusScope.of(context).unfocus();

    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      setState(() {
        _state = _ResultState.error;
        _errorMessage =
            'Some values are missing or out of range. Please check the '
            'highlighted fields and try again.';
      });
      return;
    }

    setState(() {
      _state = _ResultState.loading;
      _errorMessage = null;
      _predictedValue = null;
    });

    final features = <String, double>{
      for (final entry in _controllers.entries)
        entry.key: double.parse(entry.value.text.trim()),
    };

    try {
      final prediction = await ApiService.predictCorruption(features);
      setState(() {
        _state = _ResultState.success;
        _predictedValue = prediction;
      });
    } on PredictionException catch (e) {
      setState(() {
        _state = _ResultState.error;
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _state = _ResultState.error;
        _errorMessage = 'Something went wrong. Please try again.\n($e)';
      });
    }
  }

  void _onClearPressed() {
    FocusScope.of(context).unfocus();
    for (final c in _controllers.values) {
      c.clear();
    }
    _formKey.currentState?.reset();
    setState(() {
      _state = _ResultState.idle;
      _predictedValue = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: primaryRed,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.shield_outlined,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'GovRisk AI',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _onClearPressed,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Clear'),
            style: TextButton.styleFrom(foregroundColor: primaryRed),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildIndicatorsCard(),
                  const SizedBox(height: 20),
                  _buildResultPanel(),
                  const SizedBox(height: 20),
                  _buildMethodologyCard(),
                  const SizedBox(height: 16),
                  _buildGlobalStandardCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Corruption Risk Prediction',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'AI-Powered Governance Analytics for Comparative Institutional '
          'Quality Estimates',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildIndicatorsCard() {
    return _Card(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: primaryRed,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(Icons.grid_view_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Institutional Indicators',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: cardBorder),
            const SizedBox(height: 18),
            for (final spec in _estimateFields) ...[
              _buildFieldEntry(spec),
              const SizedBox(height: 16),
            ],
            for (final spec in _stdErrorFields) ...[
              _buildFieldEntry(spec),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: _state == _ResultState.loading
                        ? null
                        : _onPredictPressed,
                    icon: _state == _ResultState.loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.insights_rounded, size: 20),
                    label: Text(_state == _ResultState.loading
                        ? 'Predicting...'
                        : 'Predict'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    onPressed: _onClearPressed,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Clear'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldEntry(_FieldSpec spec) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              spec.label,
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: spec.tooltip,
              triggerMode: TooltipTriggerMode.tap,
              child: Icon(Icons.info_outline,
                  size: 15, color: Colors.grey.shade500),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _controllers[spec.key],
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true, signed: true),
          validator: (_) => _validate(spec),
          decoration: InputDecoration(
            hintText: 'e.g. ${spec.min < 0 ? '0.84' : '0.12'}',
          ),
        ),
      ],
    );
  }

  Widget _buildResultPanel() {
    switch (_state) {
      case _ResultState.idle:
        return _buildIdlePanel();
      case _ResultState.loading:
        return _buildLoadingPanel();
      case _ResultState.success:
        return _buildSuccessPanel();
      case _ResultState.error:
        return _buildErrorPanel();
    }
  }

  Widget _buildIdlePanel() {
    return _DashedBorderBox(
      color: primaryRed.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: primaryRed.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.bar_chart_rounded,
                  color: primaryRed.withValues(alpha: 0.7), size: 26),
            ),
            const SizedBox(height: 18),
            const Text(
              'Ready for Analysis',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              "Enter jurisdictional indicators above and click 'Predict' to "
              'generate an AI-powered corruption risk estimate.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5, color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingPanel() {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            const CircularProgressIndicator(color: primaryRed, strokeWidth: 3),
            const SizedBox(height: 18),
            Text(
              'Running the prediction model...',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessPanel() {
    final value = _predictedValue!;
    final risk = _riskLabelFor(value);
    return _Card(
      border: risk.color.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.task_alt_rounded, color: risk.color, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Prediction Result',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Text(
                  value.toStringAsFixed(3),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: risk.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Predicted CCE (Control of Corruption — Estimate)',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: risk.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(risk.icon, color: risk.color, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    risk.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: risk.color,
                      fontWeight: FontWeight.w600,
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

  Widget _buildErrorPanel() {
    return _Card(
      border: Colors.red.shade200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  color: Colors.red.shade700, size: 22),
              const SizedBox(width: 8),
              Text(
                'Prediction Error',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _errorMessage ?? 'An unknown error occurred.',
            style: TextStyle(
                fontSize: 13.5, color: Colors.grey.shade800, height: 1.4),
          ),
        ],
      ),
    );
  }

  _RiskInfo _riskLabelFor(double value) {
    if (value >= 1.0) {
      return _RiskInfo(
        'Strong Control of Corruption',
        Colors.green.shade700,
        Icons.verified_rounded,
      );
    } else if (value >= 0.0) {
      return _RiskInfo(
        'Moderate Control of Corruption',
        Colors.amber.shade800,
        Icons.info_rounded,
      );
    } else if (value >= -1.0) {
      return _RiskInfo(
        'Weak Control — Elevated Risk',
        Colors.deepOrange.shade600,
        Icons.warning_amber_rounded,
      );
    } else {
      return _RiskInfo(
        'Severe Corruption Risk',
        Colors.red.shade700,
        Icons.dangerous_rounded,
      );
    }
  }

  Widget _buildMethodologyCard() {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Predictive Methodology',
                      style: TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.info_outline,
                        size: 15, color: Colors.grey.shade500),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Our CCE estimates are produced by a regression model trained on '
                  'World Governance Indicators (WGI) data, using Voice & '
                  'Accountability, Political Stability, Government Effectiveness, '
                  'Regulatory Quality, and Rule of Law as predictors.',
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey.shade700, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalStandardCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryRed, darkRed],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(height: 14),
          const Text(
            'Global Standard',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Modeled on World Bank Worldwide Governance Indicators, aligned with '
            'international anti-corruption benchmarking standards.',
            style: TextStyle(
                fontSize: 12.5,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _FieldSpec {
  final String key;
  final String label;
  final String tooltip;
  final double min;
  final double max;

  const _FieldSpec({
    required this.key,
    required this.label,
    required this.tooltip,
    required this.min,
    required this.max,
  });
}

class _RiskInfo {
  final String description;
  final Color color;
  final IconData icon;
  _RiskInfo(this.description, this.color, this.icon);
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color? border;
  const _Card({required this.child, this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border ?? const Color(0xFFF0DEDC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _DashedBorderBox extends StatelessWidget {
  final Widget child;
  final Color color;
  const _DashedBorderBox({required this.child, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(color: color),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  _DashedRRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(16),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    const dashWidth = 6.0;
    const dashSpace = 4.0;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = math.min(distance + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color;
}
