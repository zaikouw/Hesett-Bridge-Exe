import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart' as ffi;

/// libusb FFI bindings for USB device access
/// 
/// This module provides low-level USB access using libusb library.
/// Requires libusb to be installed on the system.

// Platform-specific library loading
DynamicLibrary? _loadLibusb() {
  if (Platform.isMacOS) {
    try {
      return DynamicLibrary.open('libusb-1.0.dylib');
    } catch (e) {
      // Try alternative path
      try {
        return DynamicLibrary.open('/opt/homebrew/lib/libusb-1.0.dylib');
      } catch (_) {
        return null;
      }
    }
  } else if (Platform.isLinux) {
    try {
      return DynamicLibrary.open('libusb-1.0.so.0');
    } catch (e) {
      return null;
    }
  } else if (Platform.isWindows) {
    try {
      return DynamicLibrary.open('libusb-1.0.dll');
    } catch (e) {
      return null;
    }
  }
  return null;
}

final DynamicLibrary? _libusbLib = _loadLibusb();
final bool _libusbAvailable = _libusbLib != null;

// libusb types
typedef LibusbContext = Pointer<Void>;
typedef LibusbDevice = Pointer<Void>;
typedef LibusbDeviceHandle = Pointer<Void>;
typedef LibusbDeviceDescriptor = Struct;

// libusb constants
const int LIBUSB_SUCCESS = 0;
const int LIBUSB_ERROR_NOT_FOUND = -5;
const int LIBUSB_ERROR_ACCESS = -3;
const int LIBUSB_ERROR_BUSY = -6;
const int LIBUSB_ERROR_NO_DEVICE = -4;
const int LIBUSB_ENDPOINT_OUT = 0x00;
const int LIBUSB_TRANSFER_TYPE_BULK = 0x02;
const int LIBUSB_ENDPOINT_DIR_MASK = 0x80;
const int LIBUSB_ENDPOINT_OUT_MASK = 0x00;
const int LIBUSB_ENDPOINT_IN_MASK = 0x80;
const int LIBUSB_TRANSFER_TYPE_MASK = 0x03;

// USB class codes
const int USB_CLASS_PRINTER = 0x07;

// libusb FFI Struct definitions
final class LibusbConfigDescriptor extends Struct {
  @Uint8()
  external int bLength;
  
  @Uint8()
  external int bDescriptorType;
  
  @Uint16()
  external int wTotalLength;
  
  @Uint8()
  external int bNumInterfaces;
  
  @Uint8()
  external int bConfigurationValue;
  
  @Uint8()
  external int iConfiguration;
  
  @Uint8()
  external int bmAttributes;
  
  @Uint8()
  external int MaxPower;
  
  external Pointer<LibusbInterface> interface;
  
  external Pointer<Uint8> extra;
  
  @Int32()
  external int extra_length;
}

final class LibusbInterface extends Struct {
  external Pointer<LibusbInterfaceDescriptor> altsetting;
  
  @Int32()
  external int num_altsetting;
}

final class LibusbInterfaceDescriptor extends Struct {
  @Uint8()
  external int bLength;
  
  @Uint8()
  external int bDescriptorType;
  
  @Uint8()
  external int bInterfaceNumber;
  
  @Uint8()
  external int bAlternateSetting;
  
  @Uint8()
  external int bNumEndpoints;
  
  @Uint8()
  external int bInterfaceClass;
  
  @Uint8()
  external int bInterfaceSubClass;
  
  @Uint8()
  external int bInterfaceProtocol;
  
  @Uint8()
  external int iInterface;
  
  external Pointer<LibusbEndpointDescriptor> endpoint;
  
  external Pointer<Uint8> extra;
  
  @Int32()
  external int extra_length;
}

final class LibusbEndpointDescriptor extends Struct {
  @Uint8()
  external int bLength;
  
  @Uint8()
  external int bDescriptorType;
  
  @Uint8()
  external int bEndpointAddress;
  
  @Uint8()
  external int bmAttributes;
  
  @Uint16()
  external int wMaxPacketSize;
  
