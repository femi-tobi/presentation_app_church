import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'connectivity_service.dart';
import 'package:http/http.dart' as http;


class FormSyncService extends ChangeNotifier {
  FormSyncService._internal() {
    // Listen for network changes to automatically sync
    ConnectivityService.instance.addListener(_onConnectivityChanged);
    // Initial sync attempt in next event loop cycle
    scheduleMicrotask(syncPendingSubmissions);
  }

  static final FormSyncService instance = FormSyncService._internal();

  static const String _queueKey = 'pending_form_submissions';
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  void _onConnectivityChanged() {
    if (ConnectivityService.instance.isOnline) {
      debugPrint('[FormSyncService] Internet connection restored. Attempting sync...');
      syncPendingSubmissions();
    }
  }

  /// Queue a submission payload. Attempts immediate delivery if online,
  /// otherwise saves it to local queue.
  Future<void> queueSubmission(Map<String, String> data) async {
    final queue = await _loadQueue();
    queue.add(data);
    await _saveQueue(queue);
    
    debugPrint('[FormSyncService] Queued new submission. Total pending: ${queue.length}');
    
    if (ConnectivityService.instance.isOnline) {
      await syncPendingSubmissions();
    }
  }

  /// Attempts to upload all pending submissions in the queue one by one.
  Future<void> syncPendingSubmissions() async {
    if (_isSyncing) return;
    if (!ConnectivityService.instance.isOnline) {
      debugPrint('[FormSyncService] Sync skipped: Offline.');
      return;
    }

    final queue = await _loadQueue();
    if (queue.isEmpty) return;

    _isSyncing = true;
    notifyListeners();

    debugPrint('[FormSyncService] Starting sync for ${queue.length} pending submissions...');
    final List<Map<String, String>> remaining = [];

    for (final payload in queue) {
      bool success = false;
      if (ConnectivityService.instance.isOnline) {
        success = await _sendToGoogleForm(payload);
      }
      
      if (success) {
        debugPrint('[FormSyncService] Successfully synced payload: $payload');
      } else {
        debugPrint('[FormSyncService] Failed to sync payload, keeping in queue: $payload');
        remaining.add(payload);
      }
    }

    await _saveQueue(remaining);
    _isSyncing = false;
    notifyListeners();
    
    debugPrint('[FormSyncService] Sync finished. Remaining in queue: ${remaining.length}');
  }

  /// Sends a single payload to Google Form
  Future<bool> _sendToGoogleForm(Map<String, String> data) async {
    try {
      final url = Uri.parse(
          'https://docs.google.com/forms/d/e/1FAIpQLSfCUDuzLB8RagbxISGlWkRXan5nVhMOZqcXpE9V7uH3sYjS4rT_4Q/formResponse');
      
      final request = http.Request('POST', url)
        ..headers.addAll({'Content-Type': 'application/x-www-form-urlencoded'})
        ..bodyFields = data
        ..followRedirects = false;

      final streamedResponse = await request.send().timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('[FormSyncService] Google Form response status code: ${response.statusCode}');
      
      // Google Form responses: 200 OK or 302 Redirect (on successful submission)
      if (response.statusCode >= 200 && response.statusCode < 400) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[FormSyncService] Network error during Form submit: $e');
      return false;
    }
  }

  // ── Local Storage Helpers ──────────────────────────────────────────────────

  Future<List<Map<String, String>>> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_queueKey);
      if (jsonStr == null) return [];
      
      final List<dynamic> decodedList = json.decode(jsonStr);
      return decodedList.map((item) {
        final Map<String, dynamic> map = item as Map<String, dynamic>;
        return map.map((key, val) => MapEntry(key, val.toString()));
      }).toList();
    } catch (e) {
      debugPrint('[FormSyncService] Error loading queue: $e');
      return [];
    }
  }

  Future<void> _saveQueue(List<Map<String, String>> queue) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_queueKey, json.encode(queue));
    } catch (e) {
      debugPrint('[FormSyncService] Error saving queue: $e');
    }
  }
}
