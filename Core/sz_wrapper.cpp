//
//  sz_wrapper.cpp
//  7Zip Core iOS Wrapper implementation
//

#include "sz_wrapper.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <locale.h>
#include <pthread.h>
#include <time.h>
#include <string>
#include <vector>

#if defined(__APPLE__)
#include <TargetConditionals.h>
#if TARGET_OS_IPHONE
#include <os/proc.h>
#endif
#include <sys/sysctl.h>
#endif

// 7-Zip internal headers
#include "../third_party/7zip/CPP/Common/MyWindows.h"
#include "../third_party/7zip/CPP/Common/MyException.h"
#include "../third_party/7zip/CPP/Common/StdOutStream.h"
#include "../third_party/7zip/CPP/Common/StringConvert.h"
#include "../third_party/7zip/CPP/Common/UTFConvert.h"
#include "../third_party/7zip/CPP/Windows/ErrorMsg.h"
#include "../third_party/7zip/CPP/7zip/UI/Common/ExitCode.h"
#include "../third_party/7zip/CPP/7zip/UI/Common/ArchiveCommandLine.h"
#include "../third_party/7zip/CPP/7zip/UI/Console/ConsoleClose.h"
#include "../third_party/7zip/CPP/7zip/UI/Console/PercentPrinter.h"
#include "../third_party/7zip/CPP/7zip/UI/Console/UserInputUtils.h"

// Forward declaration of 7-Zip Main2 entrypoint in UI/Console/Main.cpp
extern int Main2(int numArgs, char *args[]);

// Global stream pointers required by 7-Zip console modules
extern CStdOutStream *g_StdStream;
extern CStdOutStream *g_ErrStream;

CStdOutStream *g_StdStream = NULL;
CStdOutStream *g_ErrStream = NULL;

namespace {

struct StreamBuffer {
    const sz_callbacks* callbacks;
    bool is_error;
    std::string line_buffer;
    pthread_mutex_t lock;

    StreamBuffer(const sz_callbacks* cb, bool err) : callbacks(cb), is_error(err) {
        pthread_mutex_init(&lock, NULL);
    }
    ~StreamBuffer() {
        flush();
        pthread_mutex_destroy(&lock);
    }

    void append(const char* data, size_t len) {
        pthread_mutex_lock(&lock);
        for (size_t i = 0; i < len; ++i) {
            char c = data[i];
            if (c == '\r') {
                continue;
            }
            if (c == '\n') {
                emit_line(line_buffer);
                line_buffer.clear();
            } else {
                line_buffer.push_back(c);
            }
        }
        pthread_mutex_unlock(&lock);
    }

