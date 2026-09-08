import '/types/courses.dart';

extension UserInfoUstbByytExtension on UserInfo {
  static UserInfo parse(Map<String, dynamic> data) {
    return UserInfo(
      userName: data['xm'] as String,
      userNameAlt: data['xm_en'] as String? ?? '',
      userSchool: data['bmmc'] as String? ?? '',
      userSchoolAlt: data['bmmc_en'] as String? ?? '',
      userId: data['yhdm'] as String? ?? '',
    );
  }
}

extension CourseGradeItemUstbByytExtension on CourseGradeItem {
  static CourseGradeItem parse(Map<String, dynamic> data) {
    return CourseGradeItem(
      courseId: data['kcdm'] as String? ?? '',
      courseName: data['kcmc'] as String? ?? '',
      courseNameAlt: data['kcmc_en'] as String?,
      termId: data['xnxq'] as String? ?? '',
      termName: data['xnxqmc'] as String? ?? '',
      termNameAlt: data['xnxqmcen'] as String? ?? '',
      type: data['kcxz'] as String? ?? '',
      category: data['kclb'] as String? ?? '',
      schoolName: data['yxmc'] as String?,
      schoolNameAlt: data['yxmc_en'] as String?,
      makeupStatus: data['bkcx'] as String?,
      makeupStatusAlt: data['bkcx_en'] as String?,
      examType: data['khfs'] as String?,
      hours: double.tryParse(data['xs']?.toString() ?? '0') ?? 0,
      credit: double.tryParse(data['xf']?.toString() ?? '0') ?? 0,
      score: double.tryParse(data['zpzscj']?.toString() ?? '0') ?? 0,
    );
  }
}

extension ClassItemUstbByytExtension on ClassItem {
  static ClassItem? parse(Map<String, dynamic> data) {
    try {
      final key = data['key'] as String?;
      final kbxx = data['kbxx'] as String?;
      // final kbxxEn = data['kbxx_en'] as String?; // 当前暂不支持英文版解析

      if (key == null || kbxx == null || key == 'bz') {
        // 跳过非正常课程格式或不排课课程
        return null;
      }

      // 从 key 解析 day 和 period
      final keyMatch = RegExp(r'xq(\d+)_jc(\d+)').firstMatch(key);
      if (keyMatch == null) {
        return null;
      }

      final day = int.parse(keyMatch.group(1)!);
      final period = int.parse(keyMatch.group(2)!);

      // 解析 kbxx 内容
      final lines = kbxx.split('\n');
      if (lines.length < 3) {
        return null;
      }

      String className = '';
      String teacherName = '';
      String weeksText = '';
      String locationName = '';
      String periodName = '';

      if (3 <= lines.length && lines.length <= 4) {
        className = lines[0];
        teacherName = lines[1];
        weeksText = lines[2];
      } else if (lines.length == 5) {
        className = lines[0];
        teacherName = lines[1];
        weeksText = lines[2];
        locationName = lines[3];
        periodName = lines[4];
      } else if (lines.length == 6) {
        className = "${lines[0]}\n${lines[1]}";
        teacherName = lines[2];
        weeksText = lines[3];
        locationName = lines[4];
        periodName = lines[5];
      } else {
        return null;
      }

      // 解析周次
      final weeks = parseWeeksText(weeksText);

      // 从课程名称生成颜色ID（简单哈希）
      final colorId = className.hashCode % 10;

      return ClassItem(
        day: day,
        period: period,
        weeks: weeks,
        weeksText: weeksText,
        className: className,
        classNameAlt: '',
        teacherName: teacherName,
        teacherNameAlt: '',
        locationName: locationName,
        locationNameAlt: '',
        periodName: periodName,
        periodNameAlt: '',
        colorId: colorId,
      );
    } catch (e) {
      return null;
    }
  }
}

extension ClassPeriodUstbByytExtension on ClassPeriod {
  static ClassPeriod parse(Map<String, dynamic> data) {
    return ClassPeriod(
      termYear: data['xn'] as String? ?? '',
      termSeason: int.tryParse(data['xq']?.toString() ?? '1') ?? 1,
      majorId: int.tryParse(data['dj']?.toString() ?? '1') ?? 1,
      minorId: int.tryParse(data['xj']?.toString() ?? '1') ?? 1,
      majorName: data['djms'] as String? ?? '',
      minorName: data['xjms'] as String? ?? '',
      majorStartTime: data['kskssj'] as String?,
      majorEndTime: data['ksjssj'] as String?,
      minorStartTime: data['kssj'] as String? ?? '',
      minorEndTime: data['jssj'] as String? ?? '',
    );
  }
}

