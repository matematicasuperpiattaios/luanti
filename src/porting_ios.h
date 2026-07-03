// Luanti
// SPDX-License-Identifier: LGPL-2.1-or-later
// Copyright (C) 2025 SFENCE <sfence.software@gmail.com>

#include <string>

namespace porting
{

std::string getAppleDocumentsDirectory();
std::string getAppleLibraryDirectory();
std::string getAppleCacheDirectory();

// Open a URL in the default browser via UIApplication. Returns false only if
// the URL string is malformed; the open itself happens asynchronously.
bool openURLApple(const std::string &url);

}
