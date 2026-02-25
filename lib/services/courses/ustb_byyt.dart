import 'package:dio/dio.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import '/types/courses.dart';
import '/services/base.dart';
import '/services/courses/base.dart';
import '/services/courses/exceptions.dart';
import 'convert.dart';

class _CourseSelectionSharedParams {
  final TermInfo? termInfo;
  final bool isForSubmission;
  final String? tabId;
  final String? classId;
  final String? courseId;

  const _CourseSelectionSharedParams({
    this.termInfo,
    this.isForSubmission = false,
    this.tabId,
    this.classId,
    this.courseId,
  });

  Map<String, String> toFormData() {
    final xnxq = termInfo != null
        ? '${termInfo!.year}${termInfo!.season}'
        : null;

    return {
      // Fixed
      'cxsfmt': '1',
      'p_pylx': '1',
      'mxpylx': '1',
      'p_sfgldjr': '0',
      'p_sfredis': '0',
      'p_sfsyxkgwc': '0',

      // Submit destination
      'p_xktjz': isForSubmission ? 'rwtjzyx' : '',

      // Reserved
      'p_chaxunxh': '',
      'p_gjz': '',
      'p_skjs': '',

      // Year and term
      'p_xn': termInfo?.year ?? '',
      'p_xq': termInfo?.season.toString() ?? '',
      'p_xnxq': xnxq ?? '',
      'p_dqxn': termInfo?.year ?? '',
      'p_dqxq': termInfo?.season.toString() ?? '',
      'p_dqxnxq': xnxq ?? '',

      // Course tab
      'p_xkfsdm': tabId ?? '',

      // Reserved
      'p_xiaoqu': '',
      'p_kkyx': '',
      'p_kclb': '',
      'p_xkxs': '',
      'p_dyc': '',
      'p_kkxnxq': '',

      // Class ID
      'p_id': classId ?? '',

      // Reserved
      'p_sfhlctkc': '0',
      'p_sfhllrlkc': '0',
      'p_kxsj_xqj': '',
      'p_kxsj_ksjc': '',
      'p_kxsj_jsjc': '',
      'p_kcdm_js': '',

      // Course ID
      'p_kcdm_cxrw': courseId ?? '',
      'p_kcdm_cxrw_zckc': courseId ?? '',

      // Reserved
      'p_kc_gjz': '',
      'p_xzcxtjz_nj': '',
      'p_xzcxtjz_yx': '',
      'p_xzcxtjz_zy': '',
      'p_xzcxtjz_zyfx': '',
      'p_xzcxtjz_bj': '',
      'p_sfxsgwckb': '1',
      'p_skyy': '',
      'p_sfmxzj': '',
      'p_chaxunxkfsdm': '',
    };
  }
}

class UstbByytService extends BaseCoursesService {
  late final Dio _dio;
  late final CookieJar _cookieJar;
  CourseSelectionState _selectionState = CourseSelectionState();

