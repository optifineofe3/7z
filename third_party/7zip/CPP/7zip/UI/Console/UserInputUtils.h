// UserInputUtils.h

#ifndef ZIP7_INC_USER_INPUT_UTILS_H
#define ZIP7_INC_USER_INPUT_UTILS_H

#include "../../../Common/StdOutStream.h"

namespace NUserAnswerMode {

enum EEnum
{
  kYes,
  kNo,
  kYesAll,
  kNoAll,
  kAutoRenameAll,
  kQuit,
  kEof,
  kError
};
}

NUserAnswerMode::EEnum ScanUserYesNoAllQuit(CStdOutStream *outStream);
// bool GetPassword(CStdOutStream *outStream, UString &psw);
HRESULT GetPassword_HRESULT(CStdOutStream *outStream, UString &psw);

typedef const char* (*SZ_GetPasswordCallback)(int verify);
typedef int (*SZ_ConfirmOverwriteCallback)(const wchar_t* existName, const wchar_t* newName);

extern SZ_GetPasswordCallback g_sz_get_password_callback;
extern SZ_ConfirmOverwriteCallback g_sz_confirm_overwrite_callback;

#endif