extension CalendarDayUstbByytExtension on CalendarDay {
  static CalendarDay parse(Map<String, dynamic> data) {
    final dateParts = (data['RQ'] as String).split('-');
    final year = int.parse(dateParts[0]);
    final month = int.parse(dateParts[1]);
    final day = int.parse(dateParts[2]);

    int weekday = 7;
    if (data['MON'] != null) {
      weekday = 1;
    } else if (data['TUE'] != null || data['TUES'] != null) {
      weekday = 2;
    } else if (data['WED'] != null) {
      weekday = 3;
    } else if (data['THU'] != null || data['THUR'] != null) {
      weekday = 4;
    } else if (data['FRI'] != null) {
      weekday = 5;
    } else if (data['SAT'] != null) {
      weekday = 6;
    }

    final rawWeekIndex = data['ZC'] as int? ?? -1;
    final weekIndex = (rawWeekIndex >= 99 || rawWeekIndex <= 0)
        ? -1
        : rawWeekIndex;

    return CalendarDay(
      year: year,
      month: month,
      day: day,
      weekday: weekday,
      weekIndex: weekIndex,
    );
  }
}

extension TermInfoUstbByytExtension on TermInfo {
  static TermInfo parse(Map<String, dynamic> data) {
    return TermInfo(
      year: data['xn'] as String,
      season: int.parse(data['xq'].toString()),
    );
  }
}

extension CourseDetailUstbByytExtension on CourseDetail {
  static CourseDetail parse(Map<String, dynamic> data) {
    final detailHtml = data['kcxx'] as String?;
    final detailHtmlAlt = data['kcxx_en'] as String?;

    final parsedDetail = _parseDetailHtml(detailHtml);
    final parsedDetailAlt = _parseDetailHtml(detailHtmlAlt);

    return CourseDetail(
      classId: data['id'] as String? ?? '',
      extraName: data['tyxmmc'] as String?,
      extraNameAlt: data['tyxmmc_en'] as String?,
      detailHtml: detailHtml,
      detailHtmlAlt: detailHtmlAlt,
      detailTeacherId: parsedDetail['teacherId'],
      detailTeacherName: parsedDetail['teacherName'],
      detailTeacherNameAlt: parsedDetailAlt['teacherName'],
      detailSchedule: parsedDetail['schedule'] as List<String>?,
      detailScheduleAlt: parsedDetailAlt['schedule'] as List<String>?,
      detailClasses: parsedDetail['classes'],
      detailClassesAlt: parsedDetailAlt['classes'],
      detailTarget: parsedDetail['target'] as List<String>?,
      detailTargetAlt: parsedDetailAlt['target'] as List<String>?,
      detailExtra: parsedDetail['extra'],
      detailExtraAlt: parsedDetailAlt['extra'],
      selectionStatus: data['xkzt'] as String? ?? '',
      selectionStartTime: data['ktxkkssj'] as String? ?? '',
      selectionEndTime: data['ktxkjssj'] as String? ?? '',
      ugTotal: int.tryParse(data['bksrl']?.toString() ?? '0') ?? 0,
      ugReserved: int.tryParse(data['bksyxrlrs']?.toString() ?? '0') ?? 0,
      pgTotal: int.tryParse(data['yjsrl']?.toString() ?? '0') ?? 0,
      pgReserved: int.tryParse(data['yjsyxrlrs']?.toString() ?? '0') ?? 0,
      maleTotal: data['nansrl'] != null
          ? int.tryParse(data['nansrl'].toString())
          : null,
      maleReserved: data['nansyxrlrs'] != null
          ? int.tryParse(data['nansyxrlrs'].toString())
          : null,
      femaleTotal: data['nvsrl'] != null
          ? int.tryParse(data['nvsrl'].toString())
          : null,
      femaleReserved: data['nvsyxrlrs'] != null
          ? int.tryParse(data['nvsyxrlrs'].toString())
          : null,
    );
  }

