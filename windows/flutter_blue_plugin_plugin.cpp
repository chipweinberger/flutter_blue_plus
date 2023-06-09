#include "include/flutter_blue_plugin/flutter_blue_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Windows.Devices.Radios.h>
#include <winrt/Windows.Devices.Bluetooth.h>
#include <winrt/Windows.Devices.Bluetooth.Advertisement.h>
#include <winrt/Windows.Devices.Bluetooth.GenericAttributeProfile.h>
#include <winrt/Windows.Devices.Enumeration.h>

#include <flutter/method_channel.h>
#include <flutter/basic_message_channel.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/standard_message_codec.h>

#include <map>
#include <memory>
#include <sstream>
#include <algorithm>
#include <iomanip>

const winrt::guid CMSN_DATA_STREAM_SERVICE_UUID     = {0x0D740001,0xD26F,0x4DBB,{0x95,0xE8,0xA4,0xF5,0xC5,0x5C,0x57,0xA9}};
const winrt::guid BSTAR_DATA_STREAM_SERVICE_UUID    = {0x6E400001,0xB5A3,0xF393,{0xE0,0xA9,0xE5,0x0E,0x24,0xDC,0xCA,0x9E}};
const winrt::guid MORPHEUS_DATA_STREAM_SERVICE_UUID = {0x4DE5A20C,0x0001,0xAE02,{0xBF,0x63,0x02,0x42,0xAC,0x13,0x00,0x02}};

const std::string MORPHEUS_UUID_STRING = "4de5a20c-0001-ae02-bf63-0242ac130002"; 

#define GUID_FORMAT "%08x-%04hx-%04hx-%02hhx%02hhx-%02hhx%02hhx%02hhx%02hhx%02hhx%02hhx"
#define GUID_ARG(guid) guid.Data1, guid.Data2, guid.Data3, guid.Data4[0], guid.Data4[1], guid.Data4[2], guid.Data4[3], guid.Data4[4], guid.Data4[5], guid.Data4[6], guid.Data4[7]

namespace {

using namespace winrt;
using namespace winrt::Windows::Foundation;
using namespace winrt::Windows::Foundation::Collections;
using namespace winrt::Windows::Storage::Streams;
using namespace winrt::Windows::Devices::Radios;
using namespace winrt::Windows::Devices::Bluetooth;
using namespace winrt::Windows::Devices::Bluetooth::Advertisement;
using namespace winrt::Windows::Devices::Bluetooth::GenericAttributeProfile;
using namespace winrt::Windows::Devices::Enumeration;

using flutter::EncodableValue;
using flutter::EncodableMap;

union uint16_t_union {
  uint16_t uint16;
  byte bytes[sizeof(uint16_t)];
};

std::vector<uint8_t> to_bytevc(IBuffer buffer) {
  auto reader = DataReader::FromBuffer(buffer);
  auto result = std::vector<uint8_t>(reader.UnconsumedBufferLength());
  reader.ReadBytes(result);
  return result;
}

IBuffer from_bytevc(std::vector<uint8_t> bytes) {
  auto writer = DataWriter();
  writer.WriteBytes(bytes);
  return writer.DetachBuffer();
}

std::string to_hexstring(std::vector<uint8_t> bytes) {
  auto ss = std::stringstream();
  for (auto b : bytes)
      ss << std::setw(2) << std::setfill('0') << std::hex << static_cast<int>(b);
  return ss.str();
}

std::string to_uuidstr(winrt::guid guid) {
  char chars[36 + 1];
  sprintf_s(chars, GUID_FORMAT, GUID_ARG(guid));
  return std::string{ chars };
}

struct BluetoothDeviceAgent {
  BluetoothLEDevice device;
  winrt::event_token connnectionStatusChangedToken;
  std::map<std::string, GattDeviceService> gattServices;
  std::map<std::string, GattCharacteristic> gattCharacteristics;
  std::map<std::string, winrt::event_token> valueChangedTokens;

  BluetoothDeviceAgent(BluetoothLEDevice device, winrt::event_token connnectionStatusChangedToken)
      : device(device),
        connnectionStatusChangedToken(connnectionStatusChangedToken) {}

  ~BluetoothDeviceAgent() {
    device = nullptr;
  }