    void flush() {
        pthread_mutex_lock(&lock);
        if (!line_buffer.empty()) {
            emit_line(line_buffer);
            line_buffer.clear();
        }
        pthread_mutex_unlock(&lock);
    }

private:
    void emit_line(const std::string& line) {
        if (!callbacks) return;
        if (is_error) {
            if (callbacks->on_error) {
                callbacks->on_error(line.c_str(), 0, callbacks->user_data);
            }
        } else {
            if (callbacks->on_log) {
                callbacks->on_log(line.c_str(), callbacks->user_data);
            }
        }
    }
};

#if defined(__APPLE__)
static int custom_write(void* cookie, const char* buf, int size) {
    if (!cookie || size <= 0) return size;
    StreamBuffer* sb = static_cast<StreamBuffer*>(cookie);
    sb->append(buf, (size_t)size);
    return size;
}

static FILE* create_callback_file(StreamBuffer* sb) {
    return funopen(sb, NULL, custom_write, NULL, NULL);
}
#else
static FILE* create_callback_file(StreamBuffer* sb) {
    (void)sb;
    return stdout;
}
#endif

// State for active run
static const sz_callbacks* g_active_cb = NULL;
static pthread_mutex_t g_cb_mutex = PTHREAD_MUTEX_INITIALIZER;
static double g_start_time_sec = 0.0;

static double get_current_time_sec() {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

static void progress_bridge(UInt64 completed, UInt64 total, UInt64 files, const wchar_t* fileName) {
    pthread_mutex_lock(&g_cb_mutex);
    const sz_callbacks* cb = g_active_cb;
    if (!cb || !cb->on_progress) {
        pthread_mutex_unlock(&g_cb_mutex);
        return;
    }

    sz_progress_info info;
    info.completed_bytes = completed;
    info.total_bytes = total;
    info.completed_files = files;

    std::string utf8_name;
    if (fileName && fileName[0]) {
        UString u(fileName);
        AString a;
        ConvertUnicodeToUTF8(u, a);
        utf8_name = a.Ptr();
    }
    info.current_file = utf8_name.c_str();

    double now = get_current_time_sec();
    double elapsed = now - g_start_time_sec;
    if (elapsed > 0.05 && completed > 0) {
        info.speed_bytes_per_sec = (double)completed / elapsed;
        if (total > completed && info.speed_bytes_per_sec > 0.0) {
            info.remaining_seconds = (double)(total - completed) / info.speed_bytes_per_sec;
        } else {
            info.remaining_seconds = 0.0;
        }
    } else {
        info.speed_bytes_per_sec = 0.0;
        info.remaining_seconds = 0.0;
    }

    if (total > 0 && total != (UInt64)(Int64)-1) {
        info.percent = ((double)completed / (double)total) * 100.0;
        if (info.percent > 100.0) info.percent = 100.0;
    } else {
        info.percent = 0.0;
    }

    cb->on_progress(&info, cb->user_data);
    pthread_mutex_unlock(&g_cb_mutex);
}

static const char* password_bridge(int verify) {
    pthread_mutex_lock(&g_cb_mutex);
    const sz_callbacks* cb = g_active_cb;
    pthread_mutex_unlock(&g_cb_mutex);

    if (cb && cb->get_password) {
        return cb->get_password(verify, cb->user_data);
    }
    return NULL;
}

static int overwrite_bridge(const wchar_t* existName, const wchar_t* newName) {
    pthread_mutex_lock(&g_cb_mutex);
    const sz_callbacks* cb = g_active_cb;
    pthread_mutex_unlock(&g_cb_mutex);

    if (!cb || !cb->confirm_overwrite) {
        return SZ_OVERWRITE_YES_ALL;
    }

    std::string exist_str;
    if (existName) {
        UString u(existName);
        AString a;
        ConvertUnicodeToUTF8(u, a);
        exist_str = a.Ptr();
    }

    std::string new_str;
    if (newName) {
        UString u(newName);
        AString a;
        ConvertUnicodeToUTF8(u, a);
        new_str = a.Ptr();
    }

    return cb->confirm_overwrite(exist_str.c_str(), new_str.c_str(), cb->user_data);
}

struct AsyncThreadArgs {
    std::vector<std::string> args;
    sz_callbacks callbacks;
};

static void* async_worker_thread(void* arg) {
    AsyncThreadArgs* a = static_cast<AsyncThreadArgs*>(arg);
    std::vector<const char*> argv_ptrs;
    argv_ptrs.reserve(a->args.size());
    for (size_t i = 0; i < a->args.size(); ++i) {
        argv_ptrs.push_back(a->args[i].c_str());
    }

    sz_run((int)argv_ptrs.size(), argv_ptrs.data(), &a->callbacks);
    delete a;
    return NULL;
}

} // namespace

int sz_run(int argc, const char* const* argv, const sz_callbacks* cb) {
    // 1. Force UTF-8 environment
    setlocale(LC_ALL, "UTF-8");

    // 2. Setup callbacks
    pthread_mutex_lock(&g_cb_mutex);
    g_active_cb = cb;
    g_start_time_sec = get_current_time_sec();
    NConsoleClose::g_BreakCounter = 0;
    g_sz_progress_callback = progress_bridge;
    g_sz_get_password_callback = password_bridge;
    g_sz_confirm_overwrite_callback = overwrite_bridge;
    pthread_mutex_unlock(&g_cb_mutex);

    // 3. Setup output stream redirection
    StreamBuffer out_buf(cb, false);
    StreamBuffer err_buf(cb, true);

#if defined(__APPLE__)
    FILE* out_file = create_callback_file(&out_buf);
    FILE* err_file = create_callback_file(&err_buf);
    CStdOutStream custom_stdout(out_file);
    CStdOutStream custom_stderr(err_file);
    g_StdStream = &custom_stdout;
    g_ErrStream = &custom_stderr;
#else
    g_StdStream = &g_StdOut;
    g_ErrStream = &g_StdErr;
#endif

    // Make local copy of argument pointers for Main2
    std::vector<char*> arg_copies;
    arg_copies.reserve((size_t)argc);
    for (int i = 0; i < argc; ++i) {
        arg_copies.push_back(const_cast<char*>(argv[i]));
    }

    int res = SZ_OK;

    // 4. In-process invocation with exception harness
    try {
        res = Main2(argc, arg_copies.data());
    }
    catch (const CNewException &) {
        if (cb && cb->on_error) {
            cb->on_error("Can't allocate required memory", 0, cb->user_data);
        }
        res = SZ_NOT_ENOUGH_MEM;
    }
    catch (const CMessagePathException &e) {
        AString a;
        ConvertUnicodeToUTF8(e, a);
        if (cb && cb->on_error) {
            cb->on_error(a.Ptr(), 0, cb->user_data);
        }
        res = SZ_CMDLINE_ERROR;
    }
    catch (const CSystemException &se) {
        if (se.ErrorCode == E_OUTOFMEMORY) {
            res = SZ_NOT_ENOUGH_MEM;
        } else if (se.ErrorCode == E_ABORT) {
            res = SZ_USER_STOPPED;
        } else {
            if (cb && cb->on_error) {
                UString errU = NWindows::NError::MyFormatMessage(se.ErrorCode);
                AString errA;
                ConvertUnicodeToUTF8(errU, errA);
                cb->on_error(errA.Ptr(), 0, cb->user_data);
            }
            res = SZ_FATAL_ERROR;
        }
    }
    catch (NExitCode::EEnum exitCode) {
        res = (int)exitCode;
    }
    catch (const UString &s) {
        AString a;
        ConvertUnicodeToUTF8(s, a);
        if (cb && cb->on_error) {
            cb->on_error(a.Ptr(), 0, cb->user_data);
        }
        res = SZ_FATAL_ERROR;
    }
    catch (const AString &s) {
        if (cb && cb->on_error) {
            cb->on_error(s.Ptr(), 0, cb->user_data);
        }
        res = SZ_FATAL_ERROR;
    }
    catch (const char *s) {
        if (cb && cb->on_error) {
            cb->on_error(s, 0, cb->user_data);
        }
        res = SZ_FATAL_ERROR;
    }
    catch (const std::exception &e) {
        if (cb && cb->on_error) {
            cb->on_error(e.what(), 0, cb->user_data);
        }
        res = SZ_FATAL_ERROR;
    }
    catch (...) {
        if (cb && cb->on_error) {
            cb->on_error("Internal unhandled error", 0, cb->user_data);
        }
        res = SZ_FATAL_ERROR;
    }

    // Check if cancellation occurred
    if (NConsoleClose::TestBreakSignal()) {
        res = SZ_USER_STOPPED;
    }

    // 5. Cleanup streams
    out_buf.flush();
    err_buf.flush();

#if defined(__APPLE__)
    if (out_file) fclose(out_file);
    if (err_file) fclose(err_file);
#endif
    g_StdStream = NULL;
    g_ErrStream = NULL;

    // 6. Reset global hooks
    pthread_mutex_lock(&g_cb_mutex);
    g_sz_progress_callback = NULL;
    g_sz_get_password_callback = NULL;
    g_sz_confirm_overwrite_callback = NULL;
    g_active_cb = NULL;
    pthread_mutex_unlock(&g_cb_mutex);

    // 7. Completion callback
    if (cb && cb->on_complete) {
        cb->on_complete(res, cb->user_data);
    }

    return res;
}

int sz_run_async(int argc, const char* const* argv, const sz_callbacks* cb) {
    AsyncThreadArgs* args = new AsyncThreadArgs();
    args->args.reserve((size_t)argc);
    for (int i = 0; i < argc; ++i) {
        args->args.push_back(argv[i]);
    }
    if (cb) {
        args->callbacks = *cb;
    } else {
        memset(&args->callbacks, 0, sizeof(args->callbacks));
    }

    pthread_t th;
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    // iOS stack size minimum 8 MB as required by Section 2.3
    pthread_attr_setstacksize(&attr, 8 * 1024 * 1024);

    int err = pthread_create(&th, &attr, async_worker_thread, args);
    pthread_attr_destroy(&attr);

    if (err != 0) {
        delete args;
        return err;
    }

    pthread_detach(th);
    return 0;
}

void sz_cancel(void) {
    NConsoleClose::g_BreakCounter = 1;
}

int sz_is_cancelled(void) {
    return NConsoleClose::TestBreakSignal() ? 1 : 0;
}

uint64_t sz_get_available_memory(void) {
#if defined(__APPLE__)
#if TARGET_OS_IPHONE
    if (__builtin_available(iOS 13.0, tvOS 13.0, watchOS 6.0, *)) {
        size_t avail = os_proc_available_memory();
        if (avail > 0) return (uint64_t)avail;
    }
#endif
    int mib[2] = { CTL_HW, HW_MEMSIZE };
    uint64_t total = 0;
    size_t len = sizeof(total);
    if (sysctl(mib, 2, &total, &len, NULL, 0) == 0 && total > 0) {
        return total / 2; // conservative estimate 50%
    }
#endif
    return 1024ULL * 1024 * 1024; // 1 GB fallback
}

void sz_get_safe_memuse_switch(char* buf, size_t buf_len, double margin_fraction) {
    if (!buf || buf_len < 16) return;
    if (margin_fraction <= 0.0 || margin_fraction >= 1.0) {
        margin_fraction = 0.70; // 70% of available memory
    }

    uint64_t avail = sz_get_available_memory();
    uint64_t safe_bytes = (uint64_t)((double)avail * margin_fraction);
    uint64_t safe_mb = safe_bytes / (1024 * 1024);
    if (safe_mb < 32) safe_mb = 32;

    snprintf(buf, buf_len, "-mmemuse=%llum", (unsigned long long)safe_mb);
}

const char* sz_get_error_message(int exit_code, int is_russian) {
    if (is_russian) {
        switch (exit_code) {
            case SZ_OK:
                return "Операция успешно завершена (Ошибок нет)";
            case SZ_WARNING:
                return "Предупреждение: некоторые файлы заблокированы, пропущены или изменены во время архивации";
            case SZ_FATAL_ERROR:
                return "Критическая ошибка: повреждённый архив, неверный пароль или сбой диска/памяти";
            case SZ_CMDLINE_ERROR:
                return "Ошибка параметров командной строки: некорректный ключ или неподдерживаемый формат";
            case SZ_NOT_ENOUGH_MEM:
                return "Недостаточно памяти для операции (превышен лимит Jetsam)";
            case SZ_USER_STOPPED:
                return "Операция отменена пользователем";
            default:
                return "Неизвестная ошибка";
        }
    } else {
        switch (exit_code) {
            case SZ_OK:
                return "Operation completed successfully (No errors)";
            case SZ_WARNING:
                return "Warning: non-fatal error(s) occurred (files locked or missing)";
            case SZ_FATAL_ERROR:
                return "Fatal error: corrupted archive, wrong password, or disk/memory fault";
            case SZ_CMDLINE_ERROR:
                return "Command line error: invalid switch syntax or unsupported format";
            case SZ_NOT_ENOUGH_MEM:
                return "Not enough memory for operation (Jetsam budget exceeded)";
            case SZ_USER_STOPPED:
                return "Operation cancelled by user";
            default:
                return "Unknown error";
        }
    }
}
