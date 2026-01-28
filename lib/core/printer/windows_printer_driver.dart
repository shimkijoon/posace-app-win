import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';
import 'printer_driver.dart';

class WindowsPrinterDriver implements PrinterDriver {
  final String printerName;
  bool _isConnected = false;

  WindowsPrinterDriver({required this.printerName});

  @override
  String get connectionId => printerName;

  @override
  Map<String, dynamic> get params => {'printerName': printerName};

  @override
  bool get isConnected => _isConnected;

  @override
  Future<bool> connect() async {
    // For Windows Spooler, we don't need a persistent connection, 
    // but we can verify the printer exists.
    final phPrinter = calloc<HANDLE>();
    try {
      final pPrinterName = printerName.toNativeUtf16();
      final result = OpenPrinter(pPrinterName, phPrinter, nullptr);
      free(pPrinterName);
      
      if (result != 0) {
        ClosePrinter(phPrinter.value);
        _isConnected = true;
        return true;
      }
      return false;
    } finally {
      free(phPrinter);
    }
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
  }

  @override
  Future<bool> printBytes(Uint8List bytes) async {
    final phPrinter = calloc<HANDLE>();
    final pPrinterName = printerName.toNativeUtf16();
    
    try {
      // 1. Open Printer
      if (OpenPrinter(pPrinterName, phPrinter, nullptr) == 0) {
        print('WindowsPrinterDriver: Failed to open printer $printerName');
        return false;
      }

      final hPrinter = phPrinter.value;
      
      // 2. Start Doc
      final docInfo = calloc<DOC_INFO_1>();
      docInfo.ref.pDocName = 'POSAce Receipt'.toNativeUtf16();
      docInfo.ref.pOutputFile = nullptr;
      docInfo.ref.pDatatype = 'RAW'.toNativeUtf16();

      if (StartDocPrinter(hPrinter, 1, docInfo.cast()) == 0) {
        print('WindowsPrinterDriver: StartDocPrinter failed');
        ClosePrinter(hPrinter);
        return false;
      }

      // 3. Start Page
      StartPagePrinter(hPrinter);

      // 4. Write Data
      final pBytes = calloc<Uint8>(bytes.length);
      pBytes.asTypedList(bytes.length).setAll(0, bytes);
      
      final pcWritten = calloc<DWORD>();
      final writeResult = WritePrinter(hPrinter, pBytes.cast(), bytes.length, pcWritten);
      
      bool success = writeResult != 0 && pcWritten.value == bytes.length;

      // 5. End Page & Doc
      EndPagePrinter(hPrinter);
      EndDocPrinter(hPrinter);
      ClosePrinter(hPrinter);

      // Cleanup docInfo strings
      free(docInfo.ref.pDocName);
      free(docInfo.ref.pDatatype);
      free(docInfo);
      free(pBytes);
      free(pcWritten);

      return success;
    } finally {
      free(pPrinterName);
      free(phPrinter);
    }
  }

  /// Utility to list all installed printers on the system
  static List<String> listPrinters() {
    final pFlags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;
    final pName = nullptr;
    final Level = 2;
    final pPrinterEnum = calloc<BYTE>(1024);
    final cbBuf = 1024;
    final pcbNeeded = calloc<DWORD>();
    final pcReturned = calloc<DWORD>();

    try {
      // First call to get required buffer size
      EnumPrinters(pFlags, pName, Level, nullptr, 0, pcbNeeded, pcReturned);
      
      if (pcbNeeded.value == 0) return [];
      
      final buffer = calloc<BYTE>(pcbNeeded.value);
      if (EnumPrinters(pFlags, pName, Level, buffer, pcbNeeded.value, pcbNeeded, pcReturned) != 0) {
        final result = <String>[];
        final printerInfoArray = buffer.cast<PRINTER_INFO_2>();
        
        for (var i = 0; i < pcReturned.value; i++) {
          final printer = printerInfoArray[i];
          result.add(printer.pPrinterName.toDartString());
        }
        free(buffer);
        return result;
      }
      free(buffer);
      return [];
    } finally {
      free(pPrinterEnum);
      free(pcbNeeded);
      free(pcReturned);
    }
  }
}