  @Uint8()
  external int bInterval;
  
  @Uint8()
  external int bRefresh;
  
  @Uint8()
  external int bSynchAddress;
  
  external Pointer<Uint8> extra;
  
  @Int32()
  external int extra_length;
}

// libusb function signatures
typedef LibusbInitNative = Int32 Function(Pointer<Pointer<Void>>);
typedef LibusbInit = int Function(Pointer<Pointer<Void>>);
typedef LibusbExitNative = Void Function(Pointer<Void>);
typedef LibusbExit = void Function(Pointer<Void>);
typedef LibusbGetDeviceListNative = IntPtr Function(Pointer<Void>, Pointer<Pointer<Pointer<Void>>>);
typedef LibusbGetDeviceList = int Function(Pointer<Void>, Pointer<Pointer<Pointer<Void>>>);
typedef LibusbFreeDeviceListNative = Void Function(Pointer<Pointer<Void>>, Int32);
typedef LibusbFreeDeviceList = void Function(Pointer<Pointer<Void>>, int);
typedef LibusbGetDeviceDescriptorNative = Int32 Function(Pointer<Void>, Pointer<Void>);
typedef LibusbGetDeviceDescriptor = int Function(Pointer<Void>, Pointer<Void>);
typedef LibusbGetBusNumberNative = Uint8 Function(Pointer<Void>);
typedef LibusbGetBusNumber = int Function(Pointer<Void>);
typedef LibusbGetDeviceAddressNative = Uint8 Function(Pointer<Void>);
typedef LibusbGetDeviceAddress = int Function(Pointer<Void>);
typedef LibusbOpenNative = Int32 Function(Pointer<Void>, Pointer<Pointer<Void>>);
typedef LibusbOpen = int Function(Pointer<Void>, Pointer<Pointer<Void>>);
typedef LibusbCloseNative = Void Function(Pointer<Void>);
typedef LibusbClose = void Function(Pointer<Void>);
typedef LibusbClaimInterfaceNative = Int32 Function(Pointer<Void>, Int32);
typedef LibusbClaimInterface = int Function(Pointer<Void>, int);
typedef LibusbReleaseInterfaceNative = Int32 Function(Pointer<Void>, Int32);
typedef LibusbReleaseInterface = int Function(Pointer<Void>, int);
typedef LibusbDetachKernelDriverNative = Int32 Function(Pointer<Void>, Int32);
typedef LibusbDetachKernelDriver = int Function(Pointer<Void>, int);
typedef LibusbAttachKernelDriverNative = Int32 Function(Pointer<Void>, Int32);
typedef LibusbAttachKernelDriver = int Function(Pointer<Void>, int);
typedef LibusbSetAutoDetachKernelDriverNative = Int32 Function(Pointer<Void>, Int32);
typedef LibusbSetAutoDetachKernelDriver = int Function(Pointer<Void>, int);
typedef LibusbSetInterfaceAltSettingNative = Int32 Function(Pointer<Void>, Int32, Int32);
typedef LibusbSetInterfaceAltSetting = int Function(Pointer<Void>, int, int);
typedef LibusbSetConfigurationNative = Int32 Function(Pointer<Void>, Int32);
typedef LibusbSetConfiguration = int Function(Pointer<Void>, int);
typedef LibusbBulkTransferNative = Int32 Function(
    Pointer<Void>, Uint8, Pointer<Uint8>, Int32, Pointer<Int32>, Uint32);
typedef LibusbBulkTransfer = int Function(
    Pointer<Void>, int, Pointer<Uint8>, int, Pointer<Int32>, int);
typedef LibusbGetActiveConfigDescriptorNative = Int32 Function(
    Pointer<Void>, Pointer<Pointer<LibusbConfigDescriptor>>);
typedef LibusbGetActiveConfigDescriptor = int Function(Pointer<Void>, Pointer<Pointer<LibusbConfigDescriptor>>);
typedef LibusbFreeConfigDescriptorNative = Void Function(Pointer<Void>);
typedef LibusbFreeConfigDescriptor = void Function(Pointer<Void>);
typedef LibusbGetStringDescriptorAsciiNative = Int32 Function(
    Pointer<Void>, Uint8, Pointer<Uint8>, Int32);
