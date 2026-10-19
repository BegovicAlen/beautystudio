import 'beauty_studio_api.dart';

class ApiBeautyService {
  const ApiBeautyService({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.category,
    required this.price,
    required this.durationMinutes,
  });
  final int id;
  final String name;
  final String description;
  final int categoryId;
  final String category;
  final num price;
  final int durationMinutes;
  factory ApiBeautyService.fromJson(Map<String, dynamic> json) =>
      ApiBeautyService(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String,
        categoryId: json['categoryId'] as int,
        category: json['categoryName'] as String,
        price: json['price'] as num,
        durationMinutes: json['durationMinutes'] as int,
      );
}

class ServiceCatalogApi {
  static Future<List<ApiBeautyService>> fetch({
    String? search,
    int? categoryId,
  }) async => (await BeautyStudioApi.serviceRows(
    search: search,
    categoryId: categoryId,
  )).map(ApiBeautyService.fromJson).toList();
}
