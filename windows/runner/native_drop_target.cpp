#include "native_drop_target.h"

#include <shlobj.h>

#include <flutter/standard_method_codec.h>

#include <fstream>
#include <string>
#include <vector>

namespace {

std::string WideToUtf8(const std::wstring& wide) {
  if (wide.empty()) return std::string();
  int size = ::WideCharToMultiByte(CP_UTF8, 0, wide.data(),
                                    static_cast<int>(wide.size()), nullptr, 0,
                                    nullptr, nullptr);
  std::string result(size, 0);
  ::WideCharToMultiByte(CP_UTF8, 0, wide.data(), static_cast<int>(wide.size()),
                        result.data(), size, nullptr, nullptr);
  return result;
}

// A real file — dragging from Explorer, or a saved image dragged back in.
bool TryGetFileDrop(IDataObject* data_object, std::vector<uint8_t>& out_bytes,
                    std::wstring& out_filename) {
  FORMATETC fmt = {CF_HDROP, nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  if (data_object->QueryGetData(&fmt) != S_OK) return false;

  STGMEDIUM medium;
  if (data_object->GetData(&fmt, &medium) != S_OK) return false;

  bool ok = false;
  if (auto* hdrop = reinterpret_cast<HDROP>(GlobalLock(medium.hGlobal))) {
    if (DragQueryFileW(hdrop, 0xFFFFFFFF, nullptr, 0) > 0) {
      wchar_t path[MAX_PATH];
      if (DragQueryFileW(hdrop, 0, path, MAX_PATH) > 0) {
        std::ifstream file(path, std::ios::binary | std::ios::ate);
        if (file) {
          auto size = file.tellg();
          out_bytes.resize(static_cast<size_t>(size));
          file.seekg(0);
          file.read(reinterpret_cast<char*>(out_bytes.data()), size);
          std::wstring wpath(path);
          auto slash = wpath.find_last_of(L"\\/");
          out_filename =
              slash == std::wstring::npos ? wpath : wpath.substr(slash + 1);
          ok = true;
        }
      }
    }
    GlobalUnlock(medium.hGlobal);
  }
  ReleaseStgMedium(&medium);
  return ok;
}

// A "virtual file" — no file exists on disk; the descriptor gives the name,
// the content arrives live via a stream. This is what Chrome/Edge offer for
// an in-page <img> dragged straight off a webpage.
bool TryGetVirtualFile(IDataObject* data_object,
                       std::vector<uint8_t>& out_bytes,
                       std::wstring& out_filename) {
  static const UINT kFileDescriptorFormat =
      RegisterClipboardFormatW(CFSTR_FILEDESCRIPTORW);
  static const UINT kFileContentsFormat =
      RegisterClipboardFormatW(CFSTR_FILECONTENTS);

  FORMATETC desc_fmt = {static_cast<CLIPFORMAT>(kFileDescriptorFormat),
                        nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  if (data_object->QueryGetData(&desc_fmt) != S_OK) return false;

  STGMEDIUM desc_medium;
  if (data_object->GetData(&desc_fmt, &desc_medium) != S_OK) return false;

  bool ok = false;
  if (auto* ptr = GlobalLock(desc_medium.hGlobal)) {
    auto* group = reinterpret_cast<FILEGROUPDESCRIPTORW*>(ptr);
    if (group->cItems > 0) {
      out_filename = group->fgd[0].cFileName;

      // lindex selects which item (0 = first) — required for
      // CFSTR_FILECONTENTS, unlike most formats where it's ignored.
      FORMATETC content_fmt = {static_cast<CLIPFORMAT>(kFileContentsFormat),
                               nullptr, DVASPECT_CONTENT, 0, TYMED_ISTREAM};
      STGMEDIUM content_medium;
      if (data_object->GetData(&content_fmt, &content_medium) == S_OK) {
        if (content_medium.tymed == TYMED_ISTREAM && content_medium.pstm) {
          STATSTG stat;
          if (SUCCEEDED(
                  content_medium.pstm->Stat(&stat, STATFLAG_NONAME))) {
            ULONGLONG size = stat.cbSize.QuadPart;
            out_bytes.resize(static_cast<size_t>(size));
            ULONG read = 0;
            content_medium.pstm->Read(out_bytes.data(),
                                      static_cast<ULONG>(size), &read);
            out_bytes.resize(read);
            ok = read > 0;
          }
        } else if (content_medium.tymed == TYMED_HGLOBAL) {
          if (auto* data = GlobalLock(content_medium.hGlobal)) {
            SIZE_T size = GlobalSize(content_medium.hGlobal);
            auto* bytes = reinterpret_cast<uint8_t*>(data);
            out_bytes.assign(bytes, bytes + size);
            GlobalUnlock(content_medium.hGlobal);
            ok = true;
          }
        }
        ReleaseStgMedium(&content_medium);
      }
    }
    GlobalUnlock(desc_medium.hGlobal);
  }
  ReleaseStgMedium(&desc_medium);
  return ok;
}

bool HasSupportedFormat(IDataObject* data_object) {
  FORMATETC hdrop_fmt = {CF_HDROP, nullptr, DVASPECT_CONTENT, -1,
                         TYMED_HGLOBAL};
  if (data_object->QueryGetData(&hdrop_fmt) == S_OK) return true;

  static const UINT kFileDescriptorFormat =
      RegisterClipboardFormatW(CFSTR_FILEDESCRIPTORW);
  FORMATETC desc_fmt = {static_cast<CLIPFORMAT>(kFileDescriptorFormat),
                        nullptr, DVASPECT_CONTENT, -1, TYMED_HGLOBAL};
  return data_object->QueryGetData(&desc_fmt) == S_OK;
}

}  // namespace

NativeDropTarget::NativeDropTarget(
    HWND hwnd, flutter::MethodChannel<flutter::EncodableValue>* channel)
    : hwnd_(hwnd), channel_(channel) {}

HRESULT NativeDropTarget::QueryInterface(REFIID riid, void** ppv) {
  if (riid == IID_IUnknown || riid == IID_IDropTarget) {
    *ppv = static_cast<IDropTarget*>(this);
    AddRef();
    return S_OK;
  }
  *ppv = nullptr;
  return E_NOINTERFACE;
}

ULONG NativeDropTarget::AddRef() { return ++ref_count_; }

ULONG NativeDropTarget::Release() {
  ULONG count = --ref_count_;
  if (count == 0) delete this;
  return count;
}

HRESULT NativeDropTarget::DragEnter(IDataObject* data_object,
                                    DWORD key_state, POINTL pt,
                                    DWORD* effect) {
  *effect = HasSupportedFormat(data_object) ? DROPEFFECT_COPY
                                            : DROPEFFECT_NONE;
  channel_->InvokeMethod("dragEntered", nullptr);
  return S_OK;
}

HRESULT NativeDropTarget::DragOver(DWORD key_state, POINTL pt,
                                   DWORD* effect) {
  *effect = DROPEFFECT_COPY;
  return S_OK;
}

HRESULT NativeDropTarget::DragLeave() {
  channel_->InvokeMethod("dragExited", nullptr);
  return S_OK;
}

HRESULT NativeDropTarget::Drop(IDataObject* data_object, DWORD key_state,
                               POINTL pt, DWORD* effect) {
  std::vector<uint8_t> bytes;
  std::wstring filename;

  bool got = TryGetFileDrop(data_object, bytes, filename);
  if (!got) {
    got = TryGetVirtualFile(data_object, bytes, filename);
  }

  if (got && !bytes.empty()) {
    flutter::EncodableMap args;
    args[flutter::EncodableValue("bytes")] = flutter::EncodableValue(bytes);
    args[flutter::EncodableValue("filename")] =
        flutter::EncodableValue(WideToUtf8(filename));
    channel_->InvokeMethod("imageDropped",
                           std::make_unique<flutter::EncodableValue>(args));
  } else {
    channel_->InvokeMethod("dropFailed", nullptr);
  }

  *effect = DROPEFFECT_COPY;
  return S_OK;
}