  static Map<String, dynamic> _parseDetailHtml(String? html) {
    if (html == null || html.isEmpty) {
      return {
        'teacherId': null,
        'teacherName': null,
        'schedule': null,
        'classes': null,
        'target': null,
        'extra': null,
      };
    }

    String? teacherId;
    String? teacherName;
    List<String>? schedule;
    String? classes;
    List<String>? target;
    String? extra;

    try {
      // teacherId and teacherName
      if (html.contains('queryJsxx')) {
        final start = html.indexOf("queryJsxx('") + 12;
        if (start > 11) {
          final end = html.indexOf("')", start);
          if (end > start) {
            teacherId = html.substring(start, end);
          }
        }

        final nameStart = html.indexOf('>', html.indexOf('queryJsxx')) + 1;
        if (nameStart > 0) {
          final nameEnd = html.indexOf('</a>', nameStart);
          if (nameEnd > nameStart) {
            final rawName = html.substring(nameStart, nameEnd).trim();
            teacherName = _cleanHtmlContent(rawName);
          }
        }
      }

      // schedule: .ivu-tag-cyan p
      if (html.contains('ivu-tag-cyan')) {
        final cyanStart = html.indexOf('ivu-tag-cyan');
        final spanStart = html.indexOf('<span', cyanStart);
        if (spanStart > 0) {
          final spanContentStart = html.indexOf('>', spanStart) + 1;
          final spanEnd = html.indexOf('</span>', spanContentStart);
          if (spanEnd > spanContentStart) {
            final spanContent = html.substring(spanContentStart, spanEnd);
            final scheduleList = <String>[];

            int searchStart = 0;
            while (true) {
              final pStart = spanContent.indexOf('<p>', searchStart);
              if (pStart == -1) break;

              final pEnd = spanContent.indexOf('</p>', pStart);
              if (pEnd == -1) break;

              final pContent = spanContent.substring(pStart + 3, pEnd).trim();
              final cleanedContent = _cleanHtmlContent(pContent);
              if (cleanedContent != null && cleanedContent.isNotEmpty) {
                scheduleList.add(cleanedContent);
              }

              searchStart = pEnd + 4;
            }

            if (scheduleList.isNotEmpty) {
              schedule = scheduleList;
            }
          }
        }
      }

      // classes: .ivu-tag-green p
      if (html.contains('ivu-tag-green')) {
        final greenStart = html.indexOf('ivu-tag-green');
        final pStart = html.indexOf('<p', greenStart);
        if (pStart > 0) {
          final contentStart = html.indexOf('>', pStart) + 1;
          final contentEnd = html.indexOf('</p>', contentStart);
          if (contentEnd > contentStart) {
            final rawClasses = html.substring(contentStart, contentEnd).trim();
            classes = _cleanHtmlContent(rawClasses);
          }
        }
      }

      // target: .ivu-tag-orange
      final targetList = <String>[];
      int searchStart = 0;
      while (true) {
        final orangeStart = html.indexOf('ivu-tag-orange', searchStart);
        if (orangeStart == -1) break;

        final tagStart = html.lastIndexOf('<div', orangeStart);
        if (tagStart != -1) {
          final tagEnd = html.indexOf('</div>', orangeStart);
          if (tagEnd != -1) {
            final tagContent = html.substring(tagStart, tagEnd);
            final contentStart = tagContent.lastIndexOf('>') + 1;
            if (contentStart > 0) {
              final rawTarget = tagContent.substring(contentStart).trim();
              final cleanedTarget = _cleanHtmlContent(rawTarget);
              if (cleanedTarget != null && cleanedTarget.isNotEmpty) {
                targetList.add(cleanedTarget);
              }
            }
          }
        }

        searchStart = orangeStart + 14; // len of "ivu-tag-orange"
      }

      if (targetList.isNotEmpty) {
        target = targetList;
      }

      // extra: last <p> content if valid
      final lastPStart = html.lastIndexOf('<p>');
      if (lastPStart > 0) {
        final lastPEnd = html.indexOf('</p>', lastPStart);
        if (lastPEnd > lastPStart) {
          final rawText = html.substring(lastPStart + 3, lastPEnd).trim();
          if (rawText.isNotEmpty &&
              !rawText.contains('queryJsxx') &&
              !rawText.contains('上课信息') &&
              !rawText.contains('Class Information') &&
              !rawText.contains('面向对象')) {
            extra = _cleanHtmlContent(rawText);
          }
        }
      }
    } catch (e) {
      // ignored
    }

    return {
      'teacherId': teacherId,
      'teacherName': teacherName,
      'schedule': schedule,
      'classes': classes,
      'target': target,
      'extra': extra,
    };
  }

