#include <ApplicationServices/ApplicationServices.h>
#include <CoreGraphics/CoreGraphics.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static bool copy_window_geometry(AXUIElementRef window, CGPoint *position, CGSize *size) {
  AXValueRef position_value = NULL;
  AXValueRef size_value = NULL;

  if (AXUIElementCopyAttributeValue(
        window,
        kAXPositionAttribute,
        (CFTypeRef *)&position_value
      ) != kAXErrorSuccess || position_value == NULL) {
    return false;
  }

  if (AXUIElementCopyAttributeValue(
        window,
        kAXSizeAttribute,
        (CFTypeRef *)&size_value
      ) != kAXErrorSuccess || size_value == NULL) {
    CFRelease(position_value);
    return false;
  }

  bool valid = AXValueGetValue(position_value, kAXValueCGPointType, position) &&
               AXValueGetValue(size_value, kAXValueCGSizeType, size);
  CFRelease(position_value);
  CFRelease(size_value);
  return valid;
}

static CGRect display_bounds_for_window(CGPoint position, CGSize size) {
  CGPoint window_center = CGPointMake(
    position.x + size.width / 2.0,
    position.y + size.height / 2.0
  );
  uint32_t display_count = 0;

  if (CGGetActiveDisplayList(0, NULL, &display_count) != kCGErrorSuccess ||
      display_count == 0) {
    return CGDisplayBounds(CGMainDisplayID());
  }

  CGDirectDisplayID *displays = calloc(display_count, sizeof(*displays));
  if (displays == NULL) {
    return CGDisplayBounds(CGMainDisplayID());
  }

  if (CGGetActiveDisplayList(display_count, displays, &display_count) != kCGErrorSuccess) {
    free(displays);
    return CGDisplayBounds(CGMainDisplayID());
  }

  CGRect selected_bounds = CGDisplayBounds(CGMainDisplayID());
  for (uint32_t index = 0; index < display_count; index += 1) {
    CGRect candidate_bounds = CGDisplayBounds(displays[index]);
    if (CGRectContainsPoint(candidate_bounds, window_center)) {
      selected_bounds = candidate_bounds;
      break;
    }
  }

  free(displays);
  return selected_bounds;
}

int main(int argc, char **argv) {
  if (argc == 2 && strcmp(argv[1], "--check-permission") == 0) {
    return AXIsProcessTrusted() ? EXIT_SUCCESS : 2;
  }

  AXUIElementRef system_wide = AXUIElementCreateSystemWide();
  AXUIElementRef focused_application = NULL;
  AXUIElementRef focused_window = NULL;
  CGPoint position;
  CGSize size;
  int result = EXIT_FAILURE;

  if (system_wide == NULL) {
    return result;
  }

  if (AXUIElementCopyAttributeValue(
        system_wide,
        kAXFocusedApplicationAttribute,
        (CFTypeRef *)&focused_application
      ) != kAXErrorSuccess || focused_application == NULL) {
    goto cleanup;
  }

  if (AXUIElementCopyAttributeValue(
        focused_application,
        kAXFocusedWindowAttribute,
        (CFTypeRef *)&focused_window
      ) != kAXErrorSuccess || focused_window == NULL) {
    goto cleanup;
  }

  if (!copy_window_geometry(focused_window, &position, &size)) {
    goto cleanup;
  }

  CGRect display_bounds = display_bounds_for_window(position, size);
  CGPoint centered_position = CGPointMake(
    CGRectGetMinX(display_bounds) + (CGRectGetWidth(display_bounds) - size.width) / 2.0,
    CGRectGetMinY(display_bounds) + (CGRectGetHeight(display_bounds) - size.height) / 2.0
  );
  AXValueRef centered_value = AXValueCreate(kAXValueCGPointType, &centered_position);
  if (centered_value == NULL) {
    goto cleanup;
  }

  if (AXUIElementSetAttributeValue(
        focused_window,
        kAXPositionAttribute,
        centered_value
      ) == kAXErrorSuccess) {
    result = EXIT_SUCCESS;
  }
  CFRelease(centered_value);

cleanup:
  if (focused_window != NULL) {
    CFRelease(focused_window);
  }
  if (focused_application != NULL) {
    CFRelease(focused_application);
  }
  CFRelease(system_wide);
  return result;
}
