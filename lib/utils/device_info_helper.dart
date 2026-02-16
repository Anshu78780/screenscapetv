import 'dart:io';
import 'package:flutter/services.dart';

class DeviceInfoHelper {
  static const MethodChannel _channel = MethodChannel('com.example.screenscapetv/device_info');
  //Set This to true to simulate low memory devices during testing
  static const bool override512mbForTest = false;
  
  static bool? _isLowMemoryDevice;
  
  static Future<bool> isLowMemoryDevice() async {
    if (_isLowMemoryDevice != null) {
      return _isLowMemoryDevice!;
    }
    
    if (override512mbForTest) {
      print('DeviceInfo: Override enabled - treating as low memory device');
      _isLowMemoryDevice = true;
      return true;
    }
    
    if (!Platform.isAndroid) {
      _isLowMemoryDevice = false;
      return false;
    }
    
    try {
      final int totalMemoryMB = await _channel.invokeMethod('getTotalMemory');
      print('DeviceInfo: Total memory: ${totalMemoryMB}MB');
      
      _isLowMemoryDevice = totalMemoryMB < 1024;
      return _isLowMemoryDevice!;
    } catch (e) {
      print('DeviceInfo: Failed to get memory info: $e');
      _isLowMemoryDevice = false;
      return false;
    }
  }
  
  static void reset() {
    _isLowMemoryDevice = null;
  }
}