  static String? _cleanHtmlContent(String? content) {
    if (content == null || content.isEmpty) {
      return null;
    }
    String cleaned = content
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty ||
        cleaned == '&nbsp;' ||
        cleaned == ' ' ||
        RegExp(r'^[\s\u00A0]*$').hasMatch(cleaned)) {
      return null;
    }
    return cleaned;
  }
}

extension CourseInfoUstbByytExtension on CourseInfo {
  static CourseInfo parse(
    Map<String, dynamic> data, {
    String? fromTabId,
    bool isSelected = false,
  }) {
    // Check if id is present and valid
    CourseDetail? classDetail;
    if (data['id'] != null && data['id'].toString().isNotEmpty) {
      classDetail = CourseDetailUstbByytExtension.parse(data);
    }

    return CourseInfo(
      courseId: data['kcdm'] as String? ?? '',
      courseName: data['kcmc'] as String? ?? '',
      courseNameAlt: data['kcmc_en'] as String?,
      courseType: data['kcxzmc'] as String? ?? '',
      courseTypeAlt: data['kcxzmc_en'] as String?,
      courseCategory: data['kclbmc'] as String? ?? '',
      courseCategoryAlt: data['kclbmc_en'] as String?,
      districtName: data['xiaoqumc'] as String? ?? '',
      districtNameAlt: data['xiaoqumc_en'] as String?,
      schoolName: data['kkyxmc'] as String? ?? '',
      schoolNameAlt: data['kkyxmc_en'] as String?,
      termName: data['xnxqmc'] as String? ?? '',
      termNameAlt: data['xnxqmc_en'] as String?,
      teachingLanguage: data['skyymc'] as String? ?? '',
      teachingLanguageAlt: data['skyymc_en'] as String?,
      credits: double.tryParse(data['xf']?.toString() ?? '0') ?? 0.0,
      hours:
          double.tryParse(
            data['xszxs']?.toString() ?? data['xs']?.toString() ?? '0',
          ) ??
          0.0,
      classDetail: classDetail,
      fromTabId: fromTabId,
      isSelected: isSelected,
    );
  }
}

extension CourseTabUstbByytExtension on CourseTab {
  static CourseTab parse(Map<String, dynamic> data) {
    return CourseTab(
      tabId: data['xkfsdm'] as String? ?? '',
      tabName: data['xkfsmc'] as String? ?? '',
      tabNameAlt: data['xkfsmc_en'] as String?,
      selectionStartTime: data['ktxkkssj'] as String?,
      selectionEndTime: data['ktxkjssj'] as String?,
    );
  }
}

extension ExamInfoUstbByytExtension on ExamInfo {
  static ExamInfo parse(Map<String, dynamic> data) {
    // Parse KSRQ datetime string (ISO format)
    DateTime examDate = DateTime.now();
    try {
      final ksrq = data['KSRQ'] as String?;
      if (ksrq != null) {
        examDate = DateTime.parse(ksrq);
      }
    } catch (e) {
      // If parsing fails, use current datetime
    }

    return ExamInfo(
      courseId: data['KCDM'] as String? ?? '',
      examRange: data['KSSJDMC'] as String? ?? '',
      examRangeAlt: data['KSSJDMC_EN'] as String?,
      courseName: data['KCMC'] as String? ?? '',
      courseNameAlt: data['KCMC_EN'] as String?,
      termYear: data['XN'] as String? ?? '',
      termSeason: int.tryParse(data['XQ']?.toString() ?? '0') ?? 0,
      examRoom: data['CDMC'] as String? ?? '',
      examRoomAlt: data['CDMC_EN'] as String?,
      examBuilding: data['JXLMC'] as String?,
      examBuildingAlt: data['JXLMC_EN'] as String?,
      examWeek: data['DJZ'] as int,
      examDate: examDate,
      examDateDisplay: data['KSRQ2'] as String? ?? '',
      examDateDisplayAlt: data['KSRQ_EN'] as String?,
      examDayName: data['XQJMC'] as String? ?? '',
      examDayNameAlt: data['XQJMC_EN'] as String?,
      examTime: data['KSJTSJ'] as String? ?? '',
      minorId: int.tryParse(data['KSJC']?.toString() ?? '0') ?? 0,
    );
  }
}

// Schedule text parsing