  IAsyncOperation<GattDeviceService> GetServiceAsync(std::string service) {
    if (gattServices.count(service) == 0) {
      auto serviceResult = co_await device.GetGattServicesAsync();
      if (serviceResult.Status() != GattCommunicationStatus::Success)
        co_return nullptr;

      for (auto s : serviceResult.Services())
        if (to_uuidstr(s.Uuid()) == service)
          gattServices.insert(std::make_pair(service, s));
    }
    co_return gattServices.at(service);
  }

  IAsyncOperation<GattCharacteristic> GetCharacteristicAsync(std::string service, std::string characteristic) {
    if (gattCharacteristics.count(characteristic) == 0) {
      auto gattService = co_await GetServiceAsync(service);

      auto characteristicResult = co_await gattService.GetCharacteristicsAsync();
      if (characteristicResult.Status() != GattCommunicationStatus::Success)
        co_return nullptr;

      for (auto c : characteristicResult.Characteristics())
        if (to_uuidstr(c.Uuid()) == characteristic)
          gattCharacteristics.insert(std::make_pair(characteristic, c));
    }
    co_return gattCharacteristics.at(characteristic);
  }
};

class FlutterBluePlugin : public flutter::Plugin, public flutter::StreamHandler<EncodableValue> {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterBluePlugin();

  virtual ~FlutterBluePlugin();

 private:
   winrt::fire_and_forget InitializeAsync();

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::StreamHandlerError<>> OnListenInternal(
      const EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<>>&& events) override;
  std::unique_ptr<flutter::StreamHandlerError<>> OnCancelInternal(
      const EncodableValue* arguments) override;

  std::unique_ptr<flutter::BasicMessageChannel<EncodableValue>> message_connector_;

  std::unique_ptr<flutter::EventSink<EncodableValue>> scan_result_sink_;
  std::unique_ptr<flutter::EventSink<EncodableValue>> paired_devices_sink_;

  Radio bluetoothRadio{ nullptr };

  BluetoothLEAdvertisementWatcher bluetoothLEWatcher{ nullptr };
  winrt::event_token bluetoothLEWatcherReceivedToken;
  void BluetoothLEWatcher_Received(BluetoothLEAdvertisementWatcher sender, BluetoothLEAdvertisementReceivedEventArgs args);

  DeviceWatcher deviceWatcher{ nullptr };
  winrt::event_token deviceWatcherAddedToken;
  winrt::event_token deviceWatcherUpdatedToken;
  winrt::event_token deviceWatcherRemovedToken;
  winrt::event_token deviceWatcherEnumerationCompletedToken;
  winrt::event_token deviceWatcherStoppedToken;
  void DeviceWatcher_Added(DeviceWatcher sender, DeviceInformation info);
  void DeviceWatcher_Updated(DeviceWatcher sender, DeviceInformationUpdate info);
  void DeviceWatcher_Removed(DeviceWatcher sender, DeviceInformationUpdate info);
  void DeviceWatcher_EnumerationCompleted(DeviceWatcher sender, IInspectable obj);
  void DeviceWatcher_Stopped(DeviceWatcher sender, IInspectable obj);

  bool IsDeviceWatcherStarted();
  bool IsDeviceWatcherRunning();

  std::map<uint64_t, std::unique_ptr<BluetoothDeviceAgent>> connectedDevices{};

  winrt::fire_and_forget ConnectAsync(uint64_t bluetoothAddress);
  void BluetoothLEDevice_ConnectionStatusChanged(BluetoothLEDevice sender, IInspectable args);
  void CleanConnection(uint64_t bluetoothAddress, bool dispose);

