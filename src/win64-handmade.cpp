/*=========================================================
$File: $
$Data: $
$Revision: $
$Creator: SANTACHAINS $
$Notice: (c) Copyright 2026 pueery, All Rights Reserved. $
==========================================================*/

#include <windows.h>
// #include <winuser.h>

void foo(void) { OutputDebugStringA("This is the first things we actually printed.\n"); }
// int CALLBACK WinMain(
int WINAPI WinMain(HINSTANCE hInstance,     // 当前应用程序实例的句柄
                   HINSTANCE hPrevInstance, // 历史遗留参数，始终为 NULL (0)
                   LPSTR lpCmdLine,         // ANSI 命令行字符串（不包括程序名）
                   int nCmdShow             // 控制窗口如何显示的标志
) {
  return MessageBox(NULL, "This first step for handmade engine and modern cpp game.", "santachains",
                    MB_OK | MB_ICONINFORMATION);
  // foo();
}
