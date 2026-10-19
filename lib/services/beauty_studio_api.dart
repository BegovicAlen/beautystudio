import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

final sessionExpired = ValueNotifier<int>(0);
final signInRequested = ValueNotifier<int>(0);
final referenceLabelsChanged = ValueNotifier<int>(0);

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.role,
    required this.expiresAtUtc,
    this.recoveryCode,
  });
  final String token;
  final String role;
  final DateTime expiresAtUtc;
  final String? recoveryCode;
}

class UserProfile {
  const UserProfile({
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.profileImageUrl,
    required this.notificationsEnabled,
    this.cityId,
    this.cityName,
  });
  final String firstName, lastName, username, email;
  final String? profileImageUrl, cityName;
  final int? cityId;
  final bool notificationsEnabled;
  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    firstName: j['firstName'] as String,
    lastName: j['lastName'] as String,
    username: j['username'] as String,
    email: j['email'] as String,
    profileImageUrl: j['profileImageUrl'] as String?,
    notificationsEnabled: j['notificationsEnabled'] as bool,
    cityId: j['cityId'] as int?,
    cityName: j['cityName'] as String?,
  );
}

class ContactMessageRecord {
  const ContactMessageRecord({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.message,
    required this.createdAtUtc,
  });
  final String id, fullName, email, phone, message;
  final DateTime createdAtUtc;
  factory ContactMessageRecord.fromJson(Map<String, dynamic> j) =>
      ContactMessageRecord(
        id: j['id'] as String,
        fullName: j['fullName'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String,
        message: j['message'] as String,
        createdAtUtc: DateTime.parse(j['createdAtUtc'] as String).toLocal(),
      );
}

class ReservationRecord {
  const ReservationRecord({
    required this.id,
    required this.serviceName,
    required this.startAtUtc,
    required this.endAtUtc,
    required this.paymentMethod,
    required this.status,
    this.statusDisplayName = '',
    this.cancellationReason,
    this.paymentStatus = 'Unpaid',
    this.isPaid = false,
    this.hasReview = false,
    this.totalAmount = 0,
    this.paidAmount = 0,
    this.remainingAmount = 0,
    this.currency = 'bam',
  });
  final String id, serviceName, paymentMethod, status, paymentStatus, currency;
  final String statusDisplayName;
  final String? cancellationReason;
  final DateTime startAtUtc, endAtUtc;
  final bool isPaid, hasReview;
  final num totalAmount, paidAmount, remainingAmount;
  factory ReservationRecord.fromJson(Map<String, dynamic> j) =>
      ReservationRecord(
        id: j['id'] as String,
        serviceName: j['serviceName'] as String,
        startAtUtc: DateTime.parse(j['startAtUtc'] as String).toLocal(),
        endAtUtc: DateTime.parse(j['endAtUtc'] as String).toLocal(),
        paymentMethod: j['paymentMethod'] as String,
        status: BeautyStudioApi.statusName(j['status']),
        statusDisplayName: j['statusDisplayName'] as String? ?? '',
        cancellationReason: j['cancellationReason'] as String?,
        paymentStatus: j['paymentStatus'] as String? ?? 'Unpaid',
        isPaid: j['isPaid'] as bool? ?? false,
        hasReview: j['hasReview'] as bool? ?? false,
        totalAmount: j['totalAmount'] as num? ?? 0,
        paidAmount: j['paidAmount'] as num? ?? 0,
        remainingAmount: j['remainingAmount'] as num? ?? 0,
        currency: j['currency'] as String? ?? 'bam',
      );
}

class StaffReservationRecord extends ReservationRecord {
  const StaffReservationRecord({
    required super.id,
    required super.serviceName,
    required super.startAtUtc,
    required super.endAtUtc,
    required super.paymentMethod,
    required super.status,
    super.statusDisplayName,
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required super.paymentStatus,
    this.paymentAmount,
    this.paymentCurrency,
    this.paidAtUtc,
    super.cancellationReason,
  });
  final String clientId;
  final String clientName;
  final String clientEmail;
  final num? paymentAmount;
  final String? paymentCurrency;
  final DateTime? paidAtUtc;

  factory StaffReservationRecord.fromJson(Map<String, dynamic> json) =>
      StaffReservationRecord(
        id: json['id'] as String,
        serviceName: json['serviceName'] as String,
        startAtUtc: DateTime.parse(json['startAtUtc'] as String).toLocal(),
        endAtUtc: DateTime.parse(json['endAtUtc'] as String).toLocal(),
        paymentMethod: json['paymentMethod'] as String,
        status: BeautyStudioApi.statusName(json['status']),
        statusDisplayName: json['statusDisplayName'] as String? ?? '',
        clientId: json['clientId'] as String,
        clientName: json['clientName'] as String,
        clientEmail: json['clientEmail'] as String,
        paymentStatus: json['paymentStatus'] as String,
        paymentAmount: json['paymentAmount'] as num?,
        paymentCurrency: json['paymentCurrency'] as String?,
        paidAtUtc: json['paidAtUtc'] == null
            ? null
            : DateTime.parse(json['paidAtUtc'] as String).toLocal(),
        cancellationReason: json['cancellationReason'] as String?,
      );
}

class ClientReservationHistory {
  const ClientReservationHistory({
    required this.clientId,
    required this.clientName,
    required this.clientEmail,
    required this.reservations,
  });
  final String clientId;
  final String clientName;
  final String clientEmail;
  final List<StaffReservationRecord> reservations;