typedef LibusbGetStringDescriptorAscii = int Function(Pointer<Void>, int, Pointer<Uint8>, int);

// Function pointers
late final LibusbInit? _libusbInit = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbInitNative>>('libusb_init').asFunction()
    : null;
late final LibusbExit? _libusbExit = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbExitNative>>('libusb_exit').asFunction()
    : null;
late final LibusbGetDeviceList? _libusbGetDeviceList = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbGetDeviceListNative>>('libusb_get_device_list').asFunction()
    : null;
late final LibusbFreeDeviceList? _libusbFreeDeviceList = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbFreeDeviceListNative>>('libusb_free_device_list').asFunction()
    : null;
late final LibusbGetDeviceDescriptor? _libusbGetDeviceDescriptor = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbGetDeviceDescriptorNative>>('libusb_get_device_descriptor').asFunction()
    : null;
late final LibusbGetBusNumber? _libusbGetBusNumber = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbGetBusNumberNative>>('libusb_get_bus_number').asFunction()
    : null;
late final LibusbGetDeviceAddress? _libusbGetDeviceAddress = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbGetDeviceAddressNative>>('libusb_get_device_address').asFunction()
    : null;
late final LibusbOpen? _libusbOpen = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbOpenNative>>('libusb_open').asFunction()
    : null;
late final LibusbClose? _libusbClose = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbCloseNative>>('libusb_close').asFunction()
    : null;
late final LibusbClaimInterface? _libusbClaimInterface = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbClaimInterfaceNative>>('libusb_claim_interface').asFunction()
    : null;
late final LibusbReleaseInterface? _libusbReleaseInterface = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbReleaseInterfaceNative>>('libusb_release_interface').asFunction()
    : null;
late final LibusbDetachKernelDriver? _libusbDetachKernelDriver = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbDetachKernelDriverNative>>('libusb_detach_kernel_driver').asFunction()
    : null;
late final LibusbAttachKernelDriver? _libusbAttachKernelDriver = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbAttachKernelDriverNative>>('libusb_attach_kernel_driver').asFunction()
    : null;
late final LibusbSetAutoDetachKernelDriver? _libusbSetAutoDetachKernelDriver = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbSetAutoDetachKernelDriverNative>>('libusb_set_auto_detach_kernel_driver').asFunction()
    : null;
late final LibusbSetInterfaceAltSetting? _libusbSetInterfaceAltSetting = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbSetInterfaceAltSettingNative>>('libusb_set_interface_alt_setting').asFunction()
    : null;
late final LibusbSetConfiguration? _libusbSetConfiguration = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbSetConfigurationNative>>('libusb_set_configuration').asFunction()
    : null;
late final LibusbBulkTransfer? _libusbBulkTransfer = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbBulkTransferNative>>('libusb_bulk_transfer').asFunction()
    : null;
late final LibusbGetActiveConfigDescriptor? _libusbGetActiveConfigDescriptor = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbGetActiveConfigDescriptorNative>>('libusb_get_active_config_descriptor').asFunction()
    : null;
late final LibusbFreeConfigDescriptor? _libusbFreeConfigDescriptor = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbFreeConfigDescriptorNative>>('libusb_free_config_descriptor').asFunction()
    : null;
late final LibusbGetStringDescriptorAscii? _libusbGetStringDescriptorAscii = _libusbLib != null
    ? _libusbLib!.lookup<NativeFunction<LibusbGetStringDescriptorAsciiNative>>('libusb_get_string_descriptor_ascii').asFunction()
    : null;

/// Check if libusb is available
bool isLibusbAvailable() => _libusbAvailable;

