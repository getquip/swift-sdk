//
/****************************************************************************
* Copyright 2019, Optimizely, Inc. and contributors                        *
*                                                                          *
* Licensed under the Apache License, Version 2.0 (the "License");          *
* you may not use this file except in compliance with the License.         *
* You may obtain a copy of the License at                                  *
*                                                                          *
*    http://www.apache.org/licenses/LICENSE-2.0                            *
*                                                                          *
* Unless required by applicable law or agreed to in writing, software      *
* distributed under the License is distributed on an "AS IS" BASIS,        *
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. *
* See the License for the specific language governing permissions and      *
* limitations under the License.                                           *
***************************************************************************/

#ifdef __APPLE__
#ifdef TARGET_OS_IPHONE
// iOS
#elif TARGET_IPHONE_SIMULATOR
// iOS Simulator
#elif TARGET_OS_MAC
// Other kinds of Mac OS
#import <Cocoa/Cocoa.h>
//! Project version number for OptimizelySwiftSDK_mac.
FOUNDATION_EXPORT double OptimizelySwiftSDK_macVersionNumber;

//! Project version string for OptimizelySwiftSDK_mac.
FOUNDATION_EXPORT const unsigned char OptimizelySwiftSDK_macVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <OptimizelySwiftSDK_mac/PublicHeader.h>
#else
// Unsupported platform
#endif
#endif