  factory ClientReservationHistory.fromJson(Map<String, dynamic> json) =>
      ClientReservationHistory(
        clientId: json['clientId'] as String,
        clientName: json['clientName'] as String,
        clientEmail: json['clientEmail'] as String,
        reservations: (json['reservations'] as List)
            .map(
              (item) =>
                  StaffReservationRecord.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}

class ReservationHistoryRecord {
  const ReservationHistoryRecord({
    required this.fromStatus,
    required this.toStatus,
    required this.reason,
    required this.changedAtUtc,
    required this.changedByName,
  });
  final String? fromStatus;
  final String toStatus;
  final String reason;
  final DateTime changedAtUtc;
  final String changedByName;

  factory ReservationHistoryRecord.fromJson(Map<String, dynamic> json) =>
      ReservationHistoryRecord(
        fromStatus: json['fromStatus'] == null
            ? null
            : BeautyStudioApi.statusName(json['fromStatus']),
        toStatus: BeautyStudioApi.statusName(json['toStatus']),
        reason: json['reason'] as String,
        changedAtUtc: DateTime.parse(json['changedAtUtc'] as String).toLocal(),
        changedByName: json['changedByName'] as String,
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAtUtc,
  });
  final String id;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAtUtc;

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        message: json['message'] as String,
        isRead: json['isRead'] as bool,
        createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toLocal(),
      );
}

class ServiceReview {
  const ServiceReview({
    required this.id,
    required this.serviceId,
    required this.clientName,
    required this.rating,
    required this.comment,
    required this.createdAtUtc,
  });
  final String id;
  final int serviceId;
  final String clientName;
  final int rating;
  final String? comment;
  final DateTime createdAtUtc;

  factory ServiceReview.fromJson(Map<String, dynamic> json) => ServiceReview(
    id: json['id'] as String,
    serviceId: json['serviceId'] as int,
    clientName: json['clientName'] as String,
    rating: json['rating'] as int,
    comment: json['comment'] as String?,
    createdAtUtc: DateTime.parse(json['createdAtUtc'] as String).toLocal(),
  );
}

class ServiceReviewSummary {
  const ServiceReviewSummary({
    required this.serviceId,
    required this.serviceName,
    required this.reviewCount,
    required this.averageRating,
  });
  final int serviceId;
  final String serviceName;
  final int reviewCount;
  final double averageRating;
  factory ServiceReviewSummary.fromJson(Map<String, dynamic> json) =>
      ServiceReviewSummary(
        serviceId: json['serviceId'] as int,
        serviceName: json['serviceName'] as String,
        reviewCount: json['reviewCount'] as int,
        averageRating: (json['averageRating'] as num).toDouble(),
      );
}

class ServiceRecommendation {
  const ServiceRecommendation({
    required this.serviceId,
    required this.name,
    required this.price,
    required this.reason,
  });
  final int serviceId;
  final String name;
  final num price;
  final String reason;
  factory ServiceRecommendation.fromJson(Map<String, dynamic> json) =>
      ServiceRecommendation(
        serviceId: json['serviceId'] as int,
        name: json['name'] as String,
        price: json['price'] as num,
        reason: json['reason'] as String,
      );
}

class ContentRecommendations {
  const ContentRecommendations({
    required this.categories,
    required this.blogPosts,
  });
  final List<CategoryRecommendation> categories;
  final List<BlogRecommendation> blogPosts;
  factory ContentRecommendations.fromJson(Map<String, dynamic> json) =>
      ContentRecommendations(
        categories: (json['categories'] as List)
            .map(
              (item) =>
                  CategoryRecommendation.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
        blogPosts: (json['blogPosts'] as List)
            .map(
              (item) =>
                  BlogRecommendation.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
}

class CategoryRecommendation {
  const CategoryRecommendation({
    required this.categoryId,
    required this.name,
    required this.reason,
  });
  final int categoryId;
  final String name;
  final String reason;
  factory CategoryRecommendation.fromJson(Map<String, dynamic> json) =>
      CategoryRecommendation(
        categoryId: json['categoryId'] as int,
        name: json['name'] as String,
        reason: json['reason'] as String,
      );
}

class BlogRecommendation {
  const BlogRecommendation({
    required this.blogPostId,
    required this.title,
    required this.imageUrl,
    required this.reason,
  });
  final String blogPostId;
  final String title;
  final String? imageUrl;
  final String reason;
  factory BlogRecommendation.fromJson(Map<String, dynamic> json) =>
      BlogRecommendation(
        blogPostId: json['blogPostId'] as String,
        title: json['title'] as String,
        imageUrl: json['imageUrl'] as String?,
        reason: json['reason'] as String,
      );
}

class DashboardData {
  const DashboardData({
    required this.totalReservations,
    required this.activeReservations,
    required this.activeClients,
    required this.completedRevenue,
    required this.mostPopularService,
    required this.recentReservations,
    required this.popularServices,
  });
  final int totalReservations;
  final int activeReservations;
  final int activeClients;
  final num completedRevenue;
  final String? mostPopularService;
  final List<DashboardReservation> recentReservations;
  final List<PopularService> popularServices;
  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
    totalReservations: json['totalReservations'] as int,
    activeReservations: json['activeReservations'] as int,
    activeClients: json['activeClients'] as int,
    completedRevenue: json['completedRevenue'] as num,
    mostPopularService: json['mostPopularService'] as String?,
    recentReservations: (json['recentReservations'] as List)
        .map(
          (item) => DashboardReservation.fromJson(item as Map<String, dynamic>),
        )
        .toList(),
    popularServices: (json['popularServices'] as List)
        .map((item) => PopularService.fromJson(item as Map<String, dynamic>))
        .toList(),
  );
}

class DashboardReservation {
  const DashboardReservation({
    required this.id,
    required this.clientName,
    required this.serviceName,
    required this.startAtUtc,
    required this.status,
  });
  final String id;
  final String clientName;
  final String serviceName;
  final DateTime startAtUtc;
  final String status;
  factory DashboardReservation.fromJson(Map<String, dynamic> json) =>
      DashboardReservation(
        id: json['id'] as String,
        clientName: json['clientName'] as String,
        serviceName: json['serviceName'] as String,
        startAtUtc: DateTime.parse(json['startAtUtc'] as String).toLocal(),
        status: BeautyStudioApi.statusName(json['status']),
      );
}

class PopularService {
  const PopularService({
    required this.serviceId,
    required this.name,
    required this.reservationCount,
    required this.completedCount,
  });
  final int serviceId;
  final String name;
  final int reservationCount;
  final int completedCount;
  factory PopularService.fromJson(Map<String, dynamic> json) => PopularService(
    serviceId: json['serviceId'] as int,
    name: json['name'] as String,
    reservationCount: json['reservationCount'] as int,
    completedCount: json['completedCount'] as int,
  );
}

class ManagedBeautyService {
  const ManagedBeautyService({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMinutes,
    required this.categoryId,
    required this.categoryName,
    required this.isActive,
  });
  final int id;
  final String name;
  final String description;
  final num price;
  final int durationMinutes;
  final int categoryId;
  final String categoryName;
  final bool isActive;
  factory ManagedBeautyService.fromJson(Map<String, dynamic> json) =>
      ManagedBeautyService(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String,
        price: json['price'] as num,
        durationMinutes: json['durationMinutes'] as int,
        categoryId: json['categoryId'] as int,
        categoryName: json['categoryName'] as String,
        isActive: json['isActive'] as bool,
      );
}

class ManagedServiceCategory {
  const ManagedServiceCategory({
    required this.id,
    required this.name,
    required this.isActive,
    required this.serviceCount,
  });
  final int id;
  final String name;
  final bool isActive;
  final int serviceCount;
  factory ManagedServiceCategory.fromJson(Map<String, dynamic> json) =>
      ManagedServiceCategory(
        id: json['id'] as int,
        name: json['name'] as String,
        isActive: json['isActive'] as bool,
        serviceCount: json['serviceCount'] as int,
      );
}

class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.role,
    required this.isActive,
  });
  final String id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String role;
  final bool isActive;
  factory ManagedUser.fromJson(Map<String, dynamic> json) => ManagedUser(
    id: json['id'] as String,
    firstName: json['firstName'] as String,
    lastName: json['lastName'] as String,
    username: json['username'] as String,
    email: json['email'] as String,
    role: json['role'] as String,
    isActive: json['isActive'] as bool,
  );
}

