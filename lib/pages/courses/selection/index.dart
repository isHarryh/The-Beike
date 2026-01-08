import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import '/services/provider.dart';
import '/types/courses.dart';
import '/utils/app_bar.dart';
import 'common.dart';
import 'list.dart';

class CourseSelectionPage extends StatefulWidget {
  const CourseSelectionPage({super.key});

  @override
  State<CourseSelectionPage> createState() => _CourseSelectionPageState();
}

class _CourseSelectionPageState extends State<CourseSelectionPage> {
  final ServiceProvider _serviceProvider = ServiceProvider.instance;

  List<TermInfo> _terms = [];
  TermInfo? _selectedTerm;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _serviceProvider.addListener(_onServiceStatusChanged);
    _loadTerms();
  }

  @override
  void dispose() {
    _serviceProvider.removeListener(_onServiceStatusChanged);
    super.dispose();
  }

  void _onServiceStatusChanged() {
    if (mounted && _serviceProvider.coursesService.isOnline) {
      setState(() {
        _loadTerms();
      });
    }
  }

  Future<void> _loadTerms() async {
    if (!mounted || !_serviceProvider.coursesService.isOnline) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final terms = await _serviceProvider.coursesService.getTerms();
      if (!mounted) return;

      setState(() {
        _terms = terms;
        if (terms.isNotEmpty) {
          final currentTerm = TermInfo.autoDetect();
          TermInfo? selectedTerm;
          for (final term in terms) {
            if (term.year == currentTerm.year &&
                term.season == currentTerm.season) {
              selectedTerm = term;
              break;
            }
          }
          _selectedTerm = selectedTerm ?? terms.first;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCourseTabs() async {
    if (_selectedTerm == null || !mounted) return;

    if (!_serviceProvider.coursesService.isOnline) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CourseListPage(termInfo: _selectedTerm!),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PageAppBar(title: '选课'),
      body: _buildTermSelectionView(),
    );
  }

  Widget _buildTermSelectionView() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildStepIndicator(context, 1),
          const SizedBox(height: 24),

          Text(
            '选择学期',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '请选择您要进行选课的学期',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),

          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_errorMessage != null)
            Expanded(
              child: Center(
                child: Card(
                  color: Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '加载失败',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadTerms,
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  if (!_serviceProvider.coursesService.isOnline)
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: Container(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Icon(
                                  Icons.login,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                              ),
                              onPressed: () =>
                                  context.router.pushPath('/courses/account'),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              '请先登录',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.calendar_today),
                                const SizedBox(width: 12),
                                Text(
                                  '学期选择',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<TermInfo>(
                              initialValue: _selectedTerm,
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                labelText: '选择学期',
                              ),
                              items: _terms.map((term) {
                                return DropdownMenuItem(
                                  value: term,
                                  child: Text(
                                    '${term.year}学年 第${term.season}学期',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (TermInfo? newTerm) {
                                if (mounted) {
                                  setState(() {
                                    _selectedTerm = newTerm;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_serviceProvider.coursesService.isOnline) ...[
                    const Spacer(),

                    Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: _selectedTerm != null
                            ? LinearGradient(
                                colors: [
                                  Theme.of(context).primaryColor,
                                  Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.8),
                                ],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: _selectedTerm != null
                            ? [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: ElevatedButton(
                        onPressed: _selectedTerm != null && !_isLoading
                            ? _loadCourseTabs
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.arrow_forward,
                              size: 24,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '开始选课',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (_selectedTerm == null)
                      Text(
                        '请先选择学期才能开始选课',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
