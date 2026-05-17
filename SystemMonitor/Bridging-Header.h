#ifndef Bridging_Header_h
#define Bridging_Header_h

#import <Foundation/Foundation.h>
#import <mach/mach.h>

typedef mach_port_t io_object_t;
typedef io_object_t io_registry_entry_t;
typedef io_object_t io_service_t;
typedef io_object_t io_connect_t;
typedef io_object_t io_iterator_t;
typedef char io_name_t[128];
typedef char io_string_t[512];

extern const mach_port_t kIOMasterPortDefault;
CFMutableDictionaryRef IOServiceMatching(const char *name);
io_service_t IOServiceGetMatchingService(mach_port_t masterPort, CFDictionaryRef matching);
CFTypeRef IORegistryEntryCreateCFProperty(io_registry_entry_t entry, CFStringRef key, CFAllocatorRef allocator, uint32_t options) CF_RETURNS_RETAINED;
kern_return_t IOObjectRelease(io_object_t object);

#endif /* Bridging_Header_h */