class GalleryContentItem {
  final String description;
  const GalleryContentItem({
    this.description = '',
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.category,
    this.categoryId = 0,
  });
  final String id;
  final String title;
  final String imageUrl;
  final String category;
  final int categoryId;
  factory GalleryContentItem.fromJson(Map<String, dynamic> json) =>
      GalleryContentItem(
        description: json['description'] as String? ?? '',
        id: json['id'] as String,
        title: json['title'] as String,
        imageUrl: json['imageUrl'] as String,
        category: json['category'] as String,
        categoryId: json['categoryId'] as int? ?? 0,
      );
}

class BlogContentItem {
  const BlogContentItem({
    required this.id,
    required this.title,
    required this.content,
    required this.imageUrl,
    this.categoryId = 0,
    this.categoryName = '',
    this.publishedAtUtc,
  });
  final int categoryId;
  final String categoryName;
  final DateTime? publishedAtUtc;
  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  factory BlogContentItem.fromJson(Map<String, dynamic> json) =>
      BlogContentItem(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        imageUrl: json['imageUrl'] as String?,
        categoryId: json['categoryId'] as int? ?? 0,
        categoryName: json['categoryName'] as String? ?? '',
        publishedAtUtc: DateTime.tryParse(
          json['publishedAtUtc'] as String? ?? '',
        )?.toLocal(),
      );
}

class ManagedGalleryContentItem extends GalleryContentItem {
  const ManagedGalleryContentItem({
    super.description,
    required super.id,
    required super.title,
    required super.imageUrl,
    required super.category,
    super.categoryId,
    required this.isActive,
  });

  final bool isActive;

  factory ManagedGalleryContentItem.fromJson(Map<String, dynamic> json) =>
      ManagedGalleryContentItem(
        description: json['description'] as String? ?? '',
        id: json['id'] as String,
        title: json['title'] as String,
        imageUrl: json['imageUrl'] as String,
        category: json['category'] as String,
        categoryId: json['categoryId'] as int? ?? 0,
        isActive: json['isActive'] as bool,
      );
}

class ManagedBlogContentItem extends BlogContentItem {
  const ManagedBlogContentItem({
    required super.id,
    required super.title,
    required super.content,
    required super.imageUrl,
    super.categoryId,
    super.categoryName,
    super.publishedAtUtc,
    required this.isPublished,
  });

  final bool isPublished;

  factory ManagedBlogContentItem.fromJson(Map<String, dynamic> json) =>
      ManagedBlogContentItem(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        imageUrl: json['imageUrl'] as String?,
        isPublished: json['isPublished'] as bool,
        categoryId: json['categoryId'] as int? ?? 0,
        categoryName: json['categoryName'] as String? ?? '',
        publishedAtUtc: DateTime.tryParse(
          json['publishedAtUtc'] as String? ?? '',
        )?.toLocal(),
      );
}

class FaqEntry {
  const FaqEntry({
    required this.id,
    required this.question,
    required this.answer,
    required this.isActive,
    required this.sortOrder,
  });
  final String id;
  final String question;
  final String answer;
  final bool isActive;
  final int sortOrder;
  factory FaqEntry.fromJson(Map<String, dynamic> json) => FaqEntry(
    id: json['id'] as String,
    question: json['question'] as String,
    answer: json['answer'] as String,
    isActive: json['isActive'] as bool,
    sortOrder: json['sortOrder'] as int,
  );
}

