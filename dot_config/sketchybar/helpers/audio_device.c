#include <AudioToolbox/AudioHardwareService.h>
#include <CoreAudio/CoreAudio.h>
#include <CoreFoundation/CoreFoundation.h>
#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int contains_case_insensitive(const char *text, const char *needle) {
  size_t text_length = strlen(text);
  size_t needle_length = strlen(needle);

  if (needle_length == 0 || needle_length > text_length) {
    return 0;
  }

  for (size_t offset = 0; offset <= text_length - needle_length; offset++) {
    size_t index = 0;
    while (index < needle_length &&
           tolower((unsigned char)text[offset + index]) ==
             tolower((unsigned char)needle[index])) {
      index++;
    }
    if (index == needle_length) {
      return 1;
    }
  }

  return 0;
}

int main(void) {
  AudioObjectPropertyAddress address = {
    kAudioHardwarePropertyDefaultOutputDevice,
    kAudioObjectPropertyScopeGlobal,
    kAudioObjectPropertyElementMain,
  };
  AudioDeviceID device_id = kAudioObjectUnknown;
  UInt32 size = sizeof(device_id);

  OSStatus status = AudioObjectGetPropertyData(
    kAudioObjectSystemObject, &address, 0, NULL, &size, &device_id
  );
  if (status != noErr || device_id == kAudioObjectUnknown) {
    fprintf(stderr, "unknown\tAudio output unavailable\n");
    return 1;
  }

  CFStringRef device_name_ref = NULL;
  address.mSelector = kAudioObjectPropertyName;
  size = sizeof(device_name_ref);
  status = AudioObjectGetPropertyData(
    device_id, &address, 0, NULL, &size, &device_name_ref
  );

  char device_name[512] = "Unknown output";
  if (status == noErr && device_name_ref != NULL) {
    CFStringGetCString(
      device_name_ref, device_name, sizeof(device_name), kCFStringEncodingUTF8
    );
    CFRelease(device_name_ref);
  }

  UInt32 transport = 0;
  address.mSelector = kAudioDevicePropertyTransportType;
  size = sizeof(transport);
  AudioObjectGetPropertyData(device_id, &address, 0, NULL, &size, &transport);

  const char *output_class = "speaker";
  if (contains_case_insensitive(device_name, "headphone") ||
      contains_case_insensitive(device_name, "headset") ||
      contains_case_insensitive(device_name, "airpods") ||
      contains_case_insensitive(device_name, "beats")) {
    output_class = "headphones";
  } else if (transport == kAudioDeviceTransportTypeBluetooth ||
             transport == kAudioDeviceTransportTypeBluetoothLE) {
    output_class = "bluetooth";
  } else if (transport == kAudioDeviceTransportTypeHDMI ||
             transport == kAudioDeviceTransportTypeDisplayPort) {
    output_class = "display";
  } else if (transport == kAudioDeviceTransportTypeBuiltIn &&
             contains_case_insensitive(device_name, "speaker")) {
    output_class = "speakers";
  }

  Float32 volume_scalar = -1.0f;
  address.mSelector = kAudioHardwareServiceDeviceProperty_VirtualMainVolume;
  address.mScope = kAudioObjectPropertyScopeOutput;
  size = sizeof(volume_scalar);
  AudioObjectGetPropertyData(
    device_id, &address, 0, NULL, &size, &volume_scalar
  );

  UInt32 muted = 0;
  address.mSelector = kAudioDevicePropertyMute;
  size = sizeof(muted);
  AudioObjectGetPropertyData(device_id, &address, 0, NULL, &size, &muted);

  int volume_percent = volume_scalar >= 0.0f
    ? (int)lroundf(volume_scalar * 100.0f)
    : -1;
  printf(
    "%s\t%s\t%d\t%u\n",
    output_class,
    device_name,
    volume_percent,
    muted
  );
  return 0;
}
