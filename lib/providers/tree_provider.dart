import 'package:flutter/material.dart';
import '../models/tree_model.dart';
import '../services/firestore_service.dart';

class TreeProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  TreeModel? _tree;
  bool _isLoading = false;
  String? _error;

  TreeModel? get tree => _tree;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTree(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      _tree = await _firestoreService.getTree(uid);
      _error = null;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }
}