class AboutContent {
  const AboutContent({
    required this.title,
    required this.content,
    this.imageUrl,
    this.address = '',
    this.phone = '',
    this.email = '',
    this.foundedYear = 2020,
    this.openingHour = 9,
    this.closingHour = 20,
    this.depositPercent = 100,
    this.cityId,
    this.cityName,
    this.clientCount = 0,
    this.averageRating = 0,
  });
  final String title, content, address, phone, email;
  final String? imageUrl, cityName;
  final int foundedYear, openingHour, closingHour, depositPercent, clientCount;
  final int? cityId;
  final num averageRating;
  factory AboutContent.fromJson(Map<String, dynamic> j) => AboutContent(
    title: j['title'] as String,
    content: j['content'] as String,
    imageUrl: j['imageUrl'] as String?,
    address: j['address'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    email: j['email'] as String? ?? '',
    foundedYear: j['foundedYear'] as int? ?? 2020,
    openingHour: j['openingHour'] as int? ?? 9,
    closingHour: j['closingHour'] as int? ?? 20,
    depositPercent: j['depositPercent'] as int? ?? 100,
    cityId: j['cityId'] as int?,
    cityName: j['cityName'] as String?,
    clientCount: j['clientCount'] as int? ?? 0,
    averageRating: j['averageRating'] as num? ?? 0,
  );
}

class ReferenceItem {
  const ReferenceItem({
    required this.id,
    required this.name,
    required this.isActive,
    this.code,
  });
  final int id;
  final String name;
  final bool isActive;
  final String? code;
  factory ReferenceItem.fromJson(Map<String, dynamic> j) => ReferenceItem(
    id: j['id'] as int,
    name: j['name'] as String,
    isActive: j['isActive'] as bool,
    code: j['code'] as String?,
  );
}

class PaymentCheckout {
  const PaymentCheckout(this.url);
  final String url;
  factory PaymentCheckout.fromJson(Map<String, dynamic> j) =>
      PaymentCheckout(j['url'] as String);
}

class PaymentRecord {
  const PaymentRecord({
    required this.reservationId,
    required this.clientName,
    required this.serviceName,
    required this.appointmentStartAtUtc,
    required this.status,
    required this.amount,
    required this.currency,
    required this.createdAtUtc,
    this.paidAtUtc,
    this.provider = 'Stripe',
    this.refundedAmount = 0,
    this.refundedAtUtc,
    this.receiptUrl,
    this.totalAmount = 0,
  });
  final String reservationId,
      clientName,
      serviceName,
      status,
      currency,
      provider;
  final num amount, refundedAmount, totalAmount;
  final DateTime appointmentStartAtUtc, createdAtUtc;
  final DateTime? paidAtUtc, refundedAtUtc;
  final String? receiptUrl;
  factory PaymentRecord.fromJson(Map<String, dynamic> j) => PaymentRecord(
    reservationId: j['reservationId'] as String,
    clientName: j['clientName'] as String,
    serviceName: j['serviceName'] as String,
    appointmentStartAtUtc: DateTime.parse(
      j['appointmentStartAtUtc'] as String,
    ).toLocal(),
    status: j['status'] as String,
    amount: j['amount'] as num,
    currency: j['currency'] as String,
    createdAtUtc: DateTime.parse(j['createdAtUtc'] as String).toLocal(),
    paidAtUtc: DateTime.tryParse(j['paidAtUtc'] as String? ?? '')?.toLocal(),
    provider: j['provider'] as String? ?? 'Stripe',
    refundedAmount: j['refundedAmount'] as num? ?? 0,
    refundedAtUtc: DateTime.tryParse(
      j['refundedAtUtc'] as String? ?? '',
    )?.toLocal(),
    receiptUrl: j['receiptUrl'] as String?,
    totalAmount: j['totalAmount'] as num? ?? 0,
  );
}

class BeautyStudioApi {
  /// Token shared by catalogue/content requests within the authenticated app.
  static String? sessionToken;
  static List<ReferenceItem> statusDefinitions = [];
  static Future<void> sendNotice(
    String token,
    String recipientId,
    int notificationTypeId,
    String title,
    String message,
  ) async => await _request(
    'POST',
    '/api/admin/notices',
    token: token,
    body: {
      'recipientId': recipientId,
      'notificationTypeId': notificationTypeId,
      'title': title,
      'message': message,
    },
  );
  static Map<String, String> statusLabels = {
    'Pending': 'Na čekanju',
    'Confirmed': 'Potvrđeno',
    'Cancelled': 'Otkazano',
    'Completed': 'Završeno',
  };
  static Future<void> refreshStatusLabels() async {
    try {
      final rows = await references('statuses');
      statusDefinitions = rows;
      final ordered = [...rows]..sort((a, b) => b.id.compareTo(a.id));
      statusLabels = {
        for (final x in ordered)
          if (x.code != null) x.code!: x.name,
      };
      referenceLabelsChanged.value++;
    } on ApiException catch (e) {
      debugPrint('Status metadata: ${e.message}');
    }
  }

  static Future<List<Map<String, dynamic>>> _items(
    String path, {
    String? token,
  }) async {
    final uri = Uri.parse(path);
    final result = <Map<String, dynamic>>[];
    var page = 1;
    while (true) {
      final query = {
        ...uri.queryParameters,
        'page': '$page',
        'pageSize': '100',
      };
      final body = await _request(
        'GET',
        uri.replace(queryParameters: query).toString(),
        token: token,
      );
      if (body is List) return body.cast<Map<String, dynamic>>();
      final data = body as Map<String, dynamic>;
      final rows = (data['items'] as List).cast<Map<String, dynamic>>();
      result.addAll(rows);
      if (rows.isEmpty || result.length >= (data['total'] as int)) break;
      page++;
    }
    return result;
  }

  static Future<List<Map<String, dynamic>>> serviceRows({
    String? search,
    int? categoryId,
  }) => _items(
    '/api/services?search=${Uri.encodeQueryComponent(search ?? "")}${categoryId == null ? "" : "&categoryId=$categoryId"}',
  );
  static Future<List<ReferenceItem>> references(
    String kind, {
    String? token,
    bool managed = false,
    String? search,
  }) async => (await _items(
    '/api/${managed ? "admin/" : ""}reference/$kind?search=${Uri.encodeQueryComponent(search ?? "")}',
    token: token,
  )).map(ReferenceItem.fromJson).toList();
  static Future<ReferenceItem> saveReference(
    String token,
    String kind, {
    int? id,
    required String name,
    required bool isActive,
    String? code,
  }) async => ReferenceItem.fromJson(
    await _request(
          id == null ? 'POST' : 'PUT',
          '/api/admin/reference/$kind${id == null ? "" : "/$id"}',
          token: token,
          body: {'name': name, 'isActive': isActive, 'code': code},
        )
        as Map<String, dynamic>,
  );
  static Future<void> logout(String token) async =>
      await _request('POST', '/api/auth/logout', token: token);
  static Future<String> resetPassword(
    String identifier,
    String code,
    String password,
  ) async =>
      (await _request(
                'POST',
                '/api/auth/reset-password',
                body: {
                  'usernameOrEmail': identifier,
                  'recoveryCode': code,
                  'newPassword': password,
                },
              )
              as Map<String, dynamic>)['recoveryCode']
          as String;
  static Future<String> recoveryCode(String token, String password) async =>
      (await _request(
                'POST',
                '/api/auth/recovery-code',
                token: token,
                body: {'currentPassword': password},
              )
              as Map<String, dynamic>)['recoveryCode']
          as String;
  static Future<List<PaymentRecord>> myPayments(String token) async =>
      (await _items(
        '/api/payments/mine',
        token: token,
      )).map(PaymentRecord.fromJson).toList();
  static Future<List<int>> paymentReceipt(String token, String id) =>
      _download(token, '/api/payments/reservation/$id/receipt');
  static Future<BlogContentItem> blog(String id) async =>
      BlogContentItem.fromJson(
        await _request('GET', '/api/blog-posts/$id') as Map<String, dynamic>,
      );
  static Future<ManagedBlogContentItem> managedBlog(
    String token,
    String id,
  ) async => ManagedBlogContentItem.fromJson(
    await _request('GET', '/api/admin/content/blog-posts/$id', token: token)
        as Map<String, dynamic>,
  );
  static final baseUrl = const String.fromEnvironment('API_BASE_URL').isNotEmpty
      ? const String.fromEnvironment('API_BASE_URL')
      : Platform.isAndroid
      ? 'http://10.0.2.2:5000'
      : 'http://localhost:5000';

