import 'package:animation_wrappers/animation_wrappers.dart';
import 'package:flutter/material.dart';
import 'package:hungerz_kiosk/Pages/orderPlaced.dart';
import 'package:hungerz_kiosk/Pages/item_info.dart';
import '../Components/custom_circular_button.dart';
import '../Theme/colors.dart';
import '../Models/menu_item.dart'; // Import MenuItem model
import '../Services/api_service.dart'; // Import ApiService
import 'dart:async'; // Import for Future

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

// Keep ItemCategory for the hardcoded list driving the UI
class ItemCategory {
  String image;
  String? name;

  ItemCategory(this.image, this.name);
}

// // Removed FoodItem class

class _HomePageState extends State<HomePage> {
  // Service instance
  final ApiService _apiService = ApiService();

  // State variables for fetched data, loading, and errors
  List<MenuItem> _displayedItems = []; // Items currently shown for the selected category
  // Cache items per category NAME (String) - now managed by ApiService
  Map<String, List<MenuItem>> _cachedItems = {}; 
  bool _isLoading = false;
  String? _errorMessage;

  int orderingIndex = 0;
  // itemSelected tracks if *any* item has a count > 0
  bool itemSelected = false;
  String? img, name; // For item info drawer (consider passing MenuItem directly) - Keep for old ItemInfoPage temporarily?
  MenuItem? _itemForInfoDrawer; // To hold the item for the new ItemInfoPage
  int drawerCount = 0; // 0 for cart drawer, 1 for item info
  int currentIndex = 0; // For category selection
  PageController _pageController = PageController();
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  // ** Keep the Hardcoded list for UI display **
  final List<ItemCategory> foodCategories = [
    ItemCategory('assets/ItemCategory/burger.png', "burgers"),
    ItemCategory('assets/ItemCategory/pizza.png', "pizzas"),
    ItemCategory('assets/ItemCategory/pates.png', "pates"),
    ItemCategory('assets/ItemCategory/kebbabs.png', "kebabs"),
    ItemCategory('assets/ItemCategory/tacos.png', "tacos"),
    ItemCategory('assets/ItemCategory/poulet.png', "poulet"),
    ItemCategory('assets/ItemCategory/healthy.png', "healthy"),
    ItemCategory('assets/ItemCategory/traditional.png', "traditional"),
    ItemCategory('assets/ItemCategory/dessert.png', "dessert"),
    ItemCategory('assets/ItemCategory/sandwitch.jpg', "sandwich"),
  ];

  @override
  void initState() {
    super.initState();
    // No need to clear the cache when the widget initializes - ApiService handles it

    // Fetch items for the initial category when the widget is first built
    if (foodCategories.isNotEmpty && foodCategories[currentIndex].name != null) {
       _fetchMenuItems(foodCategories[currentIndex].name!);
    } else {
    }
  }