  winrt::fire_and_forget SetNotifiableAsync(BluetoothDeviceAgent& bluetoothDeviceAgent, std::string service, std::string characteristic, std::string bleInputProperty);
  winrt::fire_and_forget RequestMtuAsync(BluetoothDeviceAgent& bluetoothDeviceAgent, uint64_t expectedMtu);
  winrt::fire_and_forget ReadValueAsync(BluetoothDeviceAgent& bluetoothDeviceAgent, std::string service, std::string characteristic);
  winrt::fire_and_forget WriteValueAsync(BluetoothDeviceAgent& bluetoothDeviceAgent, std::string service, std::string characteristic, std::vector<uint8_t> value, std::string bleOutputProperty);
  void FlutterBluePlugin::GattCharacteristic_ValueChanged(GattCharacteristic sender, GattValueChangedEventArgs args);
};

// static
void FlutterBluePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto method =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          registrar->messenger(), "flutter_blue_plugin/method",
          &flutter::StandardMethodCodec::GetInstance());
  auto message_connector_ =
      std::make_unique<flutter::BasicMessageChannel<EncodableValue>>(
          registrar->messenger(), "flutter_blue_plugin/message.connector",
          &flutter::StandardMessageCodec::GetInstance());

  auto event_scan_result =
      std::make_unique<flutter::EventChannel<EncodableValue>>(
          registrar->messenger(), "flutter_blue_plugin/event.scanResult",
          &flutter::StandardMethodCodec::GetInstance());
  auto event_paired_devices =
      std::make_unique<flutter::EventChannel<EncodableValue>>(
          registrar->messenger(), "flutter_blue_plugin/event.pairedDevices",
          &flutter::StandardMethodCodec::GetInstance());        

  auto plugin = std::make_unique<FlutterBluePlugin>();

  method->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  auto handler = std::make_unique<
      flutter::StreamHandlerFunctions<>>(
      [plugin_pointer = plugin.get()](
          const EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        return plugin_pointer->OnListen(arguments, std::move(events));
      },
      [plugin_pointer = plugin.get()](const EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        return plugin_pointer->OnCancel(arguments);
      });
  event_scan_result->SetStreamHandler(std::move(handler));

  auto handler2 = std::make_unique<
      flutter::StreamHandlerFunctions<>>(
      [plugin_pointer = plugin.get()](
          const EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        return plugin_pointer->OnListen(arguments, std::move(events));
      },
      [plugin_pointer = plugin.get()](const EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        return plugin_pointer->OnCancel(arguments);
      });
  event_paired_devices->SetStreamHandler(std::move(handler2));

  plugin->message_connector_ = std::move(message_connector_);

  registrar->AddPlugin(std::move(plugin));
}

FlutterBluePlugin::FlutterBluePlugin() {
  InitializeAsync();
}

FlutterBluePlugin::~FlutterBluePlugin() {}

winrt::fire_and_forget FlutterBluePlugin::InitializeAsync() {
  auto bluetoothAdapter = co_await BluetoothAdapter::GetDefaultAsync();
  bluetoothRadio = co_await bluetoothAdapter.GetRadioAsync();
}

void FlutterBluePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  auto method_name = method_call.method_name();
  OutputDebugString((L"HandleMethodCall " + winrt::to_hstring(method_name) + L"\n").c_str());
  if (method_name.compare("isBluetoothAvailable") == 0) {
    result->Success(EncodableValue(bluetoothRadio && bluetoothRadio.State() == RadioState::On));

  } else if (method_name.compare("startScanPairedDevices") == 0) { 
    if (!deviceWatcher) {
      /// fetch paired devices
      // auto aqsFilter = L"System.Devices.Aep.ProtocolId:=\"{e0cbf06c-cd8b-4647-bb8a-263b43f0f974}\" AND System.Devices.Aep.IsPaired:=System.StructuredQueryType.Boolean#True";
      // auto aqsFilter = BluetoothDevice::GetDeviceSelectorFromPairingState(true) + L" AND System.Devices.Aep.IsConnected:=System.StructuredQueryType.Boolean#True";
      auto aqsFilter = BluetoothDevice::GetDeviceSelectorFromPairingState(true);
      auto requestedProperties = {
        // L"System.Devices.Aep.AepId",
        L"System.Devices.Aep.IsConnected",
        L"System.Devices.Aep.DeviceAddress"
        // L"System.Devices.Aep.Bluetooth.Le.IsConnectable",
        // L"System.Devices.Aep.Bluetooth.Cod.Major",
        // L"System.Devices.AepService.Bluetooth.ServiceGuid"
      };
      deviceWatcher = DeviceInformation::CreateWatcher(aqsFilter, requestedProperties, DeviceInformationKind::AssociationEndpoint);
      // TODO check if need, this => get_weak()  
      deviceWatcherAddedToken = deviceWatcher.Added({ this, &FlutterBluePlugin::DeviceWatcher_Added });
      deviceWatcherUpdatedToken = deviceWatcher.Updated({ this, &FlutterBluePlugin::DeviceWatcher_Updated });
      deviceWatcherRemovedToken = deviceWatcher.Removed({ this, &FlutterBluePlugin::DeviceWatcher_Removed });
      deviceWatcherEnumerationCompletedToken = deviceWatcher.EnumerationCompleted({ this, &FlutterBluePlugin::DeviceWatcher_EnumerationCompleted });
      deviceWatcherStoppedToken = deviceWatcher.Stopped({ this, &FlutterBluePlugin::DeviceWatcher_Stopped });
    }
    deviceWatcher.Start();
    result->Success(nullptr);

  } else if (method_name.compare("stopScanPairedDevices") == 0) { 
    if (deviceWatcher && IsDeviceWatcherStarted()) {
      // We do not null out the deviceWatcher yet because we want to receive the Stopped event.
      deviceWatcher.Stop();
    }
    result->Success(nullptr);

  } else if (method_name.compare("startScan") == 0) {
    if (!bluetoothLEWatcher) {
      bluetoothLEWatcher = BluetoothLEAdvertisementWatcher();
      bluetoothLEWatcher.SignalStrengthFilter().InRangeThresholdInDBm(-70);
      bluetoothLEWatcher.SignalStrengthFilter().OutOfRangeThresholdInDBm(-75);
      auto args = std::get<EncodableMap>(*method_call.arguments());
      if (args.size() > 0) {
        auto serviceUuid = std::get<std::string>(args[EncodableValue("serviceUuid")]);
        if (serviceUuid == MORPHEUS_UUID_STRING) {
          //TODO
          //bluetoothLEWatcher.AdvertisementFilter().Advertisement().ServiceUuids().Append(MORPHEUS_DATA_STREAM_SERVICE_UUID);
        }
      }
      // bluetoothLEWatcher.SignalStrengthFilter().OutOfRangeTimeout(std::chrono::milliseconds{ 2000 });
      bluetoothLEWatcherReceivedToken = bluetoothLEWatcher.Received({ this, &FlutterBluePlugin::BluetoothLEWatcher_Received });
    }
    bluetoothLEWatcher.Start();
    result->Success(nullptr);
  } else if (method_name.compare("stopScan") == 0) {
    if (bluetoothLEWatcher) {
      bluetoothLEWatcher.Stop();
      bluetoothLEWatcher.Received(bluetoothLEWatcherReceivedToken);
    }
    bluetoothLEWatcher = nullptr;
    result->Success(nullptr);
  } else if (method_name.compare("connect") == 0) {
    auto args = std::get<EncodableMap>(*method_call.arguments());
    auto deviceId = std::get<std::string>(args[EncodableValue("deviceId")]);
    ConnectAsync(std::stoull(deviceId));
    result->Success(nullptr);
  } else if (method_name.compare("disconnect") == 0) {
    auto args = std::get<EncodableMap>(*method_call.arguments());
    auto deviceId = std::get<std::string>(args[EncodableValue("deviceId")]);
    CleanConnection(std::stoull(deviceId), true);
    result->Success(nullptr);
  } else if (method_name.compare("discoverServices") == 0) {
    // TODO
    result->Success(nullptr);
  } else if (method_name.compare("setNotifiable") == 0) {
    auto args = std::get<EncodableMap>(*method_call.arguments());
    auto deviceId = std::get<std::string>(args[EncodableValue("deviceId")]);
    auto service = std::get<std::string>(args[EncodableValue("service")]);
    auto characteristic = std::get<std::string>(args[EncodableValue("characteristic")]);
    auto bleInputProperty = std::get<std::string>(args[EncodableValue("bleInputProperty")]);
    auto it = connectedDevices.find(std::stoull(deviceId));
    if (it == connectedDevices.end()) {
      result->Error("IllegalArgument", "Unknown devicesId:" + deviceId);
      return;
    }

    SetNotifiableAsync(*it->second, service, characteristic, bleInputProperty);
    result->Success(nullptr);
  } else if (method_name.compare("requestMtu") == 0) {
    auto args = std::get<EncodableMap>(*method_call.arguments());
    auto deviceId = std::get<std::string>(args[EncodableValue("deviceId")]);
    auto expectedMtu = std::get<int32_t>(args[EncodableValue("expectedMtu")]);
    auto it = connectedDevices.find(std::stoull(deviceId));
    if (it == connectedDevices.end()) {
      result->Error("IllegalArgument", "Unknown devicesId:" + deviceId);
      return;
    }

    RequestMtuAsync(*it->second, expectedMtu);
    result->Success(nullptr);
  } else if (method_name.compare("readValue") == 0) {
    auto args = std::get<EncodableMap>(*method_call.arguments());
    auto deviceId = std::get<std::string>(args[EncodableValue("deviceId")]);
    auto service = std::get<std::string>(args[EncodableValue("service")]);
    auto characteristic = std::get<std::string>(args[EncodableValue("characteristic")]);
    auto it = connectedDevices.find(std::stoull(deviceId));
    if (it == connectedDevices.end()) {
      result->Error("IllegalArgument", "Unknown devicesId:" + deviceId);
      return;
    }

    ReadValueAsync(*it->second, service, characteristic);
    result->Success(nullptr);
  } else if (method_name.compare("writeValue") == 0) {
    auto args = std::get<EncodableMap>(*method_call.arguments());
    auto deviceId = std::get<std::string>(args[EncodableValue("deviceId")]);
    auto service = std::get<std::string>(args[EncodableValue("service")]);
    auto characteristic = std::get<std::string>(args[EncodableValue("characteristic")]);
    auto value = std::get<std::vector<uint8_t>>(args[EncodableValue("value")]);
    auto bleOutputProperty = std::get<std::string>(args[EncodableValue("bleOutputProperty")]);
    auto it = connectedDevices.find(std::stoull(deviceId));
    if (it == connectedDevices.end()) {
      result->Error("IllegalArgument", "Unknown devicesId:" + deviceId);
      return;
    }

    WriteValueAsync(*it->second, service, characteristic, value, bleOutputProperty);
    result->Success(nullptr);
  } else {
    result->NotImplemented();
  }
}