/// Parse USB descriptors by byte-walking
/// 
/// ⚠️ WARNING: This implementation has limitations. We're treating the libusb_config_descriptor
/// struct pointer as raw USB descriptor bytes, but the struct contains pointers and padding.
/// The struct's memory layout is NOT the same as the raw USB descriptor stream.
/// 
/// This may work in some cases but is not guaranteed to be reliable across all platforms.
/// 
/// ✅ RECOMMENDED: For macOS, use OS printing (CUPS) instead via discoverOsPrinters/printOs,
/// as it's more stable and avoids kernel driver conflicts. USB raw printing may fail due to
/// macOS claiming the printer device.
/// 
/// This function attempts to read descriptor bytes, but results may be unreliable.
List<UsbInterfaceInfo> _parseUsbDescriptorsByBytes(Pointer<Void> configPtr) {
  final interfaces = <UsbInterfaceInfo>[];
  
  // ⚠️ WARNING: This reads from the struct's memory layout, not raw descriptor bytes
  // The struct has pointers and padding, so this may read garbage values
  final configBytes = configPtr.cast<Uint8>();
  final wTotalLength = configBytes[2] | (configBytes[3] << 8); // Little-endian
  
  // Walk through all descriptors in the config descriptor
  int offset = 9; // Start after config descriptor header
  int currentInterface = -1;
  int currentInterfaceClass = -1;
  
  while (offset < wTotalLength && offset + 2 <= wTotalLength) {
    final bLength = configBytes[offset];
    final bDescriptorType = configBytes[offset + 1];
    
    if (bLength == 0 || offset + bLength > wTotalLength) break;
    
    if (bDescriptorType == 0x04) {
      // Interface descriptor (9 bytes minimum)
      if (bLength >= 9) {
        currentInterface = configBytes[offset + 2]; // bInterfaceNumber
        currentInterfaceClass = configBytes[offset + 5]; // bInterfaceClass
      }
    } else if (bDescriptorType == 0x05 && currentInterface >= 0) {
      // Endpoint descriptor (7 bytes minimum)
      if (bLength >= 7) {
        final bEndpointAddress = configBytes[offset + 2];
        final bmAttributes = configBytes[offset + 3];
        
        // Check if it's a bulk OUT endpoint
        final transferType = bmAttributes & LIBUSB_TRANSFER_TYPE_MASK;
        final isOut = (bEndpointAddress & LIBUSB_ENDPOINT_DIR_MASK) == LIBUSB_ENDPOINT_OUT_MASK;
        
        // Only add if it's a printer interface (class 0x07) and bulk OUT endpoint
        if (currentInterfaceClass == USB_CLASS_PRINTER && 
            transferType == LIBUSB_TRANSFER_TYPE_BULK && 
            isOut) {
          interfaces.add(UsbInterfaceInfo(
            interfaceNumber: currentInterface,
            outEndpoint: bEndpointAddress, // e.g. 0x01 or 0x02
          ));
          // Don't break - there might be multiple endpoints, but we'll use the first one found
          // (the discovery will return all interfaces with their endpoints)
        }
      }
    }
    
    offset += bLength;
  }
  
  return interfaces;
}


/// USB device information including interface/endpoint details
class UsbDeviceInfo {
  final int vendorId;
  final int productId;
  final String? vendorName;
  final String? productName;
  final String? serialNumber;
  final int busNumber;
  final int deviceAddress;
  final List<UsbInterfaceInfo> interfaces;

  UsbDeviceInfo({
    required this.vendorId,
    required this.productId,
    this.vendorName,
    this.productName,
    this.serialNumber,
    required this.busNumber,
    required this.deviceAddress,
    required this.interfaces,
  });

  Map<String, dynamic> toJson() {
    return {
      'vendorId': vendorId,
      'productId': productId,
      'vendorName': vendorName,
      'productName': productName,
      'serialNumber': serialNumber,
      'busNumber': busNumber,
      'deviceAddress': deviceAddress,
      'interfaces': interfaces.map((i) => i.toJson()).toList(),
    };
  }
}

/// USB interface information with endpoint details
class UsbInterfaceInfo {
  final int interfaceNumber;
  final int outEndpoint;

  UsbInterfaceInfo({
    required this.interfaceNumber,
    required this.outEndpoint,
  });

  Map<String, dynamic> toJson() {
    return {
      'interface': interfaceNumber,
      'outEndpoint': outEndpoint,
    };
  }
}