  static String contentImageUrl(String value) =>
      value.startsWith('/') ? '$baseUrl$value' : value;

  static Future<AuthSession> login(
    String usernameOrEmail,
    String password,
  ) async {
    final json = await _request(
      'POST',
      '/api/auth/login',
      body: {'usernameOrEmail': usernameOrEmail, 'password': password},
    );
    return AuthSession(
      token: json['token'] as String,
      role: json['role'] as String,
      expiresAtUtc: DateTime.parse(json['expiresAtUtc'] as String),
      recoveryCode: json['recoveryCode'] as String?,
    );
  }

  static Future<AuthSession> register({
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    required String password,
  }) async {
    final json = await _request(
      'POST',
      '/api/auth/register',
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'username': username,
        'email': email,
        'password': password,
      },
    );
    return AuthSession(
      token: json['token'] as String,
      role: json['role'] as String,
      expiresAtUtc: DateTime.parse(json['expiresAtUtc'] as String),
      recoveryCode: json['recoveryCode'] as String?,
    );
  }

  static Future<void> sendContactMessage({
    String? token,
    required String fullName,
    required String email,
    required String phone,
    required String message,
  }) async => await _request(
    'POST',
    '/api/contact',
    token: token,
    body: {
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'message': message,
    },
  );
  static Future<List<ContactMessageRecord>> contactMessages(
    String token, {
    String? search,
  }) async => (await _items(
    '/api/contact?search=${Uri.encodeQueryComponent(search ?? "")}',
    token: token,
  )).map(ContactMessageRecord.fromJson).toList();
  static Future<List<FaqEntry>> faq() async =>
      (await _items('/api/information/faq')).map(FaqEntry.fromJson).toList();
  static Future<AboutContent> about() async => AboutContent.fromJson(
    await _request('GET', '/api/information/about') as Map<String, dynamic>,
  );
  static Future<List<FaqEntry>> managedFaq(String token) async => (await _items(
    '/api/information/admin/faq',
    token: token,
  )).map(FaqEntry.fromJson).toList();
  static Future<FaqEntry> saveFaq(
    String token, {
    FaqEntry? existing,
    required String question,
    required String answer,
    required bool isActive,
    required int sortOrder,
  }) async => FaqEntry.fromJson(
    await _request(
          existing == null ? 'POST' : 'PUT',
          existing == null
              ? '/api/information/admin/faq'
              : '/api/information/admin/faq/${existing.id}',
          token: token,
          body: {
            'question': question,
            'answer': answer,
            'isActive': isActive,
            'sortOrder': sortOrder,
          },
        )
        as Map<String, dynamic>,
  );
  static Future<AboutContent> saveAbout(
    String token,
    AboutContent value,
  ) async => AboutContent.fromJson(
    await _request(
          'PUT',
          '/api/information/admin/about',
          token: token,
          body: {
            'title': value.title,
            'content': value.content,
            'imageUrl': value.imageUrl,
            'address': value.address,
            'phone': value.phone,
            'email': value.email,
            'cityId': value.cityId,
            'foundedYear': value.foundedYear,
            'openingHour': value.openingHour,
            'closingHour': value.closingHour,
            'depositPercent': value.depositPercent,
          },
        )
        as Map<String, dynamic>,
  );
  static Future<PaymentCheckout> startCheckout(
    String token,
    String reservationId,
  ) async => PaymentCheckout.fromJson(
    await _request(
          'POST',
          '/api/payments/reservation/$reservationId/checkout',
          token: token,
          body: {'mobile': Platform.isAndroid || Platform.isIOS},
        )
        as Map<String, dynamic>,
  );
  static Future<PaymentRecord> verifyPayment(
    String token,
    String reservationId,
  ) async => PaymentRecord.fromJson(
    await _request(
          'POST',
          '/api/payments/reservation/$reservationId/verify',
          token: token,
        )
        as Map<String, dynamic>,
  );
  static Future<List<PaymentRecord>> paymentRecords(
    String token, {
    String? search,
    String? status,
    DateTime? from,
    DateTime? to,
  }) async => (await _items(
    '/api/payments?search=${Uri.encodeQueryComponent(search ?? "")}${status == null ? "" : "&status=$status"}${from == null ? "" : "&from=${_dateQuery(from)}"}${to == null ? "" : "&to=${_dateQuery(to)}"}',
    token: token,
  )).map(PaymentRecord.fromJson).toList();

  static Future<UserProfile> profile(String token) async {
    final json = await _request('GET', '/api/profile', token: token);
    return UserProfile.fromJson(json as Map<String, dynamic>);
  }

