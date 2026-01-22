import 'dart:typed_data';
import 'package:flutter_libserialport/flutter_libserialport.dart';

class SerialPrinterService {
  static final SerialPrinterService _instance = SerialPrinterService._internal();
  factory SerialPrinterService() => _instance;
  SerialPrinterService._internal();

  final Map<String, SerialPort> _ports = {};

  List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
  }

  bool connect(String portName, {int baudRate = 9600}) {
    print('Attemping to connect to printer: $portName (Baud: $baudRate)');
    try {
      if (_ports.containsKey(portName)) {
        if (_ports[portName]!.isOpen) {
          final config = _ports[portName]!.config;
          if (config.baudRate != baudRate) {
            print('Updating baud rate for $portName to $baudRate');
            config.baudRate = baudRate;
            _ports[portName]!.config = config;
          }
          print('Printer $portName is already open.');
          return true;
        }
      }

      final port = SerialPort(portName);
      if (!port.openReadWrite()) {
        print('Failed to open port $portName in ReadWrite mode. Last error: ${SerialPort.lastError}');
        return false;
      }
      
      final config = port.config;
      config.baudRate = baudRate;
      config.bits = 8;
      config.parity = SerialPortParity.none;
      config.stopBits = 1;
      config.setFlowControl(SerialPortFlowControl.none);
      port.config = config;
      
      _ports[portName] = port;
      print('Successfully connected to printer at $portName');
      return true;
    } catch (e) {
      print('Printer connection error ($portName): $e');
      return false;
    }
  }

  void disconnect(String portName) {
    print('Disconnecting printer: $portName');
    _ports[portName]?.close();
    _ports.remove(portName);
  }

  void disconnectAll() {
    print('Disconnecting all printers');
    for (var port in _ports.values) {
      port.close();
    }
    _ports.clear();
  }

  Future<bool> printBytes(String portName, Uint8List bytes) async {
    final port = _ports[portName];
    if (port == null) {
      print('Print error: Port $portName not found in active connections.');
      return false;
    }
    if (!port.isOpen) {
      print('Print error: Port $portName is not open.');
      return false;
    }
    
    print('Sending ${bytes.length} bytes to printer at $portName...');
    try {
      int totalWritten = 0;
      int attempts = 0;
      const int maxAttempts = 20;
      
      while (totalWritten < bytes.length && attempts < maxAttempts) {
        // Splitting into smaller chunks (e.g., 64 bytes) can sometimes help with serial buffers
        final int chunkSize = 64;
        final int nextSize = (totalWritten + chunkSize < bytes.length) 
            ? chunkSize 
            : bytes.length - totalWritten;
            
        final chunk = bytes.sublist(totalWritten, totalWritten + nextSize);
        int written = port.write(chunk, timeout: 500);
        
        if (written > 0) {
          totalWritten += written;
          print('Wrote $written bytes ($totalWritten/${bytes.length})');
          // Small breathing room for the printer
          await Future.delayed(const Duration(milliseconds: 5));
        } else if (written < 0) {
          print('Serial write error (code $written) at $totalWritten bytes');
          break;
        } else {
          attempts++;
          print('Zero bytes written, attempt $attempts/$maxAttempts');
          await Future.delayed(const Duration(milliseconds: 50));
        }
      }

      if (totalWritten == bytes.length) {
        print('Successfully wrote all $totalWritten bytes to $portName');
        return true;
      } else {
        print('Failed to write all bytes to $portName: $totalWritten/${bytes.length} sent.');
        return false;
      }
    } catch (e) {
      print('Print error ($portName): $e');
      return false;
    }
  }

  bool isConnected(String portName) {
    return _ports[portName]?.isOpen ?? false;
  }
}