/// Parses a weeks description text like "1-8,9-16" into a sorted list of
/// unique week indexes.
List<int> parseWeeksText(String weeksText) {
  final weeks = <int>[];

  // 移除"周"字符，保留数字、逗号、横线
  final cleanText = weeksText.replaceAll('周', '').trim();

  // 按逗号分割不同的周期段
  final segments = cleanText.split(',');

  for (final segment in segments) {
    final trimmedSegment = segment.trim();
    if (trimmedSegment.isEmpty) continue;

    if (trimmedSegment.contains('-')) {
      // 处理范围，如 "1-8" 或 "9-16"
      final parts = trimmedSegment.split('-');
      if (parts.length == 2) {
        final start = int.tryParse(parts[0].trim());
        final end = int.tryParse(parts[1].trim());
        if (start != null && end != null && start <= end) {
          for (int i = start; i <= end; i++) {
            weeks.add(i);
          }
        }
      }
    } else {
      // 处理单个周次，如 "1" 或 "3"
      final week = int.tryParse(trimmedSegment);
      if (week != null) {
        weeks.add(week);
      }
    }
  }

  // 去重并排序
  return weeks.toSet().toList()..sort();
}

/// The result of parsing schedule texts of a course.
class ScheduleParseResult {
  /// Parsed schedule entries, ready to be rendered as overlay classes.
  final List<ClassItem> items;

  /// Raw schedule texts that could not be parsed.
  final List<String> unparsed;

  const ScheduleParseResult(this.items, this.unparsed);
}

const _scheduleDayNames = {
  '一': 1,
  '二': 2,
  '三': 3,
  '四': 4,
  '五': 5,
  '六': 6,
  '日': 7,
  '天': 7,
};

/// Parses the schedule texts of a course (e.g. "1-8周,星期二第5-6节 教学楼109(T)")
/// into [ClassItem] entries placed on major periods, so that they can be
/// rendered on the curriculum table as overlay classes.
ScheduleParseResult parseCourseSchedule(
  CourseInfo course,
  List<ClassPeriod> referPeriods,
) {
  final detail = course.classDetail;
  final texts = detail?.detailSchedule;
  if (texts == null || texts.isEmpty) {
    return const ScheduleParseResult([], []);
  }

  // Build the minor period -> major period mapping
  final minorToMajor = <int, int>{};
  for (final period in referPeriods) {
    minorToMajor[period.minorId] = period.majorId;
  }

  final items = <ClassItem>[];
  final unparsed = <String>[];

  for (final text in texts) {
    try {
      // Weeks: leading segment like "1-8周" or "1周"
      final weeksMatch = RegExp(r'^\s*([\d,，\-–\s]+?)\s*周').firstMatch(text);
      if (weeksMatch == null) {
        unparsed.add(text);
        continue;
      }
      final weeks = parseWeeksText(weeksMatch.group(1)!);
      if (weeks.isEmpty) {
        unparsed.add(text);
        continue;
      }

      // Day: like "星期二" or "周日"
      final dayMatch = RegExp(r'星期\s*([一二三四五六日天])').firstMatch(text);
      if (dayMatch == null) {
        unparsed.add(text);
        continue;
      }
      final day = _scheduleDayNames[dayMatch.group(1)!];
      if (day == null) {
        unparsed.add(text);
        continue;
      }

      // Minor periods: like "第5-6节", "第3节" or "第5,6节"
      final periodMatch = RegExp(
        r'第\s*(\d+)\s*(?:[-–,，~]\s*(\d+))?\s*节',
      ).firstMatch(text);
      if (periodMatch == null) {
        unparsed.add(text);
        continue;
      }
      final minorStart = int.parse(periodMatch.group(1)!);
      final minorEnd = int.tryParse(periodMatch.group(2) ?? '') ?? minorStart;
      if (minorEnd < minorStart) {
        unparsed.add(text);
        continue;
      }

      // Map minor periods to major periods
      final majors = <int>{};
      for (int minor = minorStart; minor <= minorEnd; minor++) {
        final major = minorToMajor[minor];
        if (major != null) {
          majors.add(major);
        }
      }
      if (majors.isEmpty) {
        unparsed.add(text);
        continue;
      }

      // Location: text after the period segment
      final location = text
          .substring(periodMatch.end)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final locationName = location == '无地点' || location == 'No location'
          ? ''
          : location;

      for (final major in majors) {
        items.add(
          ClassItem(
            day: day,
            period: major,
            weeks: weeks,
            weeksText: weeksMatch.group(0)!,
            className: course.combinedName,
            teacherName: detail?.detailTeacherName ?? '',
            locationName: locationName,
            periodName: '第$major大节',
          ),
        );
      }
    } catch (e) {
      unparsed.add(text);
    }
  }

  return ScheduleParseResult(items, unparsed);
}
