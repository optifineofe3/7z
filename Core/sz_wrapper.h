//
//  sz_wrapper.h
//  7Zip Core iOS Wrapper
//

#ifndef SZ_WRAPPER_H
#define SZ_WRAPPER_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Standard 7-Zip Exit Codes
#define SZ_OK               0   // Successful operation
#define SZ_WARNING          1   // Non fatal error(s) (e.g. locked files or missing files)
#define SZ_FATAL_ERROR      2   // Fatal error
#define SZ_CMDLINE_ERROR    7   // Command line error
#define SZ_NOT_ENOUGH_MEM   8   // Not enough memory
#define SZ_USER_STOPPED     255 // Process was stopped by user

// Overwrite answer choices for confirm_overwrite
#define SZ_OVERWRITE_YES         0
#define SZ_OVERWRITE_NO          1
#define SZ_OVERWRITE_YES_ALL     2
#define SZ_OVERWRITE_NO_ALL      3
#define SZ_OVERWRITE_AUTO_RENAME 4
#define SZ_OVERWRITE_CANCEL      5

// Progress reporting structure
typedef struct sz_progress_info {
    uint64_t completed_bytes;
    uint64_t total_bytes;
    uint64_t completed_files;
    const char* current_file;
    double speed_bytes_per_sec;
    double remaining_seconds;
    double percent; // 0.0 to 100.0
} sz_progress_info;

// Callbacks passed to sz_run / sz_run_async
typedef struct sz_callbacks {
    void* user_data;
    
    // Real-time progress update
    void (*on_progress)(const sz_progress_info* info, void* user_data);
    
    // Log lines emitted by 7-Zip (info, file listings, stats)
    void (*on_log)(const char* line, void* user_data);
    
    // Error or warning message
    void (*on_error)(const char* message, int is_warning, void* user_data);
    
    // Password prompt callback (return UTF-8 string or NULL to cancel)
    const char* (*get_password)(int verify, void* user_data);
    
    // Overwrite prompt callback (return SZ_OVERWRITE_*)
    int (*confirm_overwrite)(const char* existing_file, const char* new_file, void* user_data);
    
    // Completion callback
    void (*on_complete)(int exit_code, void* user_data);
} sz_callbacks;

// Initialize UTF-8 locale once at process launch
void sz_init_locale(void);

// Run 7-Zip command synchronously on the caller's thread
int sz_run(int argc, const char* const* argv, const sz_callbacks* cb);

// Run 7-Zip command asynchronously on a dedicated thread with an 8MB stack
int sz_run_async(int argc, const char* const* argv, const sz_callbacks* cb);

// Safely request cancellation of the active operation
void sz_cancel(void);

// Check if cancellation has been requested
int sz_is_cancelled(void);

// Safe available memory budget via os_proc_available_memory() (or fallback)
uint64_t sz_get_available_memory(void);

// Formats recommended memory usage switch into buf (e.g. "-mmemuse=600m")
void sz_get_safe_memuse_switch(char* buf, size_t buf_len, double margin_fraction);

// Get English error description for exit code
const char* sz_get_error_message(int exit_code, int is_russian);

#ifdef __cplusplus
}
#endif

#endif // SZ_WRAPPER_H