  static Future<UserProfile> updateProfile(
    String token, {
    required String firstName,
    required String lastName,
    required String email,
    String? profileImageUrl,
    required bool notificationsEnabled,
    String? currentPassword,
    String? newPassword,
    int? cityId,
  }) async {
    final json = await _request(
      'PUT',
      '/api/profile',
      token: token,
      body: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'profileImageUrl': profileImageUrl,
        'notificationsEnabled': notificationsEnabled,
        'currentPassword': currentPassword,
        'newPassword': newPassword,
        'cityId': cityId,
      },
    );
    return UserProfile.fromJson(json as Map<String, dynamic>);
  }

  static Future<ReservationRecord> createReservation(
    String token,
    int serviceId,
    DateTime startAtLocal,
    String paymentMethod,
  ) async {
    final json = await _request(
      'POST',
      '/api/reservations',
      token: token,
      body: {
        'serviceId': serviceId,
        'startAtUtc': startAtLocal.toUtc().toIso8601String(),
        'paymentMethod': paymentMethod,
      },
    );
    return ReservationRecord.fromJson(json);
  }

  static Future<List<DateTime>> availableSlots(
    String token,
    int serviceId,
    DateTime date,
  ) async {
    final value =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final json = await _request(
      'GET',
      '/api/reservations/availability?serviceId=$serviceId&date=$value',
      token: token,
    );
    return ((json as Map<String, dynamic>)['availableStartAtUtc'] as List)
        .map((item) => DateTime.parse(item as String).toLocal())
        .toList();
  }

  static Future<List<ReservationRecord>> myReservations(String token) async =>
      (await _items(
        '/api/reservations/mine',
        token: token,
      )).map(ReservationRecord.fromJson).toList();

  static Future<ReservationRecord> cancelReservation(
    String token,
    String id,
    String reason,
  ) async {
    final json = await _request(
      'POST',
      '/api/reservations/$id/cancel',
      token: token,
      body: {'status': 'Cancelled', 'reason': reason},
    );
    return ReservationRecord.fromJson(json);
  }

  static Future<List<StaffReservationRecord>> staffReservations(
    String token,
  ) async => (await _items(
    '/api/reservations',
    token: token,
  )).map(StaffReservationRecord.fromJson).toList();

  static Future<ClientReservationHistory> clientReservationHistory(
    String token,
    String clientId, {
    String? search,
  }) async {
    var page = 1;
    Map<String, dynamic>? first;
    final rows = <Map<String, dynamic>>[];
    while (true) {
      final value =
          await _request(
                'GET',
                '/api/reservations/clients/$clientId/history?page=$page&pageSize=100&search=${Uri.encodeQueryComponent(search ?? "")}',
                token: token,
              )
              as Map<String, dynamic>;
      first ??= value;
      final entries = (value['reservations'] as List)
          .cast<Map<String, dynamic>>();
      rows.addAll(entries);
      if (entries.isEmpty ||
          rows.length >= (value['total'] as int? ?? rows.length)) {
        break;
      }
      page++;
    }
    return ClientReservationHistory.fromJson({...first, 'reservations': rows});
  }

  static Future<List<ReservationHistoryRecord>> reservationHistory(
    String token,
    String id, {
    String? search,
  }) async => (await _items(
    '/api/reservations/$id/history?search=${Uri.encodeQueryComponent(search ?? "")}',
    token: token,
  )).map(ReservationHistoryRecord.fromJson).toList();

  static Future<ReservationRecord> changeReservationStatus(
    String token,
    String id,
    String status,
    String reason,
  ) async {
    final json = await _request(
      'POST',
      '/api/reservations/$id/status',
      token: token,
      body: {
        'status': status.split('|').first,
        if (status.contains('|'))
          'statusDefinitionId': int.parse(status.split('|').last),
        'reason': reason,
      },
    );
    return ReservationRecord.fromJson(json as Map<String, dynamic>);
  }

  static Future<List<AppNotification>> notifications(
    String token, {
    String? search,
    bool unreadOnly = false,
  }) async => (await _items(
    '/api/notifications?search=${Uri.encodeQueryComponent(search ?? "")}${unreadOnly ? "&active=true" : ""}',
    token: token,
  )).map(AppNotification.fromJson).toList();
  static Future<int> unreadNotificationCount(String token) async =>
      (await _request(
                'GET',
                '/api/notifications?active=true&page=1&pageSize=1',
                token: token,
              )
              as Map<String, dynamic>)['total']
          as int;

  static Future<void> markNotificationRead(String token, String id) async {
    await _request('POST', '/api/notifications/$id/read', token: token);
  }

  static Future<void> markAllNotificationsRead(String token) async {
    await _request('POST', '/api/notifications/read-all', token: token);
  }

  static Future<ServiceReview> createReview(
    String token,
    String reservationId,
    int rating,
    String? comment,
  ) async {
    final json = await _request(
      'POST',
      '/api/reviews',
      token: token,
      body: {
        'reservationId': reservationId,
        'rating': rating,
        'comment': comment,
      },
    );
    return ServiceReview.fromJson(json as Map<String, dynamic>);
  }

  static Future<List<ServiceReview>> serviceReviews(int serviceId) async =>
      (await _items(
        '/api/reviews?serviceId=$serviceId',
      )).map(ServiceReview.fromJson).toList();

  static Future<List<ServiceReviewSummary>> reviewSummary(String token) async =>
      (await _items(
        '/api/admin/reviews/summary',
        token: token,
      )).map(ServiceReviewSummary.fromJson).toList();

  static Future<List<GalleryContentItem>> gallery() async =>
      (await _items('/api/gallery')).map(GalleryContentItem.fromJson).toList();

  static Future<List<BlogContentItem>> blogPosts() async =>
      (await _items('/api/blog-posts')).map(BlogContentItem.fromJson).toList();

  static Future<List<ManagedGalleryContentItem>> managedGallery(
    String token, {
    String? search,
    int? categoryId,
  }) async => (await _items(
    '/api/admin/content/gallery?search=${Uri.encodeQueryComponent(search ?? "")}${categoryId == null ? "" : "&categoryId=$categoryId"}',
    token: token,
  )).map(ManagedGalleryContentItem.fromJson).toList();

  static Future<String> uploadContentImage(
    String token, {
    required List<int> bytes,
    required String fileName,
  }) => _uploadImage(
    token,
    bytes: bytes,
    fileName: fileName,
    endpoint: '/api/admin/content/uploads/images',
  );

  static Future<String> uploadProfileImage(
    String token, {
    required List<int> bytes,
    required String fileName,
  }) => _uploadImage(
    token,
    bytes: bytes,
    fileName: fileName,
    endpoint: '/api/profile/image',
  );

  static Future<String> _uploadImage(
    String token, {
    required List<int> bytes,
    required String fileName,
    required String endpoint,
  }) async {
    if (baseUrl.isEmpty) {
      throw const ApiException('API_BASE_URL nije konfigurisan.');
    }
    const boundary = 'beautystudio-image-boundary';
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final lowerName = safeName.toLowerCase();
    final mediaType = lowerName.endsWith('.png')
        ? 'image/png'
        : lowerName.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('$baseUrl$endpoint'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.headers.set(
        HttpHeaders.contentTypeHeader,
        'multipart/form-data; boundary=$boundary',
      );
      request.add(
        utf8.encode(
          '--$boundary\r\nContent-Disposition: form-data; name="file"; filename="$safeName"\r\nContent-Type: $mediaType\r\n\r\n',
        ),
      );
      request.add(bytes);
      request.add(utf8.encode('\r\n--$boundary--\r\n'));
      final response = await request.close();
      final text = await utf8.decodeStream(response);
      dynamic payload;
      try {
        payload = text.isEmpty ? null : jsonDecode(text);
      } on FormatException {
        payload = null;
      }
      if (response.statusCode == 401 && token.isNotEmpty) {
        sessionExpired.value++;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          payload is Map<String, dynamic> && payload['title'] is String
              ? payload['title'] as String
              : 'Upload slike nije uspio (${response.statusCode}).',
        );
      }
      if (payload is! Map<String, dynamic> || payload['imageUrl'] is! String) {
        throw const ApiException('API nije vratio putanju uploadovane slike.');
      }
      return payload['imageUrl'] as String;
    } on SocketException {
      throw const ApiException('Nije moguće povezati se s API servisom.');
    } finally {
      client.close();
    }
  }

  static Future<GalleryContentItem> createGalleryItem(
    String token, {
    required String title,
    String description = '',
    required String imageUrl,
    required int categoryId,
    required bool isActive,
  }) async {
    final json = await _request(
      'POST',
      '/api/admin/content/gallery',
      token: token,
      body: {
        'title': title,
        'imageUrl': imageUrl,
        'categoryId': categoryId,
        'isActive': isActive,
      },
    );
    return GalleryContentItem.fromJson(json as Map<String, dynamic>);
  }

  static Future<GalleryContentItem> updateGalleryItem(
    String token,
    String id, {
    required String title,
    String description = '',
    required String imageUrl,
    required int categoryId,
    required bool isActive,
  }) async {
    final json = await _request(
      'PUT',
      '/api/admin/content/gallery/$id',
      token: token,
      body: {
        'title': title,
        'imageUrl': imageUrl,
        'categoryId': categoryId,
        'isActive': isActive,
      },
    );
    return GalleryContentItem.fromJson(json as Map<String, dynamic>);
  }

  static Future<List<ManagedBlogContentItem>> managedBlogPosts(
    String token, {
    String? search,
    int? categoryId,
  }) async => (await _items(
    '/api/admin/content/blog-posts?search=${Uri.encodeQueryComponent(search ?? "")}${categoryId == null ? "" : "&categoryId=$categoryId"}',
    token: token,
  )).map(ManagedBlogContentItem.fromJson).toList();

  static Future<BlogContentItem> createBlogPost(
    String token, {
    required String title,
    required String content,
    String? imageUrl,
    required bool isPublished,
    required int categoryId,
  }) async {
    final json = await _request(
      'POST',
      '/api/admin/content/blog-posts',
      token: token,
      body: {
        'title': title,
        'content': content,
        'imageUrl': imageUrl,
        'isPublished': isPublished,
        'categoryId': categoryId,
      },
    );
    return BlogContentItem.fromJson(json as Map<String, dynamic>);
  }

  static Future<BlogContentItem> updateBlogPost(
    String token,
    String id, {
    required String title,
    required String content,
    String? imageUrl,
    required bool isPublished,
    required int categoryId,
  }) async {
    final json = await _request(
      'PUT',
      '/api/admin/content/blog-posts/$id',
      token: token,
      body: {
        'title': title,
        'content': content,
        'imageUrl': imageUrl,
        'isPublished': isPublished,
        'categoryId': categoryId,
      },
    );
    return BlogContentItem.fromJson(json as Map<String, dynamic>);
  }

  static Future<void> recordServiceView(String token, int serviceId) async {
    if (token.isEmpty) return;
    await _request(
      'POST',
      '/api/activities',
      token: token,
      body: {
        'type': 'ServiceViewed',
        'serviceId': serviceId,
        'categoryId': null,
        'blogPostId': null,
        'galleryItemId': null,
      },
    );
  }

  static Future<void> recordCategoryView(String token, int categoryId) async {
    if (token.isEmpty) return;
    await _request(
      'POST',
      '/api/activities',
      token: token,
      body: {
        'type': 'CategoryViewed',
        'serviceId': null,
        'categoryId': categoryId,
        'blogPostId': null,
        'galleryItemId': null,
      },
    );
  }

  static Future<void> recordGalleryView(
    String token,
    String galleryItemId,
  ) async {
    if (token.isEmpty) return;
    await _request(
      'POST',
      '/api/activities',
      token: token,
      body: {
        'type': 'GalleryViewed',
        'serviceId': null,
        'categoryId': null,
        'blogPostId': null,
        'galleryItemId': galleryItemId,
      },
    );
  }

  static Future<void> recordBlogView(String token, String blogPostId) async {
    if (token.isEmpty) return;
    await _request(
      'POST',
      '/api/activities',
      token: token,
      body: {
        'type': 'BlogViewed',
        'serviceId': null,
        'categoryId': null,
        'blogPostId': blogPostId,
        'galleryItemId': null,
      },
    );
  }

  static Future<List<ServiceRecommendation>> recommendations(
    String token,
  ) async {
    final json = await _request('GET', '/api/recommendations', token: token);
    return (json as List)
        .map(
          (item) =>
              ServiceRecommendation.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  static Future<ContentRecommendations> contentRecommendations(
    String token,
  ) async {
    final json = await _request(
      'GET',
      '/api/recommendations/content',
      token: token,
    );
    return ContentRecommendations.fromJson(json as Map<String, dynamic>);
  }

  static Future<DashboardData> dashboard(String token) async {
    final json = await _request('GET', '/api/dashboard', token: token);
    return DashboardData.fromJson(json as Map<String, dynamic>);
  }

  static Future<List<ManagedBeautyService>> managedServices(
    String token, {
    String? search,
    int? categoryId,
  }) async => (await _items(
    '/api/admin/services?search=${Uri.encodeQueryComponent(search ?? "")}${categoryId == null ? "" : "&categoryId=$categoryId"}',
    token: token,
  )).map(ManagedBeautyService.fromJson).toList();

  static Future<List<ManagedServiceCategory>> managedCategories(
    String token,
  ) async => (await _items(
    '/api/admin/categories',
    token: token,
  )).map(ManagedServiceCategory.fromJson).toList();

  static Future<ManagedBeautyService> saveService(
    String token, {
    ManagedBeautyService? existing,
    required String name,
    required String description,
    required num price,
    required int durationMinutes,
    required int categoryId,
    required bool isActive,
  }) async => ManagedBeautyService.fromJson(
    await _request(
          existing == null ? 'POST' : 'PUT',
          existing == null
              ? '/api/admin/services'
              : '/api/admin/services/${existing.id}',
          token: token,
          body: {
            'name': name,
            'description': description,
            'price': price,
            'durationMinutes': durationMinutes,
            'categoryId': categoryId,
            'isActive': isActive,
          },
        )
        as Map<String, dynamic>,
  );

  static Future<ManagedServiceCategory> saveCategory(
    String token, {
    ManagedServiceCategory? existing,
    required String name,
    required bool isActive,
  }) async => ManagedServiceCategory.fromJson(
    await _request(
          existing == null ? 'POST' : 'PUT',
          existing == null
              ? '/api/admin/categories'
              : '/api/admin/categories/${existing.id}',
          token: token,
          body: {'name': name, 'isActive': isActive},
        )
        as Map<String, dynamic>,
  );

  static Future<List<ManagedUser>> managedUsers(
    String token, {
    String? search,
  }) async => (await _items(
    '/api/admin/users?search=${Uri.encodeQueryComponent(search ?? "")}',
    token: token,
  )).map(ManagedUser.fromJson).toList();

  static Future<ManagedUser> saveUser(
    String token, {
    ManagedUser? existing,
    required String firstName,
    required String lastName,
    required String username,
    required String email,
    String? password,
    required String role,
    required bool isActive,
  }) async {
    final body = {
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'email': email,
      'password': password ?? '',
      'role': role,
      'isActive': isActive,
    };
    return ManagedUser.fromJson(
      await _request(
            existing == null ? 'POST' : 'PUT',
            existing == null
                ? '/api/admin/users'
                : '/api/admin/users/${existing.id}',
            token: token,
            body: body,
          )
          as Map<String, dynamic>,
    );
  }

  static Future<List<int>> reservationReport(
    String token,
    DateTime from,
    DateTime to,
  ) => _download(
    token,
    '/api/reports/reservations?from=${_dateQuery(from)}&to=${_dateQuery(to)}',
  );

  static Future<List<int>> popularServicesReport(
    String token,
    DateTime from,
    DateTime to,
  ) => _download(
    token,
    '/api/reports/popular-services?from=${_dateQuery(from)}&to=${_dateQuery(to)}',
  );
  static Future<List<int>> paymentReport(
    String token,
    DateTime from,
    DateTime to,
  ) => _download(
    token,
    '/api/reports/payments?from=${_dateQuery(from)}&to=${_dateQuery(to)}',
  );

  static String _dateQuery(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  static Future<List<int>> _download(String token, String path) async {
    if (baseUrl.isEmpty) {
      throw const ApiException('API_BASE_URL nije konfigurisan.');
    }
    final client = HttpClient();
    try {
      final request = await client.openUrl('GET', Uri.parse('$baseUrl$path'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final response = await request.close();
      final bytes = await response.fold<List<int>>(
        <int>[],
        (result, chunk) => result..addAll(chunk),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401) {
          sessionExpired.value++;
          throw const ApiException('Sesija je istekla. Prijavite se ponovo.');
        }
        throw ApiException(
          'Izvještaj nije moguće generisati (${response.statusCode}).',
        );
      }
      return bytes;
    } on SocketException {
      throw const ApiException('Nije moguće povezati se s API servisom.');
    } finally {
      client.close();
    }
  }

  static Future<dynamic> _request(
    String method,
    String path, {
    String? token,
    Object? body,
  }) async {
    if (baseUrl.isEmpty) {
      throw const ApiException('API_BASE_URL nije konfigurisan.');
    }
    final effectiveToken =
        token ?? (path.startsWith('/api/auth/') ? null : sessionToken);
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, Uri.parse('$baseUrl$path'));
      request.headers.contentType = ContentType.json;
      if (effectiveToken != null && effectiveToken.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $effectiveToken',
        );
      }
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close();
      final text = await utf8.decodeStream(response);
      dynamic payload;
      try {
        payload = text.isEmpty ? null : jsonDecode(text);
      } on FormatException {
        payload = null;
      }
      if (response.statusCode == 401 &&
          effectiveToken != null &&
          effectiveToken.isNotEmpty) {
        sessionExpired.value++;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          payload is Map<String, dynamic> && payload['title'] is String
              ? payload['title'] as String
              : 'Zahtjev nije uspio (${response.statusCode}).',
        );
      }
      return payload;
    } on SocketException {
      throw const ApiException('Nije moguće povezati se s API servisom.');
    } finally {
      client.close();
    }
  }

  static String statusName(Object? value) => switch (value) {
    'Pending' || 0 => 'Pending',
    'Confirmed' || 1 => 'Confirmed',
    'Cancelled' || 2 => 'Cancelled',
    'Completed' || 3 => 'Completed',
    _ => value?.toString() ?? 'Unknown',
  };
}