  // Method to fetch menu items for a given category NAME
  Future<void> _fetchMenuItems(String categoryName) async {
    // Check if widget is still mounted before calling setState
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // The ApiService now handles caching internally
      final items = await _apiService.getMenuItemsByCategory(categoryName);
      
      // Check if widget is still mounted before calling setState
      if (!mounted) return;
      setState(() {
        _displayedItems = items;
        // Update our local cache reference - needed for UI operations
        if (!_cachedItems.containsKey(categoryName)) {
          _cachedItems[categoryName] = items;
        }
        _isLoading = false;
        _errorMessage = null;
        _updateCartStatus();
      });
    } catch (e) {
       // Check if widget is still mounted before calling setState
       if (!mounted) return;
       setState(() {
        _errorMessage = "Failed to load items. ${e.toString()}"; // More informative error
        _isLoading = false;
        _displayedItems = []; // Clear items on error
        _updateCartStatus();
      });
      // Check mount status again specifically for ScaffoldMessenger
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error fetching items: $_errorMessage"), duration: Duration(seconds: 3))
          );
      }
    }
  }

  // Method to refresh menu items for a category by clearing cache and refetching
  Future<void> _refreshMenuItems(String categoryName) async {
    // Clear the cache in ApiService for this category 
    _apiService.clearCache(categoryName: categoryName);
    
    // Also clear our local cache reference
    if (_cachedItems.containsKey(categoryName)) {
      setState(() {
        _cachedItems.remove(categoryName);
      });
    }
    
    // Refetch the items
    await _fetchMenuItems(categoryName);
  }

  // --- Helper function to update item state in cache and displayed list ---
  void _updateItemState(MenuItem item, Function(MenuItem foundItem) updateAction) {
    // Get the local cache reference first
    if (_cachedItems.containsKey(item.category)) {
      var categoryList = _cachedItems[item.category]!;
      int itemIndex = categoryList.indexWhere((cachedItem) => cachedItem.id == item.id);
      
      if (itemIndex != -1) {
        // Apply update to the item in the local cache
        updateAction(categoryList[itemIndex]);
      } else {
        print("Warning: Item ${item.id} (${item.name}) not found in local cache for category ${item.category}");
        updateAction(item);
      }
    } else {
      print("Warning: Category ${item.category} not found in local cache for item ${item.id} (${item.name})");
      updateAction(item);
    }
    
    _updateCartStatus();
  }

  // Helper to get all items currently in the cart (count > 0) across all categories
  List<MenuItem> _getAllItemsInCart() {
    List<MenuItem> itemsInCart = [];
    // Iterate through the values (lists of items) in the cache
    _cachedItems.values.forEach((categoryItems) {
      itemsInCart.addAll(categoryItems.where((item) => item.count > 0));
    });
    // Remove duplicates based on item ID
    final itemIds = itemsInCart.map((item) => item.id).toSet();
    itemsInCart.retainWhere((item) => itemIds.remove(item.id)); 
    return itemsInCart;
  }

  // Helper method to calculate total items in cart
  int calculateTotalItems() {
    int total = 0;
    _cachedItems.values.forEach((categoryItems) {
      total += categoryItems.fold(0, (sum, item) => sum + item.count);
    });
    return total;
  }

  // Helper method to calculate total amount
  double calculateTotalAmount() {
    double total = 0.0;
     _cachedItems.values.forEach((categoryItems) {
        total += categoryItems.fold(0.0, (sum, item) => sum + item.price * item.count);
     });
     return total;
  }

  // Update the global cart selected status
  void _updateCartStatus() {
     // Check if widget is mounted before calling setState
    if (mounted) {
      setState(() {
        itemSelected = calculateTotalItems() > 0;
      });
    }
  }

  // --- Cancel Order Logic ---
  void _cancelOrder() {
     setState(() {
        // Reset counts and selection for all cached items
        _cachedItems.forEach((key, itemList) {
          for (var item in itemList) {
            item.count = 0;
            item.isSelected = false;
          }
        });
        // Update the currently displayed list as well
         _displayedItems.forEach((item) { 
            item.count = 0;
            item.isSelected = false;
         });
        _updateCartStatus(); // This will set itemSelected to false
     });
  }

  // --- Callback Functions for ItemInfoPage --- 
  void _incrementItemFromInfo(MenuItem item) {
    // Needs setState to update UI potentially (like total items in Review Order button)
    setState(() {
      _updateItemState(item, (foundItem) {
        foundItem.count++;
        foundItem.isSelected = true;
      });
    });
  }

  void _decrementItemFromInfo(MenuItem item) {
    // Needs setState to update UI potentially
    setState(() {
      _updateItemState(item, (foundItem) {
        if (foundItem.count > 0) {
          foundItem.count--;
          if (foundItem.count == 0) {
            foundItem.isSelected = false;
          }
        }
      });
    });
  }
  // --- End Callbacks ---

  @override
  Widget build(BuildContext context) {
    final List<MenuItem> itemsInCart = _getAllItemsInCart(); 

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: Drawer(
        // Updated logic to use _itemForInfoDrawer and pass callbacks
        child: drawerCount == 1
            ? (_itemForInfoDrawer != null
                ? ItemInfoPage(
                    menuItem: _itemForInfoDrawer!, 
                    onIncrement: () => _incrementItemFromInfo(_itemForInfoDrawer!),
                    onDecrement: () => _decrementItemFromInfo(_itemForInfoDrawer!),
                  )
                : Center(child: Text("Error: Item data missing."))) // Fallback
            : cartDrawer(itemsInCart), // Pass cart items to cartDrawer
      ),
      appBar: AppBar(
         // AppBar content remains the same
        actions: [Icon(null)],
        toolbarHeight: 100,
        automaticallyImplyLeading: false,
        title: Column(
          children: [
            Row(
              children: [
                Text(
                  "Welcome",
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(fontSize: 30, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(
              height: 10,
            ),
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Scroll to choose your item",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium!
                        .copyWith(fontSize: 13, color: strikeThroughColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            )
          ],
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xffFFF3C4), // Warmer yellow/light orange at the bottom
                  Color(0xffFFFCF0), // Very light beige/off-white at the top
                ],
                stops: [0.0, 0.7], // Make yellow more prominent, fade out around 70% height
              ),
            ),
            child: Row(
              children: [
                // Category List View (using hardcoded foodCategories)
                Container(
                  width: 90,
                  child: ListView.builder(
                      physics: BouncingScrollPhysics(),
                      itemCount: foodCategories.length, // Count from hardcoded list
                      itemBuilder: (context, index) {
                        final category = foodCategories[index];
                        return InkWell(
                          onTap: () {
                            if (category.name != null) {
                              // Animate PageView
                              _pageController.animateToPage(
                                index,
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                              // Update index and Fetch items using NAME
                            setState(() {
                              currentIndex = index;
                            });
                              if (category.name != null) {
                                _fetchMenuItems(category.name!);
                              }
                            }
                          },
                          child: Container(
                            height: 90,
                            margin: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: currentIndex == index
                                  ? Theme.of(context).primaryColor
                                  : Theme.of(context).scaffoldBackgroundColor,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                              children: [
                                Spacer(),
                                FadedScaleAnimation(
                                  child: Image.asset(
                                    category.image, // Use local asset from hardcoded list
                                    scale: 3.5,
                                    errorBuilder: (context, error, stackTrace) => Icon(Icons.error, size: 30),
                                  ),
                                  scaleDuration: Duration(milliseconds: 600),
                                  fadeDuration: Duration(milliseconds: 600),
                                ),
                                Spacer(),
                                Text(
                                  category.name?.toUpperCase() ?? '',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium!
                                      .copyWith(fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                                Spacer(),
                              ],
                            ),
                          ),
                        );
                      }),
                ),
                // PageView for displaying items
                Expanded(
                  child: PageView.builder(
                    physics: BouncingScrollPhysics(),
                    controller: _pageController,
                    itemCount: foodCategories.length, // Count from hardcoded list
                    onPageChanged: (index) {
                      final categoryName = foodCategories[index].name;
                      setState(() {
                        currentIndex = index;
                      });
                      if (categoryName != null) {
                        _fetchMenuItems(categoryName); // Fetch data when page changes
                      } else {
                         // Handle null category name case - maybe show error or clear items
                          // Check if widget is still mounted before calling setState
                          if (!mounted) return;
                          setState(() {
                             _isLoading = false;
                             _errorMessage = "Selected category is invalid.";
                             _displayedItems = [];
                             _updateCartStatus();
                          });
                      }
                    },
                    itemBuilder: (context, pageIndex) {
                      // buildPage handles showing loading/error/items for the *currently selected* category
                      // Check if the page being built matches the current index
                      if (pageIndex == currentIndex) {
                          // Display loading, error, or items based on state
                          if (_isLoading) {
                             return Center(child: CircularProgressIndicator());
                          }
                          if (_errorMessage != null) {
                             return Center(child: Text("Error: $_errorMessage", style: TextStyle(color: Colors.red)));
                          }
                          if (_displayedItems.isEmpty) {
                             return Center(child: Text("No items available in this category."));
                          }
                          // Render the grid if we have items
                          return buildItemGrid(_displayedItems);
                      } else {
                          // For pages not currently selected, maybe show placeholder or nothing
                          return Center(child: CircularProgressIndicator()); // Show loading while swiping? Or SizedBox.shrink();
                      }
                    }
                  ),
                ),
              ],
            ),
          ),
          // Bottom Bar (remains largely the same)
          itemSelected
              ? Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    alignment: Alignment.bottomCenter,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(10)),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Theme.of(context).primaryColor,
                          transparentColor,
                        ],
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: _cancelOrder,
                            child: Text(
                              "Cancel Order",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(fontSize: 17),
                            ),
                          ),
                          buildItemsInCartButton(context, calculateTotalItems()),
                        ],
                      ),
                    ),
                  ))
              : SizedBox.shrink()
        ],
      ),
    );
  }

  // Button builder (remains the same)
  CustomButton buildItemsInCartButton(BuildContext context, int itemCount) {
    return CustomButton(
      onTap: () {
        setState(() {
          drawerCount = 0; // Ensure cart drawer is shown
        });
        _scaffoldKey.currentState!.openEndDrawer();
      },
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      title: Row(
        children: [
          Text(
            "Review Order ($itemCount)",
            style:
                Theme.of(context).textTheme.bodyLarge!.copyWith(fontSize: 17),
          ),
          Icon(
            Icons.chevron_right,
            color: Colors.white,
          )
        ],
      ),
      bgColor: buttonColor,
    );
  }

 // Renamed buildPage to buildItemGrid for clarity, now only builds the grid
  Widget buildItemGrid(List<MenuItem> itemsToDisplay) {
    return GridView.builder(
      physics: BouncingScrollPhysics(),
      padding:
          EdgeInsetsDirectional.only(top: 6, bottom: 100, start: 16, end: 32),
      itemCount: itemsToDisplay.length, // Use the passed list
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75),
      itemBuilder: (context, index) {
        // Get the specific MenuItem for this grid cell
        final item = itemsToDisplay[index];
        return Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Theme.of(context).scaffoldBackgroundColor),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 35,
                child: GestureDetector(
                  onTap: () {
                    // ---- Add Print Statement ----
                    print("Tapped on item: ${item.id} - ${item.name} in category ${item.category}");
                    // ---------------------------
                    // Toggle selection state and update count using helper
                    setState(() {
                       // ---- Verify state change within setState ----
                       final itemBeforeUpdate = _cachedItems[item.category]?.firstWhere((i) => i.id == item.id, orElse: () => item); // Get current state from cache or fallback
                       print(">>> setState: BEFORE _updateItemState for ${item.id}, count: ${itemBeforeUpdate?.count}, isSelected: ${itemBeforeUpdate?.isSelected}");
                       
                       _updateItemState(item, (foundItem) {
                         foundItem.isSelected = !foundItem.isSelected;
                         if (foundItem.isSelected && foundItem.count == 0) {
                           foundItem.count = 1;
                         } else if (!foundItem.isSelected) {
                           foundItem.count = 0;
                         }
                       });

                       final itemAfterUpdate = _cachedItems[item.category]?.firstWhere((i) => i.id == item.id, orElse: () => item); // Get updated state from cache or fallback
                       print(">>> setState: AFTER _updateItemState for ${item.id}, count: ${itemAfterUpdate?.count}, isSelected: ${itemAfterUpdate?.isSelected}");
                       // ------------------------------------------
                    });
                  },
                  child: Stack(
                    children: [
                      Container(
                          decoration: BoxDecoration(
                           borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                        ),
                        child: ClipRRect(
                           borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
                           child: FadedScaleAnimation(
                              child: item.image != null && item.image!.isNotEmpty
                                ? Image.network(
                                    item.image!, 
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null));
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                       return Container(color: Colors.grey[300], child: Icon(Icons.broken_image, color: Colors.grey[600], size: 40,)); // Make icon bigger
                                    },
                                  )
                                : Container(color: Colors.grey[300], child: Icon(Icons.image_not_supported, color: Colors.grey[600], size: 40,)), // Make icon bigger
                        scaleDuration: Duration(milliseconds: 600),
                        fadeDuration: Duration(milliseconds: 600),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: Container(
                          height: 20,
                          width: 30,
                          child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: Icon(
                                Icons.info_outline,
                                color: Colors.grey.shade400,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _itemForInfoDrawer = item; // Store the selected item
                                  drawerCount = 1; // Set drawer type to item info
                                });
                                _scaffoldKey.currentState!.openEndDrawer();
                              }),
                        ),
                      ),
                      // --- Keep Controls Overlay ---
                      if (item.count > 0) // Show only if count > 0
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 8.0), // Adjust vertical position
                              child: Container( // Container for rounded background (optional)
                                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                                decoration: BoxDecoration(
                                  // Optional: Add background/border to the controls row if needed
                                  // color: Colors.black.withOpacity(0.2),
                                  // borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                        onTap: () {
                                          // Decrement count using helper
                                            setState(() {
                                          _updateItemState(item, (foundItem) {
                                            if (foundItem.count > 0) {
                                              foundItem.count--;
                                              if (foundItem.count == 0) {
                                                foundItem.isSelected = false;
                                              }
                                            }
                                          });
                                            });
                                        },
                                        child: Icon(
                                          Icons.remove, // Use standard remove icon
                                          color: Colors.white,
                                          size: 24, // Make icon slightly larger
                                        )),
                                    SizedBox(width: 12), // Space between icons and count
                                    // Prominent Count Display
                                    Container(
                                      padding: EdgeInsets.all(8), // Padding inside the circle
                                      decoration: BoxDecoration(
                                        color: Colors.red, // Red background like the image
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        item.count.toString(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium!
                                            .copyWith(
                                                fontSize: 14, // Adjust font size
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    SizedBox(width: 12), // Space between count and icon
                                    GestureDetector(
                                        onTap: () {
                                          // Increment count using helper
                                          setState(() {
                                             _updateItemState(item, (foundItem) {
                                               foundItem.count++;
                                               foundItem.isSelected = true; // Ensure isSelected is true when count > 0
                                             });
                                          });
                                        },
                                        child: Icon(
                                          Icons.add, // Use standard add icon
                                          color: Colors.white,
                                          size: 24, // Make icon slightly larger
                                        )),
                                  ],
                                ),
                              ),
                            ),
                          )
                      // --- End of Modified Overlay ---
                    ],
                  ),
                ),
              ),
              // Text display remains the same, uses item properties
              Spacer(flex: 5),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  item.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              Spacer(flex: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    FadedScaleAnimation(
                      child: Image.asset(
                        item.isVeg
                            ? 'assets/ic_veg.png'
                            : 'assets/ic_nonveg.png',
                        scale: 2.8,
                      ),
                      scaleDuration: Duration(milliseconds: 600),
                      fadeDuration: Duration(milliseconds: 600),
                    ),
                    SizedBox(width: 8),
                    Text(
                      item.price.toStringAsFixed(2) + ' DZD',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
              Spacer(flex: 5),
            ],
          ),
        );
      },
    );
  }

  // Update cartDrawer to use MenuItems
  Widget cartDrawer(List<MenuItem> itemsInCart) {
     // Cart drawer implementation remains largely the same as the previous refactor,
     // just ensure it uses MenuItem properties and Image.network
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            FadedSlideAnimation(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "My Order",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium!
                                    .copyWith(
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              "Quick Checkout",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium!
                                    .copyWith(
                                        fontSize: 15,
                                        color: strikeThroughColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                ],
              ),
              beginOffset: Offset(0.0, 0.3),
              endOffset: Offset(0, 0),
              slideCurve: Curves.linearToEaseOut,
            ),
            Expanded(
              child: ListView.builder(
                  physics: BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  itemCount: itemsInCart.length,
                      itemBuilder: (context, index) {
                    final cartItem = itemsInCart[index];
                        return Column(
                          children: [
                            ListTile(
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                          leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                child: cartItem.image != null && cartItem.image!.isNotEmpty
                                  ? Image.network(cartItem.image!, width: 60, height: 60, fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(width: 60, height: 60, color: Colors.grey[300], child: Icon(Icons.broken_image, color: Colors.grey[600]));
                                      },
                                      loadingBuilder: (context, child, loadingProgress) {
                                         if (loadingProgress == null) return child;
                                         return Container(width: 60, height: 60, alignment: Alignment.center, child: CircularProgressIndicator(value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null));
                                      },
                                    )
                                  : Container(width: 60, height: 60, color: Colors.grey[300], child: Icon(Icons.image_not_supported, color: Colors.grey[600])),
                              ),
                              title: Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                Expanded(
                                  child: Text(
                                    cartItem.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                        .copyWith(fontSize: 15),
                                    overflow: TextOverflow.ellipsis,
                                    ),
                                    ),
                                SizedBox(width: 8),
                                    Image.asset(
                                  cartItem.isVeg
                                          ? 'assets/ic_veg.png'
                                          : 'assets/ic_nonveg.png',
                                  height: 14,
                                    ),
                                  ],
                                ),
                              ),
                          subtitle: Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                        vertical: 5, horizontal: 8),
                                        decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                            color: Colors.grey.shade300,
                                            width: 1)),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                                onTap: () {
                                              // Decrement count in cart using helper
                                                    setState(() {
                                                _updateItemState(cartItem, (foundItem) {
                                                  if (foundItem.count > 0) {
                                                    foundItem.count--;
                                                    if (foundItem.count == 0) {
                                                      foundItem.isSelected = false;
                                                    }
                                                  }
                                                });
                                                    });
                                                },
                                                child: Icon(
                                                  Icons.remove,
                                              color: Theme.of(context).primaryColor,
                                              size: 18,
                                                )),
                                        SizedBox(width: 10),
                                            Text(
                                          cartItem.count.toString(),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium!
                                              .copyWith(fontSize: 14),
                                            ),
                                        SizedBox(width: 10),
                                            GestureDetector(
                                                onTap: () {
                                              // Increment count in cart using helper
                                                  setState(() {
                                                 _updateItemState(cartItem, (foundItem) {
                                                   foundItem.count++;
                                                   foundItem.isSelected = true;
                                                 });
                                                  });
                                                },
                                                child: Icon(
                                                  Icons.add,
                                               color: Theme.of(context).primaryColor,
                                              size: 18,
                                                )),
                                          ],
                                        ),
                                      ),
                                      Spacer(),
                                  Text(cartItem.price.toStringAsFixed(2) + ' DZD', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),)
                                ],
                              ),
                        ),
                       Divider(thickness: 0.5),
                      ],
                    );
                  }),
            ),
            // Bottom Summary Section (remains the same)
            Container(
               padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Divider(height: 1, thickness: 0.5),
                   Padding(
                     padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
                     child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                           padding: EdgeInsets.only(bottom: 10),
                           child: Text("Choose Ordering Method", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 16)),
                        ),
                        orderingMethod()
                      ],
                    ),
                   ),
                    Divider(height: 1, thickness: 0.5),
                    ListTile(
                      tileColor: Theme.of(context).colorScheme.surface,
                     title: Text("Total Amount",
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium!
                              .copyWith(
                                 fontSize: 16,
                                 fontWeight: FontWeight.w600,
                                  color: Colors.blueGrey.shade700)),
                      trailing: Text(
                       calculateTotalAmount().toStringAsFixed(2) + ' DZD',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium!
                           .copyWith(color: Colors.blueGrey.shade900, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    FadedScaleAnimation(
                     child: CustomButton(
                        onTap: () {
                         if (calculateTotalItems() > 0) {
                          _placeOrder();
                         } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Please add items to your order first.'), duration: Duration(seconds: 2),)
                            );
                         }
                        },
                        padding:
                           EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        margin:
                           EdgeInsets.symmetric(vertical: 15, horizontal: 60),
                        title: Row(
                         mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                             "Place Order",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                            ),
                           SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.white,
                            )
                          ],
                        ),
                        bgColor: buttonColor,
                       borderRadius: 8,
                      ),
                      scaleDuration: Duration(milliseconds: 600),
                     fadeDuration: Duration(milliseconds: 600),
                   ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // orderingMethod remains the same
  Widget orderingMethod() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  orderingIndex = 0;
                });
              },
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 5),
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                height: 65,
                decoration: BoxDecoration(
                  color: orderingIndex == 0 ? Color(0xffFFEEC8) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: orderingIndex == 0
                      ? Border.all(color: Theme.of(context).primaryColor, width: 1.5)
                      : Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadedScaleAnimation(
                     child: Container(
                        padding: EdgeInsets.only(right: 8),
                        child: Image(
                          image: AssetImage("assets/ic_takeaway.png"), height: 24,
                        ),
                      ),
                      scaleDuration: Duration(milliseconds: 600),
                      fadeDuration: Duration(milliseconds: 600),
                    ),
                    Text("Take Away", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15),),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  orderingIndex = 1;
                });
              },
              child: Container(
                 margin: EdgeInsets.symmetric(horizontal: 5),
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                height: 65,
                decoration: BoxDecoration(
                   color: orderingIndex == 1 ? Color(0xffFFEEC8) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: orderingIndex == 1
                      ? Border.all(color: Theme.of(context).primaryColor, width: 1.5)
                      : Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadedScaleAnimation(
                      child: Container(
                         padding: EdgeInsets.only(right: 8),
                        child: Image(
                          image: AssetImage("assets/ic_dine in.png"), height: 24,
                        ),
                      ),
                      scaleDuration: Duration(milliseconds: 600),
                      fadeDuration: Duration(milliseconds: 600),
                    ),
                    Text("Dine In", style: TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Add this new method to handle order submission
  void _placeOrder() async {
    // Show loading indicator
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get all cart items (count > 0)
      final List<MenuItem> itemsInCart = _getAllItemsInCart();
      
      // Get selected order type (Take Away or Dine In)
      // Using exact strings to match backend enum values: "Take Away" or "Dine In"
      final String orderType = orderingIndex == 0 ? 'Take Away' : 'Dine In';
      
      // Calculate total amount
      final double totalAmount = calculateTotalAmount();
      
      // Call API to create order with only essential fields
      final orderResult = await _apiService.createOrder(
        items: itemsInCart,
        orderType: orderType,
      );
      
      // Hide loading indicator
      setState(() {
        _isLoading = false;
      });
      
      // Extract order details from response
      final String? orderId = orderResult['order']['id'];
      // The backend might return an order number differently, adjust as needed
      final dynamic orderNumber = orderResult['order']['id'] != null 
          ? int.tryParse(orderResult['order']['id'].toString().substring(0, 4)) // Use first 4 chars of ID
          : null;
      
      // Navigate to order confirmation page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => OrderPlaced(
            orderId: orderId,
            orderNumber: orderNumber,
            totalAmount: totalAmount,
          ),
        ),
      );
      
    } catch (error) {
      // Hide loading indicator
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error placing order: ${error.toString()}'),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