bool lookupBooleanProperty(DeviceInformation deviceInfo, param::hstring const& property) {
  auto value = deviceInfo.Properties().TryLookup(property);
  return value && unbox_value<bool>(value);
}

winrt::hstring lookupStringProperty(DeviceInformation deviceInfo, param::hstring const& property) {
  auto value = deviceInfo.Properties().TryLookup(property);
  return unbox_value<winrt::hstring>(value);
}

uint64_t string_to_mac(std::string const& s) {
    unsigned char a[6];
    int last = -1;
    int rc = sscanf_s(s.c_str(), "%hhx:%hhx:%hhx:%hhx:%hhx:%hhx%n",
                    a + 0, a + 1, a + 2, a + 3, a + 4, a + 5,
                    &last);
    if(rc != 6 || s.size() != last)
        throw std::runtime_error("invalid mac address format " + s);
    return
        uint64_t(a[0]) << 40 |
        uint64_t(a[1]) << 32 | ( 
            // 32-bit instructions take fewer bytes on x86, so use them as much as possible.
            uint32_t(a[2]) << 24 | 
            uint32_t(a[3]) << 16 |
            uint32_t(a[4]) << 8 |
            uint32_t(a[5])
        );
}

std::vector<uint8_t> parseManufacturerData(BluetoothLEAdvertisement advertisement)  {
  if (advertisement.ManufacturerData().Size() == 0)
    return std::vector<uint8_t>();

  auto manufacturerData = advertisement.ManufacturerData().GetAt(0);
  // FIXME Compat with REG_DWORD_BIG_ENDIAN
  uint8_t* prefix = uint16_t_union{ manufacturerData.CompanyId() }.bytes;
  auto result = std::vector<uint8_t>{ prefix, prefix + sizeof(uint16_t_union) };

  auto data = to_bytevc(manufacturerData.Data());
  result.insert(result.end(), data.begin(), data.end());
  return result;
}

bool FlutterBluePlugin::IsDeviceWatcherStarted() {
    if (deviceWatcher == nullptr) return false;

    DeviceWatcherStatus status = deviceWatcher.Status();
    return status == DeviceWatcherStatus::Started || 
           status == DeviceWatcherStatus::EnumerationCompleted;
}

bool FlutterBluePlugin::IsDeviceWatcherRunning() {
    if (deviceWatcher == nullptr) return false;

    DeviceWatcherStatus status = deviceWatcher.Status();
    return status == DeviceWatcherStatus::Started || 
           status == DeviceWatcherStatus::EnumerationCompleted ||
           status == DeviceWatcherStatus::Stopping;
}

