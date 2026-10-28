//
//  smoke_test.cpp
//  Smoke test for 7-Zip Core roundtrip: 7z (LZMA2 + header encryption) and zip (AES)
//

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>
#include "../Core/sz_wrapper.h"

static void dummy_progress(const sz_progress_info* info, void* ud) {
    (void)ud;
    if (info && info->percent > 0.0) {
        // printf("[Progress] %.1f%% - %s\n", info->percent, info->current_file ? info->current_file : "");
    }
}

static void dummy_log(const char* line, void* ud) {
    (void)ud;
    printf("[7-Zip Log] %s\n", line);
}

static void dummy_error(const char* message, int is_warning, void* ud) {
    (void)ud;
    fprintf(stderr, "[7-Zip %s] %s\n", is_warning ? "Warning" : "ERROR", message);
}

static int run_cmd(int argc, const char* argv[]) {
    sz_callbacks cb;
    memset(&cb, 0, sizeof(cb));
    cb.on_progress = dummy_progress;
    cb.on_log = dummy_log;
    cb.on_error = dummy_error;

    printf("\n=== Running 7-Zip command: ===");
    for (int i = 0; i < argc; ++i) {
        printf(" %s", argv[i]);
    }
    printf("\n");

    return sz_run(argc, argv, &cb);
}

static void create_test_file(const char* path, const char* content) {
    FILE* f = fopen(path, "wb");
    if (!f) {
        fprintf(stderr, "Cannot create test file %s\n", path);
        exit(1);
    }
    fwrite(content, 1, strlen(content), f);
    fclose(f);
}

static int verify_file_content(const char* path, const char* expected) {
    FILE* f = fopen(path, "rb");
    if (!f) {
        fprintf(stderr, "Missing extracted file %s\n", path);
        return 0;
    }
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);

    char* buf = (char*)malloc(len + 1);
    fread(buf, 1, len, f);
    buf[len] = '\0';
    fclose(f);

    int match = (strcmp(buf, expected) == 0);
    free(buf);
    return match;
}

int main() {
    printf("--- Starting 7-Zip Core Smoke Test ---\n");

    // Clean previous test artifacts
    system("rm -rf test_env");
    mkdir("test_env", 0755);

    const char* sample_text_1 = "7-Zip iOS Port: Pristine Core Verification 2026. UTF-8 Тестовые данные на русском языке 🚀📦.";
    const char* sample_text_2 = "Another sample payload with numbers 1234567890 and symbols !@#$%^&*()_+";

    create_test_file("test_env/sample1.txt", sample_text_1);
    create_test_file("test_env/sample2.txt", sample_text_2);

    // Save current working directory
    char orig_cwd[1024];
    if (!getcwd(orig_cwd, sizeof(orig_cwd))) {
        strcpy(orig_cwd, ".");
    }

    if (chdir("test_env") != 0) {
        fprintf(stderr, "Cannot chdir to test_env\n");
        return 1;
    }

    // 1. Test 7z roundtrip with LZMA2, mx=7, md=64m, mhe=on, password
    {
        printf("\n>>> Test 1: 7z format (LZMA2, mx=7, md=64m, mhe=on, password)\n");
        const char* compress_args[] = {
            "7zz", "a", "test.7z", "sample1.txt", "sample2.txt",
            "-m0=lzma2", "-mx=7", "-md=64m", "-mhe=on", "-pTestSecretKey123", "-y"
        };
        int code = run_cmd(11, compress_args);
        if (code != SZ_OK) {
            fprintf(stderr, "Test 1 7z compression failed with code: %d\n", code);
            return 1;
        }

        const char* extract_args[] = {
            "7zz", "x", "test.7z", "-oout_7z", "-pTestSecretKey123", "-y"
        };
        code = run_cmd(6, extract_args);
        if (code != SZ_OK) {
            fprintf(stderr, "Test 1 7z extraction failed with code: %d\n", code);
            return 1;
        }

        if (!verify_file_content("out_7z/sample1.txt", sample_text_1) ||
            !verify_file_content("out_7z/sample2.txt", sample_text_2)) {
            fprintf(stderr, "Test 1 file content mismatch after 7z extraction!\n");
            return 1;
        }
        printf("[OK] Test 1: 7z roundtrip passed perfectly.\n");
    }

    // 2. Test ZIP roundtrip with AES encryption
    {
        printf("\n>>> Test 2: ZIP format with AES encryption\n");
        const char* compress_args[] = {
            "7zz", "a", "test.zip", "sample1.txt", "sample2.txt",
            "-tzip", "-mem=AES256", "-pZipSecretPass456", "-y"
        };
        int code = run_cmd(9, compress_args);
        if (code != SZ_OK) {
            fprintf(stderr, "Test 2 ZIP compression failed with code: %d\n", code);
            return 1;
        }

        const char* extract_args[] = {
            "7zz", "x", "test.zip", "-oout_zip", "-pZipSecretPass456", "-y"
        };
        code = run_cmd(6, extract_args);
        if (code != SZ_OK) {
            fprintf(stderr, "Test 2 ZIP extraction failed with code: %d\n", code);
            return 1;
        }

        if (!verify_file_content("out_zip/sample1.txt", sample_text_1) ||
            !verify_file_content("out_zip/sample2.txt", sample_text_2)) {
            fprintf(stderr, "Test 2 file content mismatch after ZIP extraction!\n");
            return 1;
        }
        printf("[OK] Test 2: ZIP AES roundtrip passed perfectly.\n");
    }

    // 3. Test Benchmark command (b 1)
    {
        printf("\n>>> Test 3: Benchmark command (b 1)\n");
        const char* bench_args[] = { "7zz", "b", "1" };
        int code = run_cmd(3, bench_args);
        if (code != SZ_OK) {
            fprintf(stderr, "Benchmark failed with code: %d\n", code);
            return 1;
        }
        printf("[OK] Test 3: Benchmark passed.\n");
    }

    // 4. Test Info command (i)
    {
        printf("\n>>> Test 4: Info command (i)\n");
        const char* info_args[] = { "7zz", "i" };
        int code = run_cmd(2, info_args);
        if (code != SZ_OK) {
            fprintf(stderr, "Info failed with code: %d\n", code);
            return 1;
        }
        printf("[OK] Test 4: Info command passed.\n");
    }

    // Restore working directory
    chdir(orig_cwd);
    system("rm -rf test_env");

    printf("\n=========================================\n");
    printf("   ALL 7-ZIP CORE SMOKE TESTS PASSED!    \n");
    printf("=========================================\n");
    return 0;
}
