import 'package:flutter/material.dart';
import '/services/provider.dart';
import '/services/payment/exceptions.dart';
import '/types/payment.dart';
import '/utils/app_bar.dart';
import 'common.dart';
import 'pay_qrcode.dart';

/// Step 1 for tuition and dormitory: select fee rows (full payment only).
///
/// The fee rows are pre-fetched by the payment index page and passed in via
/// [initialRows].
class TuitionCreatePage extends StatefulWidget {
  final PayProject project;
  final List<TuitionFeeRow> initialRows;

  const TuitionCreatePage({
    super.key,
    required this.project,
    required this.initialRows,
  });

  @override
  State<TuitionCreatePage> createState() => _TuitionCreatePageState();
}

class _TuitionCreatePageState extends State<TuitionCreatePage> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  late List<TuitionFeeRow> _rows;
  final Set<String> _selectedIds = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rows = List.of(widget.initialRows);
    _selectedIds.addAll(_rows.map((r) => r.id));
  }

  List<TuitionFeeRow> get _selectedRows =>
      _rows.where((r) => _selectedIds.contains(r.id)).toList();

  int get _totalCents =>
      _selectedRows.fold(0, (sum, row) => sum + row.payableAmount);

  void _toggleRow(TuitionFeeRow row, bool? selected) {
    setState(() {
      if (selected == true) {
        _selectedIds.add(row.id);
      } else {
        _selectedIds.remove(row.id);
      }
    });
  }

  Future<void> _submit() async {
    final selected = _selectedRows;
    if (selected.isEmpty) {
      showMessage(context, '请选择要缴纳的费用项');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final order = await _serviceProvider.paymentService.createTuitionOrder(
        selected,
      );
      if (!mounted) return;
      Navigator.of(context).pop(order);
    } on PaymentPendingOrderException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final order = await resolvePendingOrderFlow(context, e);
      if (order == null || !mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PayQrcodePage(project: widget.project, order: order),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PageAppBar(title: '学费住宿费'),
      body: Column(
        children: [
          buildStepIndicator(context, 1),
          Expanded(child: _buildBody()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSubmitting || _selectedRows.isEmpty
                      ? null
                      : _submit,
                  style: FilledButton.styleFrom(
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  icon: const Icon(Icons.shopping_cart),
                  label: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('缴纳 ${formatCents(_totalCents)} 元'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_rows.isEmpty) {
      return const Center(child: Text('没有待缴纳的费用'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rows.length,
      itemBuilder: (context, index) {
        final row = _rows[index];
        final checked = _selectedIds.contains(row.id);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.receipt_long),
            title: Text(row.proName),
            subtitle: Text(
              [
                row.academicYear ?? '',
                row.proCode,
                '${formatCents(row.payableAmount)} 元',
              ].where((part) => part.isNotEmpty).join(' · '),
            ),
            trailing: Checkbox(
              value: checked,
              onChanged: (value) => _toggleRow(row, value),
            ),
            onTap: () => _toggleRow(row, !checked),
          ),
        );
      },
    );
  }
}
