// Category icon + color options for budget cards.

import 'package:flutter/material.dart';

const categoryColorOptions = <String>[
  '#3b82f6',
  '#22c55e',
  '#f59e0b',
  '#ef4444',
  '#a855f7',
  '#06b6d4',
  '#ec4899',
  '#84cc16',
  '#f97316',
  '#6366f1',
];

const categoryIconOptions = <String>[
  'cart',
  'restaurant',
  'directions_car',
  'home',
  'bolt',
  'shopping_bag',
  'movie',
  'favorite',
  'work',
  'school',
  'flight',
  'pets',
  'fitness',
  'coffee',
  'phone',
  'more',
];

Color categoryColorFromHex(String hex) {
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length != 6) return const Color(0xFF3B82F6);
  return Color(int.parse('FF$cleaned', radix: 16));
}

IconData categoryIconData(String key) {
  return switch (key) {
    'cart' => Icons.shopping_cart_rounded,
    'restaurant' => Icons.restaurant_rounded,
    'directions_car' => Icons.directions_car_rounded,
    'home' => Icons.home_rounded,
    'bolt' => Icons.bolt_rounded,
    'shopping_bag' => Icons.shopping_bag_rounded,
    'movie' => Icons.movie_rounded,
    'favorite' => Icons.favorite_rounded,
    'work' => Icons.work_rounded,
    'school' => Icons.school_rounded,
    'flight' => Icons.flight_rounded,
    'pets' => Icons.pets_rounded,
    'fitness' => Icons.fitness_center_rounded,
    'coffee' => Icons.coffee_rounded,
    'phone' => Icons.phone_iphone_rounded,
    _ => Icons.category_rounded,
  };
}

String defaultIconForCategory(String category) {
  final key = category.trim().toLowerCase();
  return switch (key) {
    'food' || 'restaurant' || 'dining' => 'restaurant',
    'grocery' || 'groceries' => 'cart',
    'transport' || 'travel' || 'fuel' || 'petrol' => 'directions_car',
    'bills' || 'utilities' || 'electricity' => 'bolt',
    'shopping' || 'clothes' || 'clothing' => 'shopping_bag',
    'entertainment' || 'fun' || 'movies' => 'movie',
    'health' || 'medical' || 'fitness' || 'gym' => 'favorite',
    'rent' || 'home' || 'housing' => 'home',
    'work' || 'salary' || 'office' => 'work',
    'education' || 'school' || 'tuition' => 'school',
    'pets' || 'pet' => 'pets',
    'coffee' || 'cafe' => 'coffee',
    'phone' || 'mobile' || 'internet' => 'phone',
    'flight' || 'vacation' || 'holiday' => 'flight',
    _ => 'more',
  };
}

String defaultColorForCategory(String category, [int index = 0]) {
  final key = category.trim().toLowerCase();
  return switch (key) {
    'food' => '#3b82f6',
    'grocery' || 'groceries' => '#22c55e',
    'transport' => '#f59e0b',
    'bills' => '#ef4444',
    'shopping' => '#a855f7',
    'entertainment' => '#ec4899',
    'health' => '#06b6d4',
    'rent' => '#84cc16',
    _ => categoryColorOptions[index % categoryColorOptions.length],
  };
}