  UstbByytService() {
    _cookieJar = CookieJar();
    _dio = Dio(
      BaseOptions(
        baseUrl: defaultBaseUrl,
        contentType: Headers.formUrlEncodedContentType,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  @override
  String get defaultBaseUrl => 'https://byyt.ustb.edu.cn';

  @override
  set baseUrl(String url) {
    super.baseUrl = url;
    _dio.options.baseUrl = url;
  }

  @override
  Future<void> doLogin(String cookie) async {
    try {
      final uri = Uri.parse(baseUrl);
      final cookies = cookie
          .split(';')
          .map((c) {
            final parts = c.trim().split('=');
            if (parts.length >= 2) {
              return Cookie(parts[0], parts.sublist(1).join('='));
            }
            return null;
          })
          .whereType<Cookie>()
          .toList();

      await _cookieJar.saveFromResponse(uri, cookies);

      // Validate cookie by trying to get user info
      await getUserInfo();
    } catch (e) {
      await _cookieJar.deleteAll();
      if (e is CourseServiceException) rethrow;
      throw CourseServiceException(
        'Failed to login with cookie (unexpected exception)',
        e,
      );
    }
  }

  @override
  Future<void> doLogout() async {
    await _cookieJar.deleteAll();
    _selectionState = CourseSelectionState();
  }

  @override
  Future<bool> doSendHeartbeat() async {
    if (status == ServiceStatus.offline) {
      return false;
    }

    try {
      final response = await _dio.post('/component/online');

      if (response.statusCode == 200) {
        final data = response.data;

        final success = data['code'] == 0;

        if (!success) {
          setError('Heartbeat failed: ${data['msg'] ?? 'No msg'}');
        }

        return success;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  @override
  Future<UserInfo> getUserInfo() async {
    if (status == ServiceStatus.offline) {
      throw const CourseServiceOffline();
    }

    Response response;
    try {
      response = await _dio.post('/user/me');
    } catch (e) {
      throw CourseServiceNetworkError('Failed to to get user info', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, () {
      setError();
    });

    try {
      return UserInfoUstbByytExtension.parse(response.data);
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse('Failed to parse user info response', e);
    }
  }

  @override
  Future<List<CourseGradeItem>> getGrades() async {
    if (status == ServiceStatus.offline) {
      throw const CourseServiceOffline();
    }

    Response response;
    try {
      response = await _dio.post(
        '/cjgl/grcjcx/grcjcx',
        data: {
          'xn': null,
          'xq': null,
          'kcmc': null,
          'cxbj': '-1',
          'pylx': '1',
          'current': 1,
          'pageSize': 1000,
          'sffx': null,
        },
        options: Options(contentType: Headers.jsonContentType),
      );
    } catch (e) {
      throw CourseServiceNetworkError('Failed to get grades', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;

      if (data['code'] != 200) {
        throw CourseServiceBadRequest(
          'API returned error: ${data['msg'] ?? 'No msg'}',
          data['code'] as int?,
        );
      }
      if (data['content'] == null) {
        throw CourseServiceBadResponse('Response content is null');
      }
      if (data['content']['list'] == null) {
        return [];
      }

      final gradeList = data['content']['list'] as List<dynamic>;

      return gradeList
          .map(
            (item) => CourseGradeItemUstbByytExtension.parse(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse('Failed to parse grades response', e);
    }
  }

  @override
  Future<List<ExamInfo>> getExams(TermInfo termInfo) async {
    if (status == ServiceStatus.offline) {
      throw const CourseServiceOffline();
    }

    Response response;
    try {
      response = await _dio.post(
        '/kscxtj/queryXsksByxhList',
        data: {
          'ppylx': '1',
          'pkkyx': '',
          'pxn': termInfo.year,
          'pxq': termInfo.season.toString(),
          'pageNum': '1',
          'pageSize': '40',
        },
      );
    } catch (e) {
      throw CourseServiceNetworkError('Failed to get exams', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;

      if (data['code'] != null && data['code'] != 200) {
        throw CourseServiceBadRequest(
          'API returned error: ${data['msg'] ?? 'No msg'}',
          data['code'] as int?,
        );
      }
      if (data['list'] == null) {
        return [];
      }

      final examList = data['list'] as List<dynamic>;

      return examList
          .map(
            (item) =>
                ExamInfoUstbByytExtension.parse(item as Map<String, dynamic>),
          )
          .toList();
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse('Failed to parse exams response', e);
    }
  }

  @override
  Future<List<ClassItem>> getCurriculum(TermInfo termInfo) async {
    if (status == ServiceStatus.offline) {
      throw const CourseServiceOffline();
    }

    Response response;
    try {
      response = await _dio.post(
        '/Xskbcx/queryXskbcxList',
        data: {
          'bs': '2',
          'xn': termInfo.year,
          'xq': termInfo.season.toString(),
        },
      );
    } catch (e) {
      throw CourseServiceNetworkError('Failed to get curriculum', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;

      // Handle different response formats
      List<dynamic> curriculumList;

      if (data is List) {
        // Direct array response
        curriculumList = data;
      } else if (data is Map<String, dynamic>) {
        if (data['code'] != 200) {
          throw CourseServiceBadRequest(
            'API returned error: ${data['msg'] ?? 'No msg'}',
            data['code'] as int?,
          );
        }
        if (data['content'] == null) {
          throw CourseServiceBadResponse('Response content is null');
        }

        curriculumList = data['content'] as List<dynamic>? ?? [];
      } else {
        throw CourseServiceBadResponse(
          'Unexpected response format (neither List nor Map)',
        );
      }

      // Parse curriculum items
      final classList = <ClassItem>[];
      for (final item in curriculumList) {
        final classItem = ClassItemUstbByytExtension.parse(
          item as Map<String, dynamic>,
        );
        if (classItem != null) {
          classList.add(classItem);
        }
      }

      return classList;
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse('Failed to parse curriculum response', e);
    }
  }

  @override
  Future<List<ClassPeriod>> getCoursePeriods(TermInfo termInfo) async {
    if (status == ServiceStatus.offline) {
      throw const CourseServiceOffline();
    }

    Response response;
    try {
      response = await _dio.post(
        '/component/queryKbjg',
        data: {
          'xn': termInfo.year,
          'xq': termInfo.season.toString(),
          'nodataqx': '1',
        },
      );
    } catch (e) {
      throw CourseServiceNetworkError('Failed to get course periods', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;

      if (data['code'] != 200) {
        throw CourseServiceBadRequest(
          'API returned error: ${data['msg'] ?? 'No msg'}',
          data['code'] as int?,
        );
      }
      if (data['content'] == null) {
        throw CourseServiceBadResponse('Response content is null');
      }

      final periodsList = data['content'] as List<dynamic>? ?? [];

      return periodsList
          .map(
            (item) => ClassPeriodUstbByytExtension.parse(
              item as Map<String, dynamic>,
            ),
          )
          .toList();
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse(
        'Failed to parse course periods response',
        e,
      );
    }
  }

  @override
  Future<List<CalendarDay>> getCalendarDays(TermInfo termInfo) async {
    Response response;

    try {
      response = await _dio.post(
        '/Xiaoli/queryMonthList',
        data: {'xn': termInfo.year, 'xq': termInfo.season.toString()},
        options: Options(headers: {'Rolecode': '01'}),
      );
    } catch (e) {
      throw CourseServiceNetworkError(
        'Failed to send calendar days request',
        e,
      );
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;
      final List<dynamic> xlListJson = data['xlList'] as List<dynamic>;
      final List<CalendarDay> calendarDays = xlListJson
          .map(
            (item) => CalendarDayUstbByytExtension.parse(
              item as Map<String, dynamic>,
            ),
          )
          .toList();

      return calendarDays;
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse(
        'Failed to parse calendar days response',
        e,
      );
    }
  }

  @override
  Future<List<CourseInfo>> getSelectedCourses(
    TermInfo termInfo, [
    String? tab,
  ]) async {
    if (status == ServiceStatus.offline) {
      throw const CourseServiceOffline();
    }

    Response response;
    try {
      if (tab != null) {
        final params = _CourseSelectionSharedParams(
          termInfo: termInfo,
          tabId: tab,
        );
        final formData = params.toFormData();

        response = await _dio.post('/Xsxk/queryKxrw', data: formData);
      } else {
        final params = _CourseSelectionSharedParams(
          termInfo: termInfo,
          tabId: 'yixuan',
        );
        final formData = params.toFormData();

        response = await _dio.post('/Xsxk/queryYxkc', data: formData);
      }
    } catch (e) {
      throw CourseServiceNetworkError('Failed to get selected courses', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;

      // Handle different response formats
      if (data is Map<String, dynamic> && data.containsKey('code')) {
        // Response with code field
        if (data['code'] != 200) {
          throw CourseServiceBadRequest(
            'API returned error: ${data['msg'] ?? 'No msg'}',
            data['code'] as int?,
          );
        }
        if (data['content'] == null) {
          throw CourseServiceBadResponse('Response content is null');
        }
      }
      // For responses without code field, proceed directly

      List<dynamic> coursesList;
      if (tab != null) {
        // /Xsxk/queryKxrw response
        coursesList = data['yxkcList'] as List<dynamic>? ?? [];
      } else {
        // /Xsxk/queryYxkc response
        if (data.containsKey('content')) {
          coursesList = data['content'] as List<dynamic>? ?? [];
        } else {
          // Direct array response
          coursesList = data['yxkcList'] as List<dynamic>? ?? [];
        }
      }

      return coursesList
          .map(
            (item) => CourseInfoUstbByytExtension.parse(
              item as Map<String, dynamic>,
              fromTabId: tab ?? 'yixuan',
            ),
          )
          .toList();
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse(
        'Failed to parse selected courses response',
        e,
      );
    }
  }

  @override
  Future<List<CourseInfo>> getSelectableCourses(
    TermInfo termInfo,
    String tab,
  ) async {
    if (status == ServiceStatus.offline) {
      throw const CourseServiceOffline();
    }

    Response response;
    try {
      final params = _CourseSelectionSharedParams(
        termInfo: termInfo,
        tabId: tab,
      );
      final formData = params.toFormData();

      formData['pageNum'] = '1';
      formData['pageSize'] = '1000';

      response = await _dio.post('/Xsxk/queryKxrw', data: formData);
    } catch (e) {
      throw CourseServiceNetworkError('Failed to get selectable courses', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;

      final kxrwList = data['kxrwList'] as Map<String, dynamic>?;

      if (kxrwList == null) {
        throw CourseServiceBadResponse('Response kxrwList is null');
      }

      final coursesList = kxrwList['list'] as List<dynamic>? ?? [];

      return coursesList
          .map(
            (item) => CourseInfoUstbByytExtension.parse(
              item as Map<String, dynamic>,
              fromTabId: tab,
            ),
          )
          .toList();
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse(
        'Failed to parse selectable courses response',
        e,
      );
    }
  }

  @override
  Future<List<CourseTab>> getCourseTabs(TermInfo termInfo) async {
    if (status == ServiceStatus.offline) {
      throw const CourseServiceOffline();
    }

    Response response;
    try {
      final params = _CourseSelectionSharedParams(
        termInfo: termInfo,
        tabId: 'yixuan',
      );
      final formData = params.toFormData();

      response = await _dio.post('/Xsxk/queryYxkc', data: formData);
    } catch (e) {
      throw CourseServiceNetworkError('Failed to get course tabs', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;

      final tabsList = data['xkgzszList'] as List<dynamic>? ?? [];

      return tabsList
          .map(
            (item) =>
                CourseTabUstbByytExtension.parse(item as Map<String, dynamic>),
          )
          .toList();
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse('Failed to parse course tabs response', e);
    }
  }

  @override
  Future<List<TermInfo>> getTerms() async {
    if (status == ServiceStatus.offline) {
      throw const CourseServiceOffline();
    }

    Response response;
    try {
      response = await _dio.post(
        '/component/queryXnxq',
        data: {'data': 'cTnrJ54+H2bKCT5c1Gq1+w=='},
      );
    } catch (e) {
      throw CourseServiceNetworkError('Failed to get terms', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;

      if (data['code'] != 200) {
        throw CourseServiceBadRequest(
          'API returned error: ${data['msg'] ?? 'No msg'}',
          data['code'] as int?,
        );
      }
      if (data['content'] == null) {
        throw CourseServiceBadResponse('Response content is null');
      }

      final termsList = data['content'] as List<dynamic>;

      return termsList
          .map(
            (item) =>
                TermInfoUstbByytExtension.parse(item as Map<String, dynamic>),
          )
          .toList();
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse('Failed to parse terms response', e);
    }
  }

  @override
  Future<List<CourseInfo>> getCourseDetail(
    TermInfo termInfo,
    CourseInfo courseInfo,
  ) async {
    if (status == ServiceStatus.offline) {
      throw const CourseServiceOffline();
    }

    Response response;
    try {
      final params = _CourseSelectionSharedParams(
        termInfo: termInfo,
        tabId: courseInfo.fromTabId,
        courseId: courseInfo.courseId,
      );
      final formData = params.toFormData();

      formData['pageNum'] = '1';
      formData['pageSize'] = '1000';

      response = await _dio.post('/Xsxk/queryKxrw', data: formData);
    } catch (e) {
      throw CourseServiceNetworkError('Failed to get course detail', e);
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;

      final kxrwList = data['kxrwList'] as Map<String, dynamic>?;

      if (kxrwList == null) {
        throw CourseServiceBadResponse('Response kxrwList is null');
      }

      final coursesList = kxrwList['list'] as List<dynamic>? ?? [];

      // Filter
      List<CourseInfo> results = [];
      for (var courseJson in coursesList) {
        try {
          final courseDetail = CourseInfoUstbByytExtension.parse(
            courseJson as Map<String, dynamic>,
            fromTabId: courseInfo.fromTabId,
          );

          if (courseDetail.courseId == courseInfo.courseId &&
              courseDetail.classDetail != null) {
            results.add(courseDetail);
          }
        } catch (e) {
          continue;
        }
      }

      return results;
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse(
        'Failed to parse course detail response',
        e,
      );
    }
  }

  @override
  Future<bool> sendCourseSelection(
    TermInfo termInfo,
    CourseInfo courseInfo,
  ) async {
    if (status == ServiceStatus.offline) {
      throw const CourseServiceOffline();
    }

    Response response;
    try {
      final params = _CourseSelectionSharedParams(
        termInfo: termInfo,
        isForSubmission: true,
        tabId: courseInfo.fromTabId,
        classId: courseInfo.classDetail?.classId ?? '',
        courseId: courseInfo.courseId,
      );

      final formData = params.toFormData();

      formData['pageNum'] = '1';
      formData['pageSize'] = '100';

      response = await _dio.post('/Xsxk/addGouwuche', data: formData);
    } catch (e) {
      throw CourseServiceNetworkError(
        'Failed to send course selection request',
        e,
      );
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;

      if (data['jg'] != 1 && data['jg'] != '1') {
        throw CourseServiceBadRequest('${data['message'] ?? 'No msg'}');
      }
      return true;
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse(
        'Failed to parse course selection response',
        e,
      );
    }
  }

  @override
  Future<bool> sendCourseDeselection(
    TermInfo termInfo,
    CourseInfo courseInfo,
  ) async {
    if (status == ServiceStatus.offline) {
      throw const CourseServiceOffline();
    }

    Response response;
    try {
      final params = _CourseSelectionSharedParams(
        termInfo: termInfo,
        isForSubmission: true,
        tabId: courseInfo.fromTabId,
        classId: courseInfo.classDetail?.classId ?? '',
        courseId: courseInfo.courseId,
      );

      final formData = params.toFormData();

      formData['pageNum'] = '1';
      formData['pageSize'] = '100';

      response = await _dio.post('/Xsxk/tuike', data: formData);
    } catch (e) {
      throw CourseServiceNetworkError(
        'Failed to send course deselection request',
        e,
      );
    }

    CourseServiceException.raiseForStatus(response.statusCode!, setError);

    try {
      final data = response.data;

      if (data['jg'] != 1 && data['jg'] != '1') {
        throw CourseServiceBadRequest('${data['message'] ?? 'No msg'}');
      }
      return true;
    } on CourseServiceException {
      rethrow;
    } catch (e) {
      throw CourseServiceBadResponse(
        'Failed to parse course deselection response',
        e,
      );
    }
  }

  @override
  CourseSelectionState getCourseSelectionState() {
    return _selectionState;
  }

  @override
  void updateCourseSelectionState(CourseSelectionState state) {
    _selectionState = state;
  }

  @override
  void addCourseToSelection(CourseInfo course) {
    _selectionState = _selectionState.addCourse(course);
  }

  @override
  void removeCourseFromSelection(String courseId, [String? classId]) {
    _selectionState = _selectionState.removeCourse(courseId, classId);
  }

  @override
  void setSelectionTermInfo(TermInfo termInfo) {
    _selectionState = _selectionState.setTermInfo(termInfo);
  }

  @override
  void clearCourseSelection() {
    _selectionState = _selectionState.clear();
  }
}