void FlutterBluePlugin::DeviceWatcher_Added(DeviceWatcher sender, DeviceInformation info) {
  // Since we have the collection databound to a UI element, we need to update the collection on the UI thread.
  // co_await resume_foreground(dispatcher);

  auto isConnected = lookupBooleanProperty(info, L"System.Devices.Aep.IsConnected");
  // auto aepId = lookupStringProperty(info, L"System.Devices.Aep.AepId");
  auto address = lookupStringProperty(info, L"System.Devices.Aep.DeviceAddress");

  OutputDebugString((L"DeviceWatcher_Added " + winrt::to_hstring(info.Id()) + L"\n").c_str());
  OutputDebugString((L"DeviceWatcher_Added " + winrt::to_hstring(info.Name()) + L"\n").c_str());
  OutputDebugString((L"DeviceWatcher_Added " + winrt::to_hstring(address) + L"\n").c_str());
  OutputDebugString((L"DeviceWatcher_Added, isConnected=" + winrt::to_hstring(isConnected) + L"\n").c_str());
  // OutputDebugString((L"DeviceWatcher_Added " + winrt::to_hstring(aepId) + L"\n").c_str());

  // Watcher may have stopped while we were waiting for our chance to run.
  if (paired_devices_sink_ && IsDeviceWatcherStarted()) {
    //auto st = info.Properties();
    paired_devices_sink_->Success(EncodableMap{
     {"status", int64_t(sender.Status())},
     {"deviceId", winrt::to_string(info.Id())},
     {"name", winrt::to_string(info.Name())},
     {"isConnected", isConnected},
     {"address", (int64_t)string_to_mac(winrt::to_string(address))}
    });
  }
}

void FlutterBluePlugin::DeviceWatcher_Updated(DeviceWatcher sender, DeviceInformationUpdate info) {
  // Watcher may have stopped while we were waiting for our chance to run.
  auto value = info.Properties().TryLookup(L"System.Devices.Aep.IsConnected");
  auto isConnected = value && unbox_value<bool>(value);
  OutputDebugString((L"DeviceWatcher_Updated " + winrt::to_hstring(info.Id()) + L"\n").c_str());
  OutputDebugString((L"DeviceWatcher_Updated, isConnected=" + winrt::to_hstring(isConnected) + L"\n").c_str());

  if (paired_devices_sink_ && IsDeviceWatcherStarted()) {
    paired_devices_sink_->Success(EncodableMap{
      {"status", int64_t(sender.Status())},
      {"deviceId", winrt::to_string(info.Id())},
      {"isConnected", isConnected}
    });
  }
}

void FlutterBluePlugin::DeviceWatcher_Removed(DeviceWatcher sender, DeviceInformationUpdate info) {
  // Watcher may have stopped while we were waiting for our chance to run.
  auto value = info.Properties().TryLookup(L"System.Devices.Aep.IsConnected");
  auto isConnected = value && unbox_value<bool>(value);
  OutputDebugString((L"DeviceWatcher_Removed " + winrt::to_hstring(info.Id()) + L"\n").c_str());
  OutputDebugString((L"DeviceWatcher_Removed, isConnected=" + winrt::to_hstring(isConnected) + L"\n").c_str());

  if (paired_devices_sink_ && IsDeviceWatcherStarted()) {
    paired_devices_sink_->Success(EncodableMap{
      {"status", int64_t(sender.Status())},
      {"deviceId", winrt::to_string(info.Id())},
      {"isConnected", isConnected}
    });
  }
}

void FlutterBluePlugin::DeviceWatcher_EnumerationCompleted(DeviceWatcher sender, IInspectable obj) {
  printf("DeviceWatcher_EnumerationCompleted\n");
  if (paired_devices_sink_) {
    paired_devices_sink_->Success(EncodableMap{
      {"status", int64_t(sender.Status())}
    });
  }
}
void FlutterBluePlugin::DeviceWatcher_Stopped(DeviceWatcher sender, IInspectable obj) {
  printf("DeviceWatcher_Stopped\n");
  if (paired_devices_sink_) {
    paired_devices_sink_->Success(EncodableMap{
      {"status", int64_t(sender.Status())}
    });
  }
}

void FlutterBluePlugin::BluetoothLEWatcher_Received(
    BluetoothLEAdvertisementWatcher sender,
    BluetoothLEAdvertisementReceivedEventArgs args) {
  //OutputDebugString((L"Received " + winrt::to_hstring(args.BluetoothAddress()) + L"\n").c_str());
  auto manufacturer_data = parseManufacturerData(args.Advertisement());
  if (scan_result_sink_) {
    auto bluetoothAddress = args.BluetoothAddress();
    auto localName = args.Advertisement().LocalName();
    auto name = winrt::to_string(localName);
    if (localName.empty()) {
      // TODO
      // auto device = co_await BluetoothLEDevice::FromBluetoothAddressAsync(bluetoothAddress);
      // name = winrt::to_string(device.Name());

      std::stringstream sstream;
      sstream << std::hex << bluetoothAddress;
      name = sstream.str();
    }
    scan_result_sink_->Success(EncodableMap{
      {"name", name},
      {"deviceId", std::to_string(bluetoothAddress)},
      {"manufacturerData", manufacturer_data},
      {"rssi", args.RawSignalStrengthInDBm()},
      // TODO
      // {"serviceUuids", args.Advertisement().ServiceUuids()},
    });
  }
}

