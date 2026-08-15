#ifndef RUNNER_NATIVE_DROP_TARGET_H_
#define RUNNER_NATIVE_DROP_TARGET_H_

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <oleidl.h>

// OLE drop target for the desktop companion window. Handles two distinct
// clipboard payloads a dragged-in image can arrive as:
//
//  - CF_HDROP: a real file (dragging from Explorer, or a saved image).
//  - CFSTR_FILEDESCRIPTORW + CFSTR_FILECONTENTS: a "virtual file" — no file
//    exists on disk, the bytes are handed over live via an IStream. This is
//    how Chrome/Edge offer an in-page <img> when you drag it straight off a
//    webpage, which is the primary case this exists for — a browser image
//    drag was silently doing nothing before this, since nothing checked for
//    this format at all.
//
// Bridges to Dart over a MethodChannel rather than exposing COM types.
class NativeDropTarget : public IDropTarget {
 public:
  NativeDropTarget(HWND hwnd,
                   flutter::MethodChannel<flutter::EncodableValue>* channel);

  // IUnknown
  HRESULT __stdcall QueryInterface(REFIID riid, void** ppv) override;
  ULONG __stdcall AddRef() override;
  ULONG __stdcall Release() override;

  // IDropTarget
  HRESULT __stdcall DragEnter(IDataObject* data_object, DWORD key_state,
                              POINTL pt, DWORD* effect) override;
  HRESULT __stdcall DragOver(DWORD key_state, POINTL pt,
                             DWORD* effect) override;
  HRESULT __stdcall DragLeave() override;
  HRESULT __stdcall Drop(IDataObject* data_object, DWORD key_state,
                         POINTL pt, DWORD* effect) override;

 private:
  HWND hwnd_;
  flutter::MethodChannel<flutter::EncodableValue>* channel_;
  ULONG ref_count_ = 1;
};

#endif  // RUNNER_NATIVE_DROP_TARGET_H_
