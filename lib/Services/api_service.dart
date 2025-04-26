import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Models/menu_item.dart'; // Import the model

class ApiService {
  // --- IMPORTANT --- 
  // Replace with your computer's local IP address and port
  static const String _baseUrl = "http://10.0.2.2:5000/api";
  // ---------

  // Cache to store menu items by category
  final Map<String, List<MenuItem>> _menuItemsCache = {};

  // Fetch menu items by category name
  Future<List<MenuItem>> getMenuItemsByCategory(String categoryName) async {
    // Check if the items for this category are already in cache
    if (_menuItemsCache.containsKey(categoryName)) {
      print("Returning cached items for category: $categoryName");
      return _menuItemsCache[categoryName]!;
    }

    // URL encode the category name in case it has spaces or special characters
    final encodedCategoryName = Uri.encodeComponent(categoryName);
    // Corrected endpoint path assuming routes are like /api/menu-items/...
    final Uri uri = Uri.parse('$_baseUrl/menu-items/category/$encodedCategoryName'); 

    // print("Fetching menu items from: $uri"); // Removed log

    try {
      final response = await http.get(uri);

      // print("Response status code for items: ${response.statusCode}"); // Removed log
      // print("Response body for items: ${response.body}"); // Removed log

      if (response.statusCode == 200) {
        // Use the static parser from the MenuItem model which handles the nested structure
        final items = MenuItem.parseMenuItems(response.body);
        // Cache the results
        _menuItemsCache[categoryName] = items;
        return items;
      } else {
        // Handle server errors (e.g., 404 Not Found, 500 Internal Server Error)
        print("Error fetching items: ${response.statusCode} - ${response.reasonPhrase}");
        print("Response body for items: ${response.body}");
        // Throw an exception to be caught in the UI layer
        throw Exception('Failed to load menu items for category $categoryName (Status code: ${response.statusCode})');
      }
    } catch (e) {
      // Handle network errors or parsing errors
      print("Network or parsing error fetching items: $e");
      // Re-throw the exception
      throw Exception('Failed to load menu items. Check network connection and backend status.');
    }
  }

  // Clear cache for a specific category or all categories
  void clearCache({String? categoryName}) {
    if (categoryName != null) {
      _menuItemsCache.remove(categoryName);
    } else {
      _menuItemsCache.clear();
    }
  }

  // Fetch all unique category names
  Future<List<String>> getAllCategories() async {
    // Assuming the endpoint is /api/categories
    final Uri uri = Uri.parse('$_baseUrl/categories'); 
    // print("Fetching categories from: $uri"); // Removed log

    try {
      final response = await http.get(uri);
      // print("Response status code for categories: ${response.statusCode}"); // Removed log

      if (response.statusCode == 200) {
        final parsed = json.decode(response.body);
        // Expecting format: { "categories": ["Burger", "Pizza", ...] }
        if (parsed is Map<String, dynamic> && parsed.containsKey('categories')) {
          final List<dynamic> categoryList = parsed['categories'];
          // Ensure all elements are strings
          return categoryList.map((category) => category.toString()).toList(); 
        } else {
          print("Error: Unexpected JSON structure for categories: $parsed");
          throw Exception('Failed to parse categories: Unexpected JSON structure');
        }
      } else {
        print("Error fetching categories: ${response.statusCode} - ${response.reasonPhrase}");
        print("Response body for categories: ${response.body}");
        throw Exception('Failed to load categories (Status code: ${response.statusCode})');
      }
    } catch (e) {
      print("Network or parsing error fetching categories: $e");
      throw Exception('Failed to load categories. Check network connection and backend status.');
    }
  }

  // Create an order in the backend
  Future<Map<String, dynamic>> createOrder({
    required List<MenuItem> items,
    required String orderType,
  }) async {
    final Uri uri = Uri.parse('$_baseUrl/orders');
    
    // Format items as required by the backend
    final formattedItems = items.map((item) => {
      'menuItemId': item.id,
      'quantity': item.count,
    }).toList();
    
    // Create request body with only essential fields for kiosk
    final Map<String, dynamic> requestBody = {
      'items': formattedItems,
      'orderType': orderType, // Use exact values from the UI that match backend enum: "Take Away" or "Dine In"
    };
    
    print("Sending order to server: ${jsonEncode(requestBody)}");
    
    try {
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      print("Order response status: ${response.statusCode}");
      print("Order response body: ${response.body}");
      
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception('Failed to create order: ${errorBody['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print("Error creating order: $e");
      throw Exception('Failed to create order. Check network connection and backend status.');
    }
  }

  // Potential future methods:
  // Future<List<MenuItem>> getAllMenuItems() async { ... }
  // Future<MenuItem> getMenuItemDetails(String itemId) async { ... }
} 