std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> FlutterBluePlugin::OnListenInternal(
    const EncodableValue* arguments, std::unique_ptr<flutter::EventSink<EncodableValue>>&& events)
{
  if (arguments == nullptr) {
    return nullptr;
  }
  auto args = std::get<EncodableMap>(*arguments);
  auto name = std::get<std::string>(args[EncodableValue("name")]);
  if (name.compare("scanResult") == 0) {
    scan_result_sink_ = std::move(events);
  } else if (name.compare("pairedDevices") == 0) {
    paired_devices_sink_ = std::move(events);
  } 
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<EncodableValue>> FlutterBluePlugin::OnCancelInternal(
    const EncodableValue* arguments)
{
  if (arguments == nullptr) {
    return nullptr;
  }
  auto args = std::get<EncodableMap>(*arguments);
  auto name = std::get<std::string>(args[EncodableValue("name")]);
  if (name.compare("scanResult") == 0) {
    scan_result_sink_ = nullptr;
  } else if (name.compare("pairedDevices") == 0) {
    paired_devices_sink_ = nullptr;
  } 
  return nullptr;
}

winrt::fire_and_forget FlutterBluePlugin::ConnectAsync(uint64_t bluetoothAddress) {
    OutputDebugString((L"ConnectAsync " + winrt::to_hstring(bluetoothAddress) + L"\n").c_str());
  auto device = co_await BluetoothLEDevice::FromBluetoothAddressAsync(bluetoothAddress);
  auto servicesResult = co_await device.GetGattServicesAsync();
  if (servicesResult.Status() != GattCommunicationStatus::Success) {
    OutputDebugString((L"GetGattServicesAsync error: " + winrt::to_hstring((int32_t)servicesResult.Status()) + L"\n").c_str());
    message_connector_->Send(EncodableMap{
      {"deviceId", std::to_string(bluetoothAddress)},
      {"ConnectionState", "disconnected"},
    });
    co_return;
  }
  auto connnectionStatusChangedToken = device.ConnectionStatusChanged({ this, &FlutterBluePlugin::BluetoothLEDevice_ConnectionStatusChanged });
  auto deviceAgent = std::make_unique<BluetoothDeviceAgent>(device, connnectionStatusChangedToken);
  auto pair = std::make_pair(bluetoothAddress, std::move(deviceAgent));
  connectedDevices.insert(std::move(pair));

  message_connector_->Send(EncodableMap{
    {"deviceId", std::to_string(bluetoothAddress)},
    {"ConnectionState", "connected"},
  });
}

void FlutterBluePlugin::BluetoothLEDevice_ConnectionStatusChanged(BluetoothLEDevice sender, IInspectable args) {
  OutputDebugString((L"ConnectionStatusChanged " + winrt::to_hstring((int32_t)sender.ConnectionStatus()) + L"\n").c_str());
  if (sender.ConnectionStatus() == BluetoothConnectionStatus::Disconnected) {
    CleanConnection(sender.BluetoothAddress(), false);
  }
}

void FlutterBluePlugin::CleanConnection(uint64_t bluetoothAddress, bool dispose) {
  auto node = connectedDevices.extract(bluetoothAddress);
  if (!node.empty()) {
    auto deviceAgent = std::move(node.mapped());
    if (dispose) deviceAgent->device.Close();
    deviceAgent->device.ConnectionStatusChanged(deviceAgent->connnectionStatusChangedToken);
    for (auto& tokenPair : deviceAgent->valueChangedTokens) {
      deviceAgent->gattCharacteristics.at(tokenPair.first).ValueChanged(tokenPair.second);
    }
  }
  message_connector_->Send(EncodableMap{
      {"deviceId", std::to_string(bluetoothAddress)},
      {"ConnectionState", "disconnected"},
    });
}

winrt::fire_and_forget FlutterBluePlugin::RequestMtuAsync(BluetoothDeviceAgent& bluetoothDeviceAgent, uint64_t expectedMtu) {
  OutputDebugString(L"RequestMtuAsync expectedMtu");
  auto gattSession = co_await GattSession::FromDeviceIdAsync(bluetoothDeviceAgent.device.BluetoothDeviceId());
  message_connector_->Send(EncodableMap{
    {"mtuConfig", (int64_t)gattSession.MaxPduSize()},
  });
}

winrt::fire_and_forget FlutterBluePlugin::SetNotifiableAsync(BluetoothDeviceAgent& bluetoothDeviceAgent, std::string service, std::string characteristic, std::string bleInputProperty) {
  auto gattCharacteristic = co_await bluetoothDeviceAgent.GetCharacteristicAsync(service, characteristic);
  auto descriptorValue = bleInputProperty == "notification" ? GattClientCharacteristicConfigurationDescriptorValue::Notify
    : bleInputProperty == "indication" ? GattClientCharacteristicConfigurationDescriptorValue::Indicate
    : GattClientCharacteristicConfigurationDescriptorValue::None;
  auto writeDescriptorStatus = co_await gattCharacteristic.WriteClientCharacteristicConfigurationDescriptorAsync(descriptorValue);
  if (writeDescriptorStatus != GattCommunicationStatus::Success)
    OutputDebugString((L"WriteClientCharacteristicConfigurationDescriptorAsync " + winrt::to_hstring((int32_t)writeDescriptorStatus) + L"\n").c_str());

  if (bleInputProperty != "disabled") {
    bluetoothDeviceAgent.valueChangedTokens[characteristic] = gattCharacteristic.ValueChanged({ this, &FlutterBluePlugin::GattCharacteristic_ValueChanged });
  } else {
    gattCharacteristic.ValueChanged(std::exchange(bluetoothDeviceAgent.valueChangedTokens[characteristic], {}));
  }
}

winrt::fire_and_forget FlutterBluePlugin::ReadValueAsync(BluetoothDeviceAgent& bluetoothDeviceAgent, std::string service, std::string characteristic) {
  auto gattCharacteristic = co_await bluetoothDeviceAgent.GetCharacteristicAsync(service, characteristic);
  auto readValueResult = co_await gattCharacteristic.ReadValueAsync();
  auto bytes = to_bytevc(readValueResult.Value());
  OutputDebugString((L"ReadValueAsync " + winrt::to_hstring(characteristic) + L", " + winrt::to_hstring(to_hexstring(bytes)) + L"\n").c_str());
  message_connector_->Send(EncodableMap{
    {"deviceId", std::to_string(gattCharacteristic.Service().Device().BluetoothAddress())},
    {"characteristicValue", EncodableMap{
      {"characteristic", characteristic},
      {"value", bytes},
    }},
  });
}

winrt::fire_and_forget FlutterBluePlugin::WriteValueAsync(BluetoothDeviceAgent& bluetoothDeviceAgent, std::string service, std::string characteristic, std::vector<uint8_t> value, std::string bleOutputProperty) {
  auto gattCharacteristic = co_await bluetoothDeviceAgent.GetCharacteristicAsync(service, characteristic);
  auto writeOption = bleOutputProperty.compare("withoutResponse") == 0 ? GattWriteOption::WriteWithoutResponse : GattWriteOption::WriteWithResponse;
  auto writeValueStatus = co_await gattCharacteristic.WriteValueAsync(from_bytevc(value), writeOption);
  OutputDebugString((L"WriteValueAsync " + winrt::to_hstring(characteristic) + L", " + winrt::to_hstring(to_hexstring(value)) + L", " + winrt::to_hstring((int32_t)writeValueStatus) + L"\n").c_str());
}

void FlutterBluePlugin::GattCharacteristic_ValueChanged(GattCharacteristic sender, GattValueChangedEventArgs args) {
  auto uuid = to_uuidstr(sender.Uuid());
  auto bytes = to_bytevc(args.CharacteristicValue());
  OutputDebugString((L"GattCharacteristic_ValueChanged " + winrt::to_hstring(uuid) + L", " + winrt::to_hstring(to_hexstring(bytes)) + L"\n").c_str());
  message_connector_->Send(EncodableMap{
    {"deviceId", std::to_string(sender.Service().Device().BluetoothAddress())},
    {"characteristicValue", EncodableMap{
      {"characteristic", uuid},
      {"value", bytes},
    }},
  });
}

}  // namespace

void FlutterBluePluginRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  FlutterBluePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
