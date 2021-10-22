//
//  build.h
//  GhostReader
//
//  Created by 佐山 隆裕 on 11/12/31.
//  Copyright (c) 2011年 tanuki-project. All rights reserved.
//

#ifndef SyntheForex_common_h
#define SyntheForex_common_h

#pragma mark Enable NSLog

#if !defined(NS_BLOCK_ASSERTIONS)

#if !defined(NSLog)
#define NSLog( m, args... ) NSLog( m, ##args )
#endif

#else

#if !defined(NSLog)
#define NSLog( m, args... )
#endif

#endif

#endif
