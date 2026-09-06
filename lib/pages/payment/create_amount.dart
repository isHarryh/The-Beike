import 'package:flutter/material.dart';
import '/services/provider.dart';
import '/services/payment/exceptions.dart';
import '/types/payment.dart';
import '/utils/app_bar.dart';
import 'common.dart';
import 'pay_qrcode.dart';

/// Step 1 for campus card recharge and network fee: enter an amount.
///
/// The balance is pre-fetched by the payment index page; exactly one of
/// [initialNetBalance] and [initialECardBalance] must be non-null, matching
/// the project type.
class AmountCreatePage extends StatefulWidget {
  final PayProject project;
  final NetAccBalance? initialNetBalance;
  final String? initialECardBalance;

  const AmountCreatePage({
    super.key,
    required this.project,
    required this.initialNetBalance,
    required this.initialECardBalance,
  });

  @override
  State<AmountCreatePage> createState() => _AmountCreatePageState();
}

class _AmountCreatePageState extends State<AmountCreatePage> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _afterBalanceController = TextEditingController();
  bool _isSubmitting = false;
  String _balance = '--';
  NetAccBalance? _netBalance;

  bool get _isNetCost => widget.project.proModelUrl == 'netCost';

  static const _quickAmounts = ['10', '32.5', '50', '79.9', '100', '200'];

  /// The pre-fetched balance as a plain yuan string.
  String get _balanceText =>
      _isNetCost ? (_netBalance?.balance ?? '--') : _balance;

  @override
  void initState() {
    super.initState();
    _serviceProvider.paymentService.cacheProjectId(widget.project.id);
    _netBalance = widget.initialNetBalance;
    _balance = widget.initialECardBalance ?? '--';
    _afterBalanceController.text = _balanceText;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _afterBalanceController.dispose();
    super.dispose();
  }

  /// Keeps [当前余额] + [充值金额] = [充值后余额] consistent; the field the user
  /// is editing wins and the counterpart is recomputed. `onChanged` only
  /// fires for user edits, so no re-entrancy guard is needed.
  void _onAmountChanged(String text) {
    final amount = double.tryParse(text);
    final balance = double.tryParse(_balanceText);
    _afterBalanceController.text = amount == null || balance == null
        ? ''
        : (balance + amount).toStringAsFixed(2);
  }

  void _onAfterChanged(String text) {
    final after = double.tryParse(text);
    final balance = double.tryParse(_balanceText);
    _amountController.text = after == null || balance == null
        ? ''
        : (after - balance).toStringAsFixed(2);
  }

  /// Applies a quick-pick amount; the counterpart field is synced the same
  /// way as user edits (programmatic text assignment does not fire
  /// onChanged).
  void _selectQuickAmount(String amountText) {
    _amountController.text = amountText;
    _onAmountChanged(amountText);
  }

  Future<void> _submit() async {
    final text = _amountController.text.trim();
    final amount = double.tryParse(text);
    if (amount == null || amount <= 0) {
      showMessage(context, '请输入正确的金额');
      return;
    }
    // Reject inputs with more than 2 decimal places instead of silently
    // rounding the amount the user actually asked to pay.
    final decimalIndex = text.indexOf('.');
    if (decimalIndex >= 0 && text.length - decimalIndex - 1 > 2) {
      showMessage(context, '金额最多支持两位小数');
      return;
    }
    if (amount > 1000) {
      showMessage(context, '充值金额不能大于1000元');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final service = _serviceProvider.paymentService;
      final order = _isNetCost
          ? await service.createNetOrder((amount * 100).round())
          : await service.createECardOrder(amount.toStringAsFixed(2));
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
    final theme = Theme.of(context);
    final netAbnormal = _netBalance?.isSuspended ?? false;

    return Scaffold(
      appBar: PageAppBar(title: widget.project.projectName),
      body: Column(
        children: [
          buildStepIndicator(context, 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final balanceSegment = _buildBalanceSegment(
                          theme,
                          netAbnormal,
                        );
                        final amountField = _amountField();
                        final afterField = _afterBalanceField();
                        if (constraints.maxWidth >= 560) {
                          return Row(
                            children: [
                              Expanded(child: balanceSegment),
                              _buildOperator(theme, '+'),
                              Expanded(child: amountField),
                              _buildOperator(theme, '='),
                              Expanded(child: afterField),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            balanceSegment,
                            _buildOperator(theme, '+'),
                            amountField,
                            _buildOperator(theme, '='),
                            afterField,
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('快捷选择', style: theme.textTheme.bodyMedium),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _quickAmounts
                            .map(
                              (amount) => ActionChip(
                                label: Text(amount),
                                onPressed: () => _selectQuickAmount(amount),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
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
                      : const Text('生成订单'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shared style for the balance number and both amount inputs.
  TextStyle _valueStyle(ThemeData theme) => theme.textTheme.titleLarge!
      .copyWith(fontSize: 18, color: theme.colorScheme.primary);

  Widget _buildBalanceSegment(ThemeData theme, bool netAbnormal) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: '当前余额',
        suffixText: '元',
        helperText: netAbnormal ? '账号已停机' : null,
        helperStyle: TextStyle(color: theme.colorScheme.error),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        _balanceText,
        style: _valueStyle(theme).copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildOperator(ThemeData theme, String symbol) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Center(
        child: Text(
          symbol,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _amountField() {
    final theme = Theme.of(context);
    return TextField(
      controller: _amountController,
      onChanged: _onAmountChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: _valueStyle(theme),
      decoration: InputDecoration(
        labelText: '充值金额（上限1000）',
        suffixText: '元',
        filled: true,
        fillColor: theme.colorScheme.primary.withValues(alpha: 0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _afterBalanceField() {
    final theme = Theme.of(context);
    return TextField(
      controller: _afterBalanceController,
      onChanged: _onAfterChanged,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: _valueStyle(theme),
      decoration: InputDecoration(
        labelText: '充值后余额',
        suffixText: '元',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
