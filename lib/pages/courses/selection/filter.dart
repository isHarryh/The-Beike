import 'package:flutter/material.dart';

class FilterBodyBuilder {
  static List<Widget> buildFilterersBody(
    BuildContext context,
    Filterers filter,
    VoidCallback onChanged,
    List<String> availableCourseTypes,
    List<String> availableCourseCategories,
    double minAvailableCredits,
    double maxAvailableCredits,
    double minAvailableHours,
    double maxAvailableHours,
  ) {
    // Validate and reset filter values if they're not in the available items
    final validCourseType =
        filter.courseType != null &&
            availableCourseTypes.contains(filter.courseType)
        ? filter.courseType
        : null;
    final validCourseCategory =
        filter.courseCategory != null &&
            availableCourseCategories.contains(filter.courseCategory)
        ? filter.courseCategory
        : null;

    return [
      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: validCourseType,
        decoration: InputDecoration(
          labelText: '课程性质',
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String>(value: null, child: Text('不限')),
          ...availableCourseTypes.map(
            (type) => DropdownMenuItem<String>(
              value: type,
              child: Text(type, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (value) {
          filter.courseType = value;
          onChanged();
        },
        style: Theme.of(context).textTheme.bodyMedium,
      ),

      const SizedBox(height: 24),

      DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: validCourseCategory,
        decoration: InputDecoration(
          labelText: '课程类别',
          border: const OutlineInputBorder(),
        ),
        items: [
          const DropdownMenuItem<String>(value: null, child: Text('不限')),
          ...availableCourseCategories.map(
            (category) => DropdownMenuItem<String>(
              value: category,
              child: Text(category, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (value) {
          filter.courseCategory = value;
          onChanged();
        },
        style: Theme.of(context).textTheme.bodyMedium,
      ),

      const SizedBox(height: 24),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(
          '学分范围: ${(filter.minCredits ?? minAvailableCredits).clamp(minAvailableCredits, maxAvailableCredits).toStringAsFixed(1)} - ${(filter.maxCredits ?? maxAvailableCredits).clamp(minAvailableCredits, maxAvailableCredits).toStringAsFixed(1)}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      RangeSlider(
        values: RangeValues(
          (filter.minCredits ?? minAvailableCredits).clamp(
            minAvailableCredits,
            maxAvailableCredits,
          ),
          (filter.maxCredits ?? maxAvailableCredits).clamp(
            minAvailableCredits,
            maxAvailableCredits,
          ),
        ),
        min: minAvailableCredits,
        max: maxAvailableCredits,
        divisions: maxAvailableCredits > minAvailableCredits
            ? ((maxAvailableCredits - minAvailableCredits) * 10).toInt().clamp(
                1,
                100,
              )
            : null,
        labels: RangeLabels(
          (filter.minCredits ?? minAvailableCredits)
              .clamp(minAvailableCredits, maxAvailableCredits)
              .toStringAsFixed(1),
          (filter.maxCredits ?? maxAvailableCredits)
              .clamp(minAvailableCredits, maxAvailableCredits)
              .toStringAsFixed(1),
        ),
        onChanged: (RangeValues values) {
          filter.minCredits = values.start;
          filter.maxCredits = values.end;
          onChanged();
        },
      ),

      const SizedBox(height: 24),

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Text(
          '学时范围: ${(filter.minHours ?? minAvailableHours).clamp(minAvailableHours, maxAvailableHours).toStringAsFixed(0)} - ${(filter.maxHours ?? maxAvailableHours).clamp(minAvailableHours, maxAvailableHours).toStringAsFixed(0)}',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      RangeSlider(
        values: RangeValues(
          (filter.minHours ?? minAvailableHours).clamp(
            minAvailableHours,
            maxAvailableHours,
          ),
          (filter.maxHours ?? maxAvailableHours).clamp(
            minAvailableHours,
            maxAvailableHours,
          ),
        ),
        min: minAvailableHours,
        max: maxAvailableHours,
        divisions: maxAvailableHours > minAvailableHours
            ? ((maxAvailableHours - minAvailableHours) * 2).toInt().clamp(
                1,
                100,
              )
            : null,
        labels: RangeLabels(
          (filter.minHours ?? minAvailableHours)
              .clamp(minAvailableHours, maxAvailableHours)
              .toStringAsFixed(0),
          (filter.maxHours ?? maxAvailableHours)
              .clamp(minAvailableHours, maxAvailableHours)
              .toStringAsFixed(0),
        ),
        onChanged: (RangeValues values) {
          filter.minHours = values.start;
          filter.maxHours = values.end;
          onChanged();
        },
      ),
    ];
  }
}

class Filterers {
  String? courseType;
  String? courseCategory;
  double? minCredits;
  double? maxCredits;
  double? minHours;
  double? maxHours;

  Filterers({
    this.courseType,
    this.courseCategory,
    this.minCredits,
    this.maxCredits,
    this.minHours,
    this.maxHours,
  });

  void clear() {
    courseType = null;
    courseCategory = null;
    minCredits = null;
    maxCredits = null;
    minHours = null;
    maxHours = null;
  }

  Filterers copy() {
    return Filterers(
      courseType: courseType,
      courseCategory: courseCategory,
      minCredits: minCredits,
      maxCredits: maxCredits,
      minHours: minHours,
      maxHours: maxHours,
    );
  }
}

class FilterSidebar extends StatefulWidget {
  final Filterers filter;
  final List<String> availableCourseTypes;
  final List<String> availableCourseCategories;
  final double minAvailableCredits;
  final double maxAvailableCredits;
  final double minAvailableHours;
  final double maxAvailableHours;
  final Function(Filterers) onFilterChanged;
  final VoidCallback onReset;

  const FilterSidebar({
    super.key,
    required this.filter,
    required this.availableCourseTypes,
    required this.availableCourseCategories,
    required this.minAvailableCredits,
    required this.maxAvailableCredits,
    required this.minAvailableHours,
    required this.maxAvailableHours,
    required this.onFilterChanged,
    required this.onReset,
  });

  @override
  State<FilterSidebar> createState() => _FilterSidebarState();
}

class _FilterSidebarState extends State<FilterSidebar> {
  late Filterers _tempFilter;

  @override
  void initState() {
    super.initState();
    _tempFilter = widget.filter.copy();
  }

  @override
  void didUpdateWidget(FilterSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filter != widget.filter) {
      _tempFilter = widget.filter.copy();
    }
  }

  void _updateFilter() {
    widget.onFilterChanged(_tempFilter);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      height: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.filter_list),
                  const SizedBox(width: 8),
                  Text(
                    '高级筛选',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _tempFilter.clear();
                  });
                  widget.onReset();
                },
                icon: const Icon(Icons.clear),
                label: const Text('重置'),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: FilterBodyBuilder.buildFilterersBody(
                  context,
                  _tempFilter,
                  () {
                    setState(() {});
                    _updateFilter();
                  },
                  widget.availableCourseTypes,
                  widget.availableCourseCategories,
                  widget.minAvailableCredits,
                  widget.maxAvailableCredits,
                  widget.minAvailableHours,
                  widget.maxAvailableHours,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FilterDialog extends StatefulWidget {
  final Filterers initialFilter;
  final List<String> availableCourseTypes;
  final List<String> availableCourseCategories;
  final double minAvailableCredits;
  final double maxAvailableCredits;
  final double minAvailableHours;
  final double maxAvailableHours;
  final Function(Filterers) onApply;
  final VoidCallback onReset;

  const FilterDialog({
    super.key,
    required this.initialFilter,
    required this.availableCourseTypes,
    required this.availableCourseCategories,
    required this.minAvailableCredits,
    required this.maxAvailableCredits,
    required this.minAvailableHours,
    required this.maxAvailableHours,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<FilterDialog> createState() => _FilterDialogState();
}

class _FilterDialogState extends State<FilterDialog> {
  late Filterers tempFilter;

  @override
  void initState() {
    super.initState();
    tempFilter = widget.initialFilter.copy();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('高级筛选'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: FilterBodyBuilder.buildFilterersBody(
            context,
            tempFilter,
            () {
              setState(() {});
            },
            widget.availableCourseTypes,
            widget.availableCourseCategories,
            widget.minAvailableCredits,
            widget.maxAvailableCredits,
            widget.minAvailableHours,
            widget.maxAvailableHours,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              tempFilter.clear();
            });
            widget.onReset();
            Navigator.of(context).pop();
          },
          child: const Text('重置'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onApply(tempFilter);
            Navigator.of(context).pop();
          },
          child: const Text('应用'),
        ),
      ],
    );
  }
}