/// Discover USB printers and return interface/endpoint information
/// 
/// ⚠️ NOTE: USB descriptor parsing has limitations and may not work reliably
/// on all platforms due to struct padding/alignment issues.
/// 
/// ✅ RECOMMENDED for macOS: Use OS printing (CUPS) instead via discoverOsPrinters()
/// as it's more stable and avoids kernel driver conflicts. USB raw printing on macOS
/// may fail if the OS has claimed the printer device.
List<UsbDeviceInfo> discoverUsbPrinters() {
  if (!_libusbAvailable) {
    throw UnsupportedError('libusb not available on this system');
  }

  final printers = <UsbDeviceInfo>[];
  final ctxPtr = ffi.malloc<Pointer<Void>>();
  
  try {
    // Initialize libusb
    final result = _libusbInit!(ctxPtr);
    if (result != LIBUSB_SUCCESS) {
      throw Exception('Failed to initialize libusb: $result');
    }
    
    final ctx = ctxPtr.value;
    if (ctx.address == 0) {
      throw Exception('libusb context is null');
    }

    // Get device list
    final deviceListPtr = ffi.malloc<Pointer<Pointer<Void>>>();
    final deviceCount = _libusbGetDeviceList!(ctx, deviceListPtr);
    
    if (deviceCount < 0) {
      _libusbExit!(ctx);
      throw Exception('Failed to get device list: $deviceCount');
    }

    final deviceList = deviceListPtr.value;
    
    try {
      // Iterate through devices
      for (var i = 0; i < deviceCount; i++) {
        final device = deviceList[i];
        if (device.address == 0) continue;

        try {
          // Get device descriptor
          final descPtr = ffi.calloc<Uint8>(18); // USB descriptor is 18 bytes
          final descResult = _libusbGetDeviceDescriptor!(device, descPtr.cast());
          
          if (descResult != LIBUSB_SUCCESS) continue;

          // Parse descriptor (first 18 bytes)
          final desc = descPtr.asTypedList(18);
          final vendorId = desc[8] | (desc[9] << 8);
          final productId = desc[10] | (desc[11] << 8);
          
          // Known receipt printer vendor IDs (optional filter)
          // For now, include all USB devices and let the app filter
          
          // Get bus and address
          final busNumber = _libusbGetBusNumber!(device);
          final deviceAddress = _libusbGetDeviceAddress!(device);
          
          // Open device to get string descriptors and config
          final handlePtr = ffi.malloc<Pointer<Void>>();
          final openResult = _libusbOpen!(device, handlePtr);
          
          String? vendorName;
          String? productName;
          String? serialNumber;
          final interfaces = <UsbInterfaceInfo>[];
          
          if (openResult == LIBUSB_SUCCESS) {
            final handle = handlePtr.value;
            
            try {
              // Get string descriptors
              final strBuf = ffi.calloc<Uint8>(256);
              if (desc[14] > 0) {
                final len = _libusbGetStringDescriptorAscii!(
                    handle, desc[14], strBuf, 256);
                if (len > 0) {
                  vendorName = String.fromCharCodes(strBuf.asTypedList(len));
                }
              }
              if (desc[15] > 0) {
                final len = _libusbGetStringDescriptorAscii!(
                    handle, desc[15], strBuf, 256);
                if (len > 0) {
                  productName = String.fromCharCodes(strBuf.asTypedList(len));
                }
              }
              if (desc[16] > 0) {
                final len = _libusbGetStringDescriptorAscii!(
                    handle, desc[16], strBuf, 256);
                if (len > 0) {
                  serialNumber = String.fromCharCodes(strBuf.asTypedList(len));
                }
              }
              ffi.calloc.free(strBuf);
              
              // Get configuration descriptor to find interfaces/endpoints
              // Use byte-walking approach to avoid struct padding issues
              final configOut = ffi.calloc<Pointer<LibusbConfigDescriptor>>();
              final configResult = _libusbGetActiveConfigDescriptor!(
                device, 
                configOut
              );
              
              if (configResult == LIBUSB_SUCCESS) {
                final cfgPtr = configOut.value.cast<Void>();
                
                try {
                  // Parse descriptors by byte-walking (robust, avoids struct padding issues)
                  final foundInterfaces = _parseUsbDescriptorsByBytes(cfgPtr);
                  interfaces.addAll(foundInterfaces);
                } catch (e) {
                  // If parsing fails, device will be skipped (no interfaces = device not added)
                  print('Warning: Failed to parse USB descriptors for device $vendorId:$productId: $e');
                }
                
                _libusbFreeConfigDescriptor!(cfgPtr);
                ffi.calloc.free(configOut);
              } else {
                ffi.calloc.free(configOut);
              }
            } finally {
              _libusbClose!(handle);
            }
          }
          
          ffi.calloc.free(descPtr);
          ffi.malloc.free(handlePtr);
          
          printers.add(UsbDeviceInfo(
            vendorId: vendorId,
            productId: productId,
            vendorName: vendorName,
            productName: productName,
            serialNumber: serialNumber,
            busNumber: busNumber,
            deviceAddress: deviceAddress,
            interfaces: interfaces,
          ));
        } catch (e) {
          // Skip this device on error
          continue;
        }
      }
    } finally {
      _libusbFreeDeviceList!(deviceList, 1); // unref devices
      ffi.malloc.free(deviceListPtr);
    }
    
    _libusbExit!(ctx);
  } finally {
    ffi.malloc.free(ctxPtr);
  }
  
  return printers;
}

/// Print raw data to USB printer
/// 
/// ⚠️ NOTE: USB raw printing on macOS may fail due to kernel driver conflicts.
/// The OS may have claimed the printer device, preventing libusb from accessing it.
/// 
/// ✅ RECOMMENDED for macOS: Use OS printing (CUPS) instead via printOs() as it's
/// more stable and works with the system's print stack.
/// 
/// [busNumber] and [deviceAddress] are optional but recommended for precise device matching.
/// If not provided, falls back to VID/PID matching only.
void printToUsb({
  required int vendorId,
  required int productId,
  int? busNumber,
  int? deviceAddress,
  required int interfaceNumber,
  required int outEndpoint,
  required List<int> data,
}) {
  if (!_libusbAvailable) {
    throw UnsupportedError('libusb not available on this system');
  }

  final ctxPtr = ffi.malloc<Pointer<Void>>();
  
  try {
    // Initialize libusb
    final result = _libusbInit!(ctxPtr);
    if (result != LIBUSB_SUCCESS) {
      throw Exception('Failed to initialize libusb: $result');
    }
    
    final ctx = ctxPtr.value;
    
    // Get device list
    final deviceListPtr = ffi.malloc<Pointer<Pointer<Void>>>();
    final deviceCount = _libusbGetDeviceList!(ctx, deviceListPtr);
    
    if (deviceCount < 0) {
      _libusbExit!(ctx);
      throw Exception('Failed to get device list: $deviceCount');
    }

    final deviceList = deviceListPtr.value;
    LibusbDeviceHandle? targetHandle;
    
    try {
      // Find target device by VID/PID + bus + address (if provided)
      for (var i = 0; i < deviceCount; i++) {
        final device = deviceList[i];
        if (device.address == 0) continue;

        // If bus and address are provided, check them first (faster and more precise)
        if (busNumber != null && deviceAddress != null) {
          final devBusNumber = _libusbGetBusNumber!(device);
          final devDeviceAddress = _libusbGetDeviceAddress!(device);
          
          if (devBusNumber != busNumber || devDeviceAddress != deviceAddress) {
            continue; // Skip if bus/address don't match
          }
        }

        final descPtr = ffi.calloc<Uint8>(18);
        final descResult = _libusbGetDeviceDescriptor!(device, descPtr.cast());
        
        if (descResult == LIBUSB_SUCCESS) {
          final desc = descPtr.asTypedList(18);
          final vId = desc[8] | (desc[9] << 8);
          final pId = desc[10] | (desc[11] << 8);
          
          if (vId == vendorId && pId == productId) {
            // Found target device (VID/PID match, and bus/address if provided)
            final handlePtr = ffi.malloc<Pointer<Void>>();
            final openResult = _libusbOpen!(device, handlePtr);
            
            if (openResult == LIBUSB_SUCCESS) {
              targetHandle = handlePtr.value;
              ffi.malloc.free(handlePtr);
              ffi.calloc.free(descPtr);
              break;
            }
            
            ffi.malloc.free(handlePtr);
          }
        }
        
        ffi.calloc.free(descPtr);
      }
    } finally {
      _libusbFreeDeviceList!(deviceList, 1);
      ffi.malloc.free(deviceListPtr);
    }
    
    if (targetHandle == null || targetHandle.address == 0) {
      _libusbExit!(ctx);
      final location = (busNumber != null && deviceAddress != null) 
          ? ' bus=$busNumber address=$deviceAddress'
          : '';
      throw Exception('USB device not found: vendorId=$vendorId productId=$productId$location');
    }
    
    try {
      // Enable auto-detach kernel driver (macOS/Linux)
      // This automatically detaches the kernel driver when claiming the interface
      // and reattaches it when releasing
      _libusbSetAutoDetachKernelDriver?.call(targetHandle, 1);
      
      // Try to detach kernel driver if attached (best effort, ignore errors)
      // Some systems may require this to be done manually
      if (_libusbDetachKernelDriver != null) {
        _libusbDetachKernelDriver!(targetHandle, interfaceNumber);
        // LIBUSB_SUCCESS (0) or LIBUSB_ERROR_NOT_FOUND (-5) are both OK
        // -5 means no kernel driver was attached, which is fine
      }
      
      // Set configuration (most devices use configuration 1)
      // This is required by some printers before claiming the interface
      if (_libusbSetConfiguration != null) {
        _libusbSetConfiguration!(targetHandle, 1);
        // LIBUSB_SUCCESS (0) or LIBUSB_ERROR_BUSY (-6) are OK
        // -6 means configuration is already set, which is fine
        // Other errors are ignored (device may not need explicit configuration)
      }
      
      // Claim interface
      final claimResult = _libusbClaimInterface!(targetHandle, interfaceNumber);
      if (claimResult != LIBUSB_SUCCESS) {
        // If claim fails, try attaching kernel driver back (best effort)
        if (_libusbAttachKernelDriver != null && claimResult == LIBUSB_ERROR_BUSY) {
          _libusbAttachKernelDriver!(targetHandle, interfaceNumber);
        }
        throw Exception('Failed to claim interface $interfaceNumber: $claimResult');
      }
      
      try {
        // Prepare data
        final dataPtr = ffi.calloc<Uint8>(data.length);
        dataPtr.asTypedList(data.length).setRange(0, data.length, data);
        
        // Perform bulk transfer
        final transferredPtr = ffi.malloc<Int32>();
        final transferResult = _libusbBulkTransfer!(
          targetHandle,
          outEndpoint,
          dataPtr,
          data.length,
          transferredPtr,
          5000, // 5 second timeout
        );
        
        ffi.calloc.free(dataPtr);
        final transferred = transferredPtr.value;
        ffi.malloc.free(transferredPtr);
        
        if (transferResult != LIBUSB_SUCCESS) {
          throw Exception('Bulk transfer failed: $transferResult');
        }
        
        if (transferred != data.length) {
          throw Exception('Partial transfer: $transferred/${data.length} bytes');
        }
      } finally {
        // Release interface
        _libusbReleaseInterface!(targetHandle, interfaceNumber);
        // Reattach kernel driver if we detached it (best effort)
        // Note: set_auto_detach_kernel_driver should handle this automatically,
        // but we do it manually as a fallback
        if (_libusbAttachKernelDriver != null) {
          _libusbAttachKernelDriver!(targetHandle, interfaceNumber);
        }
      }
    } finally {
      _libusbClose!(targetHandle);
    }
    
    _libusbExit!(ctx);
  } finally {
    ffi.malloc.free(ctxPtr);
  }
